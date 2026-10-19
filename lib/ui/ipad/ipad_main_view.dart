import 'package:flutter/material.dart';
import '../../core/platform_helper.dart';
import '../landscape/landscape_main_view.dart';

/// iPad / 平板端发烧纯音横屏主视窗
/// 与 Mac、树莓派 100% 共享全景 Master-Detail 架构与发烧动效中心
class IpadMainView extends StatelessWidget {
  const IpadMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return const LandscapeMainView(
      platform: HifiPlatformType.ipad,
    );
  }
}
