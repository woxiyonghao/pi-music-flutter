import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/services/pi_system_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/pi/pi_main_view.dart';
import 'package:hide_player_flutter/ui/pi/widgets/pi_touch_controls.dart';
import 'package:hide_player_flutter/ui/pi/widgets/pi_music_library_drawer.dart';
import 'package:hide_player_flutter/ui/pi/widgets/pi_tuning_drawer.dart';
import 'package:hide_player_flutter/ui/pi/widgets/pi_hardware_settings_drawer.dart';
import 'package:hide_player_flutter/ui/pi/widgets/pi_screensaver_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('PiMainView 1024x600 Touch UI Tests', () {
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

    testWidgets('renders top status bar with DAC, Clock and Temperature', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createPiTestApp());
      await tester.pump();

      expect(find.text('AK4191 + AK4499EX'), findsOneWidget);
      expect(find.text('I2S MASTER CLOCK'), findsOneWidget);
      expect(find.byType(PiTouchControls), findsOneWidget);
      expect(find.text('本地曲库'), findsOneWidget);
      expect(find.text('音色调音'), findsOneWidget);
      expect(find.text('硬件设置'), findsOneWidget);
    });

    testWidgets('opens and closes PiMusicLibraryDrawer on touch', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createPiTestApp());
      await tester.pump();

      // 点击“本地曲库”
      await tester.tap(find.text('本地曲库'));
      await tester.pump();

      expect(find.byType(PiMusicLibraryDrawer), findsOneWidget);
      expect(find.text('发烧本地曲库'), findsOneWidget);

      // 点击返回关闭大按钮
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();

      expect(find.byType(PiMusicLibraryDrawer), findsNothing);
    });

    testWidgets('opens and closes PiTuningDrawer on touch', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createPiTestApp());
      await tester.pump();

      // 点击“音色调音”
      await tester.tap(find.text('音色调音'));
      await tester.pump();

      expect(find.byType(PiTuningDrawer), findsOneWidget);
      expect(find.text('10 段图形均衡器与调音'), findsOneWidget);
      expect(find.text('31Hz'), findsOneWidget);
      expect(find.text('16kHz'), findsOneWidget);

      // 点击关闭
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();

      expect(find.byType(PiTuningDrawer), findsNothing);
    });

    testWidgets('opens and closes PiHardwareSettingsDrawer on touch', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createPiTestApp());
      await tester.pump();

      // 点击“硬件设置”
      await tester.tap(find.text('硬件设置'));
      await tester.pump();

      expect(find.byType(PiHardwareSettingsDrawer), findsOneWidget);
      expect(find.text('树莓派 5 发烧硬件与系统设置'), findsOneWidget);
      expect(find.text('ALSA 物理硬件声卡 (Bit-Perfect Direct)'), findsOneWidget);

      // 点击关闭
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();

      expect(find.byType(PiHardwareSettingsDrawer), findsNothing);
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
