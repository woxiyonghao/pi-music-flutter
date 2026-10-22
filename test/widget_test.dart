import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/main.dart';

void main() {
  testWidgets('Startup failure shows the cause without starting player views',
      (WidgetTester tester) async {
    const error = 'No compatible audio_engine library found. Expected ABI 2';
    await tester.pumpWidget(const HiFiPlayerApp(startupError: error));

    expect(find.text('播放器启动失败'), findsOneWidget);
    expect(find.text(error), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HiFi Player App smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 750);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const HiFiPlayerApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(HiFiPlayerApp), findsOneWidget);

    HifiAudioService.instance.dispose();
  });
}
