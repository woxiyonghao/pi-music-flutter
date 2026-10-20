import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/dac_device_info.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_dac_setting_view.dart';

String devicesWithDefault(String activeId) => jsonEncode([
      for (final device in [
        {'id': 'airpods', 'name': 'AirPods Pro', 'transport': 'Bluetooth'},
        {'id': 'hdmi', 'name': 'LS27B61x', 'transport': 'HDMI / DP'},
        {
          'id': 'speakers',
          'name': 'Mac mini扬声器',
          'transport': 'BuiltIn',
          'isBuiltIn': true
        },
        {'id': 'dx12', 'name': 'TOPPING DX12', 'transport': 'USB'},
      ])
        {
          ...device,
          'isDefault': device['id'] == activeId,
          'currentSampleRate': 48000
        },
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('display transport detection keeps USB DACs regardless of their name',
      () {
    for (final bus in [
      'HDMI',
      'HDMI / DP',
      'DisplayPort',
      'Display Port',
      'DP'
    ]) {
      expect(
          DacDeviceInfo.fromJson({'transport': bus}).isDisplayOutput, isTrue);
    }
    for (final bus in ['Bluetooth', 'USB', 'BuiltIn', 'BuiltIn (I2S)']) {
      expect(
          DacDeviceInfo.fromJson(
                  {'name': 'HDMI / DisplayPort DAC', 'transport': bus})
              .isDisplayOutput,
          isFalse);
    }
  });

  test('macOS cards and remote requests cannot change the system output', () {
    var devices = devicesWithDefault('airpods');
    final attempts = <String>[];
    final service = DacSettingService.forTesting(
      readDevices: () => devices,
      selectOutput: (id) {
        attempts.add(id);
        return true;
      },
      followsSystemOutput: true,
    );
    addTearDown(service.dispose);

    for (final index in [-1, 0, 1, 2, 3, 99]) {
      expect(service.canSelectDevice(index), isFalse);
      service.selectDevice(index);
    }
    expect(attempts, isEmpty);
    expect(service.currentDevice?.id, 'airpods');
    expect(service.connectedDevices.map((device) => device.id),
        ['airpods', 'speakers', 'dx12']);

    // USB DAC remains visible; a real system route change activates it on refresh.
    expect(service.connectedDevices.last.name, 'TOPPING DX12');
    devices = devicesWithDefault('dx12');
    service.refreshDevices();
    expect(service.currentDevice?.id, 'dx12');
    expect(attempts, isEmpty);
  });

  test('selectable backends retain selection and active-card taps are a no-op',
      () {
    final attempts = <String>[];
    final service = DacSettingService.forTesting(
      readDevices: () => devicesWithDefault('airpods'),
      selectOutput: (id) {
        attempts.add(id);
        return true;
      },
      followsSystemOutput: false,
    );
    addTearDown(service.dispose);
    service.selectDevice(0);
    expect(attempts, isEmpty);
    service.selectDevice(2);
    service.selectDevice(2);
    expect(attempts, ['dx12']);
    expect(service.currentDevice?.id, 'dx12');
  });

  testWidgets(
      'inactive physical devices are grey and have no tap handler before interaction',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var devices = devicesWithDefault('airpods');
    final attempts = <String>[];
    final service = DacSettingService.forTesting(
      readDevices: () => devices,
      selectOutput: (id) {
        attempts.add(id);
        return true;
      },
      followsSystemOutput: true,
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MacDACSettingView(
      platform: HifiPlatformType.mac,
      service: service,
    ))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dac-device-hdmi')), findsNothing);
    expect(find.text('LS27B61x'), findsNothing);
    for (final id in ['speakers', 'dx12']) {
      final card = find.byKey(ValueKey('dac-device-$id'));
      expect(tester.widget<GestureDetector>(card).onTap, isNull);
      final opacity =
          find.ancestor(of: card, matching: find.byType(Opacity)).first;
      expect(tester.widget<Opacity>(opacity).opacity, 0.4);
      await tester.tap(card);
    }
    expect(attempts, isEmpty);
    expect(service.currentDevice?.id, 'airpods');
    expect(find.textContaining('显示器输出已过滤'), findsOneWidget);

    devices = devicesWithDefault('dx12');
    service.refreshDevices();
    await tester.pumpAndSettle();
    expect(service.currentDevice?.id, 'dx12');
    final card = find.byKey(const ValueKey('dac-device-dx12'));
    final opacity =
        find.ancestor(of: card, matching: find.byType(Opacity)).first;
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(attempts, isEmpty);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  test('a filtered default is never misrepresented as the first allowed device',
      () {
    final service = DacSettingService.forTesting(
      readDevices: () => devicesWithDefault('hdmi'),
      selectOutput: (_) =>
          throw StateError('Refreshing must not switch system output'),
      followsSystemOutput: true,
    );
    addTearDown(service.dispose);
    expect(service.connectedDevices.any((d) => d.isDisplayOutput), isFalse);
    expect(service.selectedDeviceIndex, -1);
    expect(service.currentDevice, isNull);
  });

  test('an empty real device list does not invent a built-in speaker', () {
    final service = DacSettingService.forTesting(
      readDevices: () => '[{"id":"hdmi","transport":"HDMI","isDefault":true}]',
      selectOutput: (_) => false,
      followsSystemOutput: true,
    );
    addTearDown(service.dispose);
    expect(service.connectedDevices, isEmpty);
    expect(service.currentDevice, isNull);
  });

  testWidgets('active Mac mini exposes editable built-in audio settings',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = DacSettingService.forTesting(
      readDevices: () => devicesWithDefault('speakers'),
      selectOutput: (_) =>
          throw StateError('Editing a preference must not switch devices'),
      followsSystemOutput: true,
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MacDACSettingView(
      platform: HifiPlatformType.mac,
      service: service,
    ))));
    await tester.pumpAndSettle();
    expect(service.currentDevice?.id, 'speakers');
    final card = find.byKey(const ValueKey('dac-device-speakers'));
    final opacity =
        find.ancestor(of: card, matching: find.byType(Opacity)).first;
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(find.text('系统音频输出与兼容设置'), findsOneWidget);
    final audio = HifiAudioService.instance;
    final previousVolume = audio.state.volume;
    addTearDown(() => audio.setVolume(previousVolume));
    final volume = find.byKey(const ValueKey('builtin-output-volume'));
    expect(volume, findsOneWidget);
    await tester.drag(volume, const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(audio.state.volume, lessThan(previousVolume));
    final bufferOption = find.text('512 帧 (11.6ms)');
    await tester.ensureVisible(bufferOption);
    await tester.tap(bufferOption);
    await tester.pumpAndSettle();
    expect(service.getParam('builtin_buffer_size'), 3);
    expect(service.currentDevice?.id, 'speakers');
    expect(find.text('LS27B61x'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
