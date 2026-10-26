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
        case AudioFormat.mp3:
          return _parseMp3(file);
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

  static AudioMetadata _parseMp3(File file) {
    final raf = file.openSync();
    try {
      final length = raf.lengthSync();
      if (length < 16) return unknown;

      int audioOffset = 0;
      final id3Header = raf.readSync(10);
      if (id3Header.length == 10 &&
          id3Header[0] == 0x49 && // 'I'
          id3Header[1] == 0x44 && // 'D'
          id3Header[2] == 0x33) {
        final tagSize = ((id3Header[6] & 0x7F) << 21) |
            ((id3Header[7] & 0x7F) << 14) |
            ((id3Header[8] & 0x7F) << 7) |
            (id3Header[9] & 0x7F);
        final hasFooter = (id3Header[5] & 0x10) != 0;
        audioOffset = 10 + tagSize + (hasFooter ? 10 : 0);
      }

      if (audioOffset >= length) {
        audioOffset = 0;
      }
      raf.setPositionSync(audioOffset);
      final probeLen = min(65536, length - audioOffset);
      final buf = raf.readSync(probeLen);
      if (buf.length < 4) return unknown;

      const mpeg1Sr = [44100, 48000, 32000];
      const mpeg2Sr = [22050, 24000, 16000];
      const mpeg25Sr = [11025, 12000, 8000];
      const mpeg1L3Bitrates = [
        0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0
      ];
      const mpeg2L3Bitrates = [
        0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0
      ];

      for (int i = 0; i <= buf.length - 4; i++) {
        if (buf[i] != 0xFF || (buf[i + 1] & 0xE0) != 0xE0) continue;
        final versionBits = (buf[i + 1] >> 3) & 0x03;
        final layerBits = (buf[i + 1] >> 1) & 0x03;
        final bitrateIdx = (buf[i + 2] >> 4) & 0x0F;
        final srIdx = (buf[i + 2] >> 2) & 0x03;
        final channelMode = (buf[i + 3] >> 6) & 0x03;

        if (versionBits == 1 ||
            layerBits != 1 ||
            bitrateIdx == 0 ||
            bitrateIdx == 15 ||
            srIdx == 3) {
          continue;
        }

        final sampleRate = versionBits == 3
            ? mpeg1Sr[srIdx]
            : (versionBits == 2 ? mpeg2Sr[srIdx] : mpeg25Sr[srIdx]);
        final bitrateKbps = versionBits == 3
            ? mpeg1L3Bitrates[bitrateIdx]
            : mpeg2L3Bitrates[bitrateIdx];
        if (sampleRate <= 0 || bitrateKbps <= 0) continue;

        final samplesPerFrame = versionBits == 3 ? 1152 : 576;
        final sideInfoSize = versionBits == 3
            ? (channelMode == 3 ? 17 : 32)
            : (channelMode == 3 ? 9 : 17);

        double seconds = 0.0;
        final xingPos = i + 4 + sideInfoSize;
        if (xingPos + 12 <= buf.length) {
          final tag = String.fromCharCodes(buf.sublist(xingPos, xingPos + 4));
          if (tag == 'Xing' || tag == 'Info') {
            final bd = ByteData.sublistView(buf);
            final flags = bd.getUint32(xingPos + 4, Endian.big);
            if ((flags & 0x01) != 0) {
              final totalFrames = bd.getUint32(xingPos + 8, Endian.big);
              if (totalFrames > 0) {
                seconds = (totalFrames * samplesPerFrame) / sampleRate;
              }
            }
          }
        }
        final vbriPos = i + 36;
        if (seconds <= 0 && vbriPos + 18 <= buf.length) {
          final tag = String.fromCharCodes(buf.sublist(vbriPos, vbriPos + 4));
          if (tag == 'VBRI') {
            final bd = ByteData.sublistView(buf);
            final totalFrames = bd.getUint32(vbriPos + 14, Endian.big);
            if (totalFrames > 0) {
              seconds = (totalFrames * samplesPerFrame) / sampleRate;
            }
          }
        }
        if (seconds <= 0) {
          final payloadBytes = max(0, length - (audioOffset + i));
          seconds = (payloadBytes * 8.0) / (bitrateKbps * 1000.0);
        }

        return AudioMetadata(
          sampleRate: sampleRate,
          bitDepth: 16,
          durationSec: seconds.round(),
          preciseDurationSec: seconds,
        );
      }
      return unknown;
    } finally {
      raf.closeSync();
    }
  }
}
