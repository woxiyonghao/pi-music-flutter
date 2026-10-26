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
      if (format == AudioFormat.unknown) {
        final path = file.path;
        final dot = path.lastIndexOf('.');
        final ext = dot >= 0 ? path.substring(dot).toLowerCase() : '';
        format = Track.formatFromExtension(ext);
      }
      switch (format) {
        case AudioFormat.wav:
          return _parseWav(file);
        case AudioFormat.flac:
          return _parseFlac(file);
        case AudioFormat.dsdDsf:
          return _parseDsf(file);
        case AudioFormat.dsdDff:
          return _parseDff(file);
        case AudioFormat.mp3:
          return _parseMp3(file);
        case AudioFormat.alac:
          return _parseAlacOrAiff(file);
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
      final length = raf.lengthSync();
      if (length < 28) return unknown;

      // Skip ID3v2 if prepended
      int offset = 0;
      final magic = raf.readSync(10);
      if (magic.length == 10 &&
          magic[0] == 0x49 &&
          magic[1] == 0x44 &&
          magic[2] == 0x33) {
        final tagSize = ((magic[6] & 0x7F) << 21) |
            ((magic[7] & 0x7F) << 14) |
            ((magic[8] & 0x7F) << 7) |
            (magic[9] & 0x7F);
        offset = 10 + tagSize;
        if (offset + 28 > length) return unknown;
        raf.setPositionSync(offset);
      } else {
        raf.setPositionSync(0);
      }

      final header = raf.readSync(28);
      if (header.length != 28 ||
          String.fromCharCodes(header.sublist(0, 4)) != 'DSD ') {
        return unknown;
      }

      int sampleRate = 0;
      int channels = 2;
      int bitDepth = 1;
      int sampleCount = 0;
      int dataBytes = 0;

      while (raf.positionSync() + 12 <= length) {
        final chunkHeader = raf.readSync(12);
        if (chunkHeader.length < 12) break;
        final id = String.fromCharCodes(chunkHeader.sublist(0, 4));
        final size =
            ByteData.sublistView(chunkHeader).getUint64(4, Endian.little);
        if (size < 12) break;
        final payloadSize = size - 12;
        final payloadPos = raf.positionSync();

        if (id == 'fmt ') {
          if (payloadSize >= 40) {
            final fmtData = raf.readSync(min(payloadSize, 52));
            if (fmtData.length >= 40) {
              final bd = ByteData.sublistView(fmtData);
              channels = bd.getUint32(12, Endian.little);
              sampleRate = bd.getUint32(16, Endian.little);
              final bits = bd.getUint32(20, Endian.little);
              if (bits > 0) bitDepth = bits;
              sampleCount = bd.getUint64(24, Endian.little);
            }
          }
        } else if (id == 'data') {
          dataBytes = payloadSize;
        }

        final nextPos = payloadPos + payloadSize;
        if (nextPos >= length || nextPos <= payloadPos) break;
        raf.setPositionSync(nextPos);
      }

      if (sampleRate <= 0) return unknown;

      double seconds = 0.0;
      if (sampleCount > 0) {
        seconds = sampleCount / sampleRate;
      } else if (dataBytes > 0 && channels > 0) {
        final totalBits = dataBytes * 8;
        final samplesPerChannel = totalBits / channels;
        seconds = samplesPerChannel / sampleRate;
      }

      if (seconds <= 0.0) return unknown;

      return AudioMetadata(
        sampleRate: sampleRate,
        bitDepth: bitDepth,
        durationSec: seconds.round(),
        preciseDurationSec: seconds,
      );
    } finally {
      raf.closeSync();
    }
  }

  static AudioMetadata _parseDff(File file) {
    final raf = file.openSync();
    try {
      final length = raf.lengthSync();
      if (length < 16) return unknown;

      int offset = 0;
      final magic = raf.readSync(10);
      if (magic.length == 10 &&
          magic[0] == 0x49 &&
          magic[1] == 0x44 &&
          magic[2] == 0x33) {
        final tagSize = ((magic[6] & 0x7F) << 21) |
            ((magic[7] & 0x7F) << 14) |
            ((magic[8] & 0x7F) << 7) |
            (magic[9] & 0x7F);
        offset = 10 + tagSize;
        if (offset + 16 > length) return unknown;
        raf.setPositionSync(offset);
      } else {
        raf.setPositionSync(0);
      }

      final header = raf.readSync(16);
      if (header.length != 16 ||
          String.fromCharCodes(header.sublist(0, 4)) != 'FRM8') {
        return unknown;
      }
      final bdHeader = ByteData.sublistView(header);
      final formSize = bdHeader.getUint64(4, Endian.big);
      if (String.fromCharCodes(header.sublist(12, 16)) != 'DSD ') {
        return unknown;
      }

      final formEnd = min(length, offset + 12 + formSize);
      int sampleRate = 0;
      int channels = 0;
      int dataBytes = 0;

      while (raf.positionSync() + 12 <= formEnd) {
        final chunkHdr = raf.readSync(12);
        if (chunkHdr.length < 12) break;
        final id = String.fromCharCodes(chunkHdr.sublist(0, 4));
        final size = ByteData.sublistView(chunkHdr).getUint64(4, Endian.big);
        final payloadPos = raf.positionSync();

        if (id == 'PROP') {
          if (size >= 4) {
            final propType = raf.readSync(4);
            if (String.fromCharCodes(propType) == 'SND ') {
              final propEnd = min(formEnd, payloadPos + size);
              while (raf.positionSync() + 12 <= propEnd) {
                final subHdr = raf.readSync(12);
                if (subHdr.length < 12) break;
                final subId = String.fromCharCodes(subHdr.sublist(0, 4));
                final subSize =
                    ByteData.sublistView(subHdr).getUint64(4, Endian.big);
                final subPayloadPos = raf.positionSync();

                if (subId == 'FS  ' && subSize >= 4) {
                  final fsBytes = raf.readSync(4);
                  if (fsBytes.length == 4) {
                    sampleRate =
                        ByteData.sublistView(fsBytes).getUint32(0, Endian.big);
                  }
                } else if (subId == 'CHNL' && subSize >= 2) {
                  final chBytes = raf.readSync(2);
                  if (chBytes.length == 2) {
                    channels =
                        ByteData.sublistView(chBytes).getUint16(0, Endian.big);
                  }
                }

                final nextSub = subPayloadPos + subSize + (subSize & 1);
                if (nextSub >= propEnd || nextSub <= subPayloadPos) break;
                raf.setPositionSync(nextSub);
              }
            }
          }
        } else if (id == 'DSD ') {
          dataBytes = size;
        }

        final nextPos = payloadPos + size + (size & 1);
        if (nextPos >= formEnd || nextPos <= payloadPos) break;
        raf.setPositionSync(nextPos);
      }

      if (sampleRate <= 0 || channels <= 0 || dataBytes <= 0) return unknown;

      final totalBits = dataBytes * 8;
      final samplesPerChannel = totalBits / channels;
      final seconds = samplesPerChannel / sampleRate;
      if (seconds <= 0.0) return unknown;

      return AudioMetadata(
        sampleRate: sampleRate,
        bitDepth: 1,
        durationSec: seconds.round(),
        preciseDurationSec: seconds,
      );
    } finally {
      raf.closeSync();
    }
  }

  static AudioMetadata _parseAlacOrAiff(File file) {
    final raf = file.openSync();
    try {
      final length = raf.lengthSync();
      if (length < 16) return unknown;

      final header = raf.readSync(12);
      if (header.length < 12) return unknown;

      if (String.fromCharCodes(header.sublist(0, 4)) == 'FORM' &&
          (String.fromCharCodes(header.sublist(8, 12)) == 'AIFF' ||
              String.fromCharCodes(header.sublist(8, 12)) == 'AIFC')) {
        return _parseAiff(raf, length);
      }

      return _parseMp4(raf, length);
    } finally {
      raf.closeSync();
    }
  }

  static AudioMetadata _parseAiff(RandomAccessFile raf, int length) {
    raf.setPositionSync(12);
    int sampleRate = 0;
    int bitDepth = 16;
    double seconds = 0.0;

    while (raf.positionSync() + 8 <= length) {
      final chunkHdr = raf.readSync(8);
      if (chunkHdr.length < 8) break;
      final id = String.fromCharCodes(chunkHdr.sublist(0, 4));
      final size = ByteData.sublistView(chunkHdr).getUint32(4, Endian.big);
      final payloadPos = raf.positionSync();

      if (id == 'COMM' && size >= 18) {
        final commData = raf.readSync(18);
        if (commData.length >= 18) {
          final bd = ByteData.sublistView(commData);
          final numFrames = bd.getUint32(2, Endian.big);
          bitDepth = bd.getUint16(6, Endian.big);
          final rate = _readExtendedFloat(bd, 8);
          if (rate > 0) {
            sampleRate = rate.round();
            seconds = numFrames / rate;
          }
        }
        break;
      }

      final nextPos = payloadPos + size + (size & 1);
      if (nextPos >= length || nextPos <= payloadPos) break;
      raf.setPositionSync(nextPos);
    }

    if (seconds <= 0 || sampleRate <= 0) return unknown;
    return AudioMetadata(
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      durationSec: seconds.round(),
      preciseDurationSec: seconds,
    );
  }

  static double _readExtendedFloat(ByteData bd, int offset) {
    final signExponent = bd.getUint16(offset, Endian.big);
    final exponent = signExponent & 0x7FFF;
    final sign = (signExponent & 0x8000) != 0 ? -1.0 : 1.0;
    final hiMantissa = bd.getUint32(offset + 2, Endian.big);
    final loMantissa = bd.getUint32(offset + 6, Endian.big);
    if (exponent == 0 && hiMantissa == 0 && loMantissa == 0) return 0.0;
    if (exponent == 0x7FFF) return 0.0;
    final mantissa =
        (hiMantissa.toDouble() * 4294967296.0) + loMantissa.toDouble();
    return sign * mantissa * pow(2.0, exponent - 16383 - 63);
  }

  static AudioMetadata _parseMp4(RandomAccessFile raf, int length) {
    raf.setPositionSync(0);
    double seconds = 0.0;
    int sampleRate = 44100;
    int bitDepth = 16;

    while (raf.positionSync() + 8 <= length) {
      final boxHdr = raf.readSync(8);
      if (boxHdr.length < 8) break;
      final bd = ByteData.sublistView(boxHdr);
      int size = bd.getUint32(0, Endian.big);
      final type = String.fromCharCodes(boxHdr.sublist(4, 8));
      final pos = raf.positionSync();

      int headerSize = 8;
      if (size == 1) {
        final size64 = raf.readSync(8);
        if (size64.length < 8) break;
        size = ByteData.sublistView(size64).getUint64(0, Endian.big);
        headerSize = 16;
      } else if (size == 0) {
        size = length - (pos - 8);
      }
      if (size < headerSize) break;

      if (type == 'moov') {
        final moovEnd = min(length, pos - 8 + size);
        while (raf.positionSync() + 8 <= moovEnd) {
          final subHdr = raf.readSync(8);
          if (subHdr.length < 8) break;
          final subSize = ByteData.sublistView(subHdr).getUint32(0, Endian.big);
          final subType = String.fromCharCodes(subHdr.sublist(4, 8));
          final subPos = raf.positionSync();
          if (subSize < 8) break;
          final subPayload = subSize - 8;

          if (subType == 'mvhd' && subPayload >= 20) {
            final mvhdData = raf.readSync(min(subPayload, 32));
            if (mvhdData.length >= 20) {
              final mbd = ByteData.sublistView(mvhdData);
              final version = mbd.getUint8(0);
              int timescale = 0;
              int duration = 0;
              if (version == 0) {
                timescale = mbd.getUint32(12, Endian.big);
                duration = mbd.getUint32(16, Endian.big);
              } else if (version == 1 && mvhdData.length >= 32) {
                timescale = mbd.getUint32(20, Endian.big);
                duration = mbd.getUint64(24, Endian.big);
              }
              if (timescale > 0 && duration > 0) {
                seconds = duration / timescale;
              }
            }
            break;
          }

          final nextSub = subPos + subPayload;
          if (nextSub >= moovEnd || nextSub <= subPos) break;
          raf.setPositionSync(nextSub);
        }
        break;
      }

      final nextBox = pos - 8 + size;
      if (nextBox >= length || nextBox <= pos) break;
      raf.setPositionSync(nextBox);
    }

    if (seconds <= 0) return unknown;
    return AudioMetadata(
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      durationSec: seconds.round(),
      preciseDurationSec: seconds,
    );
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
