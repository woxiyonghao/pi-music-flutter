import 'package:flutter/material.dart';
import '../../../core/platform_helper.dart';
import '../../mac/views/mac_dac_setting_view.dart';

/// Share actual iOS output capabilities with the landscape DAC page.
class IphoneDacSettingView extends StatelessWidget {
  const IphoneDacSettingView({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 620,
        child: MacDACSettingView(platform: HifiPlatformType.iphone),
      );
}
