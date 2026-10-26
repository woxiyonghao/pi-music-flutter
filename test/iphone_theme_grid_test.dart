import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/models/sidebar_tab.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/ui/iphone/iphone_landscape_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_theme_setting_view.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final theme = ThemeService.instance;

  setUp(() {
    HifiAudioService.instance.stopTicker();
    theme.resetToDefault();
  });

  Future<void> size(WidgetTester tester, Size value) async {
    tester.view.physicalSize = value;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final dimensions in [
    const Size(667, 375),
    const Size(844, 390),
    const Size(932, 430)
  ]) {
    testWidgets(
        'iPhone landscape presets stay in two readable columns at $dimensions with camera-cutout safe areas',
        (tester) async {
      await size(tester, dimensions);
      MusicDatabaseService.instance.setSetting(
          'active_sidebar_tab', '${SidebarTab.themeSettings.index}');
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
              size: dimensions,
              padding: const EdgeInsets.fromLTRB(62, 0, 62, 21)),
          child: const IphoneLandscapeView(),
        ),
      ));
      await tester.pump();
      final first =
          tester.getRect(find.byKey(const ValueKey('theme-preset-0')));
      final second =
          tester.getRect(find.byKey(const ValueKey('theme-preset-1')));
      final third =
          tester.getRect(find.byKey(const ValueKey('theme-preset-2')));
      expect(second.top, closeTo(first.top, 1));
      expect(second.left, greaterThan(first.right));
      expect(second.width, closeTo(first.width, 1));
      expect(third.top, greaterThan(first.bottom));
      expect(second.right, lessThanOrEqualTo(dimensions.width - 62));
      for (final preset in ThemeService.presets) {
        final card = find.byKey(ValueKey('theme-preset-${preset.id}'),
            skipOffstage: false);
        await tester.ensureVisible(card);
        await tester.pump();
        final name = tester.renderObject<RenderParagraph>(find.descendant(
            of: card,
            matching: find.text(preset.name, skipOffstage: false),
            skipOffstage: false));
        final description = tester.renderObject<RenderParagraph>(
            find.descendant(
                of: card,
                matching: find.text(preset.soundStyle, skipOffstage: false),
                skipOffstage: false));
        expect(name.didExceedMaxLines, isFalse,
            reason: '${preset.name} must be readable');
        expect(description.didExceedMaxLines, isFalse,
            reason: '${preset.name} description must fit');
      }
      await tester.ensureVisible(find.byKey(const ValueKey('theme-preset-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('theme-preset-1')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(theme.currentThemeId, 1);
      expect(theme.backgroundVisualMode, VisualizerType.mcIntosh.index);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final platform in [
    HifiPlatformType.mac,
    HifiPlatformType.pi,
    HifiPlatformType.ipad
  ]) {
    testWidgets(
        '$platform keeps its existing single-column presets in a narrow stage',
        (tester) async {
      final previous = PlatformHelper.currentPlatform;
      PlatformHelper.currentPlatform = platform;
      addTearDown(() => PlatformHelper.currentPlatform = previous);
      await size(tester, const Size(500, 390));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: MacThemeSettingView(
            currentVisualizer: VisualizerType.ledSpectrum,
            onVisualizerChanged: (_) {}),
      )));
      await tester.pump();
      final grid = tester
          .widget<GridView>(find.byKey(const ValueKey('theme-presets-grid')));
      expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
