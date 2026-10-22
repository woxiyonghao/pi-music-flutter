import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';
import 'package:hide_player_flutter/services/web_remote_service.dart';

void main() {
  test('Web DAC reflects the real route and hotplug while playback is idle',
      () async {
    var devices = [
      {
        'id': 'airpods',
        'name': 'AirPods Pro',
        'isDefault': true,
        'transport': 'Bluetooth',
        'currentSampleRate': 48000,
      },
      {
        'id': 'display',
        'name': 'Display audio',
        'transport': 'HDMI',
        'currentSampleRate': 48000,
      },
    ];
    final dac = DacSettingService.forTesting(
      readDevices: () => jsonEncode(devices),
      selectOutput: (_) => throw StateError('Remote status is read-only'),
      followsSystemOutput: true,
    );
    final web = WebRemoteService.forTesting(dac: dac);
    addTearDown(() async {
      await web.stop();
      web.dispose();
      dac.dispose();
    });

    final portReservation =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = portReservation.port;
    await portReservation.close();
    expect(await web.start(port: port), isTrue);

    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/'));
    final response = await request.close();
    final html = await response.transform(utf8.decoder).join();
    expect(response.headers.value(HttpHeaders.cacheControlHeader), 'no-store');
    expect(html, contains('dacDevicesGrid'));
    for (final unsupported in [
      '6 大名片解码芯片架构选择',
      '芯片专属发烧硬件参数配置',
      'apple_exclusive',
      'apple_sample_rate',
      'apple_drive',
      'apple_bit_depth',
      'set_dac_chip',
      'set_dac_param',
    ]) {
      expect(html, isNot(contains(unsupported)));
    }

    final socket = await WebSocket.connect('ws://127.0.0.1:$port/ws');
    final packets = StreamIterator(socket
        .where((data) => jsonDecode(data as String)['type'] == 'dac')
        .map((data) => jsonDecode(data as String) as Map<String, dynamic>));
    addTearDown(() async {
      await packets.cancel();
      await socket.close();
    });
    Future<Map<String, dynamic>> nextDac() async {
      expect(
          await packets.moveNext().timeout(const Duration(seconds: 5)), isTrue);
      return packets.current;
    }

    final initial = await nextDac();
    expect(initial['dac_name'], 'AirPods Pro');
    expect(initial['transport'], 'Bluetooth');
    expect(initial['sample_rate'], 48000);
    expect(initial['follows_system_output'], isTrue);
    expect(initial['devices'], hasLength(1));
    expect(initial['devices'][0]['is_active'], isTrue);
    expect(initial.containsKey('params'), isFalse);
    expect(initial.containsKey('selected_chip'), isFalse);

    devices = [
      {
        'id': 'usb-dac',
        'name': 'Connected USB DAC',
        'isDefault': true,
        'transport': 'USB',
        'currentSampleRate': 96000,
      },
    ];
    final switched = await nextDac();
    expect(switched['dac_name'], 'Connected USB DAC');
    expect(switched['sample_rate'], 96000);
    expect(switched['devices'][0]['id'], 'usb-dac');

    devices = [];
    final disconnected = await nextDac();
    expect(disconnected['devices'], isEmpty);
    expect(disconnected['dac_name'], isEmpty);
    expect(disconnected['sample_rate'], 0);
  });
}
