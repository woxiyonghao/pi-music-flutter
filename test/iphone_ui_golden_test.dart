import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/sidebar_tab.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/iphone/iphone_landscape_view.dart';
import 'package:hide_player_flutter/ui/iphone/iphone_portrait_view.dart';
import 'package:hide_player_flutter/ui/iphone/widgets/iphone_orientation_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ThemeService.instance.resetToDefault();
  });

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
  });

  testWidgets('Golden: iPhone Startup Orientation Dialog', (tester) async {
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
            child: IphoneOrientationDialog(
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

  testWidgets('Golden: iPhone Portrait DAC Setting View', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.dacSettings.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IphonePortraitView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(IphonePortraitView),
      matchesGoldenFile('goldens/iphone_portrait_dac.png'),
    );
  });

  testWidgets('Golden: iPhone Portrait Equalizer View', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.equalizer.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IphonePortraitView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(IphonePortraitView),
      matchesGoldenFile('goldens/iphone_portrait_eq.png'),
    );
  });

  testWidgets('Golden: iPhone Portrait All Music View', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance
        .setSetting('active_sidebar_tab', SidebarTab.allMusic.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IphonePortraitView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(IphonePortraitView),
      matchesGoldenFile('goldens/iphone_portrait_music.png'),
    );
  });

  testWidgets('Golden: iPhone Portrait Theme Setting View', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.themeSettings.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IphonePortraitView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(IphonePortraitView),
      matchesGoldenFile('goldens/iphone_portrait_theme.png'),
    );
  });

  testWidgets('Golden: iPhone Landscape View', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance
        .setSetting('active_sidebar_tab', SidebarTab.allMusic.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IphoneLandscapeView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(IphoneLandscapeView),
      matchesGoldenFile('goldens/iphone_landscape_showcase.png'),
    );
  });

  testWidgets('Golden: iPhone Landscape DAC View', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.dacSettings.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IphoneLandscapeView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(IphoneLandscapeView),
      matchesGoldenFile('goldens/iphone_landscape_dac.png'),
    );
  });

  testWidgets('Golden: iPhone Landscape Theme View', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.themeSettings.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IphoneLandscapeView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(IphoneLandscapeView),
      matchesGoldenFile('goldens/iphone_landscape_theme.png'),
    );
  });

  testWidgets('Golden: iPhone Landscape System Settings View', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.systemSettings.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IphoneLandscapeView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(IphoneLandscapeView),
      matchesGoldenFile('goldens/iphone_landscape_settings.png'),
    );
  });

  testWidgets('Golden: iPhone Landscape Equalizer View', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.equalizer.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IphoneLandscapeView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(IphoneLandscapeView),
      matchesGoldenFile('goldens/iphone_landscape_eq.png'),
    );
  });

  testWidgets('Golden: iPhone Landscape Scan Music View', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.scanMusic.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IphoneLandscapeView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(IphoneLandscapeView),
      matchesGoldenFile('goldens/iphone_landscape_scan.png'),
    );
  });

  testWidgets('Golden: iPhone Landscape Web Service View', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting(
        'active_sidebar_tab', SidebarTab.webService.index.toString());

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const IphoneLandscapeView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(IphoneLandscapeView),
      matchesGoldenFile('goldens/iphone_landscape_web.png'),
    );
  });
  testWidgets('Golden: iPhone Hardware Master Fullscreen', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ThemeService.instance.setTheme(9);
    MusicDatabaseService.instance.setSetting('active_sidebar_tab', '0');
    await tester.pumpWidget(MaterialApp(
        theme: HifiTheme.darkTheme, home: const IphoneLandscapeView()));
    await tester.pump();
    await tester.tap(find.byTooltip('全屏沉浸表头'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(IphoneLandscapeView),
        matchesGoldenFile('goldens/iphone_landscape_hardware_master.png'));
    await tester.pumpWidget(const SizedBox());
  });
}
