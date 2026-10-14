/// 音乐曲目元数据模型
class Track {
  final String title;
  final String artist;
  final String album;
  final String filepath;
  final double durationSec;
  final String format; // FLAC, DSD, WAV, MP3
  final int sampleRate;
  final int bitDepth;

  const Track({
    required this.title,
    required this.artist,
    required this.album,
    required this.filepath,
    required this.durationSec,
    required this.format,
    required this.sampleRate,
    required this.bitDepth,
  });

  String get durationString {
    final minutes = (durationSec / 60).floor();
    final seconds = (durationSec % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
