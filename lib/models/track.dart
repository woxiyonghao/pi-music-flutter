/// 音频无损/母带编码格式 (对齐 C++ MusicModel.hpp)
enum AudioFormat {
  unknown,
  flac,
  wav,
  dsdDsf,
  dsdDff,
  alac,
  mp3,
}

/// 音乐曲目元数据模型 (1:1 严格对齐 C++ Track 结构体)
class Track {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String filepath;
  final AudioFormat format;
  final int sampleRate;
  final int bitDepth;
  final int durationSec;
  final bool isCueTrack;
  final double startTimeSec;
  final double endTimeSec;
  final String cuePath;
  final int trackNumber;

  const Track({
    this.id = 0,
    required this.title,
    required this.artist,
    required this.album,
    required this.filepath,
    this.format = AudioFormat.flac,
    required this.sampleRate,
    required this.bitDepth,
    required this.durationSec,
    this.isCueTrack = false,
    this.startTimeSec = 0.0,
    this.endTimeSec = 0.0,
    this.cuePath = '',
    this.trackNumber = 0,
  });

  /// 对应 C++ Track::getFormatBadge()
  String get formatBadge {
    if (format == AudioFormat.unknown) {
      return "UNKNOWN";
    }
    if (format == AudioFormat.dsdDsf || format == AudioFormat.dsdDff) {
      final multiplier = sampleRate > 0 ? (sampleRate / 44100).round() : 64;
      return "DSD ${multiplier}x";
    }
    final khz = (sampleRate / 1000).round();
    return "${khz}kHz / ${bitDepth}bit";
  }

  String get durationString {
    final minutes = (durationSec / 60).floor();
    final seconds = (durationSec % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static AudioFormat formatFromInt(int val) {
    switch (val) {
      case 1:
        return AudioFormat.flac;
      case 2:
        return AudioFormat.wav;
      case 3:
        return AudioFormat.dsdDsf;
      case 4:
        return AudioFormat.dsdDff;
      case 5:
        return AudioFormat.alac;
      case 6:
        return AudioFormat.mp3;
      default:
        return AudioFormat.unknown;
    }
  }
}

/// 播放列表实体模型 (1:1 严格对齐 C++ Playlist)
class Playlist {
  final int id;
  String name;
  String coverPath;
  final List<Track> tracks;

  Playlist({
    required this.id,
    required this.name,
    this.coverPath = '',
    List<Track>? tracks,
  }) : tracks = tracks ?? [];

  int get totalDurationSec =>
      tracks.fold(0, (sum, t) => sum + t.durationSec);
}
