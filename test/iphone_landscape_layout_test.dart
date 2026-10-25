import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/models/sidebar_tab.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/ui/iphone/iphone_landscape_view.dart';
import 'package:hide_player_flutter/ui/iphone/widgets/iphone_bottom_bar_widget.dart';
import 'package:hide_player_flutter/ui/mac/mac_sidebar_widget.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_all_music_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_equalizer_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_web_service_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = MusicDatabaseService.instance;

  setUp(() {
    HifiAudioService.instance.stopTicker();
    HifiAudioService.instance.resetEq();
    db.setSetting('active_sidebar_tab', '${SidebarTab.allMusic.index}');
  });

  Future<void> mount(WidgetTester tester, SidebarTab tab, Size size,
      {EdgeInsets padding = const EdgeInsets.fromLTRB(62, 0, 62, 21)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    db.setSetting('active_sidebar_tab', '${tab.index}');
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, padding: padding),
        child: const IphoneLandscapeView(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder action(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(InkWell)).first;

  testWidgets(
      'Landscape margins reclaim the empty left edge while keeping the cutout and Home Indicator clear',
      (tester) async {
    await mount(tester, SidebarTab.allMusic, const Size(844, 390));
    final sidebar = tester.getRect(find.byType(MacSidebarWidget));
    final stage = tester.getRect(find.byType(MacAllMusicView));
    final transport = tester.getRect(find.byType(IphoneBottomBarWidget));
    expect(sidebar.left, 24); // 16 safe pixels + 8 workspace pixels.
    expect(stage.right, 844 - 62);
    expect(transport.right, stage.right);
    expect(transport.bottom, 390 - 21 - 10);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Phones without a camera cutout keep the requested asymmetric workspace margins',
      (tester) async {
    await mount(tester, SidebarTab.allMusic, const Size(667, 375),
        padding: EdgeInsets.zero);
    expect(tester.getRect(find.byType(MacSidebarWidget)).left, 8);
    expect(tester.getRect(find.byType(MacAllMusicView)).right, 667);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(667, 375), const Size(844, 390)]) {
    testWidgets('EQ actions stay at the right of its title at $size',
        (tester) async {
      await mount(tester, SidebarTab.equalizer, size);
      final title = tester.getRect(find.text('图形均衡器'));
      final reset = tester.getRect(action('复原'));
      final bypass = tester.getRect(action('EQ 已旁路'));
      final stage = tester.getRect(find.byType(MacEqualizerView));
      expect(reset.left, greaterThan(title.right));
      expect(bypass.left, greaterThan(reset.right));
      expect(reset.top, closeTo(title.top, 1));
      expect(bypass.top, closeTo(reset.top, 1));
      expect(stage.right - bypass.right, closeTo(21, 1));
      await tester.tap(action('EQ 已旁路'));
      await tester.pump();
      expect(find.text('EQ 已激活'), findsOneWidget);
      await tester.tap(action('复原'));
      await tester.pump();
      expect(find.text('EQ 已旁路'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Web module switch stays at the right of its title at $size',
        (tester) async {
      await mount(tester, SidebarTab.webService, size);
      final title = tester.getRect(find.text('Web 服务'));
      final remote = tester.getRect(action('Web 远程控制'));
      final wifi = tester.getRect(action('WiFi 局域网传歌'));
      final stage = tester.getRect(find.byType(MacWebServiceView));
      expect(remote.left, greaterThan(title.right));
      expect(wifi.left, greaterThanOrEqualTo(remote.right));
      expect(remote.top, closeTo(title.top + 3, 1));
      expect(wifi.top, closeTo(remote.top, 1));
      expect(stage.right - wifi.right, closeTo(24, 1));
      await tester.tap(action('WiFi 局域网传歌'));
      await tester.pump();
      expect(find.textContaining('传歌网址: http://'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Existing Mac Web header retains its narrow-window arrangement',
      (tester) async {
    tester.view.physicalSize = const Size(500, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home:
            Scaffold(body: MacWebServiceView(platform: HifiPlatformType.mac))));
    await tester.pump();
    final title = tester.getRect(find.text('Web 服务'));
    final remote = tester.getRect(action('Web 远程控制'));
    expect(remote.left, closeTo(title.left + 3, 1));
    expect(remote.top, greaterThan(title.bottom));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Existing Mac EQ header retains its wrapping toolbar arrangement',
      (tester) async {
    final previousPlatform = PlatformHelper.currentPlatform;
    PlatformHelper.currentPlatform = HifiPlatformType.mac;
    addTearDown(() => PlatformHelper.currentPlatform = previousPlatform);
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MacEqualizerView())));
    await tester.pump();
    final title = tester.getRect(find.text('图形均衡器'));
    final reset = tester.getRect(action('复原'));
    expect(reset.left, closeTo(title.left, 1));
    expect(reset.top, greaterThan(title.bottom));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
