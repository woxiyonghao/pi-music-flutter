import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';

void main() {
  late String tempDbPath;

  setUp(() {
    tempDbPath = '${Directory.systemTemp.path}/test_music_scan_${DateTime.now().microsecondsSinceEpoch}.db';
    MusicDatabaseService.instance.customDatabasePathForTesting = tempDbPath;
  });

  tearDown(() {
    MusicDatabaseService.instance.customDatabasePathForTesting = null;
    final f = File(tempDbPath);
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  });

  test('scanLibrary detects and parses 此情可待 WAV+CUE album', () async {
    const musicDir = '/Users/mk10/Downloads/music';
    if (!Directory(musicDir).existsSync()) {
      print('Warning: /Users/mk10/Downloads/music does not exist');
      return;
    }

    final count = await MusicDatabaseService.instance.scanLibrary(customPath: musicDir);
    expect(count, greaterThan(0));

    final tracks = MusicDatabaseService.instance.tracks;
    print('Scanned total tracks: ${tracks.length}');

    // 1. 验证包含 "此情可待" 歌曲
    final ciQingKeDai = tracks.where((t) => t.title.contains('此情可待')).toList();
    expect(ciQingKeDai.isNotEmpty, isTrue, reason: '必须搜索出《此情可待》这首歌曲');
    print('找到《此情可待》曲目: ${ciQingKeDai.first.title} | 歌手: ${ciQingKeDai.first.artist} | 专辑: ${ciQingKeDai.first.album}');
    expect(ciQingKeDai.first.artist, '阿强');
    expect(ciQingKeDai.first.album, '此情可待 DSD');
    expect(ciQingKeDai.first.isCueTrack, isTrue);
    expect(ciQingKeDai.first.startTimeSec, 0.0);
    expect(ciQingKeDai.first.endTimeSec, greaterThan(200.0));

    // 2. 验证同专辑其它歌曲 (如 草帽歌, 女人花)
    final caoMaoGe = tracks.where((t) => t.title.contains('草帽歌')).toList();
    expect(caoMaoGe.isNotEmpty, isTrue, reason: '必须解析出同专辑分轨《草帽歌》');
    expect(caoMaoGe.first.isCueTrack, isTrue);

    // 3. 验证未出现裸露的 CDImage 整轨冗余曲目
    final cdImageMonolithic = tracks.where((t) => t.title == 'CDImage' && !t.isCueTrack).toList();
    expect(cdImageMonolithic.isEmpty, isTrue, reason: '不能展示未解析的 CDImage 假曲目');

    for (final t in tracks) {
      if (t.isCueTrack) {
        print('  [CUE分轨 #${t.trackNumber}] ${t.title} - ${t.artist} (${t.durationString})');
      }
    }
  });

  test('scanLibrary on desktop music2 has zero duplicates', () async {
    final home = Platform.environment['HOME'] ?? '';
    final music2 = '$home/Desktop/music2';
    if (!Directory(music2).existsSync()) return;

    final count = await MusicDatabaseService.instance.scanLibrary(customPath: music2);
    final tracks = MusicDatabaseService.instance.tracks;
    expect(count, equals(tracks.length));

    final seenTrackKeys = <String>{};
    for (final t in tracks) {
      final key = t.isCueTrack ? '${t.cuePath}:${t.trackNumber}' : t.filepath;
      expect(seenTrackKeys.contains(key), isFalse, reason: 'Duplicate found: $key');
      seenTrackKeys.add(key);
    }
    print('Verified: $count tracks with 0 duplicates!');
  });
}
