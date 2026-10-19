import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/services/pi_system_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/pi/pi_main_view.dart';
import 'package:hide_player_flutter/ui/mac/mac_background_widget.dart';
import 'package:hide_player_flutter/ui/mac/mac_sidebar_widget.dart';
import 'package:hide_player_flutter/ui/mac/mac_bottom_bar_widget.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_equalizer_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_dac_setting_view.dart';
import 'package:hide_player_flutter/ui/pi/widgets/pi_screensaver_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
  });

  group('PiSystemService Unit Tests', () {
    test('reports valid SoC core temperature and color status', () {
      final piSys = PiSystemService.instance;
      expect(piSys.socTemperature, greaterThan(30.0));
      expect(piSys.socTemperature, lessThan(80.0));
      expect(['cyan', 'amber', 'red'].contains(piSys.tempColorHex), isTrue);
    });

    test('updates DAC configuration and persistence', () {
      final piSys = PiSystemService.instance;
      piSys.setDacDevice('AK4191 + AK4499EX', 'hw:0,0 (I2S Master Clock)');
      expect(piSys.dacDeviceName, equals('AK4191 + AK4499EX'));
      expect(piSys.alsaCard, contains('hw:0,0'));

      piSys.setScreenSaverTimeout(5);
      expect(piSys.screenSaverTimeoutMinutes, equals(5));
    });
  });

  group('PiMainView 1024x600 Unified Landscape UI Tests', () {
    Widget createPiTestApp() {
      return MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const Scaffold(
          body: SizedBox(
            width: 1024,
            height: 600,
            child: PiMainView(),
          ),
        ),
      );
    }

    testWidgets('renders unified landscape Master-Detail UI with sidebar, visualizer and bottom bar', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createPiTestApp());
      await tester.pump();

      // 验证三大核心板块：全景背景动效、侧边栏、底部播放胶囊
      expect(find.byType(MacBackgroundWidget), findsOneWidget);
      expect(find.byType(MacSidebarWidget), findsOneWidget);
      expect(find.byType(MacBottomBarWidget), findsOneWidget);

      // 验证左侧发烧功能菜单项 (与 Mac/iPad 100% 保持一致)
      expect(find.text('所有音乐'), findsOneWidget);
      expect(find.text('均衡器'), findsOneWidget);
      expect(find.text('调音魔棒'), findsOneWidget);
      expect(find.text('DAC'), findsOneWidget);
      expect(find.text('主题'), findsWidgets);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('Web服务'), findsOneWidget);

      // 验证声卡状态显示 (自动联动 PiSystemService DAC)
      expect(find.textContaining('AK4191 + AK4499EX'), findsWidgets);
    });

    testWidgets('switches to 10-band Equalizer view on touch without overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createPiTestApp());
      await tester.pump();

      // 点击侧边栏“均衡器”
      await tester.tap(find.text('均衡器'));
      await tester.pump();

      expect(find.byType(MacEqualizerView), findsOneWidget);
      expect(find.text('图形均衡器'), findsOneWidget);
      expect(find.text('31Hz'), findsOneWidget);
      expect(find.text('16kHz'), findsOneWidget);
    });

    testWidgets('switches to DAC Settings view on touch and displays ALSA direct hardware info', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createPiTestApp());
      await tester.pump();

      // 点击侧边栏“DAC”
      await tester.tap(find.text('DAC'));
      await tester.pump();

      expect(find.byType(MacDACSettingView), findsOneWidget);
      expect(find.textContaining('DAC 物理硬件与解码设置'), findsOneWidget);
      expect(find.text('本机解码器'), findsOneWidget);
      expect(find.text('外接解码器'), findsOneWidget);
      expect(find.text('TOPPING DX12'), findsOneWidget);
    });

    testWidgets('PiScreensaverOverlay displays and wakes on touch', (tester) async {
      bool woken = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PiScreensaverOverlay(
            onWake: () => woken = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('QLED 防烧屏节能微光中'), findsOneWidget);

      await tester.tap(find.byType(PiScreensaverOverlay));
      await tester.pump();

      expect(woken, isTrue);
    });
  });
}
