import 'package:flutter/material.dart';
import '../mac/mac_main_view.dart';
export '../mac/mac_main_view.dart';

/// 跨端全景横屏发烧主视窗 (统一 Master-Detail 架构)
/// 专为 iPad、Mac、树莓派 7 寸 (1024×600) 与 Windows 宽屏台机形态量身定制
/// 1:1 对齐 C++ 全景发烧架构，实现多端视觉风格与交互逻辑完全统一
class UnifiedLandscapeMainView extends StatelessWidget {
  const UnifiedLandscapeMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return const LandscapeMainView();
  }
}
