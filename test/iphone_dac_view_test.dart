import 'dart:convert';
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

  testWidgets('iPhone copies fresh route and session diagnostics',
      (tester) async {
    String? clipboard;
    var sampleRate = 48000;
    var routeReads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'getOutputFormat') return null;
      routeReads++;
      return {
        'id': 'usb-dx1',
        'name': 'TOPPING DX1 II',
        'transport': 'USB',
        'sampleRate': sampleRate,
      };
    });
    // Keep the serialized runtime queue inside this widget test's fake zone.
    // A runtime created by setUp has a real-zone tail that pump cannot flush.
    final copyRuntime = PlatformAudioRuntime.forTesting(
      channel: channel,
      reportOutput: (_) {},
    );
    final copyDac = DacSettingService.forTesting(
      runtime: copyRuntime,
      readDevices: () => '[]',
      selectOutput: (_) => false,
      followsSystemOutput: true,
    );
    addTearDown(() {
      copyDac.dispose();
      copyRuntime.dispose();
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MacDACSettingView(
                platform: HifiPlatformType.iphone, service: copyDac))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final readsBeforeCopy = routeReads;
    sampleRate = 96000;
    await tester.tap(find.text('复制音频诊断'));
    await tester.pump();
    expect(clipboard, isNotNull);
    final report = jsonDecode(clipboard!) as Map;
    expect(report['route']['name'], 'TOPPING DX1 II');
    expect(report['route']['transport'], 'USB');
    expect(report['route']['sampleRate'], 96000);
    expect(routeReads, greaterThan(readsBeforeCopy));
    expect(report['sessionActive'], isTrue);
    expect(report['sessionError'], isNull);
    expect(find.text('音频诊断已复制'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('entering iPhone DAC probes once and polls the live OS route',
      (tester) async {
    const liveChannel = MethodChannel('test/iphone-dac-view-live-probe');
    var active = false;
    var activationCalls = 0;
    var routeReads = 0;
    var plugged = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveChannel, (call) async {
      if (call.method != 'getOutputFormat') return null;
      routeReads++;
      return {
        'id': active && plugged ? 'live-usb' : 'speaker',
        'name': active && plugged ? 'TOPPING DX1 II' : 'iPhone 扬声器',
        'transport': active && plugged ? 'USB' : 'BuiltIn',
        'sampleRate': 48000,
      };
    });
    final liveRuntime = PlatformAudioRuntime.forTesting(
      channel: liveChannel,
      reportOutput: (_) {},
      activateSession: () async {
        activationCalls++;
        active = true;
        return true;
      },
    );
    final liveDac = DacSettingService.forTesting(
      runtime: liveRuntime,
      readDevices: () => '[]',
      selectOutput: (_) => false,
      followsSystemOutput: true,
    );
    addTearDown(() {
      liveDac.dispose();
      liveRuntime.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(liveChannel, null);
    });
    await liveRuntime.refreshOutput();
    expect(liveDac.currentDevice!.transport, 'BuiltIn');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MacDACSettingView(
                platform: HifiPlatformType.iphone, service: liveDac))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(activationCalls, 1);
    expect(liveDac.currentDevice!.name, 'TOPPING DX1 II');
    expect(find.text('TOPPING DX1 II'), findsOneWidget);

    final readsAfterEntry = routeReads;
    plugged = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(routeReads, greaterThan(readsAfterEntry));
    expect(liveDac.currentDevice!.name, 'iPhone 扬声器');
    expect(activationCalls, 1,
        reason: 'Periodic OS queries must not reactivate the audio session');

    plugged = true;
    await tester.tap(find.byTooltip('重新探测已连接的音频设备'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(liveDac.currentDevice!.name, 'TOPPING DX1 II');
    expect(activationCalls, 2,
        reason: 'A manual retry verifies OS activation despite cached state');
    expect(find.text('系统当前 USB 音频输出：TOPPING DX1 II'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
