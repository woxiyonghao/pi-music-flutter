import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_paths.dart';
import 'core/platform_helper.dart';
import 'services/music_database_service.dart';
import 'services/web_remote_service.dart';
import 'services/wifi_transfer_service.dart';
import 'theme/hifi_theme.dart';
import 'theme/ui_config.dart';
import 'ui/iphone/iphone_main_view.dart';
import 'ui/android/android_main_view.dart';
import 'ui/pi/pi_main_view.dart';
import 'ui/ipad/ipad_main_view.dart';
import 'ui/mac/mac_main_view.dart';
import 'ui/window/window_main_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();
  MusicDatabaseService.instance.loadLibrary();

  // iPad 端强制锁定纯横屏 (只允许 LandscapeLeft / LandscapeRight)
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  runApp(const HiFiPlayerApp());

  // 启动后台 Web 远程遥控中枢 (WiFi 传歌服务默认不开启，由用户在界面按需开启)
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    WebRemoteService.instance.start(port: 8088);
  }
}

class HiFiPlayerApp extends StatefulWidget {
  const HiFiPlayerApp({super.key});

  @override
  State<HiFiPlayerApp> createState() => _HiFiPlayerAppState();
}

class _HiFiPlayerAppState extends State<HiFiPlayerApp> {
  HifiPlatformType? _activePlatform;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyHiFi Player',
      debugShowCheckedModeBanner: false,
      theme: HifiTheme.darkTheme,
      scrollBehavior: const MouseDraggableScrollBehavior(),
      home: LayoutBuilder(
        builder: (context, constraints) {
          final detected = PlatformHelper.detect(constraints.maxWidth, constraints.maxHeight);
          final platform = _activePlatform ?? detected;

          Widget content;
          switch (platform) {
            case HifiPlatformType.iphone:
              content = const IphoneMainView();
              break;
            case HifiPlatformType.android:
              content = const AndroidMainView();
              break;
            case HifiPlatformType.pi:
              content = const PiMainView();
              break;
            case HifiPlatformType.ipad:
              content = const IpadMainView();
              break;
            case HifiPlatformType.mac:
              content = const MacMainView();
              break;
            case HifiPlatformType.window:
              content = const WindowMainView();
              break;
          }

          return content;
        },
      ),
    );
  }
}
