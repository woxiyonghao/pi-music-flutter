import 'dart:io';
import 'package:flutter/material.dart';
import 'core/app_paths.dart';
import 'core/platform_helper.dart';
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
  runApp(const HiFiPlayerApp());

  // 启动后台 Web 远程遥控服务 (8088 端口) 与局域网极速无线传歌服务 (8080 端口)
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    WebRemoteService.instance.start(port: 8088);
    WifiTransferService.instance.start(port: 8080);
  }
}

class HiFiPlayerApp extends StatefulWidget {
  const HiFiPlayerApp({super.key});

  @override
  State<HiFiPlayerApp> createState() => _HiFiPlayerAppState();
}

class _HiFiPlayerAppState extends State<HiFiPlayerApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyHiFi Player',
      debugShowCheckedModeBanner: false,
      theme: HifiTheme.darkTheme,
      scrollBehavior: const MouseDraggableScrollBehavior(),
      builder: (context, child) {
        if (Platform.isLinux || Platform.environment['PI_KIOSK'] == '1') {
          return MouseRegion(
            cursor: SystemMouseCursors.none,
            child: child ?? const SizedBox.shrink(),
          );
        }
        return child ?? const SizedBox.shrink();
      },
      home: LayoutBuilder(
        builder: (context, constraints) {
          final platform = PlatformHelper.detect(constraints.maxWidth, constraints.maxHeight);

          switch (platform) {
            case HifiPlatformType.iphone:
              return const IphoneMainView();
            case HifiPlatformType.android:
              return const AndroidMainView();
            case HifiPlatformType.pi:
              return const PiMainView();
            case HifiPlatformType.ipad:
              return const IpadMainView();
            case HifiPlatformType.mac:
              return const MacMainView();
            case HifiPlatformType.window:
              return const WindowMainView();
          }
        },
      ),
    );
  }
}
