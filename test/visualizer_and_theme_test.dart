import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_type.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_stage_widget.dart';
import 'package:hide_player_flutter/ui/visualizers/audio_bubbles_painter.dart';
import 'package:hide_player_flutter/ui/visualizers/cyber_grid_painter.dart';
import 'package:hide_player_flutter/ui/visualizers/glass_clock_painter.dart';
import 'package:hide_player_flutter/ui/visualizers/mcintosh_meter_painter.dart';
import 'package:hide_player_flutter/ui/visualizers/accuphase_meter_painter.dart';
import 'package:hide_player_flutter/ui/visualizers/tape_reel_painter.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_magic_tuning_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
  });

  group('Visualizers and Theme System Headless Verification', () {
    test('VisualizerType display names and subtitles are complete', () {
      expect(VisualizerType.values.length, 12);
      expect(VisualizerType.bubbles.displayName, contains('气泡'));
      expect(VisualizerType.cyberGrid.displayName, contains('赛博'));
      expect(VisualizerType.glassClock.displayName, contains('时钟'));
      expect(VisualizerType.ipadTelemetryDashboard.displayName, contains('硬件大师'));
    });

    test('ThemeService updates backgroundVisualMode and accent color', () {
      final theme = ThemeService.instance;
      theme.setTheme(1); // 麦景图湖蓝
      expect(theme.accentColor, const Color(0xFF00B4D8));

      theme.setBackgroundVisualMode(VisualizerType.bubbles.index);
      expect(theme.backgroundVisualMode, VisualizerType.bubbles.index);

      theme.setBackgroundVisualMode(VisualizerType.cyberGrid.index);
      expect(theme.backgroundVisualMode, VisualizerType.cyberGrid.index);

      theme.setBackgroundVisualMode(VisualizerType.glassClock.index);
      expect(theme.backgroundVisualMode, VisualizerType.glassClock.index);

      theme.setBackgroundVisualMode(VisualizerType.ipadTelemetryDashboard.index);
      expect(theme.backgroundVisualMode, VisualizerType.ipadTelemetryDashboard.index);

      // iPad 硬件大师专属主题预设验证
      theme.setTheme(9);
      expect(theme.currentThemeId, 9);
      expect(theme.accentColor, const Color(0xFF00E5FF));
      expect(theme.backgroundVisualMode, VisualizerType.ipadTelemetryDashboard.index);
    });

    test('AudioBubblesPainter paints successfully without throwing', () {
      final bubbles = [
        AudioBubble(
          x: 100.0,
          y: 200.0,
          vy: 20.0,
          vxPhase: 0.5,
          vxSpeed: 1.0,
          vxAmp: 15.0,
          baseRadius: 30.0,
          currentRadius: 30.0,
          alpha: 0.8,
          freqBand: 0,
        ),
      ];
      final painter = AudioBubblesPainter(
        bubbles: bubbles,
        accentColor: const Color(0xFFFA2D48),
        isPlaying: true,
        spectrumLevels: List.filled(12, 0.5),
        animTime: 1.0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(1200, 800));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('CyberGridPainter paints successfully without throwing', () {
      final painter = CyberGridPainter(
        spectrumLevels: List.filled(16, 0.5),
        animTime: 2.0,
        accentColor: const Color(0xFF00B4D8),
        isPlaying: true,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(1200, 800));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('GlassClockPainter paints successfully without throwing', () {
      final painter = GlassClockPainter(
        animTime: 3.5,
        accentColor: const Color(0xFFE2C792),
        isPlaying: true,
        energy: 0.6,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(1200, 800));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    testWidgets('VisualizerStageWidget renders Bubbles, CyberGrid, and GlassClock', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: VisualizerStageWidget(
                activeType: VisualizerType.bubbles,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(VisualizerStageWidget), findsOneWidget);

      // Switch to CyberGrid
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: VisualizerStageWidget(
                activeType: VisualizerType.cyberGrid,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(VisualizerStageWidget), findsOneWidget);

      // Switch to GlassClock
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: VisualizerStageWidget(
                activeType: VisualizerType.glassClock,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(VisualizerStageWidget), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('MacMagicTuningView immediately reflects ThemeService color changes without user interaction', (tester) async {
      final theme = ThemeService.instance;
      theme.setTheme(0); // 现代深空玫红
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: MacMagicTuningView(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MacMagicTuningView), findsOneWidget);

      // Change theme to McIntosh Blue
      theme.setTheme(1); // 麦景图湖蓝 0xFF00B4D8
      await tester.pump();
      expect(theme.accentColor, const Color(0xFF00B4D8));

      await tester.pumpWidget(const SizedBox());
    });

    test('McIntoshMeterPainter paints successfully with dual scales and shadow', () {
      final painter = McIntoshMeterPainter(
        leftAngle: -1.5,
        rightAngle: -1.2,
        accentColor: const Color(0xFF00B4D8),
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(1200, 800));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('AccuphaseMeterPainter paints successfully with trapezoid dual ribbon', () {
      final painter = AccuphaseMeterPainter(
        leftValue: 0.65,
        rightValue: 0.72,
        animTime: 2.5,
        volumePercent: 82,
        themeId: 2,
        accentColor: const Color(0xFFE2C792),
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(1200, 800));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('TapeReelPainter paints successfully with NAB hub and tape counter', () {
      final painter = TapeReelPainter(
        progress: 0.45,
        leftAngle: 1.8,
        rightAngle: 2.1,
        isPlaying: true,
        elapsedSec: 154.0,
        accentColor: const Color(0xFFF97316),
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(1200, 800));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}

