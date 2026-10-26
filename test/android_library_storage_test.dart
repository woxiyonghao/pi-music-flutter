import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/app_paths.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/audio_metadata_helper.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('Android music and database paths remain in Documents without HOME', () {
    const documents = '/data/user/0/com.example.hide_player/app_flutter';
    final music = AppPaths.resolveMusicDirectory(
      isAndroid: true,
      isIOS: false,
      homeDirectory: '',
      documentsRoot: documents,
    );
    final database = AppPaths.resolveDatabasePath(
      isAndroid: true,
      isIOS: false,
      homeDirectory: '',
      documentsRoot: documents,
    );
    expect(music, documents);
    expect(database, p.join(documents, 'hifi_player', 'library.db'));
    expect(p.isWithin(documents, database), isTrue);
    expect(
      MusicDatabaseService.androidSharedMusicDirectories,
      containsAll(<String>[
        '/storage/emulated/0/Music/pimusic',
        '/sdcard/Music/pimusic',
        '/storage/emulated/0/Music',
        '/sdcard/Music',
      ]),
    );
  });

  group('Android app-owned library', () {
    late Directory sandbox;
    late String database;
    late Directory music;

    MusicDatabaseService openLibrary() => MusicDatabaseService.forTesting(
          database,
          musicDirectory: music.path,
        );

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('android_library_');
      music = Directory(p.join(sandbox.path, 'Documents'));
      database = p.join(music.path, 'hifi_player', 'library.db');
    });

    tearDown(() => sandbox.deleteSync(recursive: true));

    test('empty mobile library stays empty and can persist settings', () {
      final library = openLibrary();
      addTearDown(library.dispose);
      library.loadLibrary();
      expect(library.tracks, isEmpty);
      expect(library.setSetting('test_theme', '4'), isTrue);
      expect(File(database).existsSync(), isTrue);
      library.loadLibrary();
      expect(library.tracks, isEmpty);
      expect(library.getSetting('test_theme', ''), '4');
    });

    test('scans nested imports once and reloads them from sandbox SQLite',
        () async {
      final album = Directory(p.join(music.path, '专辑'));
      album.createSync(recursive: true);
      final track = File(p.join(album.path, '01 - 歌曲.FLAC'))
        ..writeAsBytesSync([1, 2, 3]);
      File(p.join(album.path, 'upload.mp3.part')).writeAsBytesSync([1]);
      File(p.join(album.path, 'cover.jpg')).writeAsBytesSync([1]);
      final outside = Directory(p.join(sandbox.path, 'outside'))..createSync();
      File(p.join(outside.path, 'outside.mp3')).writeAsBytesSync([1]);
      Link(p.join(music.path, 'linked_album')).createSync(outside.path);

      final library = openLibrary();
      addTearDown(library.dispose);
      expect(await library.scanLibrary(), 1);
      expect(library.tracks.single.filepath, track.path);
      expect(library.tracks.single.format, AudioFormat.flac);
      expect(library.tracks.single.title, '歌曲');
      expect(library.tracks.single.artist, '01');
      expect(library.tracks.single.sampleRate, 0);
      final originalId = library.tracks.single.id;
      expect(await library.scanLibrary(), 1);
      expect(library.tracks.single.id, originalId);

      final reloaded = openLibrary();
      addTearDown(reloaded.dispose);
      reloaded.loadLibrary();
      expect(reloaded.tracks.single.filepath, track.path);
      expect(reloaded.tracks.single.id, originalId);
    });

    test('upload-folder scan preserves tracks imported from another folder',
        () async {
      music.createSync();
      final first = File(p.join(music.path, 'first.wav'))
        ..writeAsBytesSync([1]);
      final uploads = Directory(p.join(sandbox.path, 'uploads'))..createSync();
      final second = File(p.join(uploads.path, 'second.mp3'))
        ..writeAsBytesSync([2]);
      final library = openLibrary();
      addTearDown(library.dispose);
      expect(await library.scanLibrary(), 1);
      expect(await library.scanLibrary(directory: uploads.path), 2);
      expect(library.tracks.map((t) => t.filepath), [first.path, second.path]);
      expect(await library.scanLibrary(directory: uploads.path), 2);
    });

    test('parses MP3 header with ID3v2 and Xing frame count for duration', () {
      final mp3File = File(p.join(sandbox.path, 'mix.mp3'));
      // 10-byte ID3v2 header (tag size = 0) + MPEG-1 Layer III 44.1kHz stereo frame (0xFF 0xFB 0x90 0x00)
      // + 32-byte side info + 'Xing' + flags(0x01) + totalFrames(3828 -> 100s at 1152 spf / 44100 Hz)
      final bytes = <int>[
        0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // ID3v2
        0xFF, 0xFB, 0x90, 0x00, // MPEG-1 Layer III, 128kbps, 44100Hz, Stereo
        ...List<int>.filled(32, 0), // Side info
        0x58, 0x69, 0x6E, 0x67, // 'Xing'
        0x00, 0x00, 0x00, 0x01, // Flags: frames field present
        0x00, 0x00, 0x0E, 0xF4, // 3828 frames -> 3828 * 1152 / 44100 = 100.0s
      ];
      mp3File.writeAsBytesSync(bytes);
      final meta = AudioMetadataHelper.parse(mp3File, AudioFormat.mp3);
      expect(meta.sampleRate, 44100);
      expect(meta.bitDepth, 16);
      expect(meta.durationSec, 100);
    });
  });
}
