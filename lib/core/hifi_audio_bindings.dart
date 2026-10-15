import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// C 函数签名
typedef _HifiAudioInitC = Bool Function();
typedef _HifiAudioInitDart = bool Function();

typedef _HifiAudioOpenAndPlayC = Bool Function(Pointer<Utf8>);
typedef _HifiAudioOpenAndPlayDart = bool Function(Pointer<Utf8>);

typedef _HifiAudioOpenSectionC = Bool Function(Pointer<Utf8>, Double, Double);
typedef _HifiAudioOpenSectionDart = bool Function(Pointer<Utf8>, double, double);

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

  // 内存复用：12 频段频谱指针 (避免每帧内存分配与 GC 压力)
  late final Pointer<Float> _spectrumBuffer;

  HifiAudioBindings._() {
    _spectrumBuffer = calloc<Float>(12);
    _loadLibrary();
  }

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
          '/Users/mk10/Desktop/hide_player_flutter/native/build/libhifi_audio_ffi.dylib',
          '/Users/mk10/Desktop/hide_player_flutter/libhifi_audio_ffi.dylib',
          'libhifi_audio_ffi.dylib',
          'native/build/libhifi_audio_ffi.dylib',
          '../native/build/libhifi_audio_ffi.dylib',
          'Contents/Frameworks/libhifi_audio_ffi.dylib',
        ]);
      } else if (Platform.isLinux) {
        // Linux / 树莓派 5
        _lib = _tryOpen([
          'libhifi_audio_ffi.so',
          'native/build/libhifi_audio_ffi.so',
          './libhifi_audio_ffi.so',
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
      _init = _lib.lookupFunction<_HifiAudioInitC, _HifiAudioInitDart>('hifi_audio_init');
      _openAndPlay = _lib.lookupFunction<_HifiAudioOpenAndPlayC, _HifiAudioOpenAndPlayDart>('hifi_audio_open_and_play');
      _openAndPlaySection = _lib.lookupFunction<_HifiAudioOpenSectionC, _HifiAudioOpenSectionDart>('hifi_audio_open_and_play_section');
      _play = _lib.lookupFunction<_HifiAudioVoidC, _HifiAudioVoidDart>('hifi_audio_play');
      _pause = _lib.lookupFunction<_HifiAudioVoidC, _HifiAudioVoidDart>('hifi_audio_pause');
      _toggle = _lib.lookupFunction<_HifiAudioVoidC, _HifiAudioVoidDart>('hifi_audio_toggle');
      _stop = _lib.lookupFunction<_HifiAudioVoidC, _HifiAudioVoidDart>('hifi_audio_stop');
      _seek = _lib.lookupFunction<_HifiAudioSeekC, _HifiAudioSeekDart>('hifi_audio_seek');
      _isPlaying = _lib.lookupFunction<_HifiAudioBoolC, _HifiAudioBoolDart>('hifi_audio_is_playing');
      _isPaused = _lib.lookupFunction<_HifiAudioBoolC, _HifiAudioBoolDart>('hifi_audio_is_paused');
      _isIdle = _lib.lookupFunction<_HifiAudioBoolC, _HifiAudioBoolDart>('hifi_audio_is_idle');
      _getCurrentTime = _lib.lookupFunction<_HifiAudioDoubleC, _HifiAudioDoubleDart>('hifi_audio_get_current_time');
      _getDuration = _lib.lookupFunction<_HifiAudioDoubleC, _HifiAudioDoubleDart>('hifi_audio_get_duration');
      _getProgress = _lib.lookupFunction<_HifiAudioFloatC, _HifiAudioFloatDart>('hifi_audio_get_progress');
      _setVolume = _lib.lookupFunction<_HifiAudioSetVolumeC, _HifiAudioSetVolumeDart>('hifi_audio_set_volume');
      _getVolume = _lib.lookupFunction<_HifiAudioFloatC, _HifiAudioFloatDart>('hifi_audio_get_volume');
      _setMuted = _lib.lookupFunction<_HifiAudioSetMutedC, _HifiAudioSetMutedDart>('hifi_audio_set_muted');
      _isMuted = _lib.lookupFunction<_HifiAudioBoolC, _HifiAudioBoolDart>('hifi_audio_is_muted');
      _isBitPerfect = _lib.lookupFunction<_HifiAudioBoolC, _HifiAudioBoolDart>('hifi_audio_is_bit_perfect');
      _getSpectrumLevels = _lib.lookupFunction<_HifiAudioGetSpectrumC, _HifiAudioGetSpectrumDart>('hifi_audio_get_spectrum_levels');
      _getSampleRate = _lib.lookupFunction<_HifiAudioGetSampleRateC, _HifiAudioGetSampleRateDart>('hifi_audio_get_sample_rate');
      _getDeviceName = _lib.lookupFunction<_HifiAudioGetDeviceNameC, _HifiAudioGetDeviceNameDart>('hifi_audio_get_device_name');

      _isLoaded = true;
    } catch (e) {
      // 库未编译时的模拟降级模式
      _isLoaded = false;
    }
  }

  DynamicLibrary _tryOpen(List<String> paths) {
    for (final path in paths) {
      try {
        return DynamicLibrary.open(path);
      } catch (_) {}
    }
    return DynamicLibrary.process();
  }

  // 对外安全调用封装
  bool init() => _isLoaded ? _init() : true;
  bool openAndPlay(String path) {
    if (!_isLoaded) return true;
    final nativePath = path.toNativeUtf8();
    final res = _openAndPlay(nativePath);
    calloc.free(nativePath);
    return res;
  }
  bool openAndPlaySection(String path, double startSec, double endSec) {
    if (!_isLoaded) return true;
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
  bool isPlaying() => _isLoaded ? _isPlaying() : false;
  bool isPaused() => _isLoaded ? _isPaused() : false;
  bool isIdle() => _isLoaded ? _isIdle() : true;
  double getCurrentTime() => _isLoaded ? _getCurrentTime() : 0.0;
  double getDuration() => _isLoaded ? _getDuration() : 0.0;
  double getProgress() => _isLoaded ? _getProgress() : 0.0;
  void setVolume(double vol) => _isLoaded ? _setVolume(vol) : null;
  double getVolume() => _isLoaded ? _getVolume() : 0.8;
  void setMuted(bool muted) => _isLoaded ? _setMuted(muted) : null;
  bool isMuted() => _isLoaded ? _isMuted() : false;
  bool isBitPerfect() => _isLoaded ? _isBitPerfect() : true;

  List<double> getSpectrumLevels() {
    if (!_isLoaded) return List.filled(12, 0.0);
    _getSpectrumLevels(_spectrumBuffer);
    return List.generate(12, (i) => _spectrumBuffer[i]);
  }

  int getSampleRate() => _isLoaded ? _getSampleRate() : 192000;

  String getDeviceName() {
    if (!_isLoaded) return 'Apple Direct';
    final buf = calloc<Uint8>(256);
    _getDeviceName(buf.cast<Utf8>(), 256);
    final name = buf.cast<Utf8>().toDartString();
    calloc.free(buf);
    return name.isNotEmpty ? name : 'Apple Direct';
  }

  void dispose() {
    calloc.free(_spectrumBuffer);
  }
}
