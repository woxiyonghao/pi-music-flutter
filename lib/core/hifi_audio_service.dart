import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../models/playback_state.dart';
import '../services/music_database_service.dart';
import '../services/dac_setting_service.dart';
import 'hifi_audio_bindings.dart';
import '../platform/platform_audio_runtime.dart';
import 'playback_completion_tracker.dart';

/// 全局音频服务 (提供 60fps 动效数据流与状态响应式驱动)
class HifiAudioService extends ChangeNotifier {
  static final HifiAudioService instance = HifiAudioService._();

  final HifiAudioBindings _bindings = HifiAudioBindings.instance;
  final Future<void> Function(String)? _prepareFileOverride;
  final bool Function(String, double, double)? _openFileOverride;
  final bool _ownsBindings;
  int _loadGeneration = 0;
  bool _isPreparingTrack = false;
  bool get isPreparingTrack => _isPreparingTrack;
  bool _playWhenPrepared = true;
  double? _pendingSeek;

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
  final _completion = PlaybackCompletionTracker();
  int _consecutiveErrors = 0;
  int _hardwarePollTicks = 0;
  String _hardwareDeviceName = '';
  int _hardwareSampleRate = 0;
  final ValueNotifier<String> outputDeviceNameNotifier = ValueNotifier('');
  final ValueNotifier<int> eqSettingsRevision = ValueNotifier(0);

  bool _eqEnabled = false;
  bool get eqEnabled => _eqEnabled;

  List<double> _eqBands = List.filled(10, 0.0);
  List<double> get eqBands => List.unmodifiable(_eqBands);

  String lastDebugLog = '';

