import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/app_paths.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/audio_metadata_helper.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:path/path.dart' as p;
import 'package:hide_player_flutter/core/native_music_library.dart' as sqlite;

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
      sandbox = Directory(sandbox.resolveSymbolicLinksSync());
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

    test('auto-heals zero-duration DSD (DSF/DFF) tracks from SQLite on load', () async {
      music.createSync();
      final dsfFile = File(p.join(music.path, 'test_dsd.dsf'));
      final builder = BytesBuilder();
      builder.add([0x44, 0x53, 0x44, 0x20]); // 'DSD '
      final bdHdr = ByteData(24);
      bdHdr.setUint64(0, 28, Endian.little);
      bdHdr.setUint64(8, 28 + 52 + 12 + 100, Endian.little);
      builder.add(bdHdr.buffer.asUint8List());

      builder.add([0x66, 0x6D, 0x74, 0x20]); // 'fmt '
      final bdFmtHdr = ByteData(8)..setUint64(0, 52, Endian.little);
      builder.add(bdFmtHdr.buffer.asUint8List());
      final bdFmt = ByteData(40);
      bdFmt.setUint32(0, 1, Endian.little);
      bdFmt.setUint32(12, 2, Endian.little); // 2 ch
      bdFmt.setUint32(16, 2822400, Endian.little); // 2.8224 MHz
      bdFmt.setUint32(20, 1, Endian.little); // 1-bit
      bdFmt.setUint64(24, 2822400 * 240, Endian.little); // 240 seconds
      builder.add(bdFmt.buffer.asUint8List());
      builder.add([0x64, 0x61, 0x74, 0x61]); // 'data'
      final bdDataHdr = ByteData(8)..setUint64(0, 12 + 100, Endian.little);
      builder.add(bdDataHdr.buffer.asUint8List());
      dsfFile.writeAsBytesSync(builder.toBytes());

      final library = openLibrary();
      addTearDown(library.dispose);
      library.setSetting('init', '1');
      library.loadLibrary();

      // Insert zero-duration DSD track into database directly
      final rawDb = sqlite.NativeMusicLibrary.openDatabase(database);
      rawDb.execute('''
        INSERT INTO scanned_tracks (id, title, artist, album, file_path, format, sample_rate, bit_depth, duration_sec)
        VALUES (999, 'DSD Symphony', 'Artist', 'Album', ?, 3, 0, 0, 0)
      ''', [dsfFile.path]);
      rawDb.dispose();

      // Reload library - should auto-heal to 240s!
      library.loadLibrary();
      final healed = library.tracks.firstWhere((t) => t.id == 999);
      expect(healed.durationSec, 240);
      expect(healed.sampleRate, 2822400);
      expect(healed.bitDepth, 1);
    });
  });
}
