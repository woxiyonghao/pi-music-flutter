import 'package:flutter/material.dart';
import '../../../core/platform_helper.dart';
import '../../mac/views/mac_system_settings_view.dart';

/// Keep the same real iOS options in both startup orientations.
class IphoneSystemSettingsView extends StatelessWidget {
  const IphoneSystemSettingsView({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 900,
        child: MacSystemSettingsView(platform: HifiPlatformType.iphone),
      );
}
