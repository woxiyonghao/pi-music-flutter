import 'package:flutter/material.dart';
import 'core/platform_helper.dart';
import 'theme/hifi_theme.dart';
import 'ui/iphone/iphone_main_view.dart';
import 'ui/android/android_main_view.dart';
import 'ui/pi/pi_main_view.dart';
import 'ui/ipad/ipad_main_view.dart';
import 'ui/mac/mac_main_view.dart';
import 'ui/window/window_main_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HiFiPlayerApp());
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
