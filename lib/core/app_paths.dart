import 'dart:io';
import 'package:path/path.dart' as p;
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

  /// Rebase persisted iOS sandbox paths after reinstall/update. Keep the full
  /// Documents-relative album path so duplicate CDImage.wav names stay distinct.
  static String resolveDocumentsPath(
    String path, {
    String? documentsRoot,
    bool? isIOS,
  }) {
    if (path.isEmpty || !(isIOS ?? Platform.isIOS)) return path;
    final docs = documentsRoot ?? documentsDirectory;
    final normalized = p.normalize(path);
    final marker = normalized.indexOf('/Documents/');
    String? relative;
    if (marker >= 0) {
      relative = normalized.substring(marker + '/Documents/'.length);
    } else if (normalized.endsWith('/Documents')) {
      relative = '';
    }
    if (relative != null) {
      final remapped = p.normalize(p.join(docs, relative));
      if (FileSystemEntity.typeSync(remapped) !=
          FileSystemEntityType.notFound) {
        return remapped;
      }
    }
    if (FileSystemEntity.typeSync(normalized) !=
        FileSystemEntityType.notFound) {
      return normalized;
    }
    return path;
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
