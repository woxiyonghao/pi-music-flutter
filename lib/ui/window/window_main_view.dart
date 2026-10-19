import 'package:flutter/material.dart';
import '../../core/platform_helper.dart';
import '../landscape/landscape_main_view.dart';

/// Windows 桌面端发烧纯音横屏主视窗
/// 与 Mac、iPad、树莓派 100% 共享全景 Master-Detail 架构与发烧动效中心
class WindowMainView extends StatelessWidget {
  const WindowMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return const LandscapeMainView(
      platform: HifiPlatformType.window,
    );
  }
}
