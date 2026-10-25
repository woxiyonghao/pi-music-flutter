import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/platform/platform_audio_runtime.dart';

const track = Track(
    id: 1,
    title: 'Actual audio',
    artist: '',
    album: '',
    filepath: '/test/audio.wav',
    sampleRate: 44100,
    bitDepth: 16,
    durationSec: 5);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/ios-session-lifecycle');
  late PlatformAudioRuntime runtime;
  late List<String> events;
  late Future<bool> Function() activate;
  late Future<void> Function() deactivate;
  var nativeActive = false;
  var activations = 0;
  var deactivations = 0;

  setUp(() {
    events = [];
    nativeActive = false;
    activations = 0;
    deactivations = 0;
    activate = () async {
      nativeActive = true;
      return true;
    };
    deactivate = () async {
      nativeActive = false;
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getOutputFormat') {
        events.add(nativeActive ? 'read-usb' : 'read-speaker');
        return {
          'id': nativeActive ? 'usb' : 'speaker',
          'name': nativeActive ? 'TOPPING DX1 II' : 'iPhone 扬声器',
          'transport': nativeActive ? 'USB' : 'BuiltIn',
          'sampleRate': 48000,
          'channels': 2
        };
      }
      return null;
    });
    runtime = PlatformAudioRuntime.forTesting(
        channel: channel,
        reportOutput: (_) {},
        activateSession: () async {
          activations++;
          events.add('activate-start');
          final result = await activate();
          events.add('activate-done');
          return result;
        },
        deactivateSession: () async {
          deactivations++;
          events.add('deactivate-start');
          await deactivate();
          events.add('deactivate-done');
        });
  });
  tearDown(() {
    runtime.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
      'iPhone shares the long-form media route while Android music configuration stays unchanged',
      () {
    final ios = PlatformAudioRuntime.configurationFor(isIOS: true);
    expect(ios.avAudioSessionCategory, AVAudioSessionCategory.playback);
    expect(ios.avAudioSessionMode, AVAudioSessionMode.defaultMode);
    expect(ios.avAudioSessionRouteSharingPolicy,
        AVAudioSessionRouteSharingPolicy.longFormAudio);
    expect(ios.avAudioSessionCategoryOptions?.value ?? 0, 0);
    expect(PlatformAudioRuntime.configurationFor(isIOS: false).toJson(),
        const AudioSessionConfiguration.music().toJson());
  });

  test(
      'a delayed deactivation completes before a subsequent activation can begin',
      () async {
    await runtime.activate();
    final release = Completer<void>();
    deactivate = () async {
      await release.future;
      nativeActive = false;
    };
    events.clear();
    final pause = runtime.userPaused();
    final resume = runtime.activate();
    await Future<void>.delayed(Duration.zero);
    expect(events, ['deactivate-start']);
    expect(activations, 1);
    release.complete();
    await Future.wait([pause, resume]);
    expect(events.indexOf('deactivate-done'),
        lessThan(events.indexOf('activate-start')));
    expect(nativeActive, isTrue);
    expect(runtime.isSessionActive, isTrue);
    expect(runtime.output!['transport'], 'USB');
  });

  test(
      'pause during an unfinished activation is not lost when the cache is still inactive',
      () async {
    final activated = Completer<bool>();
    activate = () async {
      nativeActive = await activated.future;
      return nativeActive;
    };
    final opening = runtime.activate();
    await Future<void>.delayed(Duration.zero);
    expect(events, contains('activate-start'));
    expect(runtime.isSessionActive, isFalse);
    final pause = runtime.userPaused();
    activated.complete(true);
    await opening;
    await pause;
    expect(deactivations, 1);
    expect(nativeActive, isFalse);
    expect(runtime.isSessionActive, isFalse);
  });

  test(
      'explicit probe recovers an OS session deactivated behind a stale active cache',
      () async {
    await runtime.activate();
    expect(runtime.isSessionActive, isTrue);
    nativeActive = false;
    await runtime.probeOutputs();
    expect(activations, 2);
    expect(nativeActive, isTrue);
    expect(runtime.output!['transport'], 'USB');
    expect(runtime.lastProbeError, isNull);
  });

  test('deactivation errors are visible and do not poison later activation',
      () async {
    await runtime.activate();
    deactivate = () async {
      nativeActive = false;
      throw PlatformException(
          code: 'isBusy', message: 'OS deactivated running IO');
    };
    await runtime.userPaused();
    expect(runtime.lastSessionError, contains('isBusy'));
    expect(runtime.isSessionActive, isFalse);
    await runtime.probeOutputs();
    expect(runtime.lastSessionError, isNull);
    expect(runtime.isSessionActive, isTrue);
    expect(runtime.output!['transport'], 'USB');
  });

  test('route reads cannot overtake a pending deactivation', () async {
    await runtime.activate();
    final release = Completer<void>();
    deactivate = () async {
      await release.future;
      nativeActive = false;
    };
    events.clear();
    final pause = runtime.userPaused();
    final read = runtime.refreshOutput();
    await Future<void>.delayed(Duration.zero);
    expect(events, ['deactivate-start']);
    release.complete();
    await Future.wait([pause, read]);
    expect(events, ['deactivate-start', 'deactivate-done', 'read-speaker']);
  });

  test(
      'Hifi pause and stop halt native audio before deactivating the OS session',
      () async {
    var rendering = false;
    final audio = HifiAudioService.forTesting(
        runtime: runtime,
        prepareFile: (_) async {},
        openFile: (_, __, ___) {
          rendering = true;
          return true;
        },
        pauseNative: () {
          rendering = false;
          events.add('native-pause');
        },
        stopNative: () {
          rendering = false;
          events.add('native-stop');
        });
    addTearDown(audio.dispose);
    deactivate = () async {
      expect(rendering, isFalse,
          reason: 'iOS must not deactivate a running RemoteIO unit');
      nativeActive = false;
    };
    await audio.playTrack(track);
    expect(rendering, isTrue);
    events.clear();
    audio.pause();
    await runtime.refreshOutput();
    expect(events.indexOf('native-pause'),
        lessThan(events.indexOf('deactivate-start')));
    expect(audio.state.isPaused, isTrue);
    await audio.playTrack(track);
    events.clear();
    audio.stop();
    await runtime.refreshOutput();
    expect(events.indexOf('native-stop'),
        lessThan(events.indexOf('deactivate-start')));
    expect(nativeActive, isFalse);
    expect(audio.state.isPlaying, isFalse);
  });
}
