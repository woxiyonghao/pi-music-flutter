import 'dart:io';
import 'package:path/path.dart' as p;

/// Platform code chooses accessible roots; C++ owns everything below them.
class LibraryScanPolicy {
  static const androidPublicMusic = [
    '/storage/emulated/0/Music/pimusic', '/sdcard/Music/pimusic',
    '/storage/emulated/0/Music', '/sdcard/Music',
  ];

  static List<String> roots({required String platform,
      required String documents, String wifiDirectory = '',
      String? customPath, String? directory, String? home,
      String systemRoot = '/', List<String>? testRoots}) {
    if (testRoots != null) return List.of(testRoots);
    final candidates = <String>[];
    if (customPath != null) candidates.add(customPath);
    if (platform == 'android' || platform == 'iphone' || platform == 'ipad') {
      candidates.add(documents);
      if (wifiDirectory.isNotEmpty) candidates.add(wifiDirectory);
      if (platform == 'android' && customPath == null) candidates.addAll(androidPublicMusic);
    } else if (platform == 'pi' || platform == 'linux') {
      if (customPath == null) candidates.add(systemRoot);
    } else if (customPath == null) {
      final userHome = home ?? Platform.environment['HOME'] ?? '';
      candidates.addAll([p.join(userHome, 'Music'), p.join(userHome, 'Downloads', 'music')]);
    }
    if (directory != null) candidates.add(directory);
    final result = <String>{};
    for (final path in candidates) {
      if (Directory(path).existsSync()) result.add(p.normalize(p.absolute(path)));
    }
    return result.toList(growable: false);
  }
}
