import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
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
  static const unknown =
      AudioMetadata(sampleRate: 0, bitDepth: 0, durationSec: 0);

  /// Read actual headers. Unsupported/damaged files remain unknown instead of
  /// presenting an invented 3 minute, 44.1 kHz or DSD64 recording.
  static AudioMetadata parse(File file, AudioFormat format) {
    if (!file.existsSync()) return unknown;
    try {
      switch (format) {
        case AudioFormat.wav:
          return _parseWav(file);
        case AudioFormat.flac:
          return _parseFlac(file);
        case AudioFormat.dsdDsf:
          return _parseDsf(file);
        default:
          return unknown;
      }
    } catch (_) {
      return unknown;
    }
  }

  static AudioMetadata _parseWav(File file) {
    final raf = file.openSync();
    try {
      final header = raf.readSync(12);
      if (header.length != 12 ||
          String.fromCharCodes(header.sublist(0, 4)) != 'RIFF' ||
          String.fromCharCodes(header.sublist(8, 12)) != 'WAVE') {
        return unknown;
      }
      int sampleRate = 0, bitDepth = 0, byteRate = 0;
      final length = raf.lengthSync();
      while (raf.positionSync() + 8 <= length) {
        final chunk = raf.readSync(8);
        final id = String.fromCharCodes(chunk.sublist(0, 4));
        final size = ByteData.sublistView(chunk).getUint32(4, Endian.little);
        final next = raf.positionSync() + size + (size & 1);
        if (id == 'fmt ' && size >= 16) {
          final data = raf.readSync(min(size, 40));
          if (data.length < 16) return unknown;
          final fmt = ByteData.sublistView(data);
          sampleRate = fmt.getUint32(4, Endian.little);
          byteRate = fmt.getUint32(8, Endian.little);
          bitDepth = fmt.getUint16(14, Endian.little);
          if (fmt.getUint16(0, Endian.little) == 0xFFFE && data.length >= 20) {
            final validBits = fmt.getUint16(18, Endian.little);
            if (validBits > 0) bitDepth = validBits;
          }
        } else if (id == 'data') {
          final dataBytes = min(size, max(0, length - raf.positionSync()));
          final seconds = byteRate > 0 ? dataBytes / byteRate : 0.0;
          return AudioMetadata(
              sampleRate: sampleRate,
              bitDepth: bitDepth,
              durationSec: seconds.round(),
              preciseDurationSec: seconds);
        }
        if (next > length) break;
        raf.setPositionSync(next);
      }
      return unknown;
    } finally {
      raf.closeSync();
    }
  }

  static AudioMetadata _parseFlac(File file) {
    final raf = file.openSync();
    try {
      if (String.fromCharCodes(raf.readSync(4)) != 'fLaC') {
        return unknown;
      }
      final blockHeader = raf.readSync(4);
      if (blockHeader.length != 4 || blockHeader[0] & 0x7F != 0) {
        return unknown;
      }
      final size =
          (blockHeader[1] << 16) | (blockHeader[2] << 8) | blockHeader[3];
      if (size != 34) return unknown;
      final data = raf.readSync(size);
      if (data.length != size) return unknown;
      int packed = 0;
      for (int i = 10; i < 18; i++) {
        packed = (packed << 8) | data[i];
      }
      final sampleRate = (packed >> 44) & 0xFFFFF;
      final bitDepth = ((packed >> 36) & 0x1F) + 1;
      final samples = packed & 0xFFFFFFFFF;
      final seconds = sampleRate > 0 ? samples / sampleRate : 0.0;
      return AudioMetadata(
          sampleRate: sampleRate,
          bitDepth: bitDepth,
          durationSec: seconds.round(),
          preciseDurationSec: seconds);
    } finally {
      raf.closeSync();
    }
  }

  static AudioMetadata _parseDsf(File file) {
    final raf = file.openSync();
    try {
      final header = raf.readSync(28);
      if (header.length != 28 ||
          String.fromCharCodes(header.sublist(0, 4)) != 'DSD ') {
        return unknown;
      }
      final fmtBytes = raf.readSync(52);
      if (fmtBytes.length != 52 ||
          String.fromCharCodes(fmtBytes.sublist(0, 4)) != 'fmt ') {
        return unknown;
      }
      final fmt = ByteData.sublistView(fmtBytes);
      final sampleRate = fmt.getUint32(28, Endian.little);
      final samples = fmt.getUint64(36, Endian.little);
      final seconds = sampleRate > 0 ? samples / sampleRate : 0.0;
      return AudioMetadata(
          sampleRate: sampleRate,
          bitDepth: 1,
          durationSec: seconds.round(),
          preciseDurationSec: seconds);
    } finally {
      raf.closeSync();
    }
  }
}
