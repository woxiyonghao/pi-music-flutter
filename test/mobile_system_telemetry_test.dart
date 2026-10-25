import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/services/mobile_system_service.dart';
import 'package:hide_player_flutter/ui/visualizers/mobile_telemetry_dashboard_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HifiAudioService.instance.stopTicker());

  test('bad individual measurements cannot discard other native values', () {
    final snapshot = MobileSystemSnapshot.fromMap({
      'model': 'iPhone18,4',
      'systemVersion': '26.4',
      'processorCount': 6,
      'physicalMemoryBytes': double.nan,
      'appMemoryBytes': double.infinity,
      'appCpuPercent': 173.2,
      'batteryLevel': -1,
      'storageFreeBytes': 0,
      'audioSampleRate': '192000',
      'metricErrors': {
        'batteryLevel': 'battery_not_ready',
        'appMemoryBytes': 99
      },
    });
    expect(snapshot.model, 'iPhone18,4');
    expect(snapshot.processorCount, 6);
    expect(snapshot.physicalMemoryBytes, isNull);
    expect(snapshot.appMemoryBytes, isNull);
    expect(snapshot.audioSampleRate, isNull);
    expect(snapshot.appCpuPercent, 173.2);
    expect(snapshot.storageFreeBytes, 0);
    expect(snapshot.batteryLevel, isNull);
    expect(snapshot.unavailableLabel('batteryLevel'), '等待电池状态');
    expect(snapshot.metricErrors.containsKey('appMemoryBytes'), isFalse);
  });

  test('zero battery and CPU are measurements rather than missing data', () {
    final snapshot = MobileSystemSnapshot.fromMap({
      'batteryLevel': 0,
      'appCpuPercent': 0,
      'physicalFreeMemoryBytes': 0,
      'lowPowerMode': false
    });
    expect(snapshot.batteryLevel, 0);
    expect(snapshot.appCpuPercent, 0);
    expect(snapshot.physicalFreeMemoryBytes, 0);
    expect(snapshot.lowPowerMode, isFalse);
  });

  test(
      'simulator identity and unavailable sensors are distinct from device data',
      () {
    final snapshot = MobileSystemSnapshot.fromMap({
      'model': 'iPhone18,4',
      'deviceName': 'iPhone Simulator',
      'isSimulator': true,
      'metricScope': 'simulator_host',
      'metricErrors': {
        'batteryLevel': 'simulator_unavailable',
        'cpuTemperatureCelsius': 'not_public',
        'appCpuPercent': 'sampling'
      }
    });
    expect(snapshot.isSimulator, isTrue);
    expect(snapshot.metricScope, 'simulator_host');
    expect(snapshot.batteryLevel, isNull);
    expect(snapshot.unavailableLabel('batteryLevel'), '模拟器不提供');
    expect(snapshot.unavailableLabel('cpuTemperatureCelsius'), 'iOS 未开放');
    expect(snapshot.unavailableLabel('appCpuPercent'), '采样中');
  });

  test('simultaneous refresh requests share one native sample', () async {
    final reply = Completer<Map<Object?, Object?>?>();
    var reads = 0;
    final service = MobileSystemService.forTesting(readSystemInfo: () {
      reads++;
      return reply.future;
    });
    addTearDown(service.dispose);
    final first = service.refresh();
    final second = service.refresh();
    expect(identical(first, second), isTrue);
    reply.complete({'model': 'iPhone18,4', 'processorCount': 6});
    await Future.wait([first, second]);
    expect(reads, 1);
    expect(service.updatedAt, isNotNull);
    expect(service.lastError, isNull);
  });

  test(
      'bridge failure retains the last successful sample and exposes diagnostics',
      () async {
    var attempt = 0;
    final now = DateTime(2026, 10, 25, 14, 30, 20);
    final service = MobileSystemService.forTesting(
        clock: () => now,
        readSystemInfo: () async {
          attempt++;
          if (attempt == 2) {
            throw MissingPluginException('missing bridge');
          }
          return {
            'model': 'iPhone18,4',
            'processorCount': 6,
            'bridgeVersion': 2
          };
        });
    addTearDown(service.dispose);
    await service.refresh();
    final sample = service.snapshot;
    await service.refresh();
    expect(identical(service.snapshot, sample), isTrue);
    expect(service.updatedAt, now);
    expect(service.lastError, contains('bridge_missing'));
    expect(service.consecutiveFailures, 1);
    expect(service.statusLabel, contains('保留上次数据'));
    await service.refresh();
    expect(service.lastError, isNull);
    expect(service.consecutiveFailures, 0);
    expect(service.statusLabel, contains('原生遥测 v2'));
  });

  test('a stuck bridge times out and subsequent valid calls recover', () async {
    var stuck = true;
    final service = MobileSystemService.forTesting(
        requestTimeout: const Duration(milliseconds: 10),
        readSystemInfo: () => stuck
            ? Completer<Map<Object?, Object?>?>().future
            : Future.value({'model': 'iPhone18,4'}));
    addTearDown(service.dispose);
    await service.refresh();
    expect(service.lastError, contains('bridge_timeout'));
    expect(service.updatedAt, isNull);
    stuck = false;
    await service.refresh();
    expect(service.lastError, isNull);
    expect(service.snapshot.model, 'iPhone18,4');
  });

  test(
      'empty and unrecognized bridge responses never report a false connection',
      () async {
    final service = MobileSystemService.forTesting(
        readSystemInfo: () async => {'unexpected': 'data'});
    addTearDown(service.dispose);
    await service.refresh();
    expect(service.updatedAt, isNull);
    expect(service.lastError, contains('no_recognized_metrics'));
    expect(service.statusLabel, '原生遥测读取失败');
  });

  test('disposing during a native read prevents later notifications', () async {
    final reply = Completer<Map<Object?, Object?>?>();
    final service =
        MobileSystemService.forTesting(readSystemInfo: () => reply.future);
    var notifications = 0;
    service.addListener(() => notifications++);
    final refresh = service.refresh();
    service.dispose();
    reply.complete({'model': 'iPhone18,4'});
    await refresh;
    expect(notifications, 0);
  });

  Future<void> mount(WidgetTester tester, MobileSystemService service) async {
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MobileTelemetryDashboardWidget(systemService: service))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
      'small iPhone dashboard displays actual CPU, memory and audio measurements',
      (tester) async {
    final now = DateTime(2026, 10, 25, 14, 30, 20);
    final service = MobileSystemService.forTesting(
        clock: () => now,
        readSystemInfo: () async => {
              'bridgeVersion': 2,
              'sampledAtUnixMs': now.millisecondsSinceEpoch,
              'model': 'iPhone18,4',
              'deviceName': 'iPhone',
              'systemName': 'iOS',
              'systemVersion': '26.4',
              'isSimulator': false,
              'processorCount': 6,
              'activeProcessorCount': 6,
              'physicalMemoryBytes': 8589934592,
              'physicalFreeMemoryBytes': 1073741824,
              'appMemoryBytes': 134217728,
              'appFootprintBytes': 104857600,
              'appAvailableMemoryBytes': 2147483648,
              'appCpuPercent': 173.2,
              'batteryLevel': .7,
              'batteryState': 'unplugged',
              'lowPowerMode': false,
              'thermalState': 'nominal',
              'storageTotalBytes': 256000000000,
              'storageFreeBytes': 128000000000,
              'audioOutputName': 'DX1 II USB',
              'audioTransport': 'USBAudio',
              'audioSampleRate': 192000,
              'audioChannels': 2,
              'audioBufferFrames': 256,
              'audioBufferDurationMs': 1.333,
              'audioOutputLatencyMs': 2.5,
            });
    addTearDown(service.dispose);
    await mount(tester, service);
    expect(find.text('iPhone18,4'), findsOneWidget);
    expect(find.text('173.2%'), findsOneWidget);
    expect(find.text('APP 可用额度'), findsOneWidget);
    expect(find.text('192.0 kHz'), findsOneWidget);
    expect(find.text('DX1 II USB'), findsOneWidget);
    expect(find.text('256 帧'), findsOneWidget);
    expect(find.textContaining('更新 14:30:20'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'simulator explains host measurements and unavailable battery fields',
      (tester) async {
    final service = MobileSystemService.forTesting(
        readSystemInfo: () async => {
              'model': 'iPhone18,4',
              'isSimulator': true,
              'processorCount': 12,
              'metricErrors': {
                'batteryLevel': 'simulator_unavailable',
                'batteryState': 'simulator_unavailable'
              },
            });
    addTearDown(service.dispose);
    await mount(tester, service);
    expect(find.textContaining('来自宿主 Mac'), findsOneWidget);
    expect(find.text('模拟器不提供'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a missing native bridge is visible on the dashboard',
      (tester) async {
    final service = MobileSystemService.forTesting(
        readSystemInfo: () async =>
            throw MissingPluginException('no native bridge'));
    addTearDown(service.dispose);
    await mount(tester, service);
    expect(find.textContaining('原生遥测读取失败'), findsOneWidget);
    expect(find.textContaining('连续失败 1 次'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving the dashboard cancels a stuck native request deadline',
      (tester) async {
    final pending = Completer<Map<Object?, Object?>?>();
    final service =
        MobileSystemService.forTesting(readSystemInfo: () => pending.future);
    addTearDown(service.dispose);
    await mount(tester, service);
    expect(service.isRefreshing, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(service.isRefreshing, isFalse);
    expect(service.consecutiveFailures, 0);
    pending.complete({'model': 'late native response'});
    await tester.pump();
    expect(service.updatedAt, isNull);
  });
}
