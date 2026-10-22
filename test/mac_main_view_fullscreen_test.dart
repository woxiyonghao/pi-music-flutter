import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_type.dart';
import 'package:hide_player_flutter/ui/mac/mac_main_view.dart';
import 'package:hide_player_flutter/ui/mac/mac_background_widget.dart';
import 'package:hide_player_flutter/ui/mac/mac_sidebar_widget.dart';
import 'package:hide_player_flutter/ui/mac/mac_bottom_bar_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
  });

  group('MacMainView Idle Fullscreen Immersive Mode Tests', () {
    testWidgets('MacMainView renders all 4 corner components and background', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 800,
              child: MacMainView(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MacBackgroundWidget), findsOneWidget);
      expect(find.byType(MacSidebarWidget), findsOneWidget);
      expect(find.byType(MacBottomBarWidget), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Double-tap or fullscreen button triggers smooth transition', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 800,
              child: MacMainView(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the fullscreen button in the bottom bar
      final fullscreenBtn = find.byIcon(Icons.fullscreen_rounded);
      expect(fullscreenBtn, findsOneWidget);

      // Tap fullscreen button to enter fullscreen
      await tester.tap(fullscreenBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // Animated transform is in progress
      expect(find.byType(MacMainView), findsOneWidget);

      // Complete the 400ms animation
      await tester.pump(const Duration(milliseconds: 250));

      // Fullscreen must keep the theme-page selection and offer no override.
      final background = tester.widget<MacBackgroundWidget>(
          find.byType(MacBackgroundWidget));
      expect(background.visualizerType,
          VisualizerType.values[ThemeService.instance.backgroundVisualMode]);
      expect(find.byType(DropdownButton<VisualizerType>), findsNothing);
      expect(find.byTooltip('退出全屏'), findsOneWidget);

      // Trigger user activity by moving pointer
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(500, 400));
      await tester.pump();
      await gesture.moveTo(const Offset(520, 420));
      await tester.pump(const Duration(milliseconds: 100));

      // Reverse animation completes
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MacSidebarWidget), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
