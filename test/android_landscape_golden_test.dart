import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/sidebar_tab.dart';
import 'package:hide_player_flutter/services/mobile_system_service.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/android/android_player_view.dart';
import 'package:hide_player_flutter/ui/android/widgets/android_orientation_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ThemeService.instance.resetToDefault();
  });

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MobileSystemService.channel, (_) async {
      throw MissingPluginException('golden_no_native_bridge');
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MobileSystemService.channel, null);
  });

  testWidgets('Golden: Android Startup Orientation Dialog matches iPhone 1:1',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: AndroidOrientationDialog(
              initialIsLandscape: false,
              onConfirmed: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/iphone_startup_orientation.png'),
    );
  });

  testWidgets('Golden: Android Landscape Showcase matches iPhone 1:1',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance
        .setSetting('active_sidebar_tab', SidebarTab.allMusic.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const AndroidPlayerView(landscape: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(AndroidPlayerView),
      matchesGoldenFile('goldens/iphone_landscape_showcase.png'),
    );
  });

  testWidgets('Golden: Android Landscape DAC View matches iPhone 1:1',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.dacSettings.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const AndroidPlayerView(landscape: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(AndroidPlayerView),
      matchesGoldenFile('goldens/iphone_landscape_dac.png'),
    );
  });

  testWidgets('Golden: Android Landscape Theme View matches iPhone 1:1',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.themeSettings.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const AndroidPlayerView(landscape: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(AndroidPlayerView),
      matchesGoldenFile('goldens/iphone_landscape_theme.png'),
    );
  });

  testWidgets(
      'Golden: Android Landscape System Settings View matches iPhone 1:1',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.systemSettings.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const AndroidPlayerView(landscape: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(AndroidPlayerView),
      matchesGoldenFile('goldens/iphone_landscape_settings.png'),
    );
  });

  testWidgets('Golden: Android Landscape Equalizer View matches iPhone 1:1',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.equalizer.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const AndroidPlayerView(landscape: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(AndroidPlayerView),
      matchesGoldenFile('goldens/iphone_landscape_eq.png'),
    );
  });

  testWidgets('Golden: Android Landscape Scan Music View matches iPhone 1:1',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.scanMusic.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const AndroidPlayerView(landscape: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(AndroidPlayerView),
      matchesGoldenFile('goldens/iphone_landscape_scan.png'),
    );
  });

  testWidgets('Golden: Android Landscape Web Service View matches iPhone 1:1',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.webService.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const AndroidPlayerView(landscape: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(AndroidPlayerView),
      matchesGoldenFile('goldens/iphone_landscape_web.png'),
    );
  });

  testWidgets('Golden: Android Hardware Master Fullscreen matches iPhone 1:1',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ThemeService.instance.setTheme(9);
    MusicDatabaseService.instance.setSetting('active_sidebar_tab', '0');

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const AndroidPlayerView(landscape: true),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('全屏沉浸表头'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(AndroidPlayerView),
      matchesGoldenFile('goldens/iphone_landscape_hardware_master.png'),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
