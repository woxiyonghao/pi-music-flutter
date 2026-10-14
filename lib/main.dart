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

          // 包装多平台即时切换浮动悬浮球 (方便在 Mac 开发期一键预览所有 6 大平台 UI)
          return Stack(
            children: [
              content,
              Positioned(
                right: 16,
                top: 40,
                child: Opacity(
                  opacity: 0.6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: HifiTheme.mcIntoshGlow.withOpacity(0.5)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<HifiPlatformType>(
                        value: platform,
                        dropdownColor: HifiTheme.cardBackground,
                        icon: const Icon(Icons.devices_rounded, size: 16, color: HifiTheme.mcIntoshGlow),
                        style: const TextStyle(fontSize: 11, color: HifiTheme.textPrimary),
                        items: const [
                          DropdownMenuItem(value: HifiPlatformType.mac, child: Text('🖥️ Mac')),
                          DropdownMenuItem(value: HifiPlatformType.pi, child: Text('🥧 树莓派 7寸')),
                          DropdownMenuItem(value: HifiPlatformType.iphone, child: Text('📱 iPhone')),
                          DropdownMenuItem(value: HifiPlatformType.ipad, child: Text('📟 iPad')),
                          DropdownMenuItem(value: HifiPlatformType.android, child: Text('🤖 Android')),
                          DropdownMenuItem(value: HifiPlatformType.window, child: Text('🪟 Windows')),
                        ],
                        onChanged: (newPlat) {
                          if (newPlat != null) {
                            setState(() {
                              _activePlatform = newPlat;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
