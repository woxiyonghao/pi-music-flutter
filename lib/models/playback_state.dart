/// 播放循环模式 (对齐 C++ PlayMode)
enum PlayMode {
  loopList,
  loopSingle,
  shuffle,
  sequence,
}

/// 播放器实时状态模型
class PlaybackState {
  final bool isPlaying;
  final bool isPaused;
  final bool isBitPerfect;
  final double currentTime;
  final double duration;
  final double progress;
  final double volume;
  final bool isMuted;
  final PlayMode playMode;
  final String activeDeviceName;
  final int activeSampleRate;
  final List<double> spectrumLevels; // 12 频段实时振幅

  const PlaybackState({
    this.isPlaying = false,
    this.isPaused = false,
    this.isBitPerfect = true,
    this.currentTime = 0.0,
    this.duration = 0.0,
    this.progress = 0.0,
    this.volume = 0.77,
    this.isMuted = false,
    this.playMode = PlayMode.loopList,
    this.activeDeviceName = 'Apple Direct',
    this.activeSampleRate = 192000,
    this.spectrumLevels = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  });

  String get currentTimeString {
    final curSec = currentTime.clamp(0.0, 86400.0).floor();
    final minutes = (curSec / 60).floor();
    final seconds = curSec % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get durationString {
    if (duration <= 0.0) return '--:--';
    final durSec = duration.clamp(0.0, 86400.0).floor();
    final minutes = (durSec / 60).floor();
    final seconds = durSec % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
