import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/native_music_library.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';

void main() {
  late Directory temp;
  late MusicDatabaseService service;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('ipad_library_');
    temp = Directory(temp.resolveSymbolicLinksSync());
    service = MusicDatabaseService.instance;
    service.customDatabasePathForTesting = '${temp.path}/library.db';
    service.loadLibrary();
  });
  tearDown(() {
    service.customDatabasePathForTesting = null;
    service.loadLibrary();
    temp.deleteSync(recursive: true);
  });

  test(
      'legacy schema gains CUE columns and removes only missing bundled demo rows',
      () {
    final db = NativeMusicLibrary.openDatabase('${temp.path}/library.db');
    db.execute(
        "CREATE TABLE scanned_tracks (id INTEGER PRIMARY KEY, title TEXT, artist TEXT, album TEXT, file_path TEXT, format INTEGER, sample_rate INTEGER, bit_depth INTEGER, duration_sec INTEGER);");
    final real = File('${temp.path}/real.flac')..writeAsStringSync('fixture');
    for (final entry in {1: '/Music/此情可待.dsf', 2: real.path}.entries) {
      db.execute(
          'INSERT INTO scanned_tracks VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);', [
        entry.key,
        '此情可待',
        'Artist',
        'Album',
        entry.value,
        1,
        44100,
        16,
        180
      ]);
    }
    db.execute("CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT);");
    db.execute(
        "INSERT INTO app_settings VALUES ('setting_dac_topping_sample_rate_mode', '3');");
    MusicDatabaseService.initializeSettings(db);
    MusicDatabaseService.initializeSettings(db);
    expect(
        db.select('SELECT id FROM scanned_tracks;').map((r) => r['id']), [2]);
    expect(
        db.select('PRAGMA table_info(scanned_tracks);').map((r) => r['name']),
        containsAll([
          'is_cue_track',
          'start_time_sec',
          'end_time_sec',
          'cue_path',
          'track_number'
        ]));
    expect(
        db
            .select(
                "SELECT value FROM dac_dx1ii_settings WHERE key = 'sample_rate_mode';")
            .single['value'],
        '3');
    expect(
        db
            .select(
                "SELECT value FROM app_settings WHERE key = 'setting_dac_topping_sample_rate_mode';")
            .single['value'],
        '3');
    db.close();
    service.loadLibrary();
    expect(service.tracks.single.filepath, real.path);
  });

  test(
      'normalized CUE references and duplicate sheets never add the full image or duplicate tracks',
      () async {
    final album = Directory('${temp.path}/album')..createSync();
    final sub = Directory('${album.path}/sub')..createSync();
    File('${album.path}/disc.wav').writeAsBytesSync(List<int>.filled(44, 0));
    const cue =
        'PERFORMER "Artist"\nTITLE "Album"\nFILE "sub/../disc.wav" WAVE\n  TRACK 01 AUDIO\n    TITLE "One"\n    INDEX 01 00:00:00\n  TRACK 02 AUDIO\n    TITLE "Two"\n    INDEX 01 01:00:00\n';
    File('${album.path}/disc.cue').writeAsStringSync(cue);
    File('${album.path}/duplicate.cue').writeAsStringSync(cue);
    expect(sub.existsSync(), isTrue);
    expect(await service.scanLibrary(customPath: album.path), 2);
    expect(service.tracks.every((track) => track.isCueTrack), isTrue);
    expect(service.tracks.map((track) => track.title), ['One', 'Two']);
  });

  test('rescanning preserves track IDs and playlist membership and order',
      () async {
    final dir = Directory('${temp.path}/music')..createSync();
    final song = File('${dir.path}/song.flac')..writeAsStringSync('fixture');
    service.saveScannedTracks([
      Track(
          id: 42, sampleRate: 44100, bitDepth: 16,
          title: 'Song',
          artist: 'A',
          album: 'B',
          filepath: song.path,
          durationSec: 20)
    ]);
    final db = NativeMusicLibrary.openDatabase('${temp.path}/library.db');
    db.execute("INSERT INTO playlists VALUES (7, 'My music');");
    db.execute('INSERT INTO playlist_tracks VALUES (7, 42, 0);');
    db.close();
    service.loadLibrary();
    expect(service.playlists.single.tracks.single.id, 42);
    File('${dir.path}/new.flac').writeAsStringSync('fixture');
    expect(await service.scanLibrary(customPath: dir.path), 2);
    expect(
        service.tracks.singleWhere((track) => track.filepath == song.path).id,
        42);
    expect(service.playlists.single.tracks.single.id, 42);
    expect(await service.scanLibrary(customPath: '${dir.path}/../music'), 2);
    expect(service.playlists.single.tracks.single.id, 42);
  });

  test('failed scan save rolls back the previous library and settings persist',
      () {
    final song = File('${temp.path}/song.flac')..writeAsStringSync('fixture');
    final track = Track(
        id: 42, sampleRate: 44100, bitDepth: 16,
        title: 'Song',
        artist: 'A',
        album: 'B',
        filepath: song.path,
        durationSec: 20);
    expect(service.saveScannedTracks([track]), isTrue);
    expect(service.saveScannedTracks([track, track]), isFalse);
    service.loadLibrary();
    expect(service.tracks.single.id, 42);
    service.setDacDx1iiSetting('sample_rate_mode', '4');
    expect(service.getDacDx1iiSetting('sample_rate_mode', '0'), '4');
  });
}
