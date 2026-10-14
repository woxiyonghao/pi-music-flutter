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
  final List<double> spectrumLevels; // 12 频段实时振幅

  const PlaybackState({
    this.isPlaying = false,
    this.isPaused = false,
    this.isBitPerfect = true,
    this.currentTime = 0.0,
    this.duration = 0.0,
    this.progress = 0.0,
    this.volume = 0.8,
    this.isMuted = false,
    this.spectrumLevels = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  });

  String get currentTimeString {
    final minutes = (currentTime / 60).floor();
    final seconds = (currentTime % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get durationString {
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
