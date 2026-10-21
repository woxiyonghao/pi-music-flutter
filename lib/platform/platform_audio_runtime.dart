import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import '../core/hifi_audio_bindings.dart';

/// The platform application owns focus and session policy; C++ only renders audio.
class PlatformAudioRuntime {
  static final instance = PlatformAudioRuntime._();
  PlatformAudioRuntime._();
  static const _channel = MethodChannel('hifi/platform_audio');
  Future<void>? _configuration;
  AudioSession? _session;
  bool _active = false;
  final SessionResumePolicy resumePolicy = SessionResumePolicy();
  bool Function() isPlaying = () => false;
  void Function() pauseForSystem = () {};
  void Function() resumeAfterSystem = () {};

  bool get _mobileHost => Platform.isIOS || Platform.isAndroid;
  bool get _testing => Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> configure() => _configuration ??= _configure();
  Future<void> _configure() async {
    if (!_mobileHost || _testing) return;
    final session = _session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        _active = false;
        resumePolicy.begin(isPlaying: isPlaying());
        pauseForSystem();
      } else if (resumePolicy.end(
          allowed: event.type != AudioInterruptionType.unknown)) {
        resumeAfterSystem();
      }
    });
    session.becomingNoisyEventStream.listen((_) {
      _active = false;
      resumePolicy.cancel();
      pauseForSystem();
    });
    if (Platform.isIOS) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'routeChanged') await _reportOutput();
      });
      await _channel.invokeMethod<void>('prepareBackgroundStorage');
    }
  }

  Future<bool> activate() async {
    await configure();
    if (!_mobileHost || _testing) return true;
    if (!_active) {
      _active = await _session!.setActive(true);
      if (_active && Platform.isIOS) {
        // A rejected buffer preference must not prevent compatible playback.
        try {
          await _channel
              .invokeMethod<void>('setPreferredBufferFrames', {'frames': 256});
        } on PlatformException {/* Keep the system-negotiated buffer. */}
      }
    }
    if (!_active) return false;
    if (Platform.isIOS) await _reportOutput();
    return true;
  }

  Future<void> _reportOutput() async {
    final output =
        await _channel.invokeMapMethod<String, dynamic>('getOutputFormat');
    if (output == null) return;
    HifiAudioBindings.instance.updateHostOutput(output);
  }

  void userPaused() {
    resumePolicy.cancel();
    if (_active) {
      _active = false;
      unawaited(_session?.setActive(false).then<void>((_) {}) ??
          Future<void>.value());
    }
  }
}

/// User pause/stop and unplug cancel automatic interruption recovery.
class SessionResumePolicy {
  bool _pending = false;
  void begin({required bool isPlaying}) => _pending = isPlaying;
  void cancel() => _pending = false;
  bool end({required bool allowed}) {
    final resume = _pending && allowed;
    _pending = false;
    return resume;
  }
}
