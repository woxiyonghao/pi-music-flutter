import 'dart:io';
import '../core/native_music_library.dart';
import '../models/track.dart';

class AudioMetadata {
  final int sampleRate;
  final int bitDepth;
  final int durationSec;
  final double? preciseDurationSec;

  const AudioMetadata({
    required this.sampleRate,
    required this.bitDepth,
    required this.durationSec,
    this.preciseDurationSec,
  });

  double get durationSeconds => preciseDurationSec ?? durationSec.toDouble();
}

class AudioMetadataHelper {
  static const unknown = AudioMetadata(sampleRate: 0, bitDepth: 0, durationSec: 0);
  static AudioMetadata parse(File file, AudioFormat format) {
    if (!file.existsSync()) return unknown;
    try {
      final meta = NativeMusicLibrary.metadata(file.path);
      final seconds = (meta['durationSeconds'] as num? ?? 0).toDouble();
      return AudioMetadata(sampleRate: meta['sampleRate'] as int? ?? 0,
          bitDepth: meta['bitDepth'] as int? ?? 0,
          durationSec: seconds.round(), preciseDurationSec: seconds);
    } catch (_) { return unknown; }
  }
}
