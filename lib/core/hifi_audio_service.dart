import 'dart:async';
import 'dart:io';
import 'dart:math';
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

  List<Track> _playlistQueue = [];
  List<Track> get playlistQueue => _playlistQueue;

  int _currentIndex = -1;
  int get currentIndex => _currentIndex;

  PlayMode _playMode = PlayMode.loopList;
  PlayMode get playMode => _playMode;

  PlaybackState _state = const PlaybackState();
  PlaybackState get state => _state;

  Timer? _ticker;
  bool _hasStartedActivePlayback = false;
  int _playInitiatedEpoch = 0;

  final ValueNotifier<int?> currentTrackIdNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<Track?> currentTrackNotifier = ValueNotifier<Track?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  HifiAudioService._() {
    _bindings.init();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _startTicker();
    }
  }

  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_bindings.isLoaded) {
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

      if (isPlayingNotifier.value != isPlaying) {
        isPlayingNotifier.value = isPlaying;
      }

      if (isPlaying) {
        _hasStartedActivePlayback = true;
      }

      // 检查曲目是否自然播放结束 (只有在曾真正开始播放过、且当前已停止、且非用户暂停时判定，防止启动期间竞态判定)
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_hasStartedActivePlayback && !isPlaying && !_state.isPaused && (now - _playInitiatedEpoch > 1200)) {
        _hasStartedActivePlayback = false;
        _state = PlaybackState(
          isPlaying: false,
          isPaused: false,
          isBitPerfect: isBitPerfect,
          currentTime: 0.0,
          duration: duration,
          progress: 0.0,
          volume: volume,
          isMuted: isMuted,
          playMode: _playMode,
          activeDeviceName: 'Apple Direct',
          activeSampleRate: _currentTrack?.sampleRate ?? 192000,
          spectrumLevels: List.filled(12, 0.0),
        );
        isPlayingNotifier.value = false;
        notifyListeners();
        next();
        return;
      }

      // 仅在播放中或状态变更时通知监听者
      if (isPlaying || _state.isPlaying != isPlaying || _state.isPaused != isPaused) {
        _state = PlaybackState(
          isPlaying: isPlaying,
          isPaused: isPaused,
          isBitPerfect: isBitPerfect,
          currentTime: currentTime,
          duration: duration,
          progress: progress,
          volume: volume,
          isMuted: isMuted,
          playMode: _playMode,
          activeDeviceName: _currentTrack != null ? 'Apple Direct' : 'Apple Direct',
          activeSampleRate: _currentTrack?.sampleRate ?? 192000,
          spectrumLevels: spectrum,
        );
        notifyListeners();
      }
    });
  }

  void playTracks(List<Track> tracks, int startIndex) {
    if (tracks.isEmpty || startIndex < 0 || startIndex >= tracks.length) return;
    _playlistQueue = List.from(tracks);
    _currentIndex = startIndex;
    playTrack(_playlistQueue[_currentIndex], _playlistQueue, _currentIndex);
  }

  void playTrack(Track track, [List<Track>? queue, int? index]) {
    _currentTrack = track;
    currentTrackIdNotifier.value = track.id;
    currentTrackNotifier.value = track;
    _hasStartedActivePlayback = false;
    _playInitiatedEpoch = DateTime.now().millisecondsSinceEpoch;

    if (queue != null && index != null) {
      _playlistQueue = List.from(queue);
      _currentIndex = index;
    } else if (!_playlistQueue.contains(track)) {
      _playlistQueue = [track];
      _currentIndex = 0;
    } else {
      _currentIndex = _playlistQueue.indexOf(track);
    }

    final success = track.isCueTrack && track.endTimeSec > track.startTimeSec
        ? _bindings.openAndPlaySection(track.filepath, track.startTimeSec, track.endTimeSec)
        : _bindings.openAndPlay(track.filepath);

    if (!success) {
      debugPrint('[HifiAudioService] 打开音频文件失败: ${track.filepath}');
      _state = PlaybackState(
        isPlaying: false,
        isPaused: false,
        isBitPerfect: false,
        currentTime: 0.0,
        duration: track.durationSec.toDouble(),
        progress: 0.0,
        volume: _state.volume,
        isMuted: _state.isMuted,
        playMode: _playMode,
        activeDeviceName: 'Apple Direct',
        activeSampleRate: track.sampleRate,
        spectrumLevels: List.filled(12, 0.0),
      );
      isPlayingNotifier.value = false;
      notifyListeners();
      return;
    }

    isPlayingNotifier.value = true;
    _state = PlaybackState(
      isPlaying: true,
      isPaused: false,
      isBitPerfect: true,
      currentTime: 0.0,
      duration: track.durationSec.toDouble(),
      progress: 0.0,
      volume: _state.volume,
      isMuted: _state.isMuted,
      playMode: _playMode,
      activeDeviceName: 'Apple Direct',
      activeSampleRate: track.sampleRate,
      spectrumLevels: _state.spectrumLevels,
    );
    notifyListeners();
  }

  void togglePlayPause() {
    if (_currentTrack == null) {
      if (_playlistQueue.isNotEmpty) {
        playTrack(_playlistQueue.first);
      }
      return;
    }

    // 若底层音频引擎当前处于空闲停止状态，直接重新发起播放
    if (_bindings.isIdle() || (!_bindings.isPlaying() && !_bindings.isPaused())) {
      playTrack(_currentTrack!);
      return;
    }

    _bindings.toggle();
    final nowPlaying = _bindings.isPlaying();
    isPlayingNotifier.value = nowPlaying;
    _state = PlaybackState(
      isPlaying: nowPlaying,
      isPaused: !nowPlaying,
      isBitPerfect: _state.isBitPerfect,
      currentTime: _state.currentTime,
      duration: _state.duration,
      progress: _state.progress,
      volume: _state.volume,
      isMuted: _state.isMuted,
      playMode: _playMode,
      activeDeviceName: _state.activeDeviceName,
      activeSampleRate: _state.activeSampleRate,
      spectrumLevels: _state.spectrumLevels,
    );
    notifyListeners();
  }

  void play() {
    if (_currentTrack != null && (_bindings.isIdle() || (!_bindings.isPlaying() && !_bindings.isPaused()))) {
      playTrack(_currentTrack!);
      return;
    }
    _bindings.play();
    isPlayingNotifier.value = true;
    notifyListeners();
  }

  void pause() {
    _bindings.pause();
    isPlayingNotifier.value = false;
    notifyListeners();
  }

  void previous() {
    if (_playlistQueue.isEmpty) return;
    if (_state.currentTime > 3.0) {
      seek(0.0);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = _playlistQueue.length - 1;
    }
    playTrack(_playlistQueue[_currentIndex]);
  }

  void next() {
    if (_playlistQueue.isEmpty) return;
    switch (_playMode) {
      case PlayMode.loopSingle:
        seek(0.0);
        play();
        return;
      case PlayMode.shuffle:
        if (_playlistQueue.length > 1) {
          int nextIdx;
          do {
            nextIdx = Random().nextInt(_playlistQueue.length);
          } while (nextIdx == _currentIndex);
          _currentIndex = nextIdx;
        }
        break;
      case PlayMode.sequence:
        if (_currentIndex < _playlistQueue.length - 1) {
          _currentIndex++;
        } else {
          pause();
          seek(0.0);
          return;
        }
        break;
      case PlayMode.loopList:
        _currentIndex = (_currentIndex + 1) % _playlistQueue.length;
        break;
    }
    playTrack(_playlistQueue[_currentIndex]);
  }

  void addToQueue(Track track) {
    _playlistQueue.add(track);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _playlistQueue.length) {
      _playlistQueue.removeAt(index);
      if (_currentIndex >= _playlistQueue.length) {
        _currentIndex = _playlistQueue.length - 1;
      }
      notifyListeners();
    }
  }

  void clearQueue() {
    _playlistQueue.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  void cyclePlayMode() {
    switch (_playMode) {
      case PlayMode.loopList:
        _playMode = PlayMode.loopSingle;
        break;
      case PlayMode.loopSingle:
        _playMode = PlayMode.shuffle;
        break;
      case PlayMode.shuffle:
        _playMode = PlayMode.sequence;
        break;
      case PlayMode.sequence:
        _playMode = PlayMode.loopList;
        break;
    }
    _state = PlaybackState(
      isPlaying: _state.isPlaying,
      isPaused: _state.isPaused,
      isBitPerfect: _state.isBitPerfect,
      currentTime: _state.currentTime,
      duration: _state.duration,
      progress: _state.progress,
      volume: _state.volume,
      isMuted: _state.isMuted,
      playMode: _playMode,
      activeDeviceName: _state.activeDeviceName,
      activeSampleRate: _state.activeSampleRate,
      spectrumLevels: _state.spectrumLevels,
    );
    notifyListeners();
  }

  void seek(double targetSec) {
    _bindings.seek(targetSec);
    notifyListeners();
  }

  void setVolume(double vol) {
    _bindings.setVolume(vol.clamp(0.0, 1.0));
    _state = PlaybackState(
      isPlaying: _state.isPlaying,
      isPaused: _state.isPaused,
      isBitPerfect: _state.isBitPerfect,
      currentTime: _state.currentTime,
      duration: _state.duration,
      progress: _state.progress,
      volume: vol.clamp(0.0, 1.0),
      isMuted: _state.isMuted,
      playMode: _playMode,
      activeDeviceName: _state.activeDeviceName,
      activeSampleRate: _state.activeSampleRate,
      spectrumLevels: _state.spectrumLevels,
    );
    notifyListeners();
  }

  void toggleMute() {
    final nextMuted = !_state.isMuted;
    _bindings.setMuted(nextMuted);
    _state = PlaybackState(
      isPlaying: _state.isPlaying,
      isPaused: _state.isPaused,
      isBitPerfect: _state.isBitPerfect,
      currentTime: _state.currentTime,
      duration: _state.duration,
      progress: _state.progress,
      volume: _state.volume,
      isMuted: nextMuted,
      playMode: _playMode,
      activeDeviceName: _state.activeDeviceName,
      activeSampleRate: _state.activeSampleRate,
      spectrumLevels: _state.spectrumLevels,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _bindings.dispose();
    super.dispose();
  }
}
