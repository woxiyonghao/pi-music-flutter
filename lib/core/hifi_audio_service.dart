import 'dart:async';
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

  final ValueNotifier<int?> currentTrackIdNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  HifiAudioService._() {
    _bindings.init();
    _startTicker();
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
    playTrack(_playlistQueue[_currentIndex]);
  }

  void playTrack(Track track, [List<Track>? queue, int? index]) {
    _currentTrack = track;
    currentTrackIdNotifier.value = track.id;
    isPlayingNotifier.value = true;

    if (queue != null && index != null) {
      _playlistQueue = List.from(queue);
      _currentIndex = index;
    } else if (!_playlistQueue.contains(track)) {
      _playlistQueue = [track];
      _currentIndex = 0;
    } else {
      _currentIndex = _playlistQueue.indexOf(track);
    }

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

    // 延迟到事件循环下一轮执行 C++ 解码与声卡 I/O，确保当前 UI 帧 60fps 零卡顿即时响应
    Future(() async {
      if (track.isCueTrack && track.endTimeSec > track.startTimeSec) {
        _bindings.openAndPlaySection(track.filepath, track.startTimeSec, track.endTimeSec);
      } else {
        _bindings.openAndPlay(track.filepath);
      }
    });
  }

  void togglePlayPause() {
    if (_currentTrack == null && _playlistQueue.isNotEmpty) {
      playTrack(_playlistQueue.first);
      return;
    }
    _bindings.toggle();
    final nowPlaying = !_state.isPlaying;
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
    _bindings.play();
    notifyListeners();
  }

  void pause() {
    _bindings.pause();
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
      default:
        _currentIndex = (_currentIndex + 1) % _playlistQueue.length;
        break;
    }
    playTrack(_playlistQueue[_currentIndex]);
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
