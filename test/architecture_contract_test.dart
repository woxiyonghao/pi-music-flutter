import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/platform/application_config.dart';
import 'package:hide_player_flutter/platform/platform_audio_runtime.dart';

void main() {
  test('platform app pins an independent engine from the same repository', () {
    final lock =
        jsonDecode(File('audio_engine.lock.json').readAsStringSync()) as Map;
    expect(
        lock['repository'], 'git@github.com:woxiyonghao/pi-music-flutter.git');
    expect(lock['revision'], matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(lock['abiVersion'], 2);
    expect(lock['platform'], applicationPlatform.name);
    expect(Directory('native/audio_engine').existsSync(), isFalse);
    expect(Directory('native/src').existsSync(), isFalse);
    final entry = File('lib/main.dart').readAsStringSync();
    expect(RegExp("import 'ui/[^']+_main_view.dart';").allMatches(entry),
        hasLength(1));
    expect(entry,
        matches(RegExp(r'PlatformAudioRuntime\.instance\s*\.configure\(\)')));
  });
  test(
      'interruption resumes only a previously playing track and respects user pause',
      () {
    final policy = SessionResumePolicy();
    policy.begin(isPlaying: true);
    expect(policy.end(allowed: true), isTrue);
    expect(policy.end(allowed: true), isFalse);
    policy.begin(isPlaying: false);
    expect(policy.end(allowed: true), isFalse);
    policy.begin(isPlaying: true);
    policy.cancel();
    expect(policy.end(allowed: true), isFalse);
    policy.begin(isPlaying: true);
    expect(policy.end(allowed: false), isFalse);
  });
}
