import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/main.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/ui/ipad/ipad_main_view.dart';

void main() {
  testWidgets('slow initialization paints a startup screen before it completes',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => HifiAudioService.instance.stopTicker());
    final ready = Completer<void>();
    var servicesStarted = false;
    await tester.pumpWidget(HiFiPlayerStartup(
        initialize: () => ready.future, onReady: () => servicesStarted = true));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('正在启动播放器'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(IpadMainView), findsNothing);
    expect(servicesStarted, isFalse);
    ready.complete();
    await tester.pump();
    expect(find.byType(IpadMainView), findsOneWidget);
    expect(servicesStarted, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'initialization errors replace the loading screen with their cause',
      (tester) async {
    final ready = Completer<void>();
    await tester.pumpWidget(HiFiPlayerStartup(initialize: () => ready.future));
    ready.completeError(StateError('native audio initialization failed'));
    await tester.pump();
    expect(find.text('播放器启动失败'), findsOneWidget);
    expect(find.textContaining('native audio initialization failed'),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
