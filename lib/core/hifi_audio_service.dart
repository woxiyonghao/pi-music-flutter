import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../models/playback_state.dart';
import 'hifi_audio_bindings.dart';

/// 全局音频服务 (提供 60fps 动效数据流与状态响应式驱动)
class HifiAudioService extends ChangeNotifier {
  static final HifiAudioService instance = HifiAudioService._();

  final HifiAudioBindings _bindings = HifiAudioBindings.instance;

  Track? _currentTrack;
  Track? get currentTrack => _currentTrack;

  PlaybackState _state = const PlaybackState();
  PlaybackState get state => _state;

  Timer? _ticker;

  HifiAudioService._() {
    _bindings.init();
    _startTicker();
  }

  void _startTicker() {
    // 60fps 定时器轮询频谱与播放进度
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_bindings.isLoaded) {
        // 未加载原生动态库时使用微小随机波动演示动效
        return;
      }

      final isPlaying = _bindings.isPlaying();
      final isPaused = _bindings.isPaused();
      final currentTime = _bindings.getCurrentTime();
      final duration = _bindings.getDuration();
      final progress = _bindings.getProgress();
      final volume = _bindings.getVolume();
      final isMuted = _bindings.isMuted();
      final isBitPerfect = _bindings.isBitPerfect();
      final spectrum = _bindings.getSpectrumLevels();

      _state = PlaybackState(
        isPlaying: isPlaying,
        isPaused: isPaused,
        isBitPerfect: isBitPerfect,
        currentTime: currentTime,
        duration: duration,
        progress: progress,
        volume: volume,
        isMuted: isMuted,
        spectrumLevels: spectrum,
      );

      notifyListeners();
    });
  }

  void playTrack(Track track) {
    _currentTrack = track;
    _bindings.openAndPlay(track.filepath);
    notifyListeners();
  }

  void togglePlayPause() {
    _bindings.toggle();
    notifyListeners();
  }

  void seek(double targetSec) {
    _bindings.seek(targetSec);
    notifyListeners();
  }

  void setVolume(double vol) {
    _bindings.setVolume(vol);
    notifyListeners();
  }

  void toggleMute() {
    _bindings.setMuted(!_state.isMuted);
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _bindings.dispose();
    super.dispose();
  }
}
