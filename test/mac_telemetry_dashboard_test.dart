import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/services/mac_system_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/ui/visualizers/mac_telemetry_dashboard_widget.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_type.dart';

const channel = MethodChannel('test/macos_system');
final fixture = <String, dynamic>{
  'model': 'Mac16,10',
  'processor': 'Apple M4',
  'coreCount': 10,
  'corePercents': List.filled(10, 12.5),
  'cpuPercent': 12.5,
  'memoryTotalBytes': 16 * 1024 * 1024 * 1024,
  'memoryUsedBytes': 8 * 1024 * 1024 * 1024,
  'memoryCompressedBytes': 1024 * 1024 * 1024,
  'appMemoryBytes': 200 * 1024 * 1024,
  'storageName': 'Macintosh HD',
  'storageTotalBytes': 500 * 1024 * 1024 * 1024,
  'storageFreeBytes': 100 * 1024 * 1024 * 1024,
  'outputName': 'Mac mini扬声器',
  'outputSampleRate': 44100,
  'outputBufferFrames': 512,
  'thermalState': 'nominal',
  'powerSource': 'AC Power',
  'lowPowerMode': false,
  'uptimeSeconds': 90061,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Mac preset appends mode 11 without shifting existing settings', () {
    expect(VisualizerType.glassClock.index, 10);
    expect(VisualizerType.macTelemetryDashboard.index, 11);
    expect(VisualizerType.values.length, ThemeService.visualModeLabels.length);
    final preset = ThemeService.presets.singleWhere((p) => p.id == 9);
    expect(preset.name, 'Mac 硬件大师');
    expect(preset.defaultVisualMode, 11);
  });

  test('Snapshot keeps unavailable data unknown and bounds real counters', () {
    final empty = MacSystemSnapshot.fromMap(const {});
    expect(empty.cpuPercent, isNull);
    expect(empty.memoryRatio, isNull);
    expect(empty.storageFreeRatio, isNull);
    expect(empty.corePercents, isEmpty);
    expect(empty.thermalLabel, '未提供');
    final sample = MacSystemSnapshot.fromMap({...fixture, 'cpuPercent': 150});
    expect(sample.cpuPercent, 100);
    expect(sample.memoryRatio, .5);
    expect(sample.storageFreeRatio, .2);
    expect(sample.number('batteryPercent'), isNull);
    expect(sample.powerLabel, '交流电源');
  });

  testWidgets(
      'Polling shares one timer, stops on detach, and flags stale samples',
      (tester) async {
    var calls = 0;
    var fail = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      if (fail) throw PlatformException(code: 'unavailable');
      return fixture;
    });
    final service = MacSystemService(channel: channel);
    service.attach();
    service.attach();
    await tester.pump();
    expect(calls, 1);
    expect(service.snapshot?.cpuPercent, 12.5);
    service.detach();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(calls, 2);
    fail = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(service.isUnavailable, isTrue);
    expect(service.snapshot?.cpuPercent, 12.5);
    service.detach();
    final stoppedAt = calls;
    await tester.pump(const Duration(seconds: 2));
    expect(calls, stoppedAt);
    service.dispose();
  });

  for (final size in [
    const Size(960, 540),
    const Size(1024, 600),
    const Size(1280, 800)
  ]) {
    testWidgets('Hardware dashboard fits $size with many cores and a battery',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      HifiAudioService.instance.stopTicker();
      messenger.setMockMethodCallHandler(
          channel,
          (_) async => {
                ...fixture,
                'coreCount': 32,
                'corePercents': List.filled(32, 25),
                'batteryPercent': 80,
                'batteryCharging': true,
              });
      final service = MacSystemService(channel: channel);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: MacTelemetryDashboardWidget(systemService: service),
      )));
      await tester.pump();
      expect(find.text('Mac 硬件大师数据大屏'), findsOneWidget);
      expect(find.text('Mac mini扬声器'), findsOneWidget);
      expect(find.text('44.1 kHz'), findsOneWidget);
      expect(find.text('80% · 充电中'), findsOneWidget);
      final radarSize =
          tester.getSize(find.byKey(const ValueKey('mac.hardware.radar')));
      expect(radarSize.width, greaterThan(300));
      expect(radarSize.height, greaterThan(200));
      expect(find.byType(DropdownButton<VisualizerType>), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    });
  }

  testWidgets('Missing telemetry has no fake load, battery or temperature',
      (tester) async {
    HifiAudioService.instance.stopTicker();
    messenger.setMockMethodCallHandler(
        channel, (_) async => <String, dynamic>{});
    final service = MacSystemService(channel: channel);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: MacTelemetryDashboardWidget(systemService: service),
    )));
    await tester.pump();
    expect(find.text('电池电量'), findsNothing);
    expect(find.textContaining('°C'), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
