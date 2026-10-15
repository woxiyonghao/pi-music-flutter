import 'dart:io';
import 'package:flutter/material.dart';
import 'core/platform_helper.dart';
import 'services/web_remote_service.dart';
import 'theme/hifi_theme.dart';
import 'theme/ui_config.dart';
import 'ui/iphone/iphone_main_view.dart';
import 'ui/android/android_main_view.dart';
import 'ui/pi/pi_main_view.dart';
import 'ui/ipad/ipad_main_view.dart';
import 'ui/mac/mac_main_view.dart';
import 'ui/window/window_main_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HiFiPlayerApp());

  // 1:1 对齐 C++ Application.cpp，启动后台 Web 远程遥控中枢
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
  void initState() {
    super.initState();
    // dev/pi 专属开发分支默认激活树莓派 7 寸 (1024x600) 发烧台机形态
    _activePlatform = HifiPlatformType.pi;
  }

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

          // 在桌面开发环境 (macOS/Windows) 运行时，右上角配有浮动切换器，方便随时一键切换端侧 UI
          if ((Platform.isMacOS || Platform.isWindows) && !Platform.environment.containsKey('FLUTTER_TEST')) {
            return Stack(
              children: [
                content,
                Positioned(
                  top: 10,
                  right: 14,
                  child: _buildDevPlatformSwitcher(platform),
                ),
              ],
            );
          }

          return content;
        },
      ),
    );
  }

  Widget _buildDevPlatformSwitcher(HifiPlatformType current) {
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<HifiPlatformType>(
        tooltip: '开发期即时平台预览切换',
        initialValue: current,
        onSelected: (p) => setState(() => _activePlatform = p),
        color: HifiTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: HifiTheme.cardBorder),
        ),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: HifiPlatformType.pi,
            child: Text('🍓 树莓派 5 (1024×600 触控台机)', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
          const PopupMenuItem(
            value: HifiPlatformType.mac,
            child: Text('🖥️ macOS (桌面工作台全屏)', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
          const PopupMenuItem(
            value: HifiPlatformType.ipad,
            child: Text('📟 iPad (大屏双栏 Master-Detail)', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
          const PopupMenuItem(
            value: HifiPlatformType.iphone,
            child: Text('📱 iPhone (竖屏高密度)', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
          const PopupMenuItem(
            value: HifiPlatformType.window,
            child: Text('🪟 Windows (桌面客户端)', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.7), width: 1.0),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current == HifiPlatformType.pi
                    ? '🍓 树莓派 7寸屏预览'
                    : (current == HifiPlatformType.mac ? '🖥️ Mac 视图' : current.name.toUpperCase()),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down_rounded, color: HifiTheme.mcIntoshGlow, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
