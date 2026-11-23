import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/sidebar_tab.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/ui/mac/mac_main_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_theme_setting_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
  });

  testWidgets('Theme setting view scroll offset resets after fullscreen toggle', (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    MusicDatabaseService.instance.setSetting('active_sidebar_tab', SidebarTab.themeSettings.index.toString());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1024,
            height: 600,
            child: MacMainView(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final themeViewFinder = find.byType(MacThemeSettingView);
    expect(themeViewFinder, findsOneWidget);

    final scrollableFinder = find.descendant(
      of: themeViewFinder,
      matching: find.byType(Scrollable),
    ).first;

    // Scroll down 400px
    await tester.drag(scrollableFinder, const Offset(0, -400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final offsetBefore = tester.state<ScrollableState>(scrollableFinder).position.pixels;
    expect(offsetBefore, greaterThan(200));

    // Tap a visualizer mode card (e.g. mode 11 or another mode)
    final modeCard = find.text('48列全景 LED 频谱');
    expect(modeCard, findsOneWidget);
    await tester.tap(modeCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final offsetAfterTap = tester.state<ScrollableState>(scrollableFinder).position.pixels;
    expect(offsetAfterTap, equals(offsetBefore));

    // Tap fullscreen button in bottom bar
    final fullscreenBtn = find.byIcon(Icons.fullscreen_rounded);
    expect(fullscreenBtn, findsOneWidget);
    await tester.tap(fullscreenBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Moving pointer reveals floating overlay with exit button
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(500, 400));
    await tester.pump();
    await gesture.moveTo(const Offset(520, 420));
    await tester.pump(const Duration(milliseconds: 100));

    // Exit fullscreen via exit button
    final exitBtn = find.byIcon(Icons.fullscreen_exit_rounded);
    expect(exitBtn, findsOneWidget);
    await tester.tap(exitBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final scrollableAfter = find.descendant(
      of: find.byType(MacThemeSettingView),
      matching: find.byType(Scrollable),
    ).first;
    final offsetAfter = tester.state<ScrollableState>(scrollableAfter).position.pixels;

    expect(offsetAfter, equals(offsetBefore));

    await tester.pumpWidget(const SizedBox());
  });
}
