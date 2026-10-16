import 'package:flutter/material.dart';
import '../../services/pi_system_service.dart';
import '../landscape/landscape_main_view.dart';

/// 树莓派 5 专属 7寸 (1024×600) 横屏发烧台机 UI
/// 100% 保持与 Mac、iPad 统一的全景 Master-Detail 架构与发烧动效中心
class PiMainView extends StatelessWidget {
  const PiMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PiSystemService.instance,
      builder: (context, _) {
        return LandscapeMainView(
          overrideDacName: PiSystemService.instance.dacDeviceName,
        );
      },
    );
  }
}
