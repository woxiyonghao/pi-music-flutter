import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/native_music_library.dart';

void main() {
  late Directory sandbox;
  late String database;
  late String music;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('hifi-database-audit-');
    sandbox = Directory(sandbox.resolveSymbolicLinksSync());
    database = '${sandbox.path}/library.db';
    music = '${sandbox.path}/Documents';
    Directory(music).createSync();
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  File wav(String path, {int seconds = 2}) {
    final bytes = Uint8List(44 + 44100 * 4 * seconds);
    final header = ByteData.sublistView(bytes);
    void text(int offset, String value) =>
        bytes.setRange(offset, offset + value.length, value.codeUnits);
    text(0, 'RIFF');
    header.setUint32(4, bytes.length - 8, Endian.little);
    text(8, 'WAVEfmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 2, Endian.little);
    header.setUint32(24, 44100, Endian.little);
    header.setUint32(28, 176400, Endian.little);
    header.setUint16(32, 4, Endian.little);
    header.setUint16(34, 16, Endian.little);
    text(36, 'data');
    header.setUint32(40, bytes.length - 44, Endian.little);
    return File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }

  Future<void> scan(List<String> roots, {bool partial = false}) async {
    await NativeMusicLibrary.scan(
        database: database, roots: roots, documents: music, partial: partial);
  }

  void healthy(Database db) {
    expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
    expect(db.select('PRAGMA foreign_key_check'), isEmpty);
    expect(db.select('''SELECT pt.track_id FROM playlist_tracks pt
          LEFT JOIN scanned_tracks t ON t.id = pt.track_id
          LEFT JOIN playlists p ON p.id = pt.playlist_id
          WHERE t.id IS NULL OR p.id IS NULL'''), isEmpty);
  }

  test('legacy path-unique database migrates with IDs, playlists and settings',
      () async {
    final oldSong = wav('$music/old.wav');
    wav('$music/album.wav');
    File('$music/album.cue').writeAsStringSync('''TITLE "中文专辑"
FILE "album.wav" WAVE
TRACK 01 AUDIO
TITLE "第一轨"
INDEX 01 00:00:00
TRACK 02 AUDIO
TITLE "第二轨"
INDEX 01 00:01:00
''');
    var db = NativeMusicLibrary.openDatabase(database);
    db.execute('''CREATE TABLE scanned_tracks (
      id INTEGER PRIMARY KEY, title TEXT, artist TEXT, album TEXT,
      file_path TEXT UNIQUE, format INTEGER, sample_rate INTEGER,
      bit_depth INTEGER, duration_sec INTEGER);
      CREATE TABLE playlists(id INTEGER PRIMARY KEY, name TEXT);
      CREATE TABLE playlist_tracks(playlist_id INTEGER, track_id INTEGER,
        sort_order INTEGER DEFAULT 0, PRIMARY KEY(playlist_id, track_id));
      CREATE TABLE app_settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE dac_dx1ii_settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
    ''');
    db.execute('INSERT INTO scanned_tracks VALUES(47,?,?,?,?,?,?,?,?)',
        ['old', '艺术家', '专辑', oldSong.path, 2, 44100, 16, 2]);
    db.execute('INSERT INTO playlists VALUES(9,?)', ["试听'😀"]);
    db.execute('INSERT INTO playlist_tracks VALUES(9,47,3)');
    db.execute('INSERT INTO app_settings VALUES(?,?)', ['theme', 'keep']);
    db.execute('INSERT INTO dac_dx1ii_settings VALUES(?,?)',
        ['sample_rate_mode', '3']);
    db.close();

    await scan([music]);
    await scan([music]);
    db = NativeMusicLibrary.openDatabase(database);
    try {
      final tracks = db.select('SELECT * FROM scanned_tracks ORDER BY id');
      expect(tracks, hasLength(3));
      expect(tracks.first['id'], 47);
      expect(tracks.skip(1).every((row) => (row['id'] as int) > 47), isTrue);
      expect(tracks.where((row) => row['is_cue_track'] == 1), hasLength(2));
      expect(db.select('SELECT * FROM playlist_tracks').single,
          {'playlist_id': 9, 'track_id': 47, 'sort_order': 3});
      expect(db.select('SELECT name FROM playlists').single['name'], "试听'😀");
      expect(
          db
              .select("SELECT value FROM app_settings WHERE key='theme'")
              .single['value'],
          'keep');
      expect(db.select('SELECT value FROM dac_dx1ii_settings').single['value'],
          '3');
      healthy(db);
    } finally {
      db.close();
    }
  });

  test('native SQL types and Unicode survive close/reopen in a SQLite file',
      () {
    var db = NativeMusicLibrary.openDatabase(database);
    db.execute(
        'CREATE TABLE bound_values(i INTEGER,r REAL,t TEXT,n TEXT,b INTEGER)');
    const large = 9007199254740993;
    const title = "中文'\u0000😀";
    db.execute('INSERT INTO bound_values VALUES(?,?,?,?,?)',
        [large, 1.25, title, null, true]);
    db.close();
    db = NativeMusicLibrary.openDatabase(database);
    try {
      expect(db.select('SELECT * FROM bound_values').single,
          {'i': large, 'r': 1.25, 't': title, 'n': null, 'b': 1});
      expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
      expect(db.select('PRAGMA journal_mode').single.values.single, 'wal');
      expect(File(database).readAsBytesSync().take(16),
          'SQLite format 3\u0000'.codeUnits);
    } finally {
      db.close();
    }
  });

  test('failed scan rolls back tracks, playlist links and ID allocation',
      () async {
    wav('$music/original.wav');
    await scan([music]);
    final db = NativeMusicLibrary.openDatabase(database);
    try {
      final id = db.select('SELECT id FROM scanned_tracks').single['id'];
      db.execute('INSERT INTO playlists VALUES(1,?)', ['保留歌单']);
      db.execute('INSERT INTO playlist_tracks VALUES(1,?,0)', [id]);
      final before = db.select('SELECT * FROM scanned_tracks ORDER BY id');
      final settings = db.select('SELECT * FROM app_settings ORDER BY key');
      db.execute('''CREATE TRIGGER reject_new BEFORE INSERT ON scanned_tracks
        WHEN NEW.title='reject' BEGIN SELECT RAISE(ABORT,'audit rollback'); END''');
      wav('$music/reject.wav');
      await expectLater(scan([music]), throwsStateError);
      expect(db.select('SELECT * FROM scanned_tracks ORDER BY id'), before);
      expect(db.select('SELECT * FROM app_settings ORDER BY key'), settings);
      expect(
          db.select('SELECT track_id FROM playlist_tracks').single['track_id'],
          id);
      await expectLater(scan(['${sandbox.path}/missing']), throwsStateError);
      expect(db.select('SELECT * FROM scanned_tracks ORDER BY id'), before);
      db.execute('DROP TRIGGER reject_new');
      await scan([music]);
      expect(db.select('SELECT * FROM scanned_tracks'), hasLength(2));
      healthy(db);
    } finally {
      db.close();
    }
  });

  test('WiFi partial scans preserve public IDs and deleted IDs are not reused',
      () async {
    final public = '${sandbox.path}/Music';
    wav('$public/public.wav');
    final privateFile = wav('$music/private.wav');
    await scan([music, public]);
    final db = NativeMusicLibrary.openDatabase(database);
    try {
      final before =
          db.select('SELECT id,title FROM scanned_tracks ORDER BY id');
      final publicId = before.singleWhere((t) => t['title'] == 'public')['id'];
      final highest =
          before.map((t) => t['id'] as int).reduce((a, b) => a > b ? a : b);
      privateFile.deleteSync();
      await scan([music], partial: true);
      expect(db.select('SELECT id FROM scanned_tracks').single['id'], publicId);
      wav('$music/new.wav');
      await scan([music], partial: true);
      expect(
          db
              .select("SELECT id FROM scanned_tracks WHERE title='new'")
              .single['id'] as int,
          greaterThan(highest));
      expect(
          db
              .select("SELECT id FROM scanned_tracks WHERE title='public'")
              .single['id'],
          publicId);
      healthy(db);
    } finally {
      db.close();
    }
  });

  test('WAL reader snapshot remains consistent while native scan commits',
      () async {
    wav('$music/first.wav');
    await scan([music]);
    final reader = NativeMusicLibrary.openDatabase(database);
    try {
      reader.execute('BEGIN');
      expect(
          reader.select('SELECT COUNT(*) AS n FROM scanned_tracks').single['n'],
          1);
      wav('$music/second.wav');
      await scan([music]);
      expect(
          reader.select('SELECT COUNT(*) AS n FROM scanned_tracks').single['n'],
          1);
      reader.execute('COMMIT');
      expect(
          reader.select('SELECT COUNT(*) AS n FROM scanned_tracks').single['n'],
          2);
      healthy(reader);
    } finally {
      reader.close();
    }
  });
}
