import 'dart:io';
import 'dart:typed_data';
import '../models/track.dart';

class AudioMetadata {
  final int sampleRate;
  final int bitDepth;
  final int durationSec;

  const AudioMetadata({
    required this.sampleRate,
    required this.bitDepth,
    required this.durationSec,
  });
}

class AudioMetadataHelper {
  /// 读取音频元数据 (采样率、位深、时长)
  static AudioMetadata parse(File file, AudioFormat format) {
    if (!file.existsSync()) {
      return const AudioMetadata(sampleRate: 44100, bitDepth: 16, durationSec: 180);
    }

    try {
      if (format == AudioFormat.wav) {
        return _parseWav(file);
      } else if (format == AudioFormat.flac) {
        return _parseFlac(file);
      } else if (format == AudioFormat.dsdDsf || format == AudioFormat.dsdDff) {
        return _parseDsd(file);
      }
    } catch (_) {}

    return const AudioMetadata(sampleRate: 44100, bitDepth: 16, durationSec: 180);
  }

  static AudioMetadata _parseWav(File file) {
    final raf = file.openSync(mode: FileMode.read);
    try {
      final header = Uint8List(12);
      if (raf.readIntoSync(header) < 12) {
        return const AudioMetadata(sampleRate: 44100, bitDepth: 16, durationSec: 180);
      }
      final riffStr = String.fromCharCodes(header.sublist(0, 4));
      final waveStr = String.fromCharCodes(header.sublist(8, 12));
      if (riffStr != 'RIFF' || waveStr != 'WAVE') {
        return const AudioMetadata(sampleRate: 44100, bitDepth: 16, durationSec: 180);
      }

      int sampleRate = 44100;
      int bitDepth = 16;
      int byteRate = 0;
      int dataSize = 0;

      final chunkHdr = Uint8List(8);
      final bd = ByteData.sublistView(chunkHdr);

      while (raf.readIntoSync(chunkHdr) == 8) {
        final chunkId = String.fromCharCodes(chunkHdr.sublist(0, 4));
        final chunkSize = bd.getUint32(4, Endian.little);

        if (chunkId == 'fmt ' && chunkSize >= 16) {
          final fmtData = Uint8List(chunkSize);
          raf.readIntoSync(fmtData);
          final fbd = ByteData.sublistView(fmtData);
          sampleRate = fbd.getUint32(4, Endian.little);
          byteRate = fbd.getUint32(8, Endian.little);
          bitDepth = fbd.getUint16(14, Endian.little);
        } else if (chunkId == 'data') {
          dataSize = chunkSize;
          break;
        } else {
          // 跳过其他 chunk
          final pad = chunkSize % 2;
          raf.setPositionSync(raf.positionSync() + chunkSize + pad);
        }
      }

      int durationSec = 180;
      if (byteRate > 0 && dataSize > 0) {
        durationSec = (dataSize / byteRate).round();
      } else {
        final fileLen = file.lengthSync();
        if (byteRate > 0 && fileLen > 44) {
          durationSec = ((fileLen - 44) / byteRate).round();
        }
      }

      return AudioMetadata(
        sampleRate: sampleRate > 0 ? sampleRate : 44100,
        bitDepth: bitDepth > 0 ? bitDepth : 16,
        durationSec: durationSec > 0 ? durationSec : 180,
      );
    } finally {
      raf.closeSync();
    }
  }

  static AudioMetadata _parseFlac(File file) {
    final raf = file.openSync(mode: FileMode.read);
    try {
      final magic = Uint8List(4);
      if (raf.readIntoSync(magic) < 4) {
        return const AudioMetadata(sampleRate: 96000, bitDepth: 24, durationSec: 180);
      }
      if (String.fromCharCodes(magic) != 'fLaC') {
        return const AudioMetadata(sampleRate: 96000, bitDepth: 24, durationSec: 180);
      }

      final blockHdr = Uint8List(4);
      if (raf.readIntoSync(blockHdr) < 4) {
        return const AudioMetadata(sampleRate: 96000, bitDepth: 24, durationSec: 180);
      }
      final blockType = blockHdr[0] & 0x7F;
      final blockLen = (blockHdr[1] << 16) | (blockHdr[2] << 8) | blockHdr[3];

      if (blockType == 0 && blockLen >= 18 && blockLen <= 65536) {
        final data = Uint8List(blockLen);
        if (raf.readIntoSync(data) == blockLen) {
          int b = 0;
          for (int i = 10; i < 18; ++i) {
            b = (b << 8) | data[i];
          }
          final sr = (b >> 44) & 0xFFFFF;
          final bps = (((b >> 36) & 0x1F) + 1);
          final totalSamples = b & 0xFFFFFFFFF;
          final dur = sr > 0 ? (totalSamples / sr).round() : 180;
          return AudioMetadata(
            sampleRate: sr > 0 ? sr : 96000,
            bitDepth: bps > 0 ? bps : 24,
            durationSec: dur > 0 ? dur : 180,
          );
        }
      }
      return const AudioMetadata(sampleRate: 96000, bitDepth: 24, durationSec: 180);
    } finally {
      raf.closeSync();
    }
  }

  static AudioMetadata _parseDsd(File file) {
    return const AudioMetadata(
      sampleRate: 2822400,
      bitDepth: 1,
      durationSec: 180,
    );
  }
}
