import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/platform/platform_audio_runtime.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_dac_setting_view.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/android-dac-output');
  late PlatformAudioRuntime runtime;
  late DacSettingService dac;
  late List<Map<String, dynamic>> devices;
  late Map<String, dynamic> stream;
  late List<String> requests;
  late bool acceptConfiguration;
  late bool openOnConfiguration;
  var bufferFrames = 256;

  setUp(() async {
    devices = [
      {
        'id': '1',
        'name': '平板扬声器',
        'transport': 'BuiltIn',
        'isBuiltIn': true,
        'isDefault': true,
        'sampleRates': [48000],
        'maxSampleRate': 48000,
        'maxBitDepth': 24,
      },
      {
        'id': '42',
        'name': 'TOPPING DX1 II',
        'transport': 'USB',
        'sampleRates': [44100, 48000, 96000, 192000],
        'channelCounts': [2],
        'bitDepths': [16, 24, 32],
        'maxSampleRate': 192000,
        'maxBitDepth': 32,
      },
    ];
    stream = {'isOpen': false};
    requests = [];
    acceptConfiguration = true;
    openOnConfiguration = false;
    bufferFrames = 256;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      switch (call.method) {
        case 'getOutputDevices':
          return devices;
        case 'getOutputFormat':
          // A system default rate is deliberately not an opened AAudio format.
          return {...devices.first, 'sampleRate': 48000};
        default:
          fail('Android must use the engine for controls: ${call.method}');
      }
    });
    runtime = PlatformAudioRuntime.forTesting(
      channel: channel,
      isIOS: false,
      isAndroid: true,
      reportOutput: (_) {},
      readAndroidOutput: () => stream,
      setAndroidBufferFrames: (frames) {
        requests.add('buffer:$frames');
        bufferFrames = frames;
        return true;
      },
      configureAndroidOutput: (deviceId, sampleRate, exclusive) {
        requests.add('configure:$deviceId:$sampleRate:$exclusive');
        if (!acceptConfiguration) return false;
        if (openOnConfiguration) {
          stream = {
            'deviceId': deviceId == 0 ? 1 : deviceId,
            'sampleRate': sampleRate == 0 ? 48000 : sampleRate,
            'channels': 2,
            'bitDepth': 32,
            'bufferFrames': bufferFrames,
            'exclusive': exclusive,
            'isOpen': true,
          };
        }
        return true;
      },
    );
    await runtime.refreshOutput();
    dac = DacSettingService.forTesting(
      runtime: runtime,
      readDevices: () => throw StateError('Android must use real device data'),
      selectOutput: (_) => throw StateError('Android must configure AAudio'),
      followsSystemOutput: false,
    );
  });

  tearDown(() {
    dac.dispose();
    runtime.dispose();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('enumerates a USB DAC without inventing an active stream format', () {
    expect(dac.connectedDevices.map((device) => device.name),
        ['平板扬声器', 'TOPPING DX1 II']);
    final usb = dac.externalDevice!;
    expect(usb.model, 'DX1 II');
    expect(usb.sampleRates, [44100, 48000, 96000, 192000]);
    expect(usb.currentSampleRate, 0);
    expect(usb.specBadge, '等待系统协商 · PCM');
    expect(usb.supportsDpll, isFalse);
    expect(usb.supportsUacMode, isFalse);
    expect(usb.digitalFilters, isEmpty);
    expect(dac.currentDevice!.currentSampleRate, 0);
  });

  test('routes to the DAC and exposes the format negotiated by AAudio',
      () async {
    openOnConfiguration = true;
    await dac.selectDevice(1);
    expect(dac.currentDevice!.id, '42');
    expect(dac.currentDevice!.currentSampleRate, 48000);
    expect(dac.currentDevice!.currentBitDepth, 32);
    expect(requests.take(2), ['buffer:256', 'configure:42:0:true']);

    await dac.setSampleRateMode(3);
    expect(requests.last, 'configure:42:96000:true');
    expect(dac.currentDevice!.currentSampleRate, 96000);
    await runtime.setExclusiveOutput(false);
    expect(requests.last, 'configure:42:96000:false');
    expect(dac.currentDevice!.isExclusive, isFalse);
    await runtime.setBufferFrames(1024);
    expect(dac.currentDevice!.bufferFrames, 1024);
  });

  test('an active default route repairs a disconnected AAudio stream',
      () async {
    openOnConfiguration = true;
    await runtime.activate();
    requests.clear();
    stream = {'isOpen': false};
    await runtime.refreshOutput();
    expect(requests, contains('configure:0:0:true'));
    expect(runtime.hasOpenOutput, isTrue);
    requests.clear();
    await runtime.refreshOutput();
    expect(requests, isEmpty);
  });

  test('a rejected device request keeps the actual output selected', () async {
    acceptConfiguration = false;
    await dac.selectDevice(1);
    expect(runtime.preferredAndroidDeviceId, 0);
    expect(dac.currentDevice!.id, '1');
    expect(runtime.outputPreferenceError, contains('未接受输出设置'));
  });

  test('removing a USB DAC removes stale names and negotiated capabilities',
      () async {
    openOnConfiguration = true;
    await dac.selectDevice(1);
    devices.removeLast();
    stream = {'isOpen': false};
    await runtime.refreshOutput();
    expect(dac.hasExternalDac, isFalse);
    expect(runtime.preferredAndroidDeviceId, 0);
    expect(dac.currentDevice!.id, '1');
    expect(requests.last, 'configure:0:0:true');
    final requestCount = requests.length;
    await runtime.refreshOutput();
    expect(requests.length, requestCount);
  });

  test(
      'an explicit probe reopens a disconnected stream using saved preferences',
      () async {
    openOnConfiguration = true;
    await dac.selectDevice(1);
    stream = {'isOpen': false};
    await runtime.probeOutputs();
    expect(dac.currentDevice!.id, '42');
    expect(dac.currentDevice!.isOpen, isTrue);
    expect(runtime.lastProbeError, isNull);
  });

  for (final size in [const Size(1024, 600), const Size(393, 500)]) {
    testWidgets('Android DAC controls and output format fit $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      openOnConfiguration = true;
      await tester.runAsync(() => dac.selectDevice(1));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MacDACSettingView(
            platform: HifiPlatformType.android,
            service: dac,
          ),
        ),
      ));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('TOPPING DX1 II'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('输出采样率策略'), 150,
          scrollable: find.byType(Scrollable).first);
      expect(
          find.textContaining('DX1 II · Android 音频输出与缓冲区控制'), findsOneWidget);
      expect(find.text('输出采样率策略'), findsOneWidget);
      expect(find.text('独占输出偏好'), findsOneWidget);
      expect(find.text('声卡硬件缓冲区深度', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('32 bit Float'), findsOneWidget);
      expect(find.text('DX1 II 的 UAC 模式说明'), findsNothing);
      final rate = find.text('48 kHz').last;
      await tester.ensureVisible(rate);
      await tester.pump();
      await tester.tap(rate);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(requests, contains('configure:42:48000:true'));
      final buffer = find.text('1024 帧');
      await tester.ensureVisible(buffer);
      await tester.pump();
      await tester.tap(buffer);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(requests, contains('buffer:1024'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
