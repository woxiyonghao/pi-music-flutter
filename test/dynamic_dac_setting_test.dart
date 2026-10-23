import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/models/dac_device_info.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_dac_setting_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic DAC Hardware & Topping DX12 View Tests', () {
    test('DacDeviceInfo JSON deserialization and specBadge calculation', () {
      final json = {
        'id': 'usb_dx12',
        'name': 'TOPPING DX12',
        'isBuiltIn': false,
        'isDefault': false,
        'transport': 'USB',
        'currentSampleRate': 384000,
        'maxSampleRate': 384000,
        'maxBitDepth': 32,
        'brand': 'TOPPING (拓品)',
        'model': 'DX12 / DX1 II',
        'chipModel': 'ESS Sabre (ES9039Q2M)',
        'usbInterface': 'XMOS XU316',
        'maxDsdRate': 'DSD256 (Native / DoP)',
        'supportsDsd': true,
        'supportsHogMode': true,
        'supportsUacMode': true,
        'supportsDpll': true,
        'supportsGainControl': true,
        'supportsLineOutBypass': true,
        'digitalFilters': [
          '最小相位快速滚降 (Fast Roll-off, Minimum Phase)',
          '线性相位快速滚降 (Fast Roll-off, Linear Phase)',
        ],
        'filterDescriptions': [
          '瞬态极佳，无预振铃，人声与流行优选',
          '声场开阔自然，大编制首选',
        ],
      };

      final info = DacDeviceInfo.fromJson(json);
      expect(info.name, equals('TOPPING DX12'));
      expect(info.isBuiltIn, isFalse);
      expect(info.chipModel, equals('ESS Sabre (ES9039Q2M)'));
      expect(info.specBadge, equals('384kHz / 32Bit · DSD256 (Native / DoP)'));
      expect(info.digitalFilters.length, equals(2));
    });

    test('DacSettingService device enumeration and selection with opt-in mock', () {
      final service = DacSettingService.instance;
      service.toggleMockExternal(false);
      service.refreshDevices();

      // 默认状态下：未连接外接解码器，仅显示本机解码器
      expect(service.connectedDevices.length, equals(1));
      expect(service.builtinDevice, isNotNull);
      expect(service.externalDevice, isNull);
      expect(service.hasExternalDac, isFalse);

      // 显式开启模拟接入 (或物理插入外设)
      service.toggleMockExternal(true);
      expect(service.connectedDevices.length, equals(2));
      expect(service.externalDevice, isNotNull);
      expect(service.hasExternalDac, isTrue);

      // 切换选择外接设备
      final externalIdx = service.connectedDevices.indexWhere((d) => !d.isBuiltIn);
      expect(externalIdx, isNonNegative);
      service.selectDevice(externalIdx);

      expect(service.selectedDeviceIndex, equals(externalIdx));
      expect(service.currentDevice?.name, contains('TOPPING'));

      // 移除模拟外设后恢复只有本机解码器
      service.toggleMockExternal(false);
      expect(service.connectedDevices.length, equals(1));
      expect(service.hasExternalDac, isFalse);
    });

    Widget createDacViewApp() {
      return MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const Scaffold(
          body: SizedBox(
            width: 1024,
            height: 600,
            child: MacDACSettingView(platform: HifiPlatformType.mac),
          ),
        ),
      );
    }

    testWidgets('MacDACSettingView default renders ONLY built-in decoder when no external DAC is connected', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = DacSettingService.instance;
      service.toggleMockExternal(false);

      await tester.pumpWidget(createDacViewApp());
      await tester.pumpAndSettle();

      // 默认未接外接 DAC 时：仅显示【本机解码器】，绝不显示【外接解码器】
      expect(find.text('本机解码器'), findsOneWidget);
      expect(find.text('外接解码器'), findsNothing);
      expect(find.text('TOPPING DX12'), findsNothing);
      expect(find.text('模拟接入 TOPPING DX12 调校'), findsOneWidget);
    });

    testWidgets('MacDACSettingView renders TOPPING DX12 settings when external DAC is connected/mocked', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = DacSettingService.instance;
      service.toggleMockExternal(true);

      // 先选择外接解码器 (TOPPING DX12)
      final externalIdx = service.connectedDevices.indexWhere((d) => !d.isBuiltIn);
      service.selectDevice(externalIdx);

      await tester.pumpWidget(createDacViewApp());
      await tester.pumpAndSettle();

      // 1. 验证显示已连接的解码器选项卡 (本机解码器 与 外接解码器)
      expect(find.text('本机解码器'), findsOneWidget);
      expect(find.text('外接解码器'), findsOneWidget);
      expect(find.text('TOPPING DX12'), findsWidgets);

      // 2. 验证彻底移除未连接芯片（如 ROHM 34301、R-2R 纯电阻、ES9038PRO 独立选项）
      expect(find.text('ROHM 34301'), findsNothing);
      expect(find.text('R-2R 纯电阻'), findsNothing);
      expect(find.text('ES9038PRO'), findsNothing);

      // 3. 验证外接 TOPPING DX12 专属硬件信息与 8 种滤波选项
      expect(find.text('ESS Sabre (ES9039Q2M)'), findsOneWidget);
      expect(find.text('XMOS XU316 超低抖动异步传输'), findsOneWidget);
      expect(find.textContaining('384kHz / 32Bit'), findsWidgets);

      // 验证 ESS 芯片滤波
      expect(find.text('最小相位快速滚降 (Fast Roll-off, Minimum Phase)'), findsOneWidget);
      expect(find.text('线性相位快速滚降 (Fast Roll-off, Linear Phase)'), findsOneWidget);
      expect(find.text('切趾快速滚降 (Apodizing Fast Roll-off)'), findsOneWidget);
      expect(find.text('砖墙滤波 (Brickwall)'), findsOneWidget);

      // 验证 ESS DPLL 时钟抖动带宽
      expect(find.textContaining('ESS DPLL 时钟抖动抑制带宽'), findsOneWidget);
      expect(find.text('极窄带 1 (极致透明)'), findsOneWidget);

      // 验证 DSD 截止频率
      expect(find.textContaining('DSD 模拟低通滤波截止频率'), findsOneWidget);
      expect(find.text('47.7kHz (标准推荐)'), findsOneWidget);

      // 验证 UAC 2.0 / 1.0
      expect(find.textContaining('UAC 协议通信模式'), findsOneWidget);
      expect(find.text('UAC 2.0 (全速异步传输 · 384k/DSD256)'), findsOneWidget);

      // 验证 0dB 直通与增益切换
      expect(find.text('0dB 纯解码直出 (Line Out Bypass)'), findsOneWidget);
      expect(find.text('0dB 低增益 (IEM 入耳)'), findsOneWidget);
      expect(find.text('+6dB 高增益 (平衡大推力)'), findsOneWidget);

      // 4. 点击切换到【本机解码器】
      await tester.tap(find.text('本机解码器'));
      await tester.pumpAndSettle();

      expect(find.text('CoreAudio 独占模式 (Exclusive Hog Mode)'), findsOneWidget);
      expect(find.text('声卡硬件缓冲区深度 (Hardware Buffer Size)'), findsOneWidget);
      expect(find.text('64 帧 (1.4ms)'), findsOneWidget);
      // 还原状态
      service.toggleMockExternal(false);
    });

    testWidgets('MacDACSettingView renders iPad-specific settings when platform is iPad', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = DacSettingService.instance;
      service.toggleMockExternal(false);

      await tester.pumpWidget(MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const Scaffold(
          body: SizedBox(
            width: 1024,
            height: 600,
            child: MacDACSettingView(platform: HifiPlatformType.ipad),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('iPadOS 硬件音频会话直通 (AVAudio Direct Session)'), findsOneWidget);
      expect(find.text('iPad 硬件 I/O 缓冲区深度 (Hardware Buffer Size)'), findsOneWidget);
      expect(find.text('iPadOS 数字音频输出位深'), findsOneWidget);
      expect(find.text('CoreAudio 独占模式 (Exclusive Hog Mode)'), findsNothing);
    });

    testWidgets('MacDACSettingView renders Pi-specific settings when platform is Pi', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = DacSettingService.instance;
      service.toggleMockExternal(false);

      await tester.pumpWidget(MaterialApp(
        theme: HifiTheme.darkTheme,
        home: const Scaffold(
          body: SizedBox(
            width: 1024,
            height: 600,
            child: MacDACSettingView(platform: HifiPlatformType.pi),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ALSA 硬件直通与独占 (Direct Hardware hw:)'), findsOneWidget);
      expect(find.text('ALSA Ring Buffer 环形缓冲区深度'), findsOneWidget);
      expect(find.text('ALSA 数字音频输出位深'), findsOneWidget);
      expect(find.text('CoreAudio 独占模式 (Exclusive Hog Mode)'), findsNothing);
    });

    test('Hardware output sample rate forced boost and effective spec calculation', () async {
      final service = DacSettingService.instance;

      // 1. 设置为 384kHz 极频锁定 (模式 5)
      await service.setSampleRateMode(5);
      expect(service.sampleRateMode, equals(5));
      expect(service.effectiveOutputSampleRate, equals(384000));
      expect(service.effectiveOutputBitDepth, equals(32));
      expect(service.effectiveSpecText, equals('384.0k / 32b'));

      // 2. 设置为 192kHz 超采样 (模式 4)
      await service.setSampleRateMode(4);
      expect(service.sampleRateMode, equals(4));
      expect(service.effectiveOutputSampleRate, equals(192000));
      expect(service.effectiveOutputBitDepth, equals(32));
      expect(service.effectiveSpecText, equals('192.0k / 32b'));

      // 3. 恢复为 0 档 (自动跟随母带源码直出)
      await service.setSampleRateMode(0);
      expect(service.sampleRateMode, equals(0));
    });
  });
}
