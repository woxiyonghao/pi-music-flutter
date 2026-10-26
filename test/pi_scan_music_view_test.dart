import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_scan_music_view.dart';
import 'package:path/path.dart' as p;

class _FailingLibrary extends MusicDatabaseService {
  _FailingLibrary() : super.forTesting(databasePath: 'unused');

  @override
  Future<int> scanLibrary({String? customPath}) async {
    throw const FileSystemException('没有读取权限');
  }
}

void main() {
  testWidgets('Pi shared scan button imports files copied after the first scan',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    final sandbox = Directory.systemTemp.createTempSync('pi-scan-view-');
    final music = Directory(p.join(sandbox.path, 'Music'))..createSync();
    File(p.join(music.path, 'existing.flac')).writeAsBytesSync([]);
    final db = MusicDatabaseService.forTesting(
        databasePath: p.join(sandbox.path, 'library.db'),
        scanDirectories: [music.path]);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      HifiAudioService.instance.stopTicker();
      db.dispose();
      sandbox.deleteSync(recursive: true);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() => db.scanLibrary());
    File(p.join(music.path, 'newly-copied.wav')).writeAsBytesSync([]);
    var completed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MacScanMusicView(database: db, onScanComplete: () => completed++),
      ),
    ));
    await tester.tap(find.text('重新扫描'));
    // Filesystem callbacks run outside Flutter's fake clock. Pump between IO
    // turns instead of pumpAndSettle, because the scan animation keeps ticking.
    for (var turn = 0; turn < 200 && completed == 0; turn++) {
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await tester.pump();

    expect(db.tracks.map((track) => track.title),
        unorderedEquals(['existing', 'newly-copied']));
    expect(find.text('newly-copied'), findsOneWidget);
    expect(find.text('扫描完成，已入库 2 首曲目'), findsOneWidget);
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scan failure is visible and the scan button can be used again',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    final db = _FailingLibrary();
    var completed = false;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      HifiAudioService.instance.stopTicker();
      db.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MacScanMusicView(
            database: db, onScanComplete: () => completed = true),
      ),
    ));
    await tester.tap(find.text('全盘检索'));
    await tester.pump();

    expect(find.textContaining('扫描失败：'), findsOneWidget);
    expect(find.textContaining('没有读取权限'), findsOneWidget);
    expect(find.text('全盘检索'), findsOneWidget);
    expect(completed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
