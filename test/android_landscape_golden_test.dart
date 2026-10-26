import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/models/sidebar_tab.dart';
import 'package:hide_player_flutter/platform/platform_audio_runtime.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';
import 'package:hide_player_flutter/services/mobile_system_service.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/android/android_player_view.dart';
import 'package:hide_player_flutter/ui/android/widgets/android_orientation_dialog.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_dac_setting_view.dart';

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

  testWidgets('Golden: Android Landscape DAC shows real USB output controls',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const channel = MethodChannel('test/android-golden-dac');
    const devices = [
      {
        'id': '1',
        'name': 'Android 扬声器',
        'transport': 'BuiltIn',
        'isBuiltIn': true,
        'sampleRates': [48000],
        'maxSampleRate': 48000,
        'maxBitDepth': 24,
      },
      {
        'id': '42',
        'name': 'TOPPING DX1 II',
        'transport': 'USB',
        'sampleRates': [44100, 48000, 96000, 192000, 384000],
        'channelCounts': [2],
        'bitDepths': [16, 24, 32],
        'maxSampleRate': 384000,
        'maxBitDepth': 32,
      },
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return call.method == 'getOutputDevices' ? devices : devices.last;
    });
    final runtime = PlatformAudioRuntime.forTesting(
      channel: channel,
      isIOS: false,
      isAndroid: true,
      reportOutput: (_) {},
      configureAndroidOutput: (_, __, ___) => true,
      setAndroidBufferFrames: (_) => true,
      readAndroidOutput: () => {
        'deviceId': 42,
        'isOpen': true,
        'sampleRate': 96000,
        'channels': 2,
        'bitDepth': 32,
        'bufferFrames': 512,
        'exclusive': false,
      },
    );
    await tester.runAsync(() => runtime.refreshOutput());
    final dac = DacSettingService.forTesting(
      readDevices: () => '[]',
      selectOutput: (_) => false,
      followsSystemOutput: false,
      runtime: runtime,
    );
    addTearDown(() {
      dac.dispose();
      runtime.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: HifiTheme.darkTheme,
        home: Scaffold(
          body: MacDACSettingView(
            platform: HifiPlatformType.android,
            service: dac,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.text('输出采样率策略'), findsOneWidget);
    expect(find.text('独占输出偏好'), findsOneWidget);

    await expectLater(
      find.byType(MacDACSettingView),
      matchesGoldenFile('goldens/android_landscape_dac.png'),
    );
    await tester.drag(find.byType(MacDACSettingView), const Offset(0, -450));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('系统共享').hitTestable(), findsOneWidget);
    expect(find.text('1024 帧').hitTestable(), findsOneWidget);
    await expectLater(
      find.byType(MacDACSettingView),
      matchesGoldenFile('goldens/android_landscape_dac_settings.png'),
    );
    await tester.pumpWidget(const SizedBox());
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
