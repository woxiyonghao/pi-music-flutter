import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/app_paths.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/services/music_library_scanner.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandbox;

  setUp(() => sandbox = Directory.systemTemp.createTempSync('pi-music-scan-'));
  tearDown(() => sandbox.deleteSync(recursive: true));

  File audio(String relative) {
    final file = File(p.join(sandbox.path, relative));
    file.parent.createSync(recursive: true);
    return file..writeAsBytesSync([]);
  }

  test('SD scan includes home Downloads, lowercase music and boot partition',
      () async {
    final home = p.join(sandbox.path, 'home/listener');
    final expected = [
      audio('home/listener/Music/old.flac'),
      audio('home/listener/Downloads/new.WAV'),
      audio('home/listener/music/新增歌曲.dsf'),
      audio('home/listener/收藏/专辑/new.mp3'),
      audio('boot/firmware/music/sd-card.flac'),
      audio('run/media/listener/USB/usb.wav'),
      audio('mnt/ssd/nvme.flac'),
    ];
    final roots = AppPaths.linuxMusicScanDirectories(
        home: home, systemRoot: sandbox.path);
    final result = await MusicLibraryScanner.collect(roots);
    expect(result.audioFiles.map((f) => f.path),
        unorderedEquals(expected.map((f) => f.resolveSymbolicLinksSync())));
    expect(result.failedDirectories, isEmpty);
  });

  test('XDG music path outside home is included without invoking a shell',
      () async {
    final home = Directory(p.join(sandbox.path, 'home/listener'))
      ..createSync(recursive: true);
    final external = audio('srv/library/xdg.flac');
    File(p.join(home.path, '.config/user-dirs.dirs'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('XDG_MUSIC_DIR="${external.parent.path}"\n');
    final roots = AppPaths.linuxMusicScanDirectories(
        home: home.path, systemRoot: sandbox.path);
    expect(roots, contains(external.parent.path));
    final result = await MusicLibraryScanner.collect(roots);
    expect(result.audioFiles.single.path, external.resolveSymbolicLinksSync());
  });

  test('overlapping roots and symlink loops do not duplicate or miss songs',
      () async {
    final song = audio('media/usb/album/track.FLAC');
    final linkedSong = audio('external/linked.wav');
    final root = Directory(p.join(sandbox.path, 'media'));
    Link(p.join(root.path, 'linked-album')).createSync(linkedSong.parent.path);
    Link(p.join(song.parent.path, 'loop')).createSync(root.path);
    Link(p.join(root.path, 'track-alias.FLAC')).createSync(song.path);
    final result = await MusicLibraryScanner.collect(
        [root.path, song.parent.path, linkedSong.parent.path]);
    expect(
        result.audioFiles.map((f) => f.path),
        unorderedEquals([
          song.resolveSymbolicLinksSync(),
          linkedSong.resolveSymbolicLinksSync()
        ]));
    expect(result.failedDirectories, isEmpty);
  }, skip: Platform.isWindows);

  test(
      'hidden cache directories are skipped without excluding hifi_player music',
      () async {
    audio('.cache/cache.wav');
    audio('Music/.hidden.wav');
    audio('project/build/generated.wav');
    File(p.join(sandbox.path, 'project/pubspec.yaml'))
        .writeAsStringSync('name: fixture');
    final song = audio('hifi_player/music/real.wav');
    final result = await MusicLibraryScanner.collect([sandbox.path]);
    expect(result.audioFiles.single.path, song.resolveSymbolicLinksSync());
  });

  test('one unreadable directory does not abort readable siblings', () async {
    final blocked = audio('Music/a-private/private.wav').parent;
    final readable = audio('Music/z-public/new.wav');
    await Process.run('chmod', ['000', blocked.path]);
    try {
      final result =
          await MusicLibraryScanner.collect([readable.parent.parent.path]);
      expect(result.audioFiles.map((f) => f.path),
          contains(readable.resolveSymbolicLinksSync()));
      expect(result.failedDirectories,
          contains(blocked.resolveSymbolicLinksSync()));
    } finally {
      await Process.run('chmod', ['700', blocked.path]);
    }
  }, skip: Platform.isWindows);

  test('rescanning imports newly copied tracks into an existing SQLite library',
      () async {
    final first = audio('Music/existing.flac');
    final db = MusicDatabaseService.forTesting(
        databasePath: p.join(sandbox.path, 'config/library.db'));
    addTearDown(db.dispose);
    expect(await db.scanLibrary(customPath: first.parent.path), 1);
    final added = audio('Music/新专辑/new.WAV');
    expect(await db.scanLibrary(customPath: first.parent.path), 2);
    expect(db.tracks.map((t) => t.filepath),
        contains(added.resolveSymbolicLinksSync()));
    db.loadLibrary();
    expect(db.tracks.length, 2);
  });

  test('failed scan path preserves the existing library and reports failure',
      () async {
    final first = audio('Music/existing.flac');
    final db = MusicDatabaseService.forTesting(
        databasePath: p.join(sandbox.path, 'config/library.db'));
    addTearDown(db.dispose);
    await db.scanLibrary(customPath: first.parent.path);
    await expectLater(
        db.scanLibrary(customPath: p.join(sandbox.path, 'missing')),
        throwsA(isA<FileSystemException>()));
    expect(db.tracks.single.filepath, first.resolveSymbolicLinksSync());
    // A failure must not poison the queue and prevent subsequent scans.
    expect(await db.scanLibrary(customPath: first.parent.path), 1);
  });

  test(
      'scan retains old tracks in an unreadable album and imports new siblings',
      () async {
    final blocked = audio('Music/private/existing.flac').parent;
    final db = MusicDatabaseService.forTesting(
        databasePath: p.join(sandbox.path, 'config/library.db'));
    addTearDown(db.dispose);
    await db.scanLibrary(customPath: blocked.parent.path);
    audio('Music/public/new.wav');
    await Process.run('chmod', ['000', blocked.path]);
    try {
      expect(await db.scanLibrary(customPath: blocked.parent.path), 2);
      expect(db.scanWarnings, contains(blocked.resolveSymbolicLinksSync()));
      db.loadLibrary();
      expect(
          db.tracks.map((t) => t.title), unorderedEquals(['existing', 'new']));
    } finally {
      await Process.run('chmod', ['700', blocked.path]);
    }
  }, skip: Platform.isWindows);

  test('linked WAV+CUE album remains split without a duplicate whole recording',
      () async {
    final wav = audio('source/recording.wav');
    final bytes = Uint8List(44 + 44100 * 2 * 3);
    final header = ByteData.sublistView(bytes);
    void text(int offset, String value) =>
        bytes.setRange(offset, offset + value.length, value.codeUnits);
    text(0, 'RIFF');
    header.setUint32(4, bytes.length - 8, Endian.little);
    text(8, 'WAVEfmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, 44100, Endian.little);
    header.setUint32(28, 44100 * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    text(36, 'data');
    header.setUint32(40, bytes.length - 44, Endian.little);
    wav.writeAsBytesSync(bytes);
    final album = Directory(p.join(sandbox.path, 'Music/album'))
      ..createSync(recursive: true);
    Link(p.join(album.path, 'CDImage.wav')).createSync(wav.path);
    File(p.join(album.path, 'CDImage.cue')).writeAsStringSync('''
TITLE "Linked Album"
PERFORMER "Artist"
FILE "CDImage.wav" WAVE
  TRACK 01 AUDIO
    TITLE "First"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Second"
    INDEX 01 00:01:00
''');
    final db = MusicDatabaseService.forTesting(
        databasePath: p.join(sandbox.path, 'config/library.db'));
    addTearDown(db.dispose);
    expect(await db.scanLibrary(customPath: album.parent.path), 2);
    expect(db.tracks.every((t) => t.isCueTrack), isTrue);
    expect(db.tracks.map((t) => t.filepath).toSet(),
        {wav.resolveSymbolicLinksSync()});
    expect(db.tracks.map((t) => t.durationSec), [1, 2]);
  }, skip: Platform.isWindows);

  test('parallel scan requests commit in the order requested', () async {
    final first = audio('first/first.flac');
    final last = audio('last/last.wav');
    final db = MusicDatabaseService.forTesting(
        databasePath: p.join(sandbox.path, 'config/library.db'));
    addTearDown(db.dispose);
    final requests = [
      db.scanLibrary(customPath: first.parent.path),
      db.scanLibrary(customPath: last.parent.path),
    ];
    expect(await Future.wait(requests), [1, 1]);
    expect(db.tracks.single.filepath, last.resolveSymbolicLinksSync());
  });

  test(
      'SQLite insertion failure rolls back instead of deleting the old library',
      () async {
    final file = audio('Music/existing.flac');
    final db = MusicDatabaseService.forTesting(
        databasePath: p.join(sandbox.path, 'config/library.db'));
    addTearDown(db.dispose);
    await db.scanLibrary(customPath: file.parent.path);
    final invalid = Track(
        id: 1,
        title: 'duplicate',
        artist: '',
        album: '',
        filepath: file.path,
        sampleRate: 0,
        bitDepth: 0,
        durationSec: 0);
    expect(db.saveScannedTracks([invalid, invalid]), isFalse);
    db.loadLibrary();
    expect(db.tracks.single.title, 'existing');
  });
}
