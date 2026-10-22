import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/services/ipad_system_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_theme_setting_view.dart';
import 'package:hide_player_flutter/ui/visualizers/ipad_telemetry_dashboard_widget.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_stage_widget.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
  });

  group('iPad Hardware Master Theme & Telemetry Tests', () {
    test('IpadSystemService provides Apple Silicon telemetry metrics', () {
      final sys = IpadSystemService.instance;
      expect(sys.socName, contains('Apple'));
      expect(sys.cpuFreqMHz, greaterThan(3000));
      expect(sys.corePercents.length, equals(8));
      expect(sys.memTotalMB, equals(8192));
      expect(sys.memUsedPercent, greaterThan(0));
      expect(sys.thermalState, contains('Nominal'));
      expect(sys.batteryLevel, greaterThan(0));
      expect(sys.powerSource, contains('USB-C Direct PD'));
      expect(sys.activeDacName, isNotEmpty);
      expect(sys.audioFormatSpec, isNotEmpty);
      expect(sys.bufferLatencyMs, greaterThan(0));
    });

    test('VisualizerType.ipadTelemetryDashboard has valid names and subtitles', () {
      expect(
        VisualizerType.ipadTelemetryDashboard.getDisplayName(HifiPlatformType.ipad),
        equals('iPad 硬件大师大屏'),
      );
      expect(
        VisualizerType.ipadTelemetryDashboard.getDisplayName(HifiPlatformType.mac),
        equals('Mac 硬件数据大屏'),
      );
      expect(
        VisualizerType.ipadTelemetryDashboard.getDisplayName(HifiPlatformType.pi),
        equals('树莓派硬件数据大屏'),
      );
      expect(
        VisualizerType.ipadTelemetryDashboard.getSubtitle(HifiPlatformType.ipad),
        contains('Apple Studio AOP'),
      );
    });

    test('ThemeService supports iPad Hardware Master preset (id: 9)', () {
      final theme = ThemeService.instance;
      final preset9 = ThemeService.presets.firstWhere((p) => p.id == 9);
      expect(preset9.name, equals('iPad 硬件大师'));
      expect(preset9.accentColor, equals(const Color(0xFF00E5FF)));
      expect(preset9.defaultVisualMode, equals(11));

      // 切换到 iPad 硬件大师主题
      theme.setTheme(9);
      expect(theme.currentThemeId, equals(9));
      expect(theme.accentColor, equals(const Color(0xFF00E5FF)));
      expect(theme.backgroundVisualMode, equals(VisualizerType.ipadTelemetryDashboard.index));
    });

    testWidgets('IpadTelemetryDashboardWidget renders full 3-column cyber dashboard', (tester) async {
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 850,
              child: IpadTelemetryDashboardWidget(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(IpadTelemetryDashboardWidget), findsOneWidget);
      expect(find.text('iPad 硬件大师数据大屏'), findsOneWidget);
      expect(find.text('CPU 核心负载与主频'), findsOneWidget);
      expect(find.text('Apple 统一内存 (UMA)'), findsOneWidget);
      expect(find.text('供电架构与热状态'), findsOneWidget);
      expect(find.text('3D 全息控制核心 · 硬件雷达直通'), findsOneWidget);
      expect(find.text('APFS 沙盒与曲库存储气泡图'), findsOneWidget);
      expect(find.text('曲库母带格式分布统计'), findsOneWidget);
      expect(find.text('iPadOS 音频总线健康链路'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('VisualizerStageWidget switches to IpadTelemetryDashboardWidget when activeType is ipadTelemetryDashboard', (tester) async {
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 850,
              child: VisualizerStageWidget(
                activeType: VisualizerType.ipadTelemetryDashboard,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VisualizerStageWidget), findsOneWidget);
      expect(find.byType(IpadTelemetryDashboardWidget), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('MacThemeSettingView displays iPad Hardware Master preset and visualizer button', (tester) async {
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final theme = ThemeService.instance;
      theme.setTheme(9);

      VisualizerType changedType = VisualizerType.mcIntosh;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 950,
              child: MacThemeSettingView(
                currentVisualizer: VisualizerType.ipadTelemetryDashboard,
                onVisualizerChanged: (type) {
                  changedType = type;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('iPad 硬件大师'), findsOneWidget);
      expect(find.text('iPad 硬件大师大屏'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('iPad 硬件大师大屏'),
        50,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // 点击背景律动中的 iPad 硬件大师大屏
      await tester.tap(find.text('iPad 硬件大师大屏'));
      await tester.pump();

      expect(changedType, equals(VisualizerType.ipadTelemetryDashboard));

      await tester.pumpWidget(const SizedBox());
    });
  });
}
