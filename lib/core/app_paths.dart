import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 统一跨平台路径管理中心 (解决 iOS 物理真机沙盒 Documents 路径定位)
class AppPaths {
  static String? _documentsDirectory;

  /// 初始化异步路径缓存 (在 main() 中启动首位执行)
  static Future<void> init() async {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        _documentsDirectory = dir.path;
        debugPrint('[AppPaths] 已锁定 Documents 目录: $_documentsDirectory');
      } catch (e) {
        debugPrint('[AppPaths] 获取 Documents 失败: $e');
      }
    }
  }

  /// 同步获取真实沙盒 Documents 目录
  static String get documentsDirectory {
    if (_documentsDirectory != null && _documentsDirectory!.isNotEmpty) {
      return _documentsDirectory!;
    }
    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty) {
      return '$home/Documents';
    }
    return Directory.current.path;
  }

  /// 获取音乐存储目录
  static String get musicDirectory {
    final home = Platform.environment['HOME'] ?? '';
    if (Platform.isIOS) {
      return documentsDirectory;
    }
    if (home.isNotEmpty) {
      final macMusic = '$home/Music';
      if (Directory(macMusic).existsSync()) return macMusic;
      final downloadsMusic = '$home/Downloads/music';
      if (Directory(downloadsMusic).existsSync()) return downloadsMusic;
      final downloads = '$home/Downloads';
      if (Directory(downloads).existsSync()) return downloads;
    }
    if (Platform.isLinux) {
      return '/home/pi/Music';
    }
    return Directory.current.path;
  }
}
