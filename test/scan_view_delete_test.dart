import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_scan_music_view.dart';
import 'package:hide_player_flutter/ui/mac/widgets/mac_music_item_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scan_view_delete_test_');
    MusicDatabaseService.instance.customDatabasePathForTesting =
        '${tempDir.path}/test_library.db';
  });

  tearDown(() async {
    MusicDatabaseService.instance.customDatabasePathForTesting = null;
    MusicDatabaseService.instance.loadLibrary();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('MusicDatabaseService deleteTracks Unit Tests', () {
    test('deleteTracks removes records and deletes physical audio files', () async {
      final db = MusicDatabaseService.instance;

      // 创建测试音频文件
      final file1 = File('${tempDir.path}/song1.flac')..writeAsStringSync('dummy audio 1');
      final file2 = File('${tempDir.path}/song2.flac')..writeAsStringSync('dummy audio 2');
      final file3 = File('${tempDir.path}/song3.flac')..writeAsStringSync('dummy audio 3');

      final tracks = [
        Track(
          id: 101,
          title: 'Song 1',
          artist: 'Artist 1',
          album: 'Album 1',
          filepath: file1.path,
          format: AudioFormat.flac,
          sampleRate: 44100,
          bitDepth: 16,
          durationSec: 180,
        ),
        Track(
          id: 102,
          title: 'Song 2',
          artist: 'Artist 2',
          album: 'Album 1',
          filepath: file2.path,
          format: AudioFormat.flac,
          sampleRate: 44100,
          bitDepth: 16,
          durationSec: 200,
        ),
        Track(
          id: 103,
          title: 'Song 3',
          artist: 'Artist 3',
          album: 'Album 2',
          filepath: file3.path,
          format: AudioFormat.flac,
          sampleRate: 44100,
          bitDepth: 16,
          durationSec: 220,
        ),
      ];

      db.saveScannedTracks(tracks);
      db.loadLibrary();
      expect(db.tracks.length, 3);
      expect(file1.existsSync(), isTrue);
      expect(file2.existsSync(), isTrue);

      // 删除前两首
      final deletedCount = await db.deleteTracks([101, 102], deleteSourceFiles: true);
      expect(deletedCount, 2);
      expect(db.tracks.length, 1);
      expect(db.tracks.first.id, 103);

      // 物理源文件验证
      expect(file1.existsSync(), isFalse);
      expect(file2.existsSync(), isFalse);
      expect(file3.existsSync(), isTrue);
    });
  });

  group('MacScanMusicView Edit & Delete UI Tests', () {
    testWidgets('Entering edit mode and selecting tracks switches button to delete and triggers confirm dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = MusicDatabaseService.instance;
      final file = File('${tempDir.path}/ui_test.flac')..writeAsStringSync('audio data');

      final track = Track(
        id: 201,
        title: 'UI Test Track',
        artist: 'Test Artist',
        album: 'Test Album',
        filepath: file.path,
        format: AudioFormat.flac,
        sampleRate: 44100,
        bitDepth: 16,
        durationSec: 120,
      );

      db.saveScannedTracks([track]);
      db.loadLibrary();

      await tester.pumpWidget(
        MaterialApp(
          theme: HifiTheme.darkTheme,
          home: const Scaffold(
            body: MacScanMusicView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 默认状态：显示「选择」和「重新扫描」
      expect(find.text('选择'), findsOneWidget);
      expect(find.text('重新扫描'), findsOneWidget);
      expect(find.textContaining('删除'), findsNothing);

      // 1. 点击「选择」进入编辑模式
      await tester.tap(find.text('选择'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('完成选择'), findsOneWidget);
      expect(find.text('全选'), findsOneWidget);
      // 未选曲目时，仍为重新扫描（未触发删除按钮）
      expect(find.text('重新扫描'), findsOneWidget);

      // 2. 点击歌曲卡片选中
      final itemFinder = find.byType(MacMusicItemWidget);
      expect(itemFinder, findsOneWidget);
      await tester.tap(itemFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // 3. 验证选中后按钮自动变为「删除 (1)」
      expect(find.text('删除 (1)'), findsOneWidget);
      expect(find.text('重新扫描'), findsNothing);

      // 4. 点击「删除 (1)」呼出二次确认对话框
      await tester.tap(find.text('删除 (1)'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('确认删除曲目与源文件'), findsOneWidget);
      expect(find.textContaining('警告：该操作将直接从本地存储中彻底删除音频源文件'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('彻底删除'), findsOneWidget);

      // 5. 点击「彻底删除」确认操作
      await tester.tap(find.text('彻底删除'));
      await tester.pump(const Duration(milliseconds: 100));

      // 验证源文件被彻底删除
      expect(file.existsSync(), isFalse);
      expect(db.tracks.isEmpty, isTrue);

      // 验证提示 Snackbar
      expect(find.text('已成功删除 1 首歌曲及其本地源文件'), findsOneWidget);

      // 验证曲库清空后优雅退回 idle 态（本地曲库暂无音乐）
      expect(find.textContaining('本地曲库暂无音乐'), findsOneWidget);
    });
  });
}
