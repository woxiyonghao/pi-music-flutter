import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/platform/platform_audio_runtime.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';
import 'package:hide_player_flutter/services/web_remote_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/web-route');
  late PlatformAudioRuntime runtime;
  late DacSettingService dac;
  Map<String, dynamic>? route;
  setUp(() {
    route = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getOutputFormat') return route;
      return null;
    });
    runtime =
        PlatformAudioRuntime.forTesting(channel: channel, reportOutput: (_) {});
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
      'Web DAC snapshots follow hotplug without recursive refresh or stale outputs',
      () async {
    final web = WebRemoteService.forTesting(dac: dac);
    addTearDown(web.stop);
    expect(await web.start(port: 0), isTrue);
    final ws = await WebSocket.connect('ws://127.0.0.1:${web.port}/ws');
    addTearDown(ws.close);
    final packets = ws
        .map((value) => jsonDecode(value as String) as Map<String, dynamic>)
        .asBroadcastStream();
    final initial = await packets
        .firstWhere((p) => p['type'] == 'dac')
        .timeout(const Duration(seconds: 3));
    expect(initial['devices'], isEmpty);
    expect(initial['dac_name'], isEmpty);
    final plugged = packets
        .firstWhere(
            (p) => p['type'] == 'dac' && p['dac_name'] == 'Actual USB DAC')
        .timeout(const Duration(seconds: 3));
    route = {
      'id': 'usb-one',
      'name': 'Actual USB DAC',
      'transport': 'USB',
      'sampleRate': 48000
    };
    await runtime.refreshOutput();
    expect((await plugged)['sample_rate'], 48000);
    final unplugged = packets
        .firstWhere((p) => p['type'] == 'dac' && p['dac_name'] == '')
        .timeout(const Duration(seconds: 3));
    route = null;
    await runtime.refreshOutput();
    expect((await unplugged)['devices'], isEmpty);
  });

  test('remote rescan invokes scanner and surfaces success and failure',
      () async {
    var scans = 0;
    final web = WebRemoteService.forTesting(
        dac: dac,
        scanLibrary: () async {
          scans++;
          if (scans > 1) throw const FileSystemException('原曲库已保留');
          return 2;
        });
    addTearDown(web.stop);
    expect(await web.start(port: 0), isTrue);
    final ws = await WebSocket.connect('ws://127.0.0.1:${web.port}/ws');
    addTearDown(ws.close);
    final packets = ws
        .map((value) => jsonDecode(value as String) as Map<String, dynamic>)
        .asBroadcastStream();
    final success = packets
        .firstWhere((p) => p['type'] == 'scan_complete')
        .timeout(const Duration(seconds: 3));
    ws.add(jsonEncode({'action': 'start_scan'}));
    expect((await success)['track_count'], 2);
    expect(scans, 1);
    final failure = packets
        .firstWhere((p) => p['type'] == 'error')
        .timeout(const Duration(seconds: 3));
    ws.add(jsonEncode({'action': 'start_scan'}));
    expect((await failure)['message'], contains('原曲库已保留'));
    expect(scans, 2);
  });
}
