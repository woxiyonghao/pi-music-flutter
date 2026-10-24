import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/platform/platform_audio_runtime.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/iphone-dac');
  Map<String, dynamic>? route;
  final sampleRateRequests = <int>[];
  late PlatformAudioRuntime runtime;
  late DacSettingService dac;
  var deviceSelectionCalls = 0;

  setUp(() {
    route = null;
    sampleRateRequests.clear();
    deviceSelectionCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getOutputFormat') return route;
      if (call.method == 'setPreferredSampleRate') {
        sampleRateRequests.add(call.arguments['sampleRate'] as int);
      }
      return null;
    });
    runtime = PlatformAudioRuntime.forTesting(
      channel: channel,
      reportOutput: (_) {},
    );
    dac = DacSettingService.forTesting(
      runtime: runtime,
      readDevices: () => '[{"id":"stale","name":"stale","isDefault":true}]',
      selectOutput: (_) {
        deviceSelectionCalls++;
        return true;
      },
      followsSystemOutput: true,
    );
  });

  tearDown(() {
    dac.dispose();
    runtime.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('missing iOS output never invents a built-in or USB DAC', () async {
    await runtime.refreshOutput();
    expect(dac.connectedDevices, isEmpty);
    expect(dac.currentDevice, isNull);
    expect(dac.hasExternalDac, isFalse);
    expect(dac.dacName, '未检测到音频输出');
  });

  test('iOS route changes use negotiated format and real capability limits',
      () async {
    route = {
      'id': 'usb-dx1',
      'name': 'TOPPING DX1 II',
      'transport': 'USB',
      'sampleRate': 96000,
    };
    await runtime.refreshOutput();
    final output = dac.currentDevice!;
    expect(output.name, 'TOPPING DX1 II');
    expect(output.currentSampleRate, 96000);
    expect(output.specBadge, '96kHz · 系统 PCM');
    expect(output.supportsDsd, isFalse);
    expect(output.supportsUacMode, isFalse);
    expect(output.supportsGainControl, isFalse);
    dac.selectDevice(0);
    expect(deviceSelectionCalls, 0);

    route = {
      'id': 'speaker',
      'name': 'iPhone 扬声器',
      'transport': 'BuiltIn',
      'sampleRate': 48000,
    };
    await runtime.refreshOutput();
    expect(dac.currentDevice!.name, 'iPhone 扬声器');
    expect(dac.hasExternalDac, isFalse);
    expect(dac.connectedDevices, hasLength(1));
  });

  test('sample-rate preference reports the negotiated rate after a request',
      () async {
    route = {
      'id': 'usb-dx1',
      'name': 'TOPPING DX1 II',
      'transport': 'USB',
      'sampleRate': 48000,
    };
    await runtime.refreshOutput();
    await dac.setSampleRateMode(4);
    expect(sampleRateRequests.last, 192000);
    expect(dac.sampleRateMode, 4);
    expect(dac.currentDevice!.currentSampleRate, 48000);
    expect(runtime.preferenceMatched, isFalse);
  });
}
