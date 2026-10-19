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

  /// 全局当前生效的平台形态 (默认由 detect 自动推断更新)
  static HifiPlatformType currentPlatform = HifiPlatformType.mac;

  /// 智能推断当前应激活的 UI 形态
  static HifiPlatformType detect(double screenWidth, double screenHeight) {
    if (overridePlatform != null) {
      currentPlatform = overridePlatform!;
      return overridePlatform!;
    }

    if (kIsWeb) {
      currentPlatform = HifiPlatformType.mac;
      return currentPlatform;
    }

    if (Platform.isIOS) {
      currentPlatform = (screenWidth >= 600 || screenHeight >= 1000)
          ? HifiPlatformType.ipad
          : HifiPlatformType.iphone;
      return currentPlatform;
    }

    if (Platform.isAndroid) {
      currentPlatform = (screenWidth >= 600) ? HifiPlatformType.ipad : HifiPlatformType.android;
      return currentPlatform;
    }

    if (Platform.isMacOS) {
      currentPlatform = HifiPlatformType.mac;
      return currentPlatform;
    }

    if (Platform.isWindows) {
      currentPlatform = HifiPlatformType.window;
      return currentPlatform;
    }

    if (Platform.isLinux) {
      currentPlatform = HifiPlatformType.pi;
      return currentPlatform;
    }

    currentPlatform = HifiPlatformType.mac;
    return currentPlatform;
  }

  static bool get isIpad => currentPlatform == HifiPlatformType.ipad || (overridePlatform == null && Platform.isIOS);
  static bool get isMac => currentPlatform == HifiPlatformType.mac || (overridePlatform == null && Platform.isMacOS);
  static bool get isPi => currentPlatform == HifiPlatformType.pi || (overridePlatform == null && Platform.isLinux);
  static bool get isApple => isIpad || isMac;

  /// 获取平台友好名称
  static String getPlatformName([HifiPlatformType? type]) {
    final t = type ?? currentPlatform;
    switch (t) {
      case HifiPlatformType.ipad:
        return 'iPad';
      case HifiPlatformType.mac:
        return 'macOS';
      case HifiPlatformType.pi:
        return '树莓派 5';
      case HifiPlatformType.iphone:
        return 'iPhone';
      case HifiPlatformType.android:
        return 'Android';
      case HifiPlatformType.window:
        return 'Windows';
    }
  }
}
