import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import '../platform/application_config.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// C 函数签名
typedef _HifiAudioInitC = Bool Function(Pointer<Utf8>, Uint32);
typedef _HifiAudioInitDart = bool Function(Pointer<Utf8>, int);

typedef _HifiAudioOpenAndPlayC = Bool Function(Pointer<Utf8>);
typedef _HifiAudioOpenAndPlayDart = bool Function(Pointer<Utf8>);

typedef _HifiAudioOpenSectionC = Bool Function(Pointer<Utf8>, Double, Double);
typedef _HifiAudioOpenSectionDart = bool Function(
    Pointer<Utf8>, double, double);

typedef _HifiAudioVoidC = Void Function();
typedef _HifiAudioVoidDart = void Function();

typedef _HifiAudioSeekC = Void Function(Double);
typedef _HifiAudioSeekDart = void Function(double);

typedef _HifiAudioBoolC = Bool Function();
typedef _HifiAudioBoolDart = bool Function();

typedef _HifiAudioDoubleC = Double Function();
typedef _HifiAudioDoubleDart = double Function();

typedef _HifiAudioFloatC = Float Function();
typedef _HifiAudioFloatDart = double Function();

typedef _HifiAudioSetVolumeC = Void Function(Float);
typedef _HifiAudioSetVolumeDart = void Function(double);

typedef _HifiAudioSetMutedC = Void Function(Bool);
typedef _HifiAudioSetMutedDart = void Function(bool);

typedef _HifiAudioGetSpectrumC = Void Function(Pointer<Float>);
typedef _HifiAudioGetSpectrumDart = void Function(Pointer<Float>);

typedef _HifiAudioGetSampleRateC = Uint32 Function();
typedef _HifiAudioGetSampleRateDart = int Function();

typedef _HifiAudioGetDeviceNameC = Void Function(Pointer<Utf8>, Int32);
typedef _HifiAudioGetDeviceNameDart = void Function(Pointer<Utf8>, int);

typedef _HifiAudioSetEqEnabledC = Void Function(Bool);
typedef _HifiAudioSetEqEnabledDart = void Function(bool);

typedef _HifiAudioIsEqEnabledC = Bool Function();
typedef _HifiAudioIsEqEnabledDart = bool Function();

typedef _HifiAudioSetEqBandsC = Void Function(Pointer<Float>);
typedef _HifiAudioSetEqBandsDart = void Function(Pointer<Float>);

typedef _HifiAudioGetEqBandsC = Void Function(Pointer<Float>);
typedef _HifiAudioGetEqBandsDart = void Function(Pointer<Float>);

typedef _HifiAudioGetDevicesJsonC = Pointer<Utf8> Function();
typedef _HifiAudioGetDevicesJsonDart = Pointer<Utf8> Function();

typedef _HifiAudioSelectDeviceC = Bool Function(Pointer<Utf8>);
typedef _HifiAudioSelectDeviceDart = bool Function(Pointer<Utf8>);

typedef _HifiAudioSetMockExternalC = Void Function(Bool);
typedef _HifiAudioSetMockExternalDart = void Function(bool);

typedef _HifiAudioIsMockExternalC = Bool Function();
typedef _HifiAudioIsMockExternalDart = bool Function();

/// FFI 绑定底层 C++ audio_engine
class HifiAudioBindings {
  static HifiAudioBindings? _instance;
  static HifiAudioBindings get instance => _instance ??= HifiAudioBindings._();

