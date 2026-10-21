import 'dart:convert';
import 'dart:io';

// Build-time tool only. Mobile applications never fetch Git repositories.
void main(List<String> args) {
  final root = File.fromUri(Platform.script).parent.parent;
  final lock =
      jsonDecode(File('${root.path}/audio_engine.lock.json').readAsStringSync())
          as Map<String, dynamic>;
  final revision = lock['revision'] as String;
  final repository = lock['repository'] as String;
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(revision) ||
      lock['abiVersion'] != 2 ||
      repository != 'git@github.com:woxiyonghao/pi-music-flutter.git') {
    throw StateError(
        'Invalid audio_engine lock; use an exact revision from pi-music-flutter');
  }
  final cache = Directory('${root.path}/.dart_tool/audio_engine')
    ..createSync(recursive: true);
  final mutex =
      File('${cache.path}/fetch.lock').openSync(mode: FileMode.append);
  mutex.lockSync(FileLock.blockingExclusive);
  try {
    final source = Directory('${cache.path}/source');
    String git(List<String> arguments) {
      final result =
          Process.runSync('git', arguments, workingDirectory: source.path);
      if (result.exitCode != 0) {
        throw ProcessException(
            'git', arguments, '${result.stderr}', result.exitCode);
      }
      return '${result.stdout}'.trim();
    }

    if (!Directory('${source.path}/.git').existsSync()) {
      source.createSync(recursive: true);
      git(['init', '--quiet']);
      git(['remote', 'add', 'origin', repository]);
    }
    final head = Process.runSync('git', ['rev-parse', '--verify', 'HEAD'],
        workingDirectory: source.path);
    if (head.exitCode == 0 && git(['status', '--porcelain']).isNotEmpty) {
      throw StateError(
          'Cached engine contains local edits: ${source.path}. Preserve them before updating.');
    }
    if ('${head.stdout}'.trim() != revision) {
      git(['remote', 'set-url', 'origin', repository]);
      git(['fetch', '--quiet', '--depth=1', 'origin', revision]);
      git(['checkout', '--quiet', '--detach', revision]);
    }
    if (git(['rev-parse', 'HEAD']) != revision ||
        !File('${source.path}/include/hifi_audio_ffi.h').existsSync()) {
      throw StateError('Engine checkout does not match its lock');
    }
    stdout.writeln(source.absolute.path);
  } finally {
    mutex.unlockSync();
    mutex.closeSync();
  }
}
