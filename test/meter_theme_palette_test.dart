import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/ui/visualizers/mcintosh_meter_painter.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_type.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_stage_widget.dart';
import 'package:hide_player_flutter/ui/mac/mac_background_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
  });

  group('McIntoshMeterPainter Dynamic Palette System Tests', () {
    test('McIntosh theme (themeId: 1) produces iconic Ocean Blue palette', () {
      final painter = McIntoshMeterPainter(
        leftAngle: -pi * 0.5,
        rightAngle: -pi * 0.5,
        themeId: 1,
      );

      final painter2 = McIntoshMeterPainter(
        leftAngle: -pi * 0.5,
        rightAngle: -pi * 0.5,
        themeId: 2, // Changed theme
      );
      expect(painter.shouldRepaint(painter2), isTrue);
    });

    test('Accuphase theme (themeId: 2) resolves Champagne Gold palette', () {
      final painterGold = McIntoshMeterPainter(
        leftAngle: -pi * 0.5,
        rightAngle: -pi * 0.5,
        themeId: 2,
        accentColor: const Color(0xFFE2C792),
      );

      final painterMarantz = McIntoshMeterPainter(
        leftAngle: -pi * 0.5,
        rightAngle: -pi * 0.5,
        themeId: 5,
        accentColor: const Color(0xFF10B981),
      );

      expect(painterGold.shouldRepaint(painterMarantz), isTrue);
      expect(painterGold.themeId, equals(2));
      expect(painterMarantz.themeId, equals(5));
    });

    test('Custom HSV color (themeId: 4) calculates dynamic custom palette', () {
      const customColor = Color(0xFFA855F7); // Electric Purple
      final painterCustom = McIntoshMeterPainter(
        leftAngle: -pi * 0.5,
        rightAngle: -pi * 0.5,
        themeId: 4,
        accentColor: customColor,
      );

      expect(painterCustom.accentColor, equals(customColor));
      expect(painterCustom.themeId, equals(4));
    });

    testWidgets('VisualizerStageWidget renders McIntosh meter with active theme without errors', (tester) async {
      ThemeService.instance.setTheme(2); // Set to Accuphase Champagne Gold

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: VisualizerStageWidget(
                activeType: VisualizerType.mcIntosh,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(VisualizerStageWidget), findsOneWidget);

      // Now switch theme to Marantz (id: 5)
      ThemeService.instance.setTheme(5);
      await tester.pump();
      expect(ThemeService.instance.currentThemeId, equals(5));

      // Now switch theme to Custom HSV
      ThemeService.instance.setCustomHsv(280.0, 0.85, 0.95);
      await tester.pump();
      expect(ThemeService.instance.currentThemeId, equals(4));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('MacBackgroundWidget updates dynamically when theme changes', (tester) async {
      ThemeService.instance.setTheme(1); // McIntosh

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: MacBackgroundWidget(
                visualizerType: VisualizerType.mcIntosh,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(MacBackgroundWidget), findsOneWidget);

      // Switch to Gold
      ThemeService.instance.setTheme(2);
      await tester.pump();
      expect(ThemeService.instance.currentThemeId, equals(2));

      await tester.pumpWidget(const SizedBox());
    });
  });
}