  late final DynamicLibrary _lib;
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // 导出的 Dart 方法指针
  late final _HifiAudioInitDart _init;
  late final _HifiAudioOpenAndPlayDart _openAndPlay;
  late final _HifiAudioOpenSectionDart _openAndPlaySection;
  late final _HifiAudioVoidDart _play;
  late final _HifiAudioVoidDart _pause;
  late final _HifiAudioVoidDart _toggle;
  late final _HifiAudioVoidDart _stop;
  late final _HifiAudioSeekDart _seek;
  late final _HifiAudioBoolDart _isPlaying;
  late final _HifiAudioBoolDart _isPaused;
  late final _HifiAudioBoolDart _isIdle;
  late final _HifiAudioDoubleDart _getCurrentTime;
  late final _HifiAudioDoubleDart _getDuration;
  late final _HifiAudioFloatDart _getProgress;
  late final _HifiAudioSetVolumeDart _setVolume;
  late final _HifiAudioFloatDart _getVolume;
  late final _HifiAudioSetMutedDart _setMuted;
  late final _HifiAudioBoolDart _isMuted;
  late final _HifiAudioBoolDart _isBitPerfect;
  late final _HifiAudioGetSpectrumDart _getSpectrumLevels;
  late final _HifiAudioGetSampleRateDart _getSampleRate;
  late final _HifiAudioGetDeviceNameDart _getDeviceName;
  late final _HifiAudioSetEqEnabledDart _setEqEnabled;
  late final _HifiAudioIsEqEnabledDart _isEqEnabled;
  late final _HifiAudioSetEqBandsDart _setEqBands;
  late final _HifiAudioGetEqBandsDart _getEqBands;
  late final _HifiAudioGetDevicesJsonDart _getConnectedDevicesJson;
  late final _HifiAudioSelectDeviceDart _selectOutputDevice;
  late final _HifiAudioSetMockExternalDart _setExternalDeviceMock;
  late final _HifiAudioIsMockExternalDart _isExternalDeviceMock;
  bool _hasDeviceCatalog = false;
  _HifiAudioGetDevicesJsonDart? _getDiagnosticsJson;
  _HifiAudioBoolDart? _hasPlaybackCompleted;

  // 内存复用：12 频段频谱指针与 10 频段 EQ 指针 (避免每帧内存分配与 GC 压力)
  late final Pointer<Float> _spectrumBuffer;
  late final Pointer<Float> _eqBuffer;

  HifiAudioBindings._() {
    _spectrumBuffer = calloc<Float>(12);
    _eqBuffer = calloc<Float>(10);
    _loadLibrary();
  }

  String loadError = '';

  void _loadLibrary() {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        _isLoaded = false;
        return;
      }

