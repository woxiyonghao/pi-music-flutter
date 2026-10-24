import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/models/playback_state.dart';

void main() {
  Track track(
          {AudioFormat format = AudioFormat.wav,
          int rate = 0,
          int depth = 0}) =>
      Track(
        title: '',
        artist: '',
        album: '',
        filepath: '/test',
        format: format,
        sampleRate: rate,
        bitDepth: depth,
        durationSec: 0,
      );
  test(
      'unknown metadata does not invent sample rate, bit depth, or DSD multiple',
      () {
    expect(track().formatBadge, 'WAV');
    expect(track(format: AudioFormat.dsdDsf).formatBadge, 'DSD · 采样率未知');
    expect(track(rate: 44100).formatBadge, '44.1kHz');
    expect(track(rate: 44100, depth: 16).formatBadge, '44.1kHz / 16bit');
  });
  test('idle player has no invented hardware format or bit-perfect status', () {
    const state = PlaybackState();
    expect(state.activeDeviceName, isEmpty);
    expect(state.activeSampleRate, 0);
    expect(state.isBitPerfect, isFalse);
  });
}
