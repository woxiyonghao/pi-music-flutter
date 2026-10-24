import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/services/mseb_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tone = MsebService.instance;
  late HifiAudioService audio;
  late bool enabled;
  late List<double> sentBands;
  setUp(() {
    tone.resetAll();
    enabled = false;
    sentBands = [];
    audio = HifiAudioService.forTesting(
      prepareFile: (_) async {},
      openFile: (_, __, ___) => true,
      applyDsp: (active, bands) {
        enabled = active;
        sentBands = bands;
      },
    );
  });
  tearDown(() {
    audio.dispose();
    tone.resetAll();
  });

  test('tone controls reach engine DSP while the graphic EQ is disabled', () {
    tone.setParam(1, 10);
    expect(enabled, isTrue);
    expect(sentBands.first, greaterThan(0));
    expect(audio.eqEnabled, isFalse);
    expect(audio.eqBands, everyElement(0));
    tone.setEnabled(false);
    expect(enabled, isFalse);
    expect(sentBands, everyElement(0));
  });

  test(
      'tone overlay preserves and restores the users EQ and caps combined gain',
      () {
    audio.setEqAndBands(true, List.filled(10, 11));
    tone.setParam(1, 10);
    expect(sentBands.first, 12);
    expect(audio.eqBands, everyElement(11));
    tone.setEnabled(false);
    expect(enabled, isTrue);
    expect(sentBands, everyElement(11));
    tone.setEnabled(true);
    audio.resetEq();
    expect(enabled, isTrue);
    expect(sentBands.first, greaterThan(0));
    expect(audio.eqBands, everyElement(0));
    tone.resetAll();
    expect(enabled, isFalse);
    expect(sentBands, everyElement(0));
  });

  test('each tone control has an audible band response and reset bypasses it',
      () {
    for (var index = 0; index < 10; index++) {
      tone.setParam(index, 10);
      expect(enabled, isTrue);
      expect(sentBands.any((gain) => gain != 0), isTrue);
      tone.resetAll();
      expect(enabled, isFalse);
    }
  });
}
