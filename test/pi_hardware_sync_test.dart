import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';
import 'package:hide_player_flutter/services/wifi_transfer_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/pi/widgets/pi_hardware_settings_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DacSettingService & WebRemote Integration Tests', () {
    test('DAC chip selection updates and invokes broadcast callback', () {
      final dac = DacSettingService.instance;
      bool broadcastCalled = false;
      dac.onBroadcastNeeded = () {
        broadcastCalled = true;
      };

      dac.setChip(1); // ES9038PRO
      expect(dac.selectedChip, equals(1));
      expect(dac.dacName, equals('ES9038PRO'));
      expect(broadcastCalled, isTrue);

      broadcastCalled = false;
      dac.setChip(2); // AK4499EX
      expect(dac.selectedChip, equals(2));
      expect(dac.dacName, equals('AK4499EX'));
      expect(broadcastCalled, isTrue);

      // DAC 参数修改与持久化
      dac.setParam('pcm_filter', 3);
      expect(dac.getParam('pcm_filter'), equals(3));
      expect(dac.allParams['pcm_filter'], equals(3));
    });

    test('WifiTransferService start and stop lifecycle', () async {
      final wifi = WifiTransferService.instance;
      expect(wifi.isRunning, isFalse);

      final started = await wifi.start(port: 8089);
      expect(started, isTrue);
      expect(wifi.isRunning, isTrue);
      expect(wifi.port, equals(8089));

      await wifi.stop();
      expect(wifi.isRunning, isFalse);
    });
  });

  group('PiHardwareSettingsDrawer Widget Tests', () {
    Widget createSettingsDrawerApp() {
      return MaterialApp(
        theme: HifiTheme.darkTheme,
        home: Scaffold(
          body: SizedBox(
            width: 1024,
            height: 600,
            child: PiHardwareSettingsDrawer(
              onClose: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders ALSA options, DAC architecture chips, and WiFi transfer controls', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSettingsDrawerApp());
      await tester.pump();

      // 验证标题与顶栏
      expect(find.text('树莓派 5 发烧硬件与系统设置'), findsOneWidget);
      expect(find.textContaining('SoC 温度:'), findsOneWidget);

      // 验证 ALSA 声卡选项
      expect(find.text('AK4191 + AK4499EX'), findsWidgets);
      expect(find.text('HiFiBerry DAC+ Pro (PCM5122)'), findsOneWidget);
      expect(find.text('USB Audio Class 2.0 DAC'), findsOneWidget);

      // 验证发烧 DAC 架构芯片选择按钮
      expect(find.text('ES9038PRO'), findsWidgets);
      expect(find.text('CS43198'), findsOneWidget);
      expect(find.text('R-2R 纯电阻'), findsOneWidget);
      expect(find.text('ROHM 34301'), findsOneWidget);

      // 验证点击切换 DAC 芯片
      await tester.tap(find.text('CS43198'));
      await tester.pump();
      expect(DacSettingService.instance.selectedChip, equals(3));
      expect(find.textContaining('CS43198'), findsWidgets);

      // 验证防烧屏超时选项
      expect(find.text('1 分钟'), findsOneWidget);
      expect(find.text('3 分钟'), findsOneWidget);
      expect(find.text('5 分钟'), findsOneWidget);

      // 验证 Web 遥控与 WiFi 传歌服务控制卡片
      expect(find.text('手机/平板 Web 发烧遥控'), findsOneWidget);
      expect(find.text('电脑无线拖拽传歌服务'), findsOneWidget);
      expect(find.textContaining('传歌服务'), findsWidgets);
    });
  });
}
