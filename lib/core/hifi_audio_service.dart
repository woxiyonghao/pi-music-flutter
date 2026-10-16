import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../models/playback_state.dart';
import '../services/music_database_service.dart';
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
  bool _hasConfirmedPlaying = false;
  int _consecutiveErrors = 0;

  bool _eqEnabled = false;
  bool get eqEnabled => _eqEnabled;

  List<double> _eqBands = List.filled(10, 0.0);
  List<double> get eqBands => List.unmodifiable(_eqBands);

  String lastDebugLog = '';

  final ValueNotifier<int?> currentTrackIdNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<Track?> currentTrackNotifier = ValueNotifier<Track?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  HifiAudioService._() {
    _bindings.init();
    _loadEqSettings();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _startTicker();
    }
  }

  void _loadEqSettings() {
    try {
      final db = MusicDatabaseService.instance;
      _eqEnabled = db.getSetting('eq_enabled', '0') == '1';
      for (int i = 0; i < 10; i++) {
        final valStr = db.getSetting('eq_band_$i', '0.0');
        _eqBands[i] = double.tryParse(valStr)?.clamp(-12.0, 12.0) ?? 0.0;
      }
      _bindings.setEqEnabled(_eqEnabled);
      _bindings.setEqBands(_eqBands);
    } catch (_) {}
  }

  void setEqEnabled(bool enabled) {
    _eqEnabled = enabled;
    _bindings.setEqEnabled(enabled);
    MusicDatabaseService.instance.setSetting('eq_enabled', enabled ? '1' : '0');
    notifyListeners();
  }

  void setEqAndBands(bool enabled, List<double> bands, {int? selectedPreset}) {
    _eqEnabled = enabled;
    _bindings.setEqEnabled(enabled);
    if (bands.length == 10) {
      _eqBands = List.from(bands);
      _bindings.setEqBands(_eqBands);
    }
    final db = MusicDatabaseService.instance;
    db.setSetting('eq_enabled', enabled ? '1' : '0');
    if (selectedPreset != null) {
      db.setSetting('eq_selected_preset', selectedPreset.toString());
    }
    for (int i = 0; i < _eqBands.length; i++) {
      db.setSetting('eq_band_$i', _eqBands[i].toStringAsFixed(1));
    }
    notifyListeners();
  }

  void setEqBands(List<double> bands) {
    if (bands.length != 10) return;
    _eqBands = List.from(bands);
    _bindings.setEqBands(_eqBands);
    final db = MusicDatabaseService.instance;
    for (int i = 0; i < 10; i++) {
      db.setSetting('eq_band_$i', _eqBands[i].toStringAsFixed(1));
    }
    notifyListeners();
  }

  void setEqBand(int index, double gain) {
    if (index < 0 || index >= 10) return;
    _eqBands[index] = gain.clamp(-12.0, 12.0);
    _bindings.setEqBands(_eqBands);
    MusicDatabaseService.instance.setSetting('eq_band_$index', _eqBands[index].toStringAsFixed(1));
    notifyListeners();
  }

  void resetEq() {
    _eqBands = List.filled(10, 0.0);
    _eqEnabled = false;
    _bindings.setEqEnabled(false);
    _bindings.setEqBands(_eqBands);
    final db = MusicDatabaseService.instance;
    db.setSetting('eq_enabled', '0');
    db.setSetting('eq_selected_preset', '0');
    for (int i = 0; i < 10; i++) {
      db.setSetting('eq_band_$i', '0.0');
    }
    notifyListeners();
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
        _hasConfirmedPlaying = true;
        _consecutiveErrors = 0;
      }

      // 仅当曲目曾经在底层引擎真正开始播放，且现在底层已经停止，并且不是处于暂停状态时，才视为自然播完
      if (_hasConfirmedPlaying && _state.isPlaying && !isPlaying && !_state.isPaused) {
        _hasConfirmedPlaying = false;
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

    if (queue != null && index != null) {
      _playlistQueue = List.from(queue);
      _currentIndex = index;
    } else if (!_playlistQueue.contains(track)) {
      _playlistQueue = [track];
      _currentIndex = 0;
    } else {
      _currentIndex = _playlistQueue.indexOf(track);
    }

    _hasConfirmedPlaying = false;

    // 在单元测试无头环境下模拟成功播放，方便验证 Flutter Widget 树与高亮状态流转
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _hasConfirmedPlaying = true;
      _consecutiveErrors = 0;
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
      return;
    }

    // 智能自愈并校验物理文件是否存在，彻底避免 iOS Sandbox Container UUID 变化导致播放失败
    final resolvedPath = MusicDatabaseService.resolveTrackPath(track.filepath);
    final fileExists = File(resolvedPath).existsSync();
    if (!fileExists) {
      lastDebugLog = 'FILE_NOT_FOUND: resolved=$resolvedPath (orig=${track.filepath})';
      debugPrint('[HifiAudioService] 音频物理文件不存在: $resolvedPath (原路径: ${track.filepath})');
      _consecutiveErrors++;
      isPlayingNotifier.value = false;
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
      notifyListeners();
      return;
    }

    final bool success;
    if (track.isCueTrack && track.endTimeSec > track.startTimeSec) {
      success = _bindings.openAndPlaySection(resolvedPath, track.startTimeSec, track.endTimeSec);
    } else {
      success = _bindings.openAndPlay(resolvedPath);
    }

    if (!success) {
      lastDebugLog = 'BINDINGS_OPEN_FAIL: path=$resolvedPath, isCue=${track.isCueTrack}, isLoaded=${_bindings.isLoaded}';
      debugPrint('[HifiAudioService] 底层解码器打开音频文件失败: $resolvedPath');
      _consecutiveErrors++;
      isPlayingNotifier.value = false;
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
      notifyListeners();
      return;
    }

    lastDebugLog = 'SUCCESS_PLAY: $resolvedPath';
    _consecutiveErrors = 0;
    _hasConfirmedPlaying = false;
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
    if (_currentTrack == null && _playlistQueue.isNotEmpty) {
      playTrack(_playlistQueue.first);
      return;
    }
    _bindings.toggle();
    final nowPlaying = !_state.isPlaying;
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
    _bindings.play();
    isPlayingNotifier.value = true;
    _state = PlaybackState(
      isPlaying: true,
      isPaused: false,
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

  void pause() {
    _hasConfirmedPlaying = false;
    _bindings.pause();
    isPlayingNotifier.value = false;
    _state = PlaybackState(
      isPlaying: false,
      isPaused: true,
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

  void stop() {
    _hasConfirmedPlaying = false;
    _bindings.stop();
    isPlayingNotifier.value = false;
    _state = PlaybackState(
      isPlaying: false,
      isPaused: false,
      isBitPerfect: _state.isBitPerfect,
      currentTime: 0.0,
      duration: _state.duration,
      progress: 0.0,
      volume: _state.volume,
      isMuted: _state.isMuted,
      playMode: _playMode,
      activeDeviceName: _state.activeDeviceName,
      activeSampleRate: _state.activeSampleRate,
      spectrumLevels: List.filled(12, 0.0),
    );
    notifyListeners();
  }

  void previous() {
    if (_playlistQueue.isEmpty) return;
    _hasConfirmedPlaying = false;
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
    if (_consecutiveErrors >= _playlistQueue.length) {
      _consecutiveErrors = 0;
      _hasConfirmedPlaying = false;
      pause();
      return;
    }
    _hasConfirmedPlaying = false;
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
