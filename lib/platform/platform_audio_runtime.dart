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
        _androidOverride = null,
        _hostOutputOverride = null,
        _activateSessionOverride = null,
        _deactivateSessionOverride = null,
        _configureAndroidOverride = null,
        _readAndroidOutputOverride = null,
        _androidBufferOverride = null;

  @visibleForTesting
  PlatformAudioRuntime.forTesting(
      {required MethodChannel channel,
      bool isIOS = true,
      bool isAndroid = false,
      void Function(Map<String, dynamic>)? reportOutput,
      Future<bool> Function()? activateSession,
      Future<void> Function()? deactivateSession,
      bool Function(int, int, bool)? configureAndroidOutput,
      Map<String, dynamic> Function()? readAndroidOutput,
      bool Function(int)? setAndroidBufferFrames})
      : _channel = channel,
        _iosOverride = isIOS,
        _androidOverride = isAndroid,
        _hostOutputOverride = reportOutput,
        _activateSessionOverride = activateSession,
        _deactivateSessionOverride = deactivateSession,
        _configureAndroidOverride = configureAndroidOutput,
        _readAndroidOutputOverride = readAndroidOutput,
        _androidBufferOverride = setAndroidBufferFrames;

  final MethodChannel _channel;
  final bool? _iosOverride;
  final bool? _androidOverride;
  final void Function(Map<String, dynamic>)? _hostOutputOverride;
  final Future<bool> Function()? _activateSessionOverride;
  final Future<void> Function()? _deactivateSessionOverride;
  final bool Function(int, int, bool)? _configureAndroidOverride;
  final Map<String, dynamic> Function()? _readAndroidOutputOverride;
  final bool Function(int)? _androidBufferOverride;
  Future<void>? _configuration;
  Future<void> _sessionOperations = Future<void>.value();
  AudioSession? _session;
  bool _active = false;
  bool _disposed = false;
  String? _sessionError;
  bool get isSessionActive => _active;
  String? get lastSessionError => _sessionError;
  final List<Map<String, dynamic>> _routeDiagnostics = [];
  List<Map<String, dynamic>> get routeDiagnostics =>
      List.unmodifiable(_routeDiagnostics);
  final SessionResumePolicy resumePolicy = SessionResumePolicy();
  bool Function() isPlaying = () => false;
  void Function() pauseForSystem = () {};
  void Function() resumeAfterSystem = () {};

  bool get isIOS => _iosOverride ?? Platform.isIOS;
  bool get isAndroid => _androidOverride ?? Platform.isAndroid;
  bool get usesHostOutput => isIOS || isAndroid;
  bool get _mobileHost => usesHostOutput;
  bool get _testing =>
      _iosOverride != null || Platform.environment.containsKey('FLUTTER_TEST');
  Map<String, dynamic>? _output;
  Map<String, dynamic>? get output => _output;
  List<Map<String, dynamic>> _outputDevices = [];
  List<Map<String, dynamic>> get outputDevices =>
      List.unmodifiable(_outputDevices);
  int _androidDeviceId = 0;
  bool _androidExclusive = true;
  int _androidBufferFrames = 256;
  int get preferredAndroidDeviceId => _androidDeviceId;
  bool get prefersExclusiveOutput => _androidExclusive;
  int get preferredBufferFrames => _androidBufferFrames;
  String? _outputPreferenceError;
  String? get outputPreferenceError => _outputPreferenceError;
  bool get hasOpenOutput => _output?['isOpen'] == true;
  int _sampleRateMode = 0;
  int _sourceSampleRate = 44100;
  String? _requestedSignature;
  String? _sampleRateError;
  String? _routeError;
  DateTime? _lastProbeAt;
  String? _lastProbeError;
  DateTime? get lastProbeAt => _lastProbeAt;
  String? get lastProbeError => _lastProbeError;
  bool get hasUsbOutput => _output?['transport'] == 'USB';
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
      (isAndroid ? hasOpenOutput : _active) &&
      (isAndroid || isDx1iiConnected) &&
      negotiatedSampleRate == requestedSampleRate &&
      _sampleRateError == null;
  String get sampleRateStatus {
    final sys = isIOS ? 'iOS' : 'Android';
    if (isAndroid) {
      if (_outputPreferenceError != null) return _outputPreferenceError!;
      if (!hasOpenOutput) return '偏好已保存，播放时协商实际输出格式';
      if (_sampleRateMode == 0) {
        return '自动跟随音源，当前实际 ${negotiatedSampleRate / 1000} kHz';
      }
      if (preferenceMatched) return 'AAudio 已采用请求的采样率';
      return '请求 ${requestedSampleRate / 1000} kHz，当前按实际协商格式播放';
    }
    if (!isDx1iiConnected) return '偏好已保存，连接 DX1 II 后自动恢复';
    if (_sampleRateError != null) return '采样率请求未生效，继续使用系统协商格式';
    if (!_active) return '偏好已保存，播放时由 $sys 协商采样率';
    if (preferenceMatched) return '$sys 已采用请求的采样率';
    return '$sys 未采用请求值，按实际协商采样率播放';
  }

  // Loading settings is synchronous; actual hardware access is serialized below.
  void restoreSampleRateMode(int mode) {
    _sampleRateMode = mode.clamp(0, sampleRates.length - 1);
  }

  Future<void> setSampleRateMode(int mode) => _serialize(() async {
        restoreSampleRateMode(mode);
        if (isAndroid) _applyAndroidPreferences();
        await _refreshAndApply(true);
      });

  void restoreAndroidPreferences({
    required int deviceId,
    required bool exclusive,
    required int bufferFrames,
  }) {
    _androidDeviceId = deviceId < 0 ? 0 : deviceId;
    _androidExclusive = exclusive;
    _androidBufferFrames = bufferFrames;
  }

  bool _applyAndroidPreferences() {
    final sampleRate = _sampleRateMode == 0 ? 0 : requestedSampleRate;
    final bufferAccepted = _androidBufferOverride?.call(_androidBufferFrames) ??
        HifiAudioBindings.instance
            .setHardwareBufferFrames(_androidBufferFrames);
    final accepted = _configureAndroidOverride?.call(
            _androidDeviceId, sampleRate, _androidExclusive) ??
        HifiAudioBindings.instance.configureAndroidOutput(
          deviceId: _androidDeviceId,
          sampleRate: sampleRate,
          exclusive: _androidExclusive,
        );
    _outputPreferenceError =
        accepted && bufferAccepted ? null : '音频引擎未接受输出设置，请重新探测设备后重试';
    return accepted;
  }

  Future<bool> selectOutputDevice(String id) => _serialize(() async {
        final deviceId = int.tryParse(id);
        if (!isAndroid || deviceId == null || deviceId < 0) return false;
        final oldDeviceId = _androidDeviceId;
        _androidDeviceId = deviceId;
        final accepted = _applyAndroidPreferences();
        if (!accepted) _androidDeviceId = oldDeviceId;
        await _refreshAndApply(false);
        return accepted;
      });

  Future<void> setExclusiveOutput(bool exclusive) => _serialize(() async {
        _androidExclusive = exclusive;
        _applyAndroidPreferences();
        await _refreshAndApply(false);
      });

  Future<void> setBufferFrames(int frames) => _serialize(() async {
        _androidBufferFrames = frames;
        _applyAndroidPreferences();
        await _refreshAndApply(false);
      });

  Future<void> configure() => _configuration ??= _configure().catchError(
        (Object error, StackTrace stack) {
          _configuration = null;
          Error.throwWithStackTrace(error, stack);
        },
      );
  Future<void> _configure() async {
    if (!_mobileHost || _testing) return;
    final session = _session = await AudioSession.instance;
    await session.configure(configurationFor(isIOS: isIOS));
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
    if (usesHostOutput) {
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

  /// Music uses the same long-form output route as the system Music app.
  /// Android keeps audio_session's existing music/focus configuration.
  @visibleForTesting
  static AudioSessionConfiguration configurationFor({required bool isIOS}) {
    const music = AudioSessionConfiguration.music();
    return isIOS
        ? music.copyWith(
            avAudioSessionRouteSharingPolicy:
                AVAudioSessionRouteSharingPolicy.longFormAudio)
        : music;
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final work = _sessionOperations.then((_) => operation());
    // A rejected OS request must not poison the queue for the next retry.
    _sessionOperations =
        work.then<void>((_) {}, onError: (Object error, StackTrace _) {
      debugPrint('[PlatformAudioRuntime] $error');
    });
    return work;
  }

  Future<bool> activate({int? sourceSampleRate}) =>
      _serialize(() => _activate(sourceSampleRate: sourceSampleRate));

  Future<bool> _activate({int? sourceSampleRate, bool force = false}) async {
    try {
      await configure();
      if (sourceSampleRate != null && sourceSampleRate >= 8000) {
        _sourceSampleRate = sourceSampleRate;
      }
      if (!_mobileHost) return true;
      // All preferences, activations and route reads execute in this same queue.
      if (usesHostOutput && (!_testing || _iosOverride != null)) {
        if (isAndroid) _applyAndroidPreferences();
        await _refreshAndApply(false);
        _recordRoute('before_activation');
      }
      if (!_active || force) {
        if (force && isIOS && !_testing) {
          // An explicit probe also repairs session policy after an OS reset or
          // another component replacing the shared category configuration.
          await _session!.configure(configurationFor(isIOS: true));
        }
        _active = _testing
            ? await (_activateSessionOverride?.call() ?? Future.value(true))
            : await _session!.setActive(true);
        if (!_active) {
          final sys = isIOS ? 'iOS' : 'Android';
          _sessionError = '$sys 未允许激活音频会话，请结束其他占用音频的操作后重试';
          return false;
        }
        // Keep the negotiated I/O buffer. Forcing a tiny buffer after activation
        // restarts active I/O and can disrupt an external USB route.
      }
      _sessionError = null;
      if (usesHostOutput && (!_testing || _iosOverride != null)) {
        await _refreshAndApply(force);
        _recordRoute('after_activation');
      }
      return true;
    } catch (error) {
      // After a failed request the cached flag cannot prove OS activation.
      _active = false;
      _sessionError = error.toString();
      rethrow;
    } finally {
      _notifyState();
    }
  }

  /// A user-requested probe always verifies activation, even if our cached flag
  /// says active. A late deactivation or an OS reset may have invalidated it.
  Future<void> probeOutputs() => _serialize(() async {
        try {
          if (isAndroid) {
            await configure();
            _applyAndroidPreferences();
            await _refreshAndApply(true);
          } else if (!await _activate(force: true)) {
            throw StateError(_sessionError ?? '音频会话激活失败');
          }
          if (_routeError != null) throw StateError(_routeError!);
          if (_output == null && usesHostOutput) {
            final sys = isIOS ? 'iOS' : 'Android';
            throw StateError('$sys 暂未提供音频输出，请重新连接设备后重试');
          }
          _lastProbeAt = DateTime.now();
          _lastProbeError = null;
        } catch (error) {
          _lastProbeError = error.toString();
          rethrow;
        } finally {
          _notifyState();
        }
      });

  Future<void> refreshOutput({bool force = false, String? stage}) {
    if (!usesHostOutput) return Future<void>.value();
    return _serialize(() async {
      await _refreshAndApply(force);
      if (stage != null) _recordRoute(stage);
    });
  }

  void _recordRoute(String stage) {
    _routeDiagnostics.add(Map.unmodifiable({
      'stage': stage,
      'at': DateTime.now().toIso8601String(),
      'route': _output,
      'sessionActive': _active,
      'sessionError': _sessionError,
      'routeError': _routeError,
    }));
    if (_routeDiagnostics.length > 24) _routeDiagnostics.removeAt(0);
  }

  Future<void> _refreshAndApply(bool force) async {
    try {
      if (isAndroid) {
        await _refreshAndroidOutput();
        _routeError = null;
        return;
      }
      final output =
          await _channel.invokeMapMethod<String, dynamic>('getOutputFormat');
      _routeError = null;
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
      _recordRoute('after_sample_rate_preference');
    } on MissingPluginException {
      final sys = isIOS ? 'iOS' : 'Android';
      _routeError = '$sys 音频路由接口不可用，请更新并重新启动 App';
      _outputDevices = [];
      _publishOutput(null);
    } on PlatformException catch (error) {
      _routeError = error.message ?? error.code;
      _outputDevices = [];
      _publishOutput(null);
    } finally {
      _notifyState();
    }
  }

  Future<void> _refreshAndroidOutput() async {
    final devices =
        await _channel.invokeListMethod<dynamic>('getOutputDevices');
    final systemOutput =
        await _channel.invokeMapMethod<String, dynamic>('getOutputFormat');
    final deviceRows = (devices ?? []).whereType<Map>().toList(growable: false);
    Map<String, dynamic> readState() =>
        _readAndroidOutputOverride?.call() ??
        HifiAudioBindings.instance.androidOutputState;
    var state = readState();
    final connectedIds =
        deviceRows.map((device) => device['id'].toString()).toSet();
    final previousActualId = (state['deviceId'] as num?)?.toInt() ?? 0;
    if ((_androidDeviceId > 0 && !connectedIds.contains('$_androidDeviceId')) ||
        (state['isOpen'] == true &&
            previousActualId > 0 &&
            !connectedIds.contains('$previousActualId'))) {
      // Device IDs are temporary. A removed DAC must not leave a stale explicit
      // route pinned; reopen the system route and report its negotiated format.
      _androidDeviceId = 0;
      _applyAndroidPreferences();
      state = readState();
    }
    // Android can disconnect the default AAudio stream when a USB route is
    // added without removing the built-in port from the inventory.
    if (_active && state['isOpen'] != true) {
      _applyAndroidPreferences();
      state = readState();
    }
    final isOpen = state['isOpen'] == true;
    final actualId = (state['deviceId'] as num?)?.toInt();
    final selectedId = isOpen && actualId != null && actualId > 0
        ? '$actualId'
        : (_androidDeviceId > 0 ? '$_androidDeviceId' : systemOutput?['id']);
    _outputDevices = deviceRows.map((device) {
      final info = Map<String, dynamic>.from(device);
      final selected = info['id'].toString() == selectedId?.toString();
      final active =
          selected && isOpen && info['id'].toString() == actualId?.toString();
      return Map<String, dynamic>.unmodifiable({
        ...info,
        'isDefault': selected,
        'isOpen': active,
        'sampleRate': active ? (state['sampleRate'] ?? 0) : 0,
        'currentSampleRate': active ? (state['sampleRate'] ?? 0) : 0,
        'bitDepth': active ? (state['bitDepth'] ?? 0) : 0,
        'channels': active ? (state['channels'] ?? 0) : 0,
        'bufferFrames': active ? (state['bufferFrames'] ?? 0) : 0,
        'exclusive': active && state['exclusive'] == true,
      });
    }).toList(growable: false);
    final selected =
        _outputDevices.where((device) => device['isDefault'] == true);
    _publishOutput(selected.isEmpty ? null : selected.first);
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

  /// The caller must stop/pause native audio before requesting deactivation.
  /// Never fire setActive(false) outside the session queue: a delayed false
  /// could otherwise overtake a subsequent play/probe's setActive(true).
  Future<void> userPaused() {
    resumePolicy.cancel();
    if (!_mobileHost) return Future<void>.value();
    return _serialize(() async {
      if (!_active) return;
      _active = false;
      try {
        if (_testing) {
          await _deactivateSessionOverride?.call();
        } else {
          await _session?.setActive(false);
        }
        _sessionError = null;
      } catch (error) {
        // Deactivation can report isBusy while still making the session
        // inactive. Keep the error visible and require a fresh activation.
        _sessionError = '音频会话停用失败：$error';
        debugPrint('[PlatformAudioRuntime] $_sessionError');
      } finally {
        _notifyState();
      }
    });
  }

  void _notifyState() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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
