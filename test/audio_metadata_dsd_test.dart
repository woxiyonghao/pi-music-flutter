import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/audio_metadata_helper.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dsd_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DSD and Hi-Res Audio Metadata Parsing', () {
    test('parses standard DSF file with fmt chunk', () {
      final file = File('${tempDir.path}/sample.dsf');
      final builder = BytesBuilder();

      // DSD header: 28 bytes
      builder.add([0x44, 0x53, 0x44, 0x20]); // 'DSD '
      final bdHeader = ByteData(24);
      bdHeader.setUint64(0, 28, Endian.little); // chunk size
      bdHeader.setUint64(8, 28 + 52 + 12 + 1000, Endian.little); // total size
      bdHeader.setUint64(16, 0, Endian.little); // metadata offset
      builder.add(bdHeader.buffer.asUint8List());

      // fmt chunk: 52 bytes (12 header + 40 payload)
      builder.add([0x66, 0x6D, 0x74, 0x20]); // 'fmt '
      final bdFmtHdr = ByteData(8);
      bdFmtHdr.setUint64(0, 52, Endian.little); // chunk size
      builder.add(bdFmtHdr.buffer.asUint8List());

      final bdFmtPayload = ByteData(40);
      bdFmtPayload.setUint32(0, 1, Endian.little); // format version
      bdFmtPayload.setUint32(4, 0, Endian.little); // format id
      bdFmtPayload.setUint32(8, 2, Endian.little); // channel type (stereo)
      bdFmtPayload.setUint32(12, 2, Endian.little); // channel num
      bdFmtPayload.setUint32(16, 2822400, Endian.little); // 2.8224 MHz (DSD64)
      bdFmtPayload.setUint32(20, 1, Endian.little); // bits per sample
      bdFmtPayload.setUint64(24, 2822400 * 120, Endian.little); // 120 seconds
      bdFmtPayload.setUint32(32, 4096, Endian.little); // block size
      bdFmtPayload.setUint32(36, 0, Endian.little); // reserved
      builder.add(bdFmtPayload.buffer.asUint8List());

      // data chunk: 12 bytes header
      builder.add([0x64, 0x61, 0x74, 0x61]); // 'data'
      final bdDataHdr = ByteData(8);
      bdDataHdr.setUint64(0, 12 + 1000, Endian.little);
      builder.add(bdDataHdr.buffer.asUint8List());

      file.writeAsBytesSync(builder.toBytes());

      final meta = AudioMetadataHelper.parse(file, AudioFormat.dsdDsf);
      expect(meta.sampleRate, 2822400);
      expect(meta.bitDepth, 1);
      expect(meta.durationSec, 120);
      expect(meta.durationSeconds, closeTo(120.0, 0.01));
    });

    test('parses DSF with prepended ID3v2 tag and data chunk duration fallback', () {
      final file = File('${tempDir.path}/tagged_fallback.dsf');
      final builder = BytesBuilder();

      // ID3v2 tag: 10 byte header + 14 bytes payload = 24 bytes total
      builder.add([
        0x49, 0x44, 0x33, 0x03, 0x00, 0x00, // ID3v2.3
        0x00, 0x00, 0x00, 0x0E, // tagSize = 14 syncsafe
        ...List.filled(14, 0), // dummy ID3 payload
      ]);

      // DSD header: 28 bytes
      builder.add([0x44, 0x53, 0x44, 0x20]); // 'DSD '
      final bdHeader = ByteData(24);
      bdHeader.setUint64(0, 28, Endian.little);
      bdHeader.setUint64(8, 28 + 52 + 12 + 42336000, Endian.little);
      bdHeader.setUint64(16, 0, Endian.little);
      builder.add(bdHeader.buffer.asUint8List());

      // fmt chunk: sample_count is 0
      builder.add([0x66, 0x6D, 0x74, 0x20]); // 'fmt '
      final bdFmtHdr = ByteData(8);
      bdFmtHdr.setUint64(0, 52, Endian.little);
      builder.add(bdFmtHdr.buffer.asUint8List());

      final bdFmtPayload = ByteData(40);
      bdFmtPayload.setUint32(0, 1, Endian.little);
      bdFmtPayload.setUint32(4, 0, Endian.little);
      bdFmtPayload.setUint32(8, 2, Endian.little);
      bdFmtPayload.setUint32(12, 2, Endian.little); // 2 channels
      bdFmtPayload.setUint32(16, 2822400, Endian.little); // 2.8224 MHz
      bdFmtPayload.setUint32(20, 1, Endian.little);
      bdFmtPayload.setUint64(24, 0, Endian.little); // 0 sample count!
      bdFmtPayload.setUint32(32, 4096, Endian.little);
      bdFmtPayload.setUint32(36, 0, Endian.little);
      builder.add(bdFmtPayload.buffer.asUint8List());

      // data chunk: 2 channels * (2822400 / 8) bytes/sec * 60 sec = 42336000 bytes
      builder.add([0x64, 0x61, 0x74, 0x61]); // 'data'
      final bdDataHdr = ByteData(8);
      bdDataHdr.setUint64(0, 12 + 42336000, Endian.little);
      builder.add(bdDataHdr.buffer.asUint8List());

      file.writeAsBytesSync(builder.toBytes());

      final meta = AudioMetadataHelper.parse(file, AudioFormat.dsdDsf);
      expect(meta.sampleRate, 2822400);
      expect(meta.bitDepth, 1);
      expect(meta.durationSec, 60);
    });

    test('parses DFF (DSDIFF) file', () {
      final file = File('${tempDir.path}/track.dff');
      final builder = BytesBuilder();

      // PROP chunk payload:
      final propBuilder = BytesBuilder();
      propBuilder.add([0x53, 0x4E, 0x44, 0x20]); // 'SND '

      // FS chunk: 4 byte header + 8 byte size + 4 byte rate
      propBuilder.add([0x46, 0x53, 0x20, 0x20]); // 'FS  '
      final bdFsHdr = ByteData(8)..setUint64(0, 4, Endian.big);
      propBuilder.add(bdFsHdr.buffer.asUint8List());
      final bdFs = ByteData(4)..setUint32(0, 5644800, Endian.big); // DSD128 (5.6448 MHz)
      propBuilder.add(bdFs.buffer.asUint8List());

      // CHNL chunk: 4 byte header + 8 byte size + 2 byte count
      propBuilder.add([0x43, 0x48, 0x4E, 0x4C]); // 'CHNL'
      final bdChnlHdr = ByteData(8)..setUint64(0, 2, Endian.big);
      propBuilder.add(bdChnlHdr.buffer.asUint8List());
      final bdChnl = ByteData(2)..setUint16(0, 2, Endian.big); // 2 channels
      propBuilder.add(bdChnl.buffer.asUint8List());

      final propPayload = propBuilder.toBytes();

      // DSD sound data chunk: 2 channels * (5644800 / 8) bytes/sec * 90 sec = 127008000 bytes
      const dataSize = 127008000;

      // FRM8 body: 4 bytes 'DSD ' + PROP chunk + DSD chunk
      final bodyBuilder = BytesBuilder();
      bodyBuilder.add([0x44, 0x53, 0x44, 0x20]); // 'DSD '
      bodyBuilder.add([0x50, 0x52, 0x4F, 0x50]); // 'PROP'
      final bdPropHdr = ByteData(8)..setUint64(0, propPayload.length, Endian.big);
      bodyBuilder.add(bdPropHdr.buffer.asUint8List());
      bodyBuilder.add(propPayload);
      if (propPayload.length & 1 != 0) bodyBuilder.add([0]); // pad

      bodyBuilder.add([0x44, 0x53, 0x44, 0x20]); // 'DSD '
      final bdDataHdr = ByteData(8)..setUint64(0, dataSize, Endian.big);
      bodyBuilder.add(bdDataHdr.buffer.asUint8List());

      final body = bodyBuilder.toBytes();

      // Header: FRM8 + formSize + body
      builder.add([0x46, 0x52, 0x4D, 0x38]); // 'FRM8'
      final bdFormSize = ByteData(8)..setUint64(0, body.length, Endian.big);
      builder.add(bdFormSize.buffer.asUint8List());
      builder.add(body);

      file.writeAsBytesSync(builder.toBytes());

      final meta = AudioMetadataHelper.parse(file, AudioFormat.dsdDff);
      expect(meta.sampleRate, 5644800);
      expect(meta.bitDepth, 1);
      expect(meta.durationSec, 90);
    });

    test('parses AIFF file with COMM chunk', () {
      final file = File('${tempDir.path}/track.aiff');
      final builder = BytesBuilder();

      // FORM chunk header
      builder.add([0x46, 0x4F, 0x52, 0x4D]); // 'FORM'
      final bdFormSize = ByteData(4)..setUint32(0, 4 + 8 + 18, Endian.big);
      builder.add(bdFormSize.buffer.asUint8List());
      builder.add([0x41, 0x49, 0x46, 0x46]); // 'AIFF'

      // COMM chunk:
      builder.add([0x43, 0x4F, 0x4D, 0x4D]); // 'COMM'
      final bdCommSize = ByteData(4)..setUint32(0, 18, Endian.big);
      builder.add(bdCommSize.buffer.asUint8List());

      final bdCommPayload = ByteData(18);
      bdCommPayload.setUint16(0, 2, Endian.big); // 2 channels
      bdCommPayload.setUint32(2, 44100 * 75, Endian.big); // 75 seconds
      bdCommPayload.setUint16(6, 24, Endian.big); // 24-bit
      // 44100.0 in 80-bit IEEE 754:
      // Exponent: 16383 + 15 = 16398 = 0x400E
      // Mantissa: 44100 / 32768 = 1.3458251953125 * 2^63 = 0xAC440000 0x00000000
      bdCommPayload.setUint16(8, 0x400E, Endian.big);
      bdCommPayload.setUint32(10, 0xAC440000, Endian.big);
      bdCommPayload.setUint32(14, 0x00000000, Endian.big);
      builder.add(bdCommPayload.buffer.asUint8List());

      file.writeAsBytesSync(builder.toBytes());

      final meta = AudioMetadataHelper.parse(file, AudioFormat.alac);
      expect(meta.sampleRate, 44100);
      expect(meta.bitDepth, 24);
      expect(meta.durationSec, 75);
    });

    test('parses M4A / MP4 with moov -> mvhd atom', () {
      final file = File('${tempDir.path}/track.m4a');
      final builder = BytesBuilder();

      // ftyp box: 20 bytes
      final bdFtyp = ByteData(20);
      bdFtyp.setUint32(0, 20, Endian.big);
      builder.add(bdFtyp.buffer.asUint8List()..setRange(4, 8, [0x66, 0x74, 0x79, 0x70])); // 'ftyp'

      // mvhd payload: version 0 -> 4 bytes hdr + 8 bytes times + 4 bytes timescale + 4 bytes duration
      final mvhdPayload = ByteData(24);
      mvhdPayload.setUint8(0, 0); // version 0
      mvhdPayload.setUint32(12, 1000, Endian.big); // timescale = 1000 Hz
      mvhdPayload.setUint32(16, 185000, Endian.big); // duration = 185000 -> 185.0s

      // mvhd box: 8 byte header + 24 byte payload = 32 bytes
      final mvhdBuilder = BytesBuilder();
      final bdMvhdHdr = ByteData(8)..setUint32(0, 32, Endian.big);
      mvhdBuilder.add(bdMvhdHdr.buffer.asUint8List()..setRange(4, 8, [0x6D, 0x76, 0x68, 0x64])); // 'mvhd'
      mvhdBuilder.add(mvhdPayload.buffer.asUint8List());

      final mvhdBytes = mvhdBuilder.toBytes();

      // moov box: 8 byte header + mvhdBytes = 40 bytes
      final bdMoovHdr = ByteData(8)..setUint32(0, 8 + mvhdBytes.length, Endian.big);
      builder.add(bdMoovHdr.buffer.asUint8List()..setRange(4, 8, [0x6D, 0x6F, 0x6F, 0x76])); // 'moov'
      builder.add(mvhdBytes);

      file.writeAsBytesSync(builder.toBytes());

      final meta = AudioMetadataHelper.parse(file, AudioFormat.alac);
      expect(meta.durationSec, 185);
      expect(meta.durationSeconds, closeTo(185.0, 0.01));
    });
  });
}
