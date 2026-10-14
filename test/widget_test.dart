import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/main.dart';

void main() {
  testWidgets('HiFi Player App smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 750);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const HiFiPlayerApp());
    expect(find.byType(HiFiPlayerApp), findsOneWidget);

    // Cancel pending timer to satisfy test invariant
    HifiAudioService.instance.dispose();
  });
}
