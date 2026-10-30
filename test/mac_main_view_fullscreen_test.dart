import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/ui/mac/mac_main_view.dart';
import 'package:hide_player_flutter/ui/mac/mac_background_widget.dart';
import 'package:hide_player_flutter/ui/mac/mac_sidebar_widget.dart';
import 'package:hide_player_flutter/ui/mac/mac_bottom_bar_widget.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_all_music_view.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_type.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_stage_widget.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_system_settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
  });

  group('MacMainView Idle Fullscreen Immersive Mode Tests', () {
    testWidgets('Sidebar scroll offset is preserved after entering and exiting fullscreen', (tester) async {
      tester.view.physicalSize = const Size(1024, 500); // Shorter height so sidebar scrolls
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1024,
              height: 500,
              child: MacMainView(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final sidebarFinder = find.byType(MacSidebarWidget);
      expect(sidebarFinder, findsOneWidget);

      final scrollableInSidebar = find.descendant(
        of: sidebarFinder,
        matching: find.byType(Scrollable),
      );
      expect(scrollableInSidebar, findsOneWidget);

      // Scroll sidebar down
      await tester.drag(scrollableInSidebar, const Offset(0, -150));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final scrollOffsetBefore = tester.state<ScrollableState>(scrollableInSidebar).position.pixels;
      expect(scrollOffsetBefore, greaterThan(50));

      // Enter fullscreen
      final fullscreenBtn = find.byIcon(Icons.fullscreen_rounded);
      expect(fullscreenBtn, findsOneWidget);
      await tester.tap(fullscreenBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Exit fullscreen
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(500, 400));
      await tester.pump();
      await gesture.moveTo(const Offset(520, 420));
      await tester.pump(const Duration(milliseconds: 100));

      final exitBtn = find.byIcon(Icons.fullscreen_exit_rounded);
      expect(exitBtn, findsOneWidget);
      await tester.tap(exitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify sidebar scroll offset after exiting fullscreen
      final scrollableAfter = find.descendant(
        of: find.byType(MacSidebarWidget),
        matching: find.byType(Scrollable),
      );
      expect(scrollableAfter, findsOneWidget);
      final scrollOffsetAfter = tester.state<ScrollableState>(scrollableAfter).position.pixels;
      expect(scrollOffsetAfter, equals(scrollOffsetBefore));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Scroll offset is preserved after entering and exiting fullscreen', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dummyTracks = List.generate(
        60,
        (i) => Track(
          id: i + 1,
          title: 'Track ${i + 1}',
          artist: 'Artist ${i % 5}',
          album: 'Album ${i % 3}',
          filepath: '/music/track_${i + 1}.flac',
          format: AudioFormat.flac,
          sampleRate: 44100,
          bitDepth: 16,
          durationSec: 180,
        ),
      );
      MusicDatabaseService.instance.setTracksForTesting(dummyTracks);

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
      await tester.pump(const Duration(milliseconds: 100));

      final allMusicFinder = find.byType(MacAllMusicView);
      expect(allMusicFinder, findsOneWidget);

      final scrollableInAllMusic = find.descendant(
        of: allMusicFinder,
        matching: find.byType(Scrollable),
      );
      expect(scrollableInAllMusic, findsOneWidget);

      // Scroll down by 400 pixels
      await tester.drag(scrollableInAllMusic, const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final scrollOffsetBefore = tester.state<ScrollableState>(scrollableInAllMusic).position.pixels;
      expect(scrollOffsetBefore, greaterThan(200));

      // Enter fullscreen
      final fullscreenBtn = find.byIcon(Icons.fullscreen_rounded);
      expect(fullscreenBtn, findsOneWidget);
      await tester.tap(fullscreenBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Simulate PiSystemService or ThemeService or MusicDatabaseService notifying while in fullscreen
      ThemeService.instance.notifyListeners();
      await tester.pump(const Duration(milliseconds: 100));

      // Moving pointer reveals floating overlay with exit button
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(500, 400));
      await tester.pump();
      await gesture.moveTo(const Offset(520, 420));
      await tester.pump(const Duration(milliseconds: 100));

      // In fullscreen, find exit button
      final exitBtn = find.byIcon(Icons.fullscreen_exit_rounded);
      expect(exitBtn, findsOneWidget);

      // Exit fullscreen
      await tester.tap(exitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Check scroll offset after exiting fullscreen
      final scrollableAfter = find.descendant(
        of: find.byType(MacAllMusicView),
        matching: find.byType(Scrollable),
      );
      expect(scrollableAfter, findsOneWidget);
      final scrollOffsetAfter = tester.state<ScrollableState>(scrollableAfter).position.pixels;
      expect(scrollOffsetAfter, equals(scrollOffsetBefore));

      await tester.pumpWidget(const SizedBox());
    });
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

      // Moving pointer reveals bottom right floating overlay with exit button
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(500, 400));
      await tester.pump();
      await gesture.moveTo(const Offset(520, 420));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap exit fullscreen button
      final exitBtn = find.byIcon(Icons.fullscreen_exit_rounded);
      expect(exitBtn, findsOneWidget);
      await tester.tap(exitBtn);
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.byType(MacSidebarWidget), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('MacBackgroundWidget renders VisualizerStageWidget in non-fullscreen for hardware meters', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1024,
              height: 600,
              child: MacBackgroundWidget(
                visualizerType: VisualizerType.mcIntosh,
                fullscreenProgress: 0.0,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VisualizerStageWidget), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Manual fullscreen follows activeVisualizer instead of screensaver theme', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ThemeService.instance.setBackgroundVisualMode(VisualizerType.mcIntosh.index);
      MusicDatabaseService.instance.setSetting('setting_idle_screensaver_theme', '3'); // tapeReel

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

      final bg = tester.widget<MacBackgroundWidget>(find.byType(MacBackgroundWidget));
      expect(bg.visualizerType, equals(VisualizerType.mcIntosh));

      // Enter manual fullscreen
      final fullscreenBtn = find.byIcon(Icons.fullscreen_rounded);
      await tester.tap(fullscreenBtn);
      await tester.pump(const Duration(milliseconds: 450));

      final bgFullscreen = tester.widget<MacBackgroundWidget>(find.byType(MacBackgroundWidget));
      expect(bgFullscreen.visualizerType, equals(VisualizerType.mcIntosh));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('SystemSettingsView displays all settings rows horizontally without vertical column wrap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1024,
              height: 600,
              child: MacSystemSettingsView(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('空余时间显示全屏'), findsOneWidget);
      // Verify no Wrap widgets are used inside button group rows
      expect(find.byType(Wrap), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