      if (Platform.isMacOS) {
        // macOS: 多路径探测，支持 Xcode app bundle 与直接运行
        final execPath = Platform.resolvedExecutable;
        final execDir = File(execPath).parent.path;
        final appDir = File(execPath).parent.parent.path;
        _lib = _tryOpen([
          '$appDir/Frameworks/libhifi_audio_ffi.dylib',
          '$execDir/libhifi_audio_ffi.dylib',
          'libhifi_audio_ffi.dylib',
          'native/build/libhifi_audio_ffi.dylib',
          '../native/build/libhifi_audio_ffi.dylib',
          'Contents/Frameworks/libhifi_audio_ffi.dylib',
        ]);
      } else if (Platform.isLinux) {
        // Linux / 树莓派 5: 优先搜寻 bundle/lib、可执行程序同级与本地构建目录
        final execPath = Platform.resolvedExecutable;
        final execDir = File(execPath).parent.path;
        _lib = _tryOpen([
          '$execDir/lib/libhifi_audio_ffi.so',
          '$execDir/libhifi_audio_ffi.so',
          'libhifi_audio_ffi.so',
          'native/build/libhifi_audio_ffi.so',
          './libhifi_audio_ffi.so',
          '/usr/local/lib/libhifi_audio_ffi.so',
        ]);
      } else if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libhifi_audio_ffi.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      } else if (Platform.isWindows) {
        _lib = _tryOpen([
          'hifi_audio_ffi.dll',
          'native/build/Release/hifi_audio_ffi.dll',
        ]);
      } else {
        _lib = DynamicLibrary.process();
      }

      // 绑定函数指针
      final abi = _lib.lookupFunction<Uint32 Function(), int Function()>(
          'hifi_audio_get_abi_version')();
      if (abi != 2) throw StateError('Expected audio_engine ABI 2, got $abi');
      _init = _lib.lookupFunction<_HifiAudioInitC, _HifiAudioInitDart>(
          'hifi_audio_init_for_platform');
      _openAndPlay = _lib.lookupFunction<_HifiAudioOpenAndPlayC,
          _HifiAudioOpenAndPlayDart>('hifi_audio_open_and_play');
      _openAndPlaySection = _lib.lookupFunction<_HifiAudioOpenSectionC,
          _HifiAudioOpenSectionDart>('hifi_audio_open_and_play_section');
      _play = _lib.lookupFunction<_HifiAudioVoidC, _HifiAudioVoidDart>(
          'hifi_audio_play');
      _pause = _lib.lookupFunction<_HifiAudioVoidC, _HifiAudioVoidDart>(
          'hifi_audio_pause');
      _toggle = _lib.lookupFunction<_HifiAudioVoidC, _HifiAudioVoidDart>(
          'hifi_audio_toggle');
      _stop = _lib.lookupFunction<_HifiAudioVoidC, _HifiAudioVoidDart>(
          'hifi_audio_stop');
      _seek = _lib.lookupFunction<_HifiAudioSeekC, _HifiAudioSeekDart>(
          'hifi_audio_seek');
      _isPlaying = _lib.lookupFunction<_HifiAudioBoolC, _HifiAudioBoolDart>(
          'hifi_audio_is_playing');
      _isPaused = _lib.lookupFunction<_HifiAudioBoolC, _HifiAudioBoolDart>(
          'hifi_audio_is_paused');
      _isIdle = _lib.lookupFunction<_HifiAudioBoolC, _HifiAudioBoolDart>(
          'hifi_audio_is_idle');
      _getCurrentTime =
          _lib.lookupFunction<_HifiAudioDoubleC, _HifiAudioDoubleDart>(
              'hifi_audio_get_current_time');
      _getDuration =
          _lib.lookupFunction<_HifiAudioDoubleC, _HifiAudioDoubleDart>(
              'hifi_audio_get_duration');
      _getProgress = _lib.lookupFunction<_HifiAudioFloatC, _HifiAudioFloatDart>(
          'hifi_audio_get_progress');
      _setVolume =
          _lib.lookupFunction<_HifiAudioSetVolumeC, _HifiAudioSetVolumeDart>(
              'hifi_audio_set_volume');
      _getVolume = _lib.lookupFunction<_HifiAudioFloatC, _HifiAudioFloatDart>(
          'hifi_audio_get_volume');
      _setMuted =
          _lib.lookupFunction<_HifiAudioSetMutedC, _HifiAudioSetMutedDart>(
              'hifi_audio_set_muted');
      _isMuted = _lib.lookupFunction<_HifiAudioBoolC, _HifiAudioBoolDart>(
          'hifi_audio_is_muted');
      _isBitPerfect = _lib.lookupFunction<_HifiAudioBoolC, _HifiAudioBoolDart>(
          'hifi_audio_is_bit_perfect');
      _getSpectrumLevels = _lib.lookupFunction<_HifiAudioGetSpectrumC,
          _HifiAudioGetSpectrumDart>('hifi_audio_get_spectrum_levels');
      _getSampleRate = _lib.lookupFunction<_HifiAudioGetSampleRateC,
          _HifiAudioGetSampleRateDart>('hifi_audio_get_sample_rate');
      _getDeviceName = _lib.lookupFunction<_HifiAudioGetDeviceNameC,
          _HifiAudioGetDeviceNameDart>('hifi_audio_get_device_name');
      _setEqEnabled = _lib.lookupFunction<_HifiAudioSetEqEnabledC,
          _HifiAudioSetEqEnabledDart>('hifi_audio_set_eq_enabled');
      _isEqEnabled = _lib.lookupFunction<_HifiAudioIsEqEnabledC,
          _HifiAudioIsEqEnabledDart>('hifi_audio_is_eq_enabled');
      _setEqBands =
          _lib.lookupFunction<_HifiAudioSetEqBandsC, _HifiAudioSetEqBandsDart>(
              'hifi_audio_set_eq_bands');
      _getEqBands =
          _lib.lookupFunction<_HifiAudioGetEqBandsC, _HifiAudioGetEqBandsDart>(
              'hifi_audio_get_eq_bands');

      try {
        _getConnectedDevicesJson = _lib.lookupFunction<
                _HifiAudioGetDevicesJsonC, _HifiAudioGetDevicesJsonDart>(
            'hifi_audio_get_connected_devices_json');
        _selectOutputDevice = _lib.lookupFunction<_HifiAudioSelectDeviceC,
            _HifiAudioSelectDeviceDart>('hifi_audio_select_output_device');
        _setExternalDeviceMock = _lib.lookupFunction<_HifiAudioSetMockExternalC,
                _HifiAudioSetMockExternalDart>(
            'hifi_audio_set_external_device_mock');
        _isExternalDeviceMock = _lib.lookupFunction<_HifiAudioIsMockExternalC,
            _HifiAudioIsMockExternalDart>('hifi_audio_is_external_device_mock');
        _hasDeviceCatalog = true;
      } catch (e) {
        _hasDeviceCatalog = false;
        debugPrint('[HifiAudioBindings] 提示: 动态设备画像符号未导出 (平滑降级): $e');
      }

      _isLoaded = true;
      try {
        _hasPlaybackCompleted =
            _lib.lookupFunction<_HifiAudioBoolC, _HifiAudioBoolDart>(
                'hifi_audio_has_playback_completed');
      } catch (_) {}
      try {
        _getDiagnosticsJson = _lib.lookupFunction<_HifiAudioGetDevicesJsonC,
            _HifiAudioGetDevicesJsonDart>('hifi_audio_get_diagnostics_json');
      } catch (_) {}
    } catch (e, stack) {
      loadError = 'LOOKUP_ERROR: $e\n$stack';
      _isLoaded = false;
    }
  }

  DynamicLibrary _tryOpen(List<String> paths) {
    final failures = <String>[];
    for (final path in paths) {
      try {
        final lib = DynamicLibrary.open(path);
        final abi = lib.lookupFunction<Uint32 Function(), int Function()>(
            'hifi_audio_get_abi_version')();
        if (abi != 2 || !lib.providesSymbol('hifi_audio_init_for_platform')) {
          throw StateError('Expected audio_engine ABI 2, got $abi');
        }
        return lib;
      } catch (error) {
        failures.add('$path: $error');
      }
    }
    throw StateError('No compatible audio_engine library found.\n'
        '${failures.join('\n')}');
  }

  // 对外安全调用封装
  bool init() {
    if (!_isLoaded) return Platform.environment.containsKey('FLUTTER_TEST');
    final platform = applicationPlatform.name.toNativeUtf8();
    try {
      final initialized = _init(platform, outputPolicies);
      if (!initialized) loadError = 'audio_engine rejected initialization';
      return initialized;
    } finally {
      calloc.free(platform);
    }
  }

  Map<String, dynamic> get capabilities {
    if (!_isLoaded) return {};
    final value =
        _lib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
            'hifi_audio_get_capabilities_json')();
    return jsonDecode(value.toDartString()) as Map<String, dynamic>;
  }

  bool updateHostOutput(Map<String, dynamic> output) {
    if (!_isLoaded) return false;
    final id = (output['id'] as String? ?? '').toNativeUtf8();
    final name = (output['name'] as String? ?? '').toNativeUtf8();
    final transport =
        (output['transport'] as String? ?? 'System').toNativeUtf8();
    try {
      return _lib.lookupFunction<
              Bool Function(
                  Uint32, Uint32, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>),
              bool Function(int, int, Pointer<Utf8>, Pointer<Utf8>,
                  Pointer<Utf8>)>('hifi_audio_update_host_output')(
          (output['sampleRate'] as num? ?? 0).toInt(),
          (output['channels'] as num? ?? 0).toInt(),
          id,
          name,
          transport);
    } finally {
      calloc.free(id);
      calloc.free(name);
      calloc.free(transport);
    }
  }

  bool openAndPlay(String path) {
    if (!_isLoaded) return false;
    final nativePath = path.toNativeUtf8();
    final res = _openAndPlay(nativePath);
    calloc.free(nativePath);
    return res;
  }

  bool openAndPlaySection(String path, double startSec, double endSec) {
    if (!_isLoaded) return false;
    final nativePath = path.toNativeUtf8();
    final res = _openAndPlaySection(nativePath, startSec, endSec);
    calloc.free(nativePath);
    return res;
  }

  void play() => _isLoaded ? _play() : null;
  void pause() => _isLoaded ? _pause() : null;
  void toggle() => _isLoaded ? _toggle() : null;
  void stop() => _isLoaded ? _stop() : null;
  void seek(double sec) => _isLoaded ? _seek(sec) : null;

  Future<void> seekAsync(double sec) async {
    if (!_isLoaded) return;
    if (Platform.isAndroid &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      await Isolate.run(() {
        final lib = DynamicLibrary.open('libhifi_audio_ffi.so');
        final fn = lib.lookupFunction<_HifiAudioSeekC, _HifiAudioSeekDart>(
            'hifi_audio_seek');
        fn(sec);
      });
      return;
    }
    _seek(sec);
  }
  bool isPlaying() => _isLoaded ? _isPlaying() : false;
  bool isPaused() => _isLoaded ? _isPaused() : false;
  bool isIdle() => _isLoaded ? _isIdle() : true;
  // Older libraries cannot prove natural completion. Do not infer it from a
  // transient stopped state, which can also mean a device is being reopened.
  bool hasPlaybackCompleted() =>
      _isLoaded && (_hasPlaybackCompleted?.call() ?? false);
  double getCurrentTime() => _isLoaded ? _getCurrentTime() : 0.0;
  double getDuration() => _isLoaded ? _getDuration() : 0.0;
  double getProgress() => _isLoaded ? _getProgress() : 0.0;
  void setVolume(double vol) => _isLoaded ? _setVolume(vol) : null;
  double getVolume() => _isLoaded ? _getVolume() : 0.8;
  void setMuted(bool muted) => _isLoaded ? _setMuted(muted) : null;
  bool isMuted() => _isLoaded ? _isMuted() : false;
  bool isBitPerfect() => _isLoaded ? _isBitPerfect() : false;

  List<double> getSpectrumLevels() {
    if (!_isLoaded) return List.filled(12, 0.0);
    _getSpectrumLevels(_spectrumBuffer);
    return List.generate(12, (i) => _spectrumBuffer[i]);
  }

  int getSampleRate() => _isLoaded ? _getSampleRate() : 0;

  String getDeviceName() {
    if (!_isLoaded) return '音频引擎未连接';
    final buf = calloc<Uint8>(256);
    _getDeviceName(buf.cast<Utf8>(), 256);
    final name = buf.cast<Utf8>().toDartString();
    calloc.free(buf);
    return name.isNotEmpty ? name : '系统音频输出';
  }

  void setEqEnabled(bool enabled) {
    if (_isLoaded) _setEqEnabled(enabled);
  }

  bool isEqEnabled() => _isLoaded ? _isEqEnabled() : false;

  void setEqBands(List<double> gains) {
    if (!_isLoaded || gains.length != 10) return;
    for (int i = 0; i < 10; i++) {
      _eqBuffer[i] = gains[i];
    }
    _setEqBands(_eqBuffer);
  }

  List<double> getEqBands() {
    if (!_isLoaded) return List.filled(10, 0.0);
    _getEqBands(_eqBuffer);
    return List.generate(10, (i) => _eqBuffer[i]);
  }

  String getConnectedDevicesJson() {
    if (!_isLoaded || !_hasDeviceCatalog) return '[]';
    final ptr = _getConnectedDevicesJson();
    if (ptr == nullptr) return '[]';
    return ptr.toDartString();
  }

  String getDiagnosticsJson() {
    final getter = _getDiagnosticsJson;
    if (!_isLoaded || getter == null) return '{}';
    final ptr = getter();
    return ptr == nullptr ? '{}' : ptr.toDartString();
  }

  bool selectOutputDevice(String deviceId) {
    if (!_isLoaded || !_hasDeviceCatalog) return false;
    final nativeId = deviceId.toNativeUtf8();
    final res = _selectOutputDevice(nativeId);
    calloc.free(nativeId);
    return res;
  }

  bool _mockExternalFallback = false;

  void setExternalDeviceMock(bool enable) {
    _mockExternalFallback = enable;
    if (_isLoaded && _hasDeviceCatalog) _setExternalDeviceMock(enable);
  }

  bool isExternalDeviceMock() {
    if (!_isLoaded || !_hasDeviceCatalog) return _mockExternalFallback;
    return _isExternalDeviceMock();
  }

  void dispose() {
    calloc.free(_spectrumBuffer);
    calloc.free(_eqBuffer);
  }
}
