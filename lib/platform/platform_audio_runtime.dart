import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/hifi_audio_bindings.dart';

/// The host owns session policy and reports the negotiated output to the engine.
class PlatformAudioRuntime extends ChangeNotifier {
  static final instance = PlatformAudioRuntime._();
  PlatformAudioRuntime._()
      : _channel = const MethodChannel('hifi/platform_audio'),
        _iosOverride = null,
        _hostOutputOverride = null;

  @visibleForTesting
  PlatformAudioRuntime.forTesting(
      {required MethodChannel channel,
      void Function(Map<String, dynamic>)? reportOutput})
      : _channel = channel,
        _iosOverride = true,
        _hostOutputOverride = reportOutput;

  final MethodChannel _channel;
  final bool? _iosOverride;
  final void Function(Map<String, dynamic>)? _hostOutputOverride;
  Future<void>? _configuration;
  Future<void> _routeOperations = Future<void>.value();
  AudioSession? _session;
  bool _active = false;
  final SessionResumePolicy resumePolicy = SessionResumePolicy();
  bool Function() isPlaying = () => false;
  void Function() pauseForSystem = () {};
  void Function() resumeAfterSystem = () {};

  bool get isIOS => _iosOverride ?? Platform.isIOS;
  bool get _mobileHost => isIOS || Platform.isAndroid;
  bool get _testing =>
      _iosOverride != null || Platform.environment.containsKey('FLUTTER_TEST');
  Map<String, dynamic>? _output;
  Map<String, dynamic>? get output => _output;
  int _sampleRateMode = 0;
  int _sourceSampleRate = 44100;
  String? _requestedSignature;
  String? _sampleRateError;
  static const sampleRates = [0, 44100, 48000, 96000, 192000, 384000];

  static bool isDx1iiName(String name) => name
      .toUpperCase()
      .replaceAll('Ⅱ', 'II')
      .replaceAll(RegExp('[^A-Z0-9]'), '')
      .contains('DX1II');
  bool get isDx1iiConnected =>
      _output?['transport'] == 'USB' &&
      isDx1iiName(_output?['name'] as String? ?? '');
  int get negotiatedSampleRate => (_output?['sampleRate'] as num? ?? 0).round();
  int get requestedSampleRate => _sampleRateMode == 0
      ? (_sourceSampleRate > 384000 ? 176400 : _sourceSampleRate)
      : sampleRates[_sampleRateMode];
  bool get preferenceMatched =>
      _active &&
      isDx1iiConnected &&
      negotiatedSampleRate == requestedSampleRate &&
      _sampleRateError == null;
  String get sampleRateStatus {
    if (!isDx1iiConnected) return '偏好已保存，连接 DX1 II 后自动恢复';
    if (_sampleRateError != null) return '采样率请求未生效，继续使用系统协商格式';
    if (!_active) return '偏好已保存，播放时由 iOS 协商采样率';
    if (preferenceMatched) return 'iOS 已采用请求的采样率';
    return 'iOS 未采用请求值，按实际协商采样率播放';
  }

  // Loading settings is synchronous; actual hardware access is serialized below.
  void restoreSampleRateMode(int mode) {
    _sampleRateMode = mode.clamp(0, sampleRates.length - 1);
  }

  Future<void> setSampleRateMode(int mode) async {
    restoreSampleRateMode(mode);
    await refreshOutput(force: true);
  }

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
    if (isIOS) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'routeChanged') {
          final args = call.arguments;
          if (args is Map && args['reason'] == 2) {
            resumePolicy.cancel();
            pauseForSystem();
          }
          await refreshOutput();
        }
      });
    }
  }

  /// Updating every file's protection can take time on a large library. It is
  /// maintenance for background playback, not a prerequisite for showing UI.
  Future<void> prepareBackgroundStorage() async {
    if (!isIOS || _testing) return;
    await _channel.invokeMethod<void>('prepareBackgroundStorage');
  }

  Future<bool> activate({int? sourceSampleRate}) async {
    await configure();
    if (sourceSampleRate != null && sourceSampleRate >= 8000) {
      _sourceSampleRate = sourceSampleRate;
    }
    if (!_mobileHost) return true;
    // Request preferences before activation, then read back the actual format.
    if (isIOS && (!_testing || _iosOverride != null)) await refreshOutput();
    if (_testing) {
      _active = true;
      return true;
    }
    if (!_active) {
      _active = await _session!.setActive(true);
      if (_active && isIOS) {
        try {
          await _channel
              .invokeMethod<void>('setPreferredBufferFrames', {'frames': 256});
        } on PlatformException {/* Keep the negotiated buffer. */}
      }
    }
    if (!_active) return false;
    if (isIOS) await refreshOutput();
    return true;
  }

  Future<void> refreshOutput({bool force = false}) {
    if (!isIOS) return Future<void>.value();
    final work = _routeOperations.then((_) => _refreshAndApply(force));
    _routeOperations = work.catchError((Object error) {
      debugPrint('[PlatformAudioRuntime] $error');
    });
    return work;
  }

  Future<void> _refreshAndApply(bool force) async {
    try {
      final output =
          await _channel.invokeMapMethod<String, dynamic>('getOutputFormat');
      _publishOutput(output);
      if (!isDx1iiConnected) {
        _requestedSignature = null;
        _sampleRateError = null;
        return;
      }
      final signature = '${_output!['id']}:$requestedSampleRate';
      if (!force && signature == _requestedSignature) return;
      _requestedSignature = signature;
      _sampleRateError = null;
      try {
        await _channel.invokeMethod<void>('setPreferredSampleRate', {
          'routeId': _output!['id'],
          'sampleRate': requestedSampleRate,
        });
      } on PlatformException catch (error) {
        _sampleRateError = error.code;
      }
      // Read again: a successful preference request is not proof of the format.
      _publishOutput(
          await _channel.invokeMapMethod<String, dynamic>('getOutputFormat'));
    } on MissingPluginException {
      _sampleRateError = 'unavailable';
    } on PlatformException catch (error) {
      _sampleRateError = error.code;
    } finally {
      notifyListeners();
    }
  }

  void _publishOutput(Map<String, dynamic>? output) {
    _output = output == null ? null : Map.unmodifiable(output);
    if (output == null) return;
    if (_hostOutputOverride != null) {
      _hostOutputOverride?.call(output);
    } else {
      HifiAudioBindings.instance.updateHostOutput(output);
    }
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