  final ValueNotifier<int?> currentTrackIdNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<Track?> currentTrackNotifier =
      ValueNotifier<Track?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  HifiAudioService._()
      : _prepareFileOverride = null,
        _openFileOverride = null,
        _ownsBindings = true {
    _bindings.init();
    _loadEqSettings();
    final runtime = PlatformAudioRuntime.instance;
    runtime.isPlaying = () => _state.isPlaying;
    runtime.pauseForSystem = () => pause(fromSystem: true);
    runtime.resumeAfterSystem = () {
      play();
    };
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _startTicker();
    }
  }

  @visibleForTesting
  HifiAudioService.forTesting({
    required Future<void> Function(String) prepareFile,
    required bool Function(String, double, double) openFile,
  })  : _prepareFileOverride = prepareFile,
        _openFileOverride = openFile,
        _ownsBindings = false;

  static Future<void> _prepareFile(String path) async {
    // macOS can wait here for Downloads / Desktop access permission. Dart's
    // asynchronous file service keeps that wait off the Flutter platform thread.
    final file = await File(path).open(mode: FileMode.read);
    await file.close();
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
    eqSettingsRevision.value++;
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
    eqSettingsRevision.value++;
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
    eqSettingsRevision.value++;
    notifyListeners();
  }

  void setEqBand(int index, double gain) {
    if (index < 0 || index >= 10) return;
    _eqBands[index] = gain.clamp(-12.0, 12.0);
    _bindings.setEqBands(_eqBands);
    MusicDatabaseService.instance
        .setSetting('eq_band_$index', _eqBands[index].toStringAsFixed(1));
    eqSettingsRevision.value++;
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
    eqSettingsRevision.value++;
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
      if (_hardwarePollTicks++ % 10 == 0) {
        _hardwareDeviceName = _bindings.getDeviceName();
        _hardwareSampleRate = _bindings.getSampleRate();
        outputDeviceNameNotifier.value = _hardwareDeviceName;
      }

      if (isPlayingNotifier.value != isPlaying) {
        isPlayingNotifier.value = isPlaying;
      }

      if (isPlaying) {
        _consecutiveErrors = 0;
      }

      // 停播也可能来自设备重建；只有引擎确认 EOF 且缓冲区已耗尽才自动切歌。
      if (!_isPreparingTrack &&
          _completion.update(
              isPlaying: isPlaying,
              isPaused: isPaused,
              hasCompleted: _bindings.hasPlaybackCompleted())) {
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
          activeDeviceName: _hardwareDeviceName,
          activeSampleRate: _hardwareSampleRate,
          spectrumLevels: List.filled(12, 0.0),
        );
        isPlayingNotifier.value = false;
        notifyListeners();
        next(isAutomatic: true);
        return;
      }

      // 仅在播放中或状态变更时通知监听者
      if (isPlaying ||
          _state.isPlaying != isPlaying ||
          _state.isPaused != isPaused ||
          _state.activeDeviceName != _hardwareDeviceName ||
          _state.activeSampleRate != _hardwareSampleRate) {
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
          activeDeviceName: _hardwareDeviceName,
          activeSampleRate: _hardwareSampleRate,
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

  Future<void> playTrack(Track track, [List<Track>? queue, int? index]) async {
    final generation = ++_loadGeneration;
    _isPreparingTrack = true;
    _playWhenPrepared = true;
    _pendingSeek = null;
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

    _completion.reset();

    // 在单元测试无头环境下模拟成功播放，方便验证 Flutter Widget 树与高亮状态流转
    if (Platform.environment.containsKey('FLUTTER_TEST') &&
        _prepareFileOverride == null) {
      _isPreparingTrack = false;
      _completion.update(isPlaying: true, isPaused: false, hasCompleted: false);
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
    Object? fileError;
    try {
      await (_prepareFileOverride ?? _prepareFile)(resolvedPath);
      if (generation != _loadGeneration) return;
      if (!await PlatformAudioRuntime.instance.activate()) {
        throw StateError('Audio session activation was denied');
      }
    } catch (error) {
      fileError = error;
    }
    // A newer selection or Stop supersedes a pending OS permission request.
    if (generation != _loadGeneration) return;
    _isPreparingTrack = false;
    if (fileError != null) {
      lastDebugLog =
          'FILE_OPEN_FAILED: resolved=$resolvedPath, error=$fileError';
      debugPrint('[HifiAudioService] 无法读取音频文件: $resolvedPath: $fileError');
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
    if (_openFileOverride != null) {
      success = _openFileOverride!(
          resolvedPath, track.startTimeSec, track.endTimeSec);
    } else if (track.isCueTrack && track.endTimeSec > track.startTimeSec) {
      success = _bindings.openAndPlaySection(
          resolvedPath, track.startTimeSec, track.endTimeSec);
    } else {
      success = _bindings.openAndPlay(resolvedPath);
    }

    if (!success) {
      lastDebugLog =
          'BINDINGS_OPEN_FAIL: path=$resolvedPath, isCue=${track.isCueTrack}, isLoaded=${_bindings.isLoaded}';
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
    if (track.sampleRate > 0) {
      DacSettingService.instance.syncPlaybackSampleRate(track.sampleRate.toDouble());
    }
    final position = _pendingSeek ?? 0.0;
    if (_pendingSeek != null) _bindings.seek(position);
    if (!_playWhenPrepared) _bindings.pause();
    _consecutiveErrors = 0;
    _completion.reset();
    isPlayingNotifier.value = _playWhenPrepared;
    _state = PlaybackState(
      isPlaying: _playWhenPrepared,
      isPaused: !_playWhenPrepared,
      isBitPerfect: _bindings.isBitPerfect(),
      currentTime: position,
      duration: track.durationSec.toDouble(),
      progress: track.durationSec > 0
          ? (position / track.durationSec).clamp(0.0, 1.0)
          : 0.0,
      volume: _state.volume,
      isMuted: _state.isMuted,
      playMode: _playMode,
      activeDeviceName: _bindings.getDeviceName(),
      activeSampleRate: _bindings.getSampleRate(),
      spectrumLevels: _state.spectrumLevels,
    );
    notifyListeners();
  }

  void togglePlayPause() {
    if (_currentTrack == null && _playlistQueue.isNotEmpty) {
      playTrack(_playlistQueue.first);
    } else if (_state.isPlaying || (_isPreparingTrack && _playWhenPrepared)) {
      pause();
    } else {
      play();
    }
  }

  Future<void> play() async {
    _playWhenPrepared = true;
    if (_isPreparingTrack) return;
    final generation = _loadGeneration;
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      if (!await PlatformAudioRuntime.instance.activate()) return;
      if (generation != _loadGeneration || !_playWhenPrepared) return;
      // A selection paused during preparation has no native decoder yet.
      if (_bindings.isIdle() && _currentTrack != null) {
        await playTrack(_currentTrack!);
        return;
      }
    }
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

  void pause({bool fromSystem = false}) {
    if (!fromSystem) PlatformAudioRuntime.instance.userPaused();
    _playWhenPrepared = false;
    _completion.reset();
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
    PlatformAudioRuntime.instance.userPaused();
    _loadGeneration++;
    _isPreparingTrack = false;
    _pendingSeek = null;
    _playWhenPrepared = false;
    _completion.reset();
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
    _completion.reset();
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

  void next({bool isAutomatic = false}) {
    if (_playlistQueue.isEmpty) return;
    if (_consecutiveErrors >= _playlistQueue.length) {
      _consecutiveErrors = 0;
      _completion.reset();
      pause();
      return;
    }
    _completion.reset();
    switch (_playMode) {
      case PlayMode.loopSingle:
        if (isAutomatic) {
          // 自然播完单曲循环模式：重新播放当前曲目
          final trackToReplay = _currentTrack ??
              (_playlistQueue.isNotEmpty
                  ? _playlistQueue[_currentIndex]
                  : null);
          if (trackToReplay != null) {
            playTrack(trackToReplay);
            return;
          }
        }
        // 用户手动点击下一曲或队列无当前曲：切到队列的下一首
        _currentIndex = (_currentIndex + 1) % _playlistQueue.length;
        break;
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

  void setPlayMode(PlayMode mode) {
    if (_playMode == mode) return;
    _playMode = mode;
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
    if (_isPreparingTrack) {
      _pendingSeek = targetSec;
      return;
    }
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
    if (_ownsBindings) _bindings.dispose();
    super.dispose();
  }
}
