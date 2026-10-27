import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/app_paths.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/audio_metadata_helper.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/core/native_music_library.dart';

File writeWav(String path, {double seconds = 6.5}) {
  final file = File(path)..parent.createSync(recursive: true);
  const sampleRate = 8000;
  const byteRate = sampleRate * 2;
  final size = (seconds * byteRate).round();
  final header = ByteData(44);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      header.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  header.setUint32(4, size + 36, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  text(36, 'data');
  header.setUint32(40, size, Endian.little);
  final raf = file.openSync(mode: FileMode.write);
  raf.writeFromSync(header.buffer.asUint8List());
  raf.truncateSync(size + 44);
  raf.closeSync();
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late MusicDatabaseService library;
  late String dbPath;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('hifi_library_');
    temp = Directory(temp.resolveSymbolicLinksSync());
    dbPath = '${temp.path}/private/library.db';
    library = MusicDatabaseService.forTesting(dbPath);
  });
  tearDown(() {
    library.dispose();
    temp.deleteSync(recursive: true);
  });

  test('new and empty rescanned libraries never repopulate demo songs',
      () async {
    library.loadLibrary();
    expect(library.tracks, isEmpty);
    await library.scanLibrary(customPath: temp.path);
    expect(library.tracks, isEmpty);
    library.loadLibrary();
    expect(library.tracks, isEmpty);
  });

  test('WAV+CUE uses frame-accurate ranges and suppresses the whole WAV',
      () async {
    writeWav('${temp.path}/Album/Disc 1/CDImage.WAV');
    File('${temp.path}/Album/album.cue').writeAsStringSync('''
PERFORMER "Actual Artist"
TITLE "Actual Album"
FILE "disc 1\\cdimage.wav" WAVE
  TRACK 01 AUDIO
    TITLE "First"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Second"
    INDEX 01 00:02:15
  TRACK 03 AUDIO
    TITLE "Third"
    INDEX 01 00:04:00
''');
    expect(await library.scanLibrary(customPath: temp.path), 3);
    final tracks = library.tracks;
    expect(tracks.map((t) => t.title), ['First', 'Second', 'Third']);
    expect(tracks.every((t) => t.isCueTrack), isTrue);
    expect(tracks[0].endTimeSec, closeTo(2.2, 0.00001));
    expect(tracks[1].startTimeSec, closeTo(2.2, 0.00001));
    expect(tracks[1].endTimeSec, 4);
    expect(tracks[2].endTimeSec, 6.5);
    expect(tracks[2].durationSec, 3);
    expect(
        tracks.every((t) => t.sampleRate == 8000 && t.bitDepth == 16), isTrue);
  });

  test('rescans preserve existing IDs and playlist members as files arrive',
      () async {
    writeWav('${temp.path}/b.wav');
    await library.scanLibrary(customPath: temp.path);
    final original = library.tracks.single;
    final db = NativeMusicLibrary.openDatabase(dbPath);
    db.execute("INSERT INTO playlists (id, name) VALUES (7, 'My songs');");
    db.execute('INSERT INTO playlist_tracks VALUES (7, ?, 0);', [original.id]);
    db.close();
    writeWav('${temp.path}/a.wav');
    await Future.wait([
      library.scanLibrary(customPath: temp.path),
      library.scanLibrary(customPath: temp.path),
    ]);
    expect(library.tracks.length, 2);
    expect(library.tracks.singleWhere((t) => t.filepath.endsWith('/b.wav')).id,
        original.id);
    expect(library.playlists.single.tracks.single.id, original.id);
    expect(library.tracks.map((t) => t.id).toSet().length, 2);
  });

  test('a failed scan and failed SQL replacement retain the previous library',
      () async {
    writeWav('${temp.path}/keep.wav');
    await library.scanLibrary(customPath: temp.path);
    final original = library.tracks.single;
    await expectLater(library.scanLibrary(customPath: '${temp.path}/missing'),
        throwsA(isA<FileSystemException>()));
    expect(library.tracks.single.id, original.id);
    expect(library.saveScannedTracks([original, original]), isFalse);
    library.loadLibrary();
    expect(library.tracks.single.filepath, original.filepath);
    expect(await library.scanLibrary(customPath: temp.path), 1);
  });

  test(
      'known nonexistent demos are removed without removing real rows or playlists',
      () {
    final dbFile = File(dbPath)..parent.createSync(recursive: true);
    final db = NativeMusicLibrary.openDatabase(dbFile.path);
    MusicDatabaseService.initializeSettings(db);
    db.execute(
        "DELETE FROM app_settings WHERE key = 'migration_demo_cleanup_v2';");
    const insert =
        'INSERT INTO scanned_tracks (id,title,artist,album,file_path,format,sample_rate,bit_depth,duration_sec) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);';
    db.execute(insert, [
      1,
      'decaud-goldberg-var5-dsd128',
      'J.S. Bach',
      'Goldberg Variations',
      '/Music/goldberg.dsf',
      3,
      5644800,
      1,
      180
    ]);
    db.execute(insert, [
      2,
      'Actual import',
      '',
      '',
      '${temp.path}/missing-user.wav',
      2,
      44100,
      16,
      34
    ]);
    db.execute(insert, [
      3,
      'User-owned recording',
      'My Artist',
      'My Album',
      '/Music/goldberg.dsf',
      3,
      2822400,
      1,
      46
    ]);
    db.execute("INSERT INTO playlists VALUES (9, 'Favorites');");
    db.execute('INSERT INTO playlist_tracks VALUES (9, 1, 0);');
    db.execute('INSERT INTO playlist_tracks VALUES (9, 2, 1);');
    MusicDatabaseService.initializeSettings(db);
    expect(
        db
            .select('SELECT id FROM scanned_tracks ORDER BY id;')
            .map((row) => row['id']),
        [2, 3]);
    expect(
        db.select('SELECT track_id FROM playlist_tracks;').single['track_id'],
        2);
    expect(
        db.select('SELECT name FROM playlists;').single['name'], 'Favorites');
    db.close();
  });

  test('deleted last source leaves an empty database after rescan', () async {
    final song = writeWav('${temp.path}/only.wav');
    await library.scanLibrary(customPath: temp.path);
    song.deleteSync();
    expect(await library.scanLibrary(customPath: temp.path), 0);
    expect(library.tracks, isEmpty);
  });

  test(
      'iOS sandbox changes preserve duplicate filenames and scan root identity',
      () {
    final docs = Directory('${temp.path}/new-container/Documents')
      ..createSync(recursive: true);
    final first = writeWav('${docs.path}/Artist A/CDImage.wav');
    final second = writeWav('${docs.path}/Artist B/CDImage.wav');
    String resolve(String suffix) =>
        AppPaths.resolveDocumentsPath('/old-container/Documents/$suffix',
            documentsRoot: docs.path, isIOS: true);
    expect(resolve('Artist A/CDImage.wav'), first.path);
    expect(resolve('Artist B/CDImage.wav'), second.path);
    expect(
        AppPaths.resolveDocumentsPath('/old-container/Documents',
            documentsRoot: docs.path, isIOS: true),
        docs.path);
    expect(resolve('missing/CDImage.wav'),
        '/old-container/Documents/missing/CDImage.wav');
  });

  test('deleting an unrelated song never removes a differently named CUE',
      () async {
    writeWav('${temp.path}/Album/CDImage.wav');
    writeWav('${temp.path}/unrelated.wav');
    final cue = File('${temp.path}/Album/album.cue')
      ..writeAsStringSync('''FILE "CDImage.wav" WAVE
TRACK 01 AUDIO
  TITLE "First"
  INDEX 01 00:00:00
TRACK 02 AUDIO
  TITLE "Second"
  INDEX 01 00:02:00
''');
    await library.scanLibrary(customPath: temp.path);
    final unrelated = library.tracks.singleWhere((t) => !t.isCueTrack);
    await library.deleteTracks([unrelated.id]);
    expect(cue.existsSync(), isTrue);
    expect(File('${temp.path}/Album/CDImage.wav').existsSync(), isTrue);
    expect(await library.scanLibrary(customPath: temp.path), 2);
  });

  test(
      'partial CUE deletion retains sibling audio and descriptor, final deletion removes both',
      () async {
    final audio = writeWav('${temp.path}/CDImage.wav');
    final cue = File('${temp.path}/album.cue')
      ..writeAsStringSync('''FILE "CDImage.wav" WAVE
TRACK 01 AUDIO
  INDEX 01 00:00:00
TRACK 02 AUDIO
  INDEX 01 00:02:00
''');
    await library.scanLibrary(customPath: temp.path);
    final first = library.tracks.first;
    final last = library.tracks.last;
    await library.deleteTracks([first.id]);
    expect(audio.existsSync(), isTrue);
    expect(cue.existsSync(), isTrue);
    expect(library.tracks.single.id, last.id);
    await library.deleteTracks([last.id]);
    expect(audio.existsSync(), isFalse);
    expect(cue.existsSync(), isFalse);
    expect(await library.scanLibrary(customPath: temp.path), 0);
  });

  test(
      'missing files in multi-file CUEs are never replaced by another remaining song',
      () async {
    final removed = writeWav('${temp.path}/first.wav');
    final retained = writeWav('${temp.path}/second.wav');
    final cue = File('${temp.path}/album.cue')
      ..writeAsStringSync('''FILE "first.wav" WAVE
TRACK 01 AUDIO
  TITLE "First"
  INDEX 01 00:00:00
FILE "second.wav" WAVE
TRACK 02 AUDIO
  TITLE "Second"
  INDEX 01 00:00:00
''');
    await library.scanLibrary(customPath: temp.path);
    final first = library.tracks.singleWhere((t) => t.title == 'First');
    await library.deleteTracks([first.id]);
    expect(removed.existsSync(), isFalse);
    expect(retained.existsSync(), isTrue);
    expect(cue.existsSync(), isTrue);
    expect(await library.scanLibrary(customPath: temp.path), 1);
    expect(library.tracks.single.title, 'Second');
    expect(library.tracks.single.filepath, retained.path);
  });

  test('retaining source files removes only selected playlist members',
      () async {
    final retained = writeWav('${temp.path}/retained.wav');
    writeWav('${temp.path}/other.wav');
    await library.scanLibrary(customPath: temp.path);
    final target =
        library.tracks.singleWhere((t) => t.filepath == retained.path);
    final other = library.tracks.singleWhere((t) => t.id != target.id);
    final db = NativeMusicLibrary.openDatabase(dbPath);
    db.execute("INSERT INTO playlists VALUES (10, 'Keep my playlist');");
    db.execute('INSERT INTO playlist_tracks VALUES (10, ?, 0);', [target.id]);
    db.execute('INSERT INTO playlist_tracks VALUES (10, ?, 1);', [other.id]);
    db.close();
    await library.deleteTracks([target.id], deleteSourceFiles: false);
    expect(retained.existsSync(), isTrue);
    library.loadLibrary();
    expect(library.playlists.single.name, 'Keep my playlist');
    expect(library.playlists.single.tracks.single.id, other.id);
  });

  test('playlist membership persists, preserves order and survives rescans',
      () async {
    writeWav('${temp.path}/first.wav');
    writeWav('${temp.path}/second.wav');
    await library.scanLibrary(customPath: temp.path);
    final first = library.tracks.first;
    final second = library.tracks.last;
    library.createPlaylist('My favorites');
    final playlistId = library.playlists.single.id;
    expect(library.addTrackToPlaylist(playlistId, second.id), isTrue);
    expect(library.addTrackToPlaylist(playlistId, first.id), isTrue);
    expect(library.addTrackToPlaylist(playlistId, second.id), isTrue);
    expect(library.playlists.single.tracks.map((t) => t.id),
        [second.id, first.id]);
    expect(library.addTrackToPlaylist(playlistId, 9999), isFalse);
    expect(library.addTrackToPlaylist(9999, first.id), isFalse);
    await library.scanLibrary(customPath: temp.path);
    expect(library.playlists.single.tracks.map((t) => t.id),
        [second.id, first.id]);
    expect(library.removeTrackFromPlaylist(playlistId, second.id), isTrue);
    library.loadLibrary();
    expect(library.playlists.single.tracks.single.id, first.id);
    expect(library.tracks.length, 2);
    expect(File(second.filepath).existsSync(), isTrue);
  });

  test('a removed recording ID is never reused by a new upload', () async {
    writeWav('${temp.path}/removed.wav');
    await library.scanLibrary(customPath: temp.path);
    final removedId = library.tracks.single.id;
    await library.deleteTracks([removedId]);
    await library.scanLibrary(customPath: temp.path);
    writeWav('${temp.path}/new.wav');
    await library.scanLibrary(customPath: temp.path);
    expect(library.tracks.single.id, greaterThan(removedId));
  });

  test(
      'APFS filename normalization still associates CUE with the physical recording',
      () async {
    writeWav('${temp.path}/Cafe\u0301.wav');
    File('${temp.path}/album.cue').writeAsStringSync('''FILE "Café.wav" WAVE
TRACK 01 AUDIO
  INDEX 01 00:00:00
TRACK 02 AUDIO
  INDEX 01 00:02:00
''');
    expect(await library.scanLibrary(customPath: temp.path), 2);
    expect(library.tracks.every((track) => track.isCueTrack), isTrue);
  });

  test('subsecond CUE boundaries are not expanded to the full recording',
      () async {
    writeWav('${temp.path}/CDImage.wav');
    File('${temp.path}/album.cue').writeAsStringSync('''FILE "CDImage.wav" WAVE
TRACK 01 AUDIO
  INDEX 01 00:00:00
TRACK 02 AUDIO
  INDEX 01 00:00:15
''');
    expect(await library.scanLibrary(customPath: temp.path), 2);
    expect(library.tracks.first.endTimeSec, closeTo(0.2, 0.000001));
    expect(library.tracks.last.startTimeSec, closeTo(0.2, 0.000001));
    expect(library.tracks.last.endTimeSec, 6.5);
  });

  test('UTF-16 CUE decodes without corrupting song names', () async {
    writeWav('${temp.path}/unicode.wav');
    const cue = 'TITLE "真实专辑"\r\nFILE "unicode.wav" WAVE\r\nTRACK 01 AUDIO\r\nTITLE "真实曲名"\r\nINDEX 01 00:00:00\r\n';
    final bytes = BytesBuilder()..add([0xff, 0xfe]);
    for (final unit in cue.codeUnits) {
      bytes.add([unit & 0xff, unit >> 8]);
    }
    File('${temp.path}/unicode.cue').writeAsBytesSync(bytes.toBytes());
    await library.scanLibrary(customPath: temp.path);
    expect(library.tracks.single.title, '真实曲名');
    expect(library.tracks.single.album, '真实专辑');
  });

  test(
      'damaged and unsupported metadata is unknown rather than fake DSD or 180 seconds',
      () {
    final invalid = File('${temp.path}/invalid.wav')
      ..writeAsStringSync('broken');
    final meta = AudioMetadataHelper.parse(invalid, AudioFormat.wav);
    expect(meta.durationSec, 0);
    expect(meta.sampleRate, 0);
    expect(meta.bitDepth, 0);
    final real = AudioMetadataHelper.parse(
        writeWav('${temp.path}/real.wav'), AudioFormat.wav);
    expect(real.durationSeconds, 6.5);
  });
}
