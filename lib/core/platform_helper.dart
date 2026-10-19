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

  static bool get isIpad => (overridePlatform ?? currentPlatform) == HifiPlatformType.ipad;
  static bool get isMac => (overridePlatform ?? currentPlatform) == HifiPlatformType.mac;
  static bool get isPi => (overridePlatform ?? currentPlatform) == HifiPlatformType.pi;
  static bool get isApple => isIpad || isMac;

  /// 判断当前平台环境是否支持基于 Git 命令行工具的在线 OTA 热更新
  /// 移动端设备 (iPad, iPhone, Android) 处于无 Git 环境的封闭沙盒，严禁显示系统在线 OTA 升级
  static bool supportsGitOta([HifiPlatformType? platform]) {
    final p = platform ?? overridePlatform ?? currentPlatform;
    if (p == HifiPlatformType.ipad || p == HifiPlatformType.iphone || p == HifiPlatformType.android) {
      return false;
    }
    return p == HifiPlatformType.pi || p == HifiPlatformType.mac || p == HifiPlatformType.window;
  }

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
