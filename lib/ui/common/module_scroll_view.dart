import 'package:flutter/material.dart';
import '../../core/platform_helper.dart';

/// iPhone modules use one scroll position for their heading and all controls.
/// Other platform layouts retain their fixed heading and scrolling body.
class ModuleScrollView extends StatelessWidget {
  const ModuleScrollView({
    super.key,
    required this.storageId,
    required this.header,
    required this.children,
    this.platform,
  });

  final String storageId;
  final List<Widget> header;
  final List<Widget> children;
  final HifiPlatformType? platform;

  @override
  Widget build(BuildContext context) {
    final activePlatform = platform ?? PlatformHelper.currentPlatform;
    if (activePlatform == HifiPlatformType.iphone ||
        activePlatform == HifiPlatformType.android) {
      return ListView(
        key: PageStorageKey(storageId),
        physics: const BouncingScrollPhysics(),
        children: [...header, ...children],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...header,
        Expanded(
          child: ListView(
            key: PageStorageKey('$storageId-body'),
            physics: const BouncingScrollPhysics(),
            children: children,
          ),
        ),
      ],
    );
  }
}
