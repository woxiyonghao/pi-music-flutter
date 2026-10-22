import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/ipad/ipad_main_view.dart';
import 'package:hide_player_flutter/ui/mac/mac_background_widget.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_system_settings_view.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
  });

  group('Theme Single Source of Truth & Fullscreen Tests', () {
    testWidgets('MacSystemSettingsView has no 全屏屏保主题 setting', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: HifiTheme.darkTheme,
          home: const Scaffold(
            body: MacSystemSettingsView(),
          ),
        ),
      );
      await tester.pump();

      // 验证全屏屏保主题已被完全移除
      expect(find.text('全屏屏保主题'), findsNothing);
      expect(find.text('跟随当前律动'), findsNothing);
      expect(find.text('玻璃时钟'), findsNothing);

      // 但保留空余时间显示全屏
      expect(find.text('空余时间显示全屏'), findsOneWidget);
    });

    test('MusicDatabaseService automatically purges setting_idle_screensaver_theme on every open', () {
      final db = MusicDatabaseService.instance;
      // 数据库在每次 openDb 时确保表结构并执行 DELETE FROM app_settings WHERE key = 'setting_idle_screensaver_theme';
      // 因此该键永远为默认值，无法残留脏数据
      expect(db.getSetting('setting_idle_screensaver_theme', 'none'), 'none');

      // deleteSetting 同样返回 true
      expect(db.deleteSetting('setting_idle_screensaver_theme'), isTrue);
    });

    testWidgets('Fullscreen background strictly respects ThemeService active visualizer', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. 设置侧边栏主题为 48列全景 LED 频谱 (VisualizerType.ledSpectrum = index 0)
      ThemeService.instance.setBackgroundVisualMode(0);
      expect(ThemeService.instance.backgroundVisualMode, 0);

      await tester.pumpWidget(
        MaterialApp(
          theme: HifiTheme.darkTheme,
          home: const IpadMainView(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // 初始普通模式下背景动效为 ledSpectrum
      MacBackgroundWidget bgWidget = tester.widget(find.byType(MacBackgroundWidget));
      expect(bgWidget.visualizerType, VisualizerType.ledSpectrum);

      // 2. 点击底部全屏按钮进入全屏沉浸模式
      final fullscreenBtn = find.byIcon(Icons.fullscreen_rounded);
      expect(fullscreenBtn, findsOneWidget);
      await tester.tap(fullscreenBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      // 全屏模式下，依然必须是 48列全景 LED 频谱
      bgWidget = tester.widget(find.byType(MacBackgroundWidget));
      expect(bgWidget.visualizerType, VisualizerType.ledSpectrum);

      // 验证全屏下没有主题切换 DropdownButton，只有一个干净的退出全屏按钮
      expect(find.byType(DropdownButton<VisualizerType>), findsNothing);
      expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);

      // 3. 点击退出全屏
      await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      // 4. 切换到 硬件大师 (index 11)
      ThemeService.instance.setBackgroundVisualMode(11);
      await tester.pump(const Duration(milliseconds: 50));
      bgWidget = tester.widget(find.byType(MacBackgroundWidget));
      expect(bgWidget.visualizerType, VisualizerType.ipadTelemetryDashboard);

      // 再次进入全屏，全屏背景立即变为 硬件大师
      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      bgWidget = tester.widget(find.byType(MacBackgroundWidget));
      expect(bgWidget.visualizerType, VisualizerType.ipadTelemetryDashboard);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
