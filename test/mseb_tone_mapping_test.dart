import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/services/mseb_service.dart';

void main() {
  test('neutral tone parameters do not alter the source response', () {
    expect(MsebService.bandOffsetsFromValues(List.filled(10, 0)),
        List.filled(10, 0));
  });

  test('each tone control has an audible band mapping and reversible polarity',
      () {
    for (var parameter = 0; parameter < 10; parameter++) {
      final values = List<double>.filled(10, 0)..[parameter] = 10;
      final positive = MsebService.bandOffsetsFromValues(values);
      values[parameter] = -10;
      final negative = MsebService.bandOffsetsFromValues(values);
      expect(positive.any((band) => band.abs() >= 1), isTrue,
          reason: 'Parameter $parameter must alter DSP bands');
      for (var band = 0; band < 10; band++) {
        expect(negative[band], closeTo(-positive[band], 0.000001));
      }
    }
  });

  test('warmth increases low bands while air increases the top octave', () {
    final warm = MsebService.bandOffsetsFromValues([10]);
    expect(warm.first, greaterThan(0));
    expect(warm.last, lessThan(0));
    final values = List<double>.filled(10, 0)..[8] = 10;
    final air = MsebService.bandOffsetsFromValues(values);
    expect(air.last, greaterThan(air.first));
  });

  test('extreme and invalid remote values produce bounded finite DSP bands',
      () {
    for (final values in [
      List<double>.filled(10, 100000),
      List<double>.filled(10, -100000),
      [double.nan, double.infinity, double.negativeInfinity],
    ]) {
      for (final band in MsebService.bandOffsetsFromValues(values)) {
        expect(band.isFinite, isTrue);
        expect(band, inInclusiveRange(-12, 12));
      }
    }
  });
}
