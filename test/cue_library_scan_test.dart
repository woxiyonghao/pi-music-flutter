import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:path/path.dart' as p;
import 'package:hide_player_flutter/core/native_music_library.dart';

const _cueText = r'''
PERFORMER "测试歌手"
TITLE "整轨专辑"
FILE "Disc 1\CDImage.wav" WAVE
  TRACK 01 AUDIO
    TITLE "第一首"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "第二首"
    INDEX 01 00:02:01
  TRACK 03 AUDIO
    TITLE "第三首"
    INDEX 01 00:05:37
''';

void _writeWav(File file) {
  file.parent.createSync(recursive: true);
  const sampleRate = 44100;
  const byteRate = sampleRate * 2 * 2;
  const dataBytes = byteRate * 84 ~/ 10; // 8.4 seconds, stereo PCM16.
  final header = ByteData(44);
  header.buffer.asUint8List().setRange(0, 4, ascii.encode('RIFF'));
  header.setUint32(4, 36 + dataBytes, Endian.little);
  header.buffer.asUint8List().setRange(8, 16, ascii.encode('WAVEfmt '));
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 2, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, 4, Endian.little);
  header.setUint16(34, 16, Endian.little);
  header.buffer.asUint8List().setRange(36, 40, ascii.encode('data'));
  header.setUint32(40, dataBytes, Endian.little);
  final output = file.openSync(mode: FileMode.write);
  try {
    output.writeFromSync(header.buffer.asUint8List());
    output.truncateSync(44 + dataBytes);
  } finally {
    output.closeSync();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late Directory music;
  late File wav;
  late File cue;
  late String databasePath;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('cue_library_');
      sandbox = Directory(sandbox.resolveSymbolicLinksSync());
    music = Directory(p.join(sandbox.path, 'Documents'))..createSync();
    wav = File(p.join(music.path, 'Disc 1', 'CDImage.WAV'));
    cue = File(p.join(music.path, 'Album.CUE'));
    databasePath = p.join(sandbox.path, 'library.db');
    _writeWav(wav);
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  test('GBK WAV+CUE import persists distinct tracks and frame-accurate bounds',
      () async {
    cue.writeAsBytesSync(gbk.encode(_cueText));
    final library = MusicDatabaseService.forTesting(
      databasePath,
      musicDirectory: music.path,
    );
    addTearDown(library.dispose);

    expect(await library.scanLibrary(), 3);
    expect(library.tracks.map((t) => t.title), ['第一首', '第二首', '第三首']);
    expect(library.tracks.every((t) => t.isCueTrack), isTrue);
    expect(library.tracks.map((t) => t.filepath).toSet(), {wav.path});
    expect(library.tracks.map((t) => t.trackNumber), [1, 2, 3]);
    expect(library.tracks.map((t) => t.artist).toSet(), {'测试歌手'});
    expect(library.tracks.map((t) => t.album).toSet(), {'整轨专辑'});
    expect(library.tracks.every((t) => t.sampleRate == 44100), isTrue);
    expect(library.tracks.every((t) => t.bitDepth == 16), isTrue);
    expect(library.tracks[1].startTimeSec, closeTo(2 + 1 / 75, 1e-9));
    expect(library.tracks[1].endTimeSec, closeTo(5 + 37 / 75, 1e-9));
    expect(library.tracks.last.endTimeSec, closeTo(8.4, 1e-9));
    expect(library.tracks.last.durationSec, 3);
    expect(library.tracks[0].matches(library.tracks[1]), isFalse);
    final ids = library.tracks.map((t) => t.id).toList();

    final reloaded = MusicDatabaseService.forTesting(
      databasePath,
      musicDirectory: music.path,
    );
    addTearDown(reloaded.dispose);
    reloaded.loadLibrary();
    expect(reloaded.tracks.map((t) => t.id), ids);
    expect(reloaded.tracks.last.endTimeSec, closeTo(8.4, 1e-9));
    expect(await reloaded.scanLibrary(), 3);
    expect(reloaded.tracks.map((t) => t.id), ids);

    final opened = <List<Object>>[];
    final audio = HifiAudioService.forTesting(
      prepareFile: (_) async {},
      openFile: (path, start, end) {
        opened.add([path, start, end]);
        return true;
      },
    );
    addTearDown(audio.dispose);
    await audio.playTrack(reloaded.tracks[1]);
    await audio.playTrack(reloaded.tracks.last);
    expect(opened[0][0], wav.path);
    expect(opened[0][1] as double, closeTo(2 + 1 / 75, 1e-9));
    expect(opened[0][2] as double, closeTo(5 + 37 / 75, 1e-9));
    expect(opened[1][1] as double, closeTo(5 + 37 / 75, 1e-9));
    expect(opened[1][2] as double, closeTo(8.4, 1e-9));
  });

  test('UTF-16 CUE preserves Unicode titles and Windows file references', () async {
    final bytes = BytesBuilder()..add([0xff, 0xfe]);
    for (final unit in _cueText.codeUnits) {
      bytes.add([unit & 0xff, unit >> 8]);
    }
    cue.writeAsBytesSync(bytes.takeBytes());
    final library = MusicDatabaseService.forTesting(databasePath, musicDirectory: music.path);
    await library.scanLibrary();
    expect(library.tracks.map((t) => t.album).toSet(), {'整轨专辑'});
    expect(library.tracks.map((t) => t.title), ['第一首', '第二首', '第三首']);
    expect(library.tracks.every((t) => FileSystemEntity.identicalSync(t.filepath, wav.path)), isTrue);
  });

  test('scan waits for full storage permission and preserves SQLite on denial',
      () async {
    var permission = Completer<bool>()..complete(true);
    final library = MusicDatabaseService.forTesting(
      databasePath,
      musicDirectory: music.path,
      requestStoragePermission: () => permission.future,
    );
    addTearDown(library.dispose);
    expect(await library.scanLibrary(), 1);
    final originalId = library.tracks.single.id;
    cue.writeAsBytesSync(gbk.encode(_cueText));

    permission = Completer<bool>();
    final scan = library.scanLibrary();
    final denied = expectLater(
      scan,
      throwsA(isA<MusicLibraryScanException>()
          .having((error) => error.message, 'message', contains('CUE'))),
    );
    await Future<void>.delayed(Duration.zero);
    expect(library.tracks.single.id, originalId);
    final db = NativeMusicLibrary.openDatabase(databasePath);
    expect(
        db
            .select('SELECT COUNT(*) AS count FROM scanned_tracks')
            .single['count'],
        1);
    db.close();
    permission.complete(false);
    await denied;
    expect(library.tracks.single.isCueTrack, isFalse);
    final reloaded = MusicDatabaseService.forTesting(databasePath);
    addTearDown(reloaded.dispose);
    reloaded.loadLibrary();
    expect(reloaded.tracks.single.id, originalId);

    // A rejected permission request must not poison the serialized scan queue.
    permission = Completer<bool>()..complete(true);
    expect(await library.scanLibrary(), 3);
    expect(library.tracks.every((t) => t.isCueTrack), isTrue);
  });
}
