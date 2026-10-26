import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/services/mseb_service.dart';

void main() {
  group('MsebService Tonal Curves and Offsets', () {
    test('Zero values produce all-zero EQ band offsets', () {
      final offsets = MsebService.bandOffsetsFromValues(List.filled(10, 0.0));
      expect(offsets, equals(List.filled(10, 0.0)));
    });

    test('Bass Extension (低音下潜) at +10 produces strong sub-bass boost', () {
      final values = List.filled(10, 0.0);
      values[1] = 10.0; // Bass Extension
      final offsets = MsebService.bandOffsetsFromValues(values);

      // 31.25 Hz should have +9.5 dB
      expect(offsets[0], closeTo(9.5, 0.01));
      // 62.5 Hz should have +7.5 dB
      expect(offsets[1], closeTo(7.5, 0.01));
      // 125 Hz should have +3.5 dB
      expect(offsets[2], closeTo(3.5, 0.01));
      // High bands remain unchanged
      expect(offsets[4], equals(0.0));
      expect(offsets[9], equals(0.0));
    });

    test('Bass Texture (低音质感) at +10 produces punchy mid-bass boost', () {
      final values = List.filled(10, 0.0);
      values[2] = 10.0; // Bass Texture
      final offsets = MsebService.bandOffsetsFromValues(values);

      // 125 Hz should have +8.5 dB
      expect(offsets[2], closeTo(8.5, 0.01));
      // 62.5 Hz should have +5.5 dB
      expect(offsets[1], closeTo(5.5, 0.01));
      // 250 Hz should have +5.0 dB
      expect(offsets[3], closeTo(5.0, 0.01));
      // High bands remain unchanged
      expect(offsets[6], equals(0.0));
      expect(offsets[9], equals(0.0));
    });

    test('Negative values clamp within graphic EQ limits [-12, 12]', () {
      final values = List.filled(10, -10.0);
      final offsets = MsebService.bandOffsetsFromValues(values);

      for (final gain in offsets) {
        expect(gain, greaterThanOrEqualTo(-12.0));
        expect(gain, lessThanOrEqualTo(12.0));
      }
    });

    test('Non-finite inputs fall back safely without throwing', () {
      final values = [double.nan, double.infinity, -double.infinity, 0.0];
      final offsets = MsebService.bandOffsetsFromValues(values);
      expect(offsets.length, equals(10));
      for (final gain in offsets) {
        expect(gain.isFinite, isTrue);
      }
    });
  });
}
