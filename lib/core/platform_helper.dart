import 'dart:io';
import 'package:flutter/foundation.dart';

enum HifiPlatformType {
  iphone,
  android,
  pi,
  ipad,
  mac,
  window,
}

class PlatformHelper {
  /// 手动覆盖平台类型（方便在 Mac 开发期预览所有端界面）
  static HifiPlatformType? overridePlatform;

  /// 智能推断当前应激活的 UI 形态
  static HifiPlatformType detect(double screenWidth, double screenHeight) {
    if (overridePlatform != null) {
      return overridePlatform!;
    }

    if (kIsWeb) return HifiPlatformType.mac;

    if (Platform.isIOS) {
      return (screenWidth >= 600 || screenHeight >= 1000)
          ? HifiPlatformType.ipad
          : HifiPlatformType.iphone;
    }

    if (Platform.isAndroid) {
      return (screenWidth >= 600) ? HifiPlatformType.ipad : HifiPlatformType.android;
    }

    if (Platform.isMacOS) {
      return HifiPlatformType.mac;
    }

    if (Platform.isWindows) {
      return HifiPlatformType.window;
    }

    if (Platform.isLinux) {
      // 树莓派微雪 7 寸通常是 1024x600 或检测环境变量
      final isPiScreen = (screenWidth <= 1024 && screenHeight <= 600) ||
          Platform.environment.containsKey('HIFI_PLATFORM_RPI');
      return isPiScreen ? HifiPlatformType.pi : HifiPlatformType.mac;
    }

    return HifiPlatformType.mac;
  }
}
