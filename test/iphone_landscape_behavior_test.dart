import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/sidebar_tab.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/mobile_system_service.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/iphone/iphone_landscape_view.dart';
import 'package:hide_player_flutter/ui/mac/mac_sidebar_widget.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_all_music_view.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_stage_widget.dart';
import 'package:hide_player_flutter/ui/visualizers/mobile_telemetry_dashboard_widget.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = MusicDatabaseService.instance;
  setUp(() {
    HifiAudioService.instance.stopTicker();
    db.tracks.clear();
    db.playlists.clear();
    db.setSetting('active_sidebar_tab', '0');
    ThemeService.instance.resetToDefault();
  });

  Future<void> mount(WidgetTester tester, Size size,
      {Key? key, EdgeInsets viewInsets = EdgeInsets.zero}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: HifiTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
            size: size,
            viewInsets: viewInsets,
            padding: const EdgeInsets.only(left: 44, right: 44, bottom: 21)),
        child: IphoneLandscapeView(key: key),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final size in [
    const Size(667, 375),
    const Size(844, 390),
    const Size(932, 430)
  ]) {
    testWidgets('All landscape pages fit safe areas at $size', (tester) async {
      for (final tab
          in SidebarTab.values.where((t) => t != SidebarTab.customPlaylist)) {
        db.setSetting('active_sidebar_tab', '${tab.index}');
        await mount(tester, size, key: ValueKey(tab));
        expect(tester.takeException(), isNull, reason: '$tab must fit $size');
        expect(find.byIcon(Icons.screen_rotation_rounded), findsNothing);
        final sidebar = tester.getRect(find.byType(MacSidebarWidget));
        expect(sidebar.left, 12);
        expect(sidebar.bottom, lessThanOrEqualTo(size.height - 21));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Custom playlist excludes unrelated library tracks',
      (tester) async {
    const first = Track(
        id: 1,
        title: '歌单内曲目',
        artist: '音乐家',
        album: '专辑',
        filepath: '/Music/one.wav',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitDepth: 16,
        durationSec: 100);
    const second = Track(
        id: 2,
        title: '其他曲库歌曲',
        artist: '音乐家',
        album: '专辑',
        filepath: '/Music/two.wav',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitDepth: 16,
        durationSec: 100);
    db.tracks.addAll([first, second]);
    db.playlists.add(Playlist(id: 80, name: '我的精选', tracks: [first]));
    db.setSetting('active_sidebar_tab', '${SidebarTab.customPlaylist.index}');
    db.setSetting('active_playlist_id', '80');
    await mount(tester, const Size(844, 390));
    final view = tester.widget<MacAllMusicView>(find.byType(MacAllMusicView));
    expect(view.title, '我的精选');
    expect(view.tracks, [first]);
    expect(find.text('歌单内曲目'), findsOneWidget);
    expect(find.text('其他曲库歌曲'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Long press adds a library track and removes it from the selected playlist',
      (tester) async {
    db.cleanLibrary();
    const track = Track(
        title: '歌单操作测试',
        artist: '音乐家',
        album: '专辑',
        filepath: '/Music/playlist-test.wav',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitDepth: 16,
        durationSec: 100);
    expect(db.saveScannedTracks([track]), isTrue);
    db.createPlaylist('收藏');
    final playlistId = db.playlists.last.id;
    final trackId = db.tracks.single.id;
    await mount(tester, const Size(844, 390));
    await tester.longPress(find.text('歌单操作测试'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '收藏'));
    await tester.pumpAndSettle();
    expect(db.playlists.single.tracks.single.id, trackId);
    db.setSetting('active_sidebar_tab', '${SidebarTab.customPlaylist.index}');
    db.setSetting('active_playlist_id', '$playlistId');
    await mount(tester, const Size(844, 390), key: const ValueKey('playlist'));
    await tester.longPress(find.text('歌单操作测试'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从本歌单移除'));
    await tester.pumpAndSettle();
    expect(db.playlists.single.tracks, isEmpty);
    expect(find.text('此播放列表暂无音乐'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    db.cleanLibrary();
  });

  testWidgets('Sidebar never invents a connected external DAC', (tester) async {
    await mount(tester, const Size(844, 390));
    final sidebar =
        tester.widget<MacSidebarWidget>(find.byType(MacSidebarWidget));
    expect(sidebar.isDacConnected, isFalse);
    expect(find.text('TOPPING DX1 II'), findsNothing);
    expect(find.text('DAC: 未连接'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Fullscreen keeps the selected theme and restores the workspace',
      (tester) async {
    ThemeService.instance
        .setBackgroundVisualMode(VisualizerType.tapeReel.index);
    await mount(tester, const Size(844, 390));
    await tester.tap(find.byTooltip('全屏沉浸表头'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MacSidebarWidget), findsNothing);
    expect(
        tester
            .widget<VisualizerStageWidget>(find.byType(VisualizerStageWidget))
            .activeType,
        VisualizerType.tapeReel);
    await tester.tap(find.byTooltip('退出全屏'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MacSidebarWidget), findsOneWidget);
    expect(ThemeService.instance.backgroundVisualMode,
        VisualizerType.tapeReel.index);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('New playlist remains reachable above the landscape keyboard',
      (tester) async {
    await mount(tester, const Size(667, 375),
        viewInsets: const EdgeInsets.only(bottom: 210));
    final add = find.text('添加播放列表');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '测试歌单');
    await tester.ensureVisible(find.text('创建'));
    await tester.tap(find.text('创建'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.widget<MacAllMusicView>(find.byType(MacAllMusicView)).title,
        '测试歌单');
    expect(find.text('此播放列表暂无音乐'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'iPhone hardware master retains all panels on a small landscape display',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(MobileSystemService.channel,
        (_) async => {'model': 'iPhone test device'});
    addTearDown(() =>
        messenger.setMockMethodCallHandler(MobileSystemService.channel, null));
    ThemeService.instance.setTheme(9);
    await mount(tester, const Size(667, 375));
    await tester.tap(find.byTooltip('全屏沉浸表头'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MobileTelemetryDashboardWidget), findsOneWidget);
    expect(find.text('iPhone 硬件大师'), findsOneWidget);
    expect(find.textContaining('CPU 核心'), findsNothing);
    expect(find.text('核心数未提供'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'System telemetry accepts measured values and preserves unavailable metrics',
      () {
    final data = MobileSystemSnapshot.fromMap({
      'model': 'iPhone18,1',
      'processorCount': 6,
      'batteryLevel': -1.0,
      'storageTotalBytes': 256000000000,
    });
    expect(data.model, 'iPhone18,1');
    expect(data.processorCount, 6);
    expect(data.batteryLevel, isNull);
    expect(data.appMemoryBytes, isNull);
    expect(data.thermalState, isNull);
  });

  test('System telemetry reads the iOS bridge without synthetic fallbacks',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MobileSystemService.channel, (call) async {
      expect(call.method, 'getSystemInfo');
      return {
        'model': 'iPhone18,1',
        'processorCount': 6,
        'physicalMemoryBytes': 8000000000,
        'appMemoryBytes': 125000000,
        'batteryLevel': 0.73,
        'batteryState': 'unplugged'
      };
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MobileSystemService.channel, null));
    final service = MobileSystemService.forTesting();
    await service.refresh();
    expect(service.snapshot.batteryLevel, .73);
    expect(service.snapshot.processorCount, 6);
    expect(service.snapshot.thermalState, isNull);
  });
}
