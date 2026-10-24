import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/platform/platform_audio_runtime.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_dac_setting_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_system_settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/iphone-dac-view');
  late PlatformAudioRuntime runtime;
  late DacSettingService dac;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getOutputFormat') {
        return {
          'id': 'usb-dx1',
          'name': 'TOPPING DX1 II',
          'transport': 'USB',
          'sampleRate': 48000,
        };
      }
      return null;
    });
    runtime = PlatformAudioRuntime.forTesting(
      channel: channel,
      reportOutput: (_) {},
    );
    await runtime.refreshOutput();
    dac = DacSettingService.forTesting(
      runtime: runtime,
      readDevices: () => '[]',
      selectOutput: (_) => false,
      followsSystemOutput: true,
    );
  });

  tearDown(() {
    dac.dispose();
    runtime.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final size in [const Size(1024, 600), const Size(390, 620)]) {
    testWidgets('iPhone DAC keeps iPad controls using real output at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MacDACSettingView(
                  platform: HifiPlatformType.iphone, service: dac))));
      await tester.pump();
      expect(find.text('USB 输出采样率偏好'), findsOneWidget);
      expect(find.textContaining('实际协商采样率：48 kHz'), findsOneWidget);
      expect(find.textContaining('模拟接入'), findsNothing);
      expect(find.textContaining('iPad'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('iPhone system settings expose session-safe controls',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MacSystemSettingsView(platform: HifiPlatformType.iphone))));
    await tester.pump();
    expect(find.text('空余时间显示全屏'), findsOneWidget);
    expect(find.text('CPU 调频策略'), findsNothing);
    expect(find.textContaining('Native 原生直通'), findsNothing);
    expect(find.textContaining('切换横/竖屏'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
