import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/platform/platform_audio_runtime.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/ios-usb-probe');
  late PlatformAudioRuntime runtime;
  late DacSettingService dac;
  bool sessionActive = false;
  bool permitActivation = true;
  bool failRoute = false;
  bool plugged = true;
  int activationCalls = 0;
  int reads = 0;

  setUp(() {
    sessionActive = false;
    permitActivation = true;
    failRoute = false;
    plugged = true;
    activationCalls = 0;
    reads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getOutputFormat') {
        reads++;
        if (failRoute) {
          throw PlatformException(
              code: 'route_unavailable', message: '系统路由暂不可读取');
        }
        if (sessionActive && plugged) {
          return {
            'id': 'actual-usb',
            'name': 'TOPPING DX1 II',
            'transport': 'USB',
            'sampleRate': 48000
          };
        }
        return {
          'id': 'speaker',
          'name': 'iPhone 扬声器',
          'transport': 'BuiltIn',
          'sampleRate': 48000
        };
      }
      return null;
    });
    runtime = PlatformAudioRuntime.forTesting(
      channel: channel,
      reportOutput: (_) {},
      activateSession: () async {
        activationCalls++;
        sessionActive = permitActivation;
        return permitActivation;
      },
    );
    dac = DacSettingService.forTesting(
        runtime: runtime,
        readDevices: () => '[]',
        selectOutput: (_) => false,
        followsSystemOutput: true);
  });
  tearDown(() {
    dac.dispose();
    runtime.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
      'probe activates inactive iPhone session before reading actual USB route',
      () async {
    await runtime.refreshOutput();
    expect(dac.currentDevice!.transport, 'BuiltIn');
    await dac.probeOutputs();
    expect(activationCalls, 1);
    expect(reads, greaterThanOrEqualTo(3));
    expect(dac.currentDevice!.name, 'TOPPING DX1 II');
    expect(dac.currentDevice!.transport, 'USB');
    expect(dac.hasExternalDac, isTrue);
    expect(runtime.lastProbeAt, isNotNull);
    expect(runtime.lastProbeError, isNull);
    await dac.probeOutputs();
    expect(activationCalls, 2,
        reason:
            'Explicit probes must verify OS activation instead of trusting a cached flag');
  });

  test('activation rejection reports failure rather than claiming mounted USB',
      () async {
    permitActivation = false;
    await expectLater(dac.probeOutputs(), throwsStateError);
    expect(dac.hasExternalDac, isFalse);
    expect(runtime.lastProbeAt, isNull);
    expect(runtime.lastProbeError, contains('未允许激活'));
  });

  test('failed route read clears stale device and successful retry restores it',
      () async {
    await dac.probeOutputs();
    expect(dac.hasExternalDac, isTrue);
    failRoute = true;
    await expectLater(dac.probeOutputs(), throwsStateError);
    expect(dac.currentDevice, isNull);
    expect(runtime.lastProbeError, contains('系统路由暂不可读取'));
    failRoute = false;
    await dac.probeOutputs();
    expect(dac.hasExternalDac, isTrue);
    expect(runtime.lastProbeError, isNull);
  });

  test(
      'live refresh follows unplug without pretending cached USB is still mounted',
      () async {
    await dac.probeOutputs();
    plugged = false;
    await runtime.refreshOutput();
    expect(dac.currentDevice!.transport, 'BuiltIn');
    expect(dac.hasExternalDac, isFalse);
    expect(runtime.hasUsbOutput, isFalse);
  });
}
