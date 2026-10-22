import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/cue_parser.dart';
import 'package:hide_player_flutter/services/audio_metadata_helper.dart';

void main() {
  test('parse real CDImage.cue and CDImage.wav', () {
    final cueFile = File('/Users/mk10/Downloads/music/阿强 此情可待[WAV+CUE]/CDImage.cue');
    if (!cueFile.existsSync()) return;

    final sheet = CueSheetParser.parse(cueFile);
    expect(sheet, isNotNull);
    expect(sheet!.albumPerformer, '阿强');
    expect(sheet.albumTitle, '此情可待 DSD');
    expect(sheet.tracks.length, greaterThanOrEqualTo(10));

    final trk1 = sheet.tracks[0];
    expect(trk1.trackNumber, 1);
    expect(trk1.title, '此情可待');
    expect(trk1.performer, '阿强');
    expect(trk1.startTimeSec, 0.0);
    expect(trk1.endTimeSec, greaterThan(200.0));
    expect(trk1.resolvedAudioPath.endsWith('CDImage.wav'), isTrue);

    final wavFile = File(trk1.resolvedAudioPath);
    expect(wavFile.existsSync(), isTrue);

    final meta = AudioMetadataHelper.parse(wavFile, AudioFormat.wav);
    expect(meta.sampleRate, 44100);
    expect(meta.bitDepth, 16);
    expect(meta.durationSec, greaterThan(3000)); // ~3500 seconds

    print('Track 1: ${trk1.title} by ${trk1.performer}');
    print('  Start: ${trk1.startTimeSec}s, End: ${trk1.endTimeSec}s, Dur: ${trk1.durationSec}s');
    print('  Resolved Audio: ${trk1.resolvedAudioPath}');
    print('  Audio Meta: ${meta.sampleRate}Hz, ${meta.bitDepth}bit, total ${meta.durationSec}s');

    final lastTrk = sheet.tracks.last;
    print('Last Track: ${lastTrk.title}, Start: ${lastTrk.startTimeSec}s, End: ${lastTrk.endTimeSec}s');
  });
}
