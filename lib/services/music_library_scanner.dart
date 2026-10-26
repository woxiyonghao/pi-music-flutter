import 'dart:io';

import 'package:path/path.dart' as p;

/// Lists each physical music file once, including music reached through links.
/// A directory that cannot be read must not abort the rest of a storage device.
class MusicLibraryScanner {
  static const audioExtensions = {
    '.flac',
    '.wav',
    '.mp3',
    '.dsf',
    '.dff',
    '.alac',
    '.m4a',
    '.aac',
    '.aiff',
    '.aif',
    '.caf',
    '.ape',
  };

  static Future<MusicLibraryFiles> collect(Iterable<String> roots) async {
    final audio = <File>[];
    final cues = <File>[];
    final failedDirectories = <String>[];
    final visitedDirectories = <String>{};
    final visitedFiles = <String>{};
    final requestedRoots = roots.map(p.absolute).map(p.normalize).toSet();
    final pending =
        requestedRoots.map(Directory.new).toList().reversed.toList();

    while (pending.isNotEmpty) {
      final directory = pending.removeLast();
      try {
        final canonical = await directory.resolveSymbolicLinks();
        if (!visitedDirectories.add(canonical)) continue;
        // A Pi user's home commonly contains the app checkout and Flutter SDK.
        // Prune code/dependency trees while still allowing an explicit custom
        // scan of such a directory. Do not import bundled test audio as music.
        if (!requestedRoots.contains(p.normalize(directory.absolute.path)) &&
            (Directory(p.join(canonical, '.git')).existsSync() ||
                File(p.join(canonical, '.git')).existsSync() ||
                File(p.join(canonical, 'pubspec.yaml')).existsSync() ||
                File(p.join(canonical, 'package.json')).existsSync())) {
          continue;
        }
        // Work from the physical directory so CUE paths and linked WAV paths
        // have the same identity, and a symlink loop terminates here.
        await for (final entry
            in Directory(canonical).list(followLinks: false)) {
          final name = p.basename(entry.path);
          if (name.startsWith('.')) continue;
          final type = entry is Link
              ? await FileSystemEntity.type(entry.path)
              : (entry is Directory
                  ? FileSystemEntityType.directory
                  : FileSystemEntityType.file);
          if (type == FileSystemEntityType.directory) {
            // Avoid dependency/build trees when scanning a Pi user's SD card.
            if (name == 'node_modules' ||
                (name == 'build' &&
                    File(p.join(canonical, 'pubspec.yaml')).existsSync())) {
              continue;
            }
            pending.add(Directory(entry.path));
          } else if (type == FileSystemEntityType.file) {
            final extension = p.extension(name).toLowerCase();
            if (extension != '.cue' && !audioExtensions.contains(extension)) {
              continue;
            }
            final path = await File(entry.path).resolveSymbolicLinks();
            if (!visitedFiles.add(path)) continue;
            (extension == '.cue' ? cues : audio).add(File(path));
          }
        }
      } on FileSystemException {
        failedDirectories.add(directory.absolute.path);
      }
    }
    audio.sort((a, b) => a.path.compareTo(b.path));
    cues.sort((a, b) => a.path.compareTo(b.path));
    return MusicLibraryFiles(audio, cues, failedDirectories);
  }
}

class MusicLibraryFiles {
  final List<File> audioFiles;
  final List<File> cueFiles;
  final List<String> failedDirectories;

  const MusicLibraryFiles(
      this.audioFiles, this.cueFiles, this.failedDirectories);
}
