import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_equalizer_view.dart';

void main() {
  testWidgets('Flutter EQ presets, bypass and remote changes update the actual audio service', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = HifiAudioService.instance;
    audio.resetEq();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MacEqualizerView())));
    await tester.tap(find.text('震撼低音'));
    await tester.pumpAndSettle();
    expect(audio.eqEnabled, isTrue);
    expect(audio.eqBands.take(3), [6.0, 5.0, 3.5]);
    await tester.tap(find.text('EQ 已激活'));
    await tester.pumpAndSettle();
    expect(audio.eqEnabled, isFalse);
    expect(find.text('EQ 已旁路'), findsOneWidget);
    audio.setEqEnabled(true);
    await tester.pumpAndSettle();
    expect(find.text('EQ 已激活'), findsOneWidget);
    await tester.tap(find.text('复原'));
    await tester.pumpAndSettle();
    expect(audio.eqBands, List<double>.filled(10, 0));
    expect(audio.eqEnabled, isFalse);
  });
}
