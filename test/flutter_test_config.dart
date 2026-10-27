import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hide_player_flutter/core/native_music_library.dart';

/// Plain `flutter test` exercises the same C++ database/CUE core as the app.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final override = Platform.environment['HIFI_LIBRARY_TEST_DYLIB'];
  if (override != null && override.isNotEmpty) {
    NativeMusicLibrary.testingLibraryPath = override;
  } else {
    final root = Directory.current;
    final build = Directory('${root.path}/.dart_tool/audio_engine/host-library-tests')..createSync(recursive: true);
    final mutex = File('${build.path}/build.lock').openSync(mode: FileMode.append);
    mutex.lockSync(FileLock.blockingExclusive);
    try {
      final revision = (jsonDecode(File('${root.path}/audio_engine.lock.json').readAsStringSync()) as Map)['revision'];
      final library = '${build.path}/${Platform.isMacOS ? 'libhifi_audio_ffi.dylib' : Platform.isWindows ? 'hifi_audio_ffi.dll' : 'libhifi_audio_ffi.so'}';
      final stamp = File('${build.path}/revision');
      if (!File(library).existsSync() || !stamp.existsSync() || stamp.readAsStringSync() != revision) {
        Future<void> run(String executable, List<String> args) async {
          final result = await Process.run(executable, args, workingDirectory: root.path);
          if (result.exitCode != 0) throw StateError('$executable ${args.join(' ')}\n${result.stdout}\n${result.stderr}');
        }
        await run('dart', ['scripts/fetch_audio_engine.dart']);
        await run('cmake', ['-S', '${root.path}/.dart_tool/audio_engine/source', '-B', build.path, '-DBUILD_TESTING=OFF', '-DCMAKE_BUILD_TYPE=Release']);
        await run('cmake', ['--build', build.path, '--target', 'hifi_audio_ffi', '-j', '4']);
        stamp.writeAsStringSync('$revision');
      }
      NativeMusicLibrary.testingLibraryPath = library;
    } finally { mutex.unlockSync(); mutex.closeSync(); }
  }
  await testMain();
}
