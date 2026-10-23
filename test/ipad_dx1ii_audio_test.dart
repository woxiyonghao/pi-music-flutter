import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/platform/platform_audio_runtime.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_dac_setting_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/ipad-dx1ii');
  late PlatformAudioRuntime runtime;
  late Map<String, dynamic> route;
  late List<Map<Object?, Object?>> requests;
  bool reject = false;
  bool adopt = true;
  setUp(() {
    route = {
      'id': 'usb-dx1ii',
      'name': 'TOPPING DX1 II',
      'transport': 'USB',
      'sampleRate': 48000,
      'channels': 2
    };
    requests = [];
    reject = false;
    adopt = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getOutputFormat') return Map.of(route);
      if (call.method == 'setPreferredSampleRate') {
        final args = Map<Object?, Object?>.from(call.arguments as Map);
        requests.add(args);
        if (reject) throw PlatformException(code: 'unsupported_rate');
        if (adopt) route['sampleRate'] = args['sampleRate'];
      }
      return null;
    });
    runtime =
        PlatformAudioRuntime.forTesting(channel: channel, reportOutput: (_) {});
  });
  tearDown(() {
    runtime.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
      'saved preference restores on USB reconnect and never targets other outputs',
      () async {
    runtime.restoreSampleRateMode(3);
    await runtime.refreshOutput();
    expect(requests.single['sampleRate'], 96000);
    expect(requests.single['routeId'], 'usb-dx1ii');
    await runtime.refreshOutput();
    expect(requests, hasLength(1));
    for (final other in [
      {'name': 'iPad Speaker', 'transport': 'BuiltIn'},
      {'name': 'AirPods', 'transport': 'Bluetooth'},
      {'name': 'TOPPING DX1', 'transport': 'USB'},
      {'name': 'TOPPING E30', 'transport': 'USB'},
    ]) {
      route = {...route, ...other, 'id': 'other'};
      await runtime.refreshOutput();
      expect(runtime.isDx1iiConnected, isFalse);
      expect(requests, hasLength(1));
    }
    route = {
      ...route,
      'id': 'usb-dx1ii',
      'name': 'TOPPING DX1 II',
      'transport': 'USB'
    };
    await runtime.refreshOutput();
    expect(requests, hasLength(2));
    expect(runtime.negotiatedSampleRate, 96000);
  });

  test('auto follows PCM tracks and converts DSD rate to a PCM preference',
      () async {
    await runtime.activate(sourceSampleRate: 44100);
    expect(requests.last['sampleRate'], 44100);
    await runtime.activate(sourceSampleRate: 88200);
    expect(requests.last['sampleRate'], 88200);
    await runtime.activate(sourceSampleRate: 5644800);
    expect(requests.last['sampleRate'], 176400);
    expect(runtime.preferenceMatched, isTrue);
  });

  test('a rejected or unadopted preference preserves compatible playback',
      () async {
    adopt = false;
    await runtime.setSampleRateMode(5);
    expect(await runtime.activate(), isTrue);
    expect(runtime.negotiatedSampleRate, 48000);
    expect(runtime.preferenceMatched, isFalse);
    expect(runtime.sampleRateStatus, contains('未采用'));
    reject = true;
    await runtime.setSampleRateMode(4);
    expect(await runtime.activate(), isTrue);
    expect(runtime.negotiatedSampleRate, 48000);
    expect(runtime.sampleRateStatus, contains('未生效'));
  });

  testWidgets(
      'iPad DX1 II shows actual rate and physical UAC guidance without fake controls',
      (tester) async {
    tester.view.physicalSize = const Size(1300, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => runtime.refreshOutput());
    final dac = DacSettingService.forTesting(
        readDevices: () => '[]',
        selectOutput: (_) => throw StateError('iPadOS owns routing'),
        followsSystemOutput: true,
        runtime: runtime);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MacDACSettingView(
                platform: HifiPlatformType.ipad, service: dac))));
    await tester.pumpAndSettle();
    expect(find.text('USB 输出采样率偏好'), findsOneWidget);
    expect(find.textContaining('实际协商采样率：44.1 kHz'), findsOneWidget);
    expect(find.textContaining('DSD256'), findsNothing);
    expect(find.textContaining('模拟接入'), findsNothing);
    expect(find.text('UAC 协议通信模式 (USB Audio Class)'), findsNothing);
    await tester.tap(find.text('DX1 II 的 UAC 模式说明'));
    await tester.pumpAndSettle();
    expect(find.text('DX1 II · UAC 物理开关'), findsOneWidget);
    expect(find.textContaining('拔出并重新连接 USB'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    dac.dispose();
  });
}
