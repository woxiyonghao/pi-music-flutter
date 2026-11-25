import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/models/sidebar_tab.dart';
import 'package:hide_player_flutter/services/wireless_audio_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/mac/mac_sidebar_widget.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_wireless_audio_view.dart';

void main() {
  group('WirelessAudioService', () {
    test('defaults to OFF (local music) with Bluetooth as default wireless mode',
        () {
      final service = WirelessAudioService.forTesting(
        runCommand: (exe, args) async => ProcessResult(0, 0, '', ''),
        releaseLocalOutput: () {},
        reclaimLocalOutput: () {},
        restoreDac: () async {},
      );
      addTearDown(service.dispose);

      expect(service.activeMode, WirelessAudioMode.none);
      expect(service.defaultWirelessMode, WirelessAudioMode.bluetooth);
      expect(service.isBluetoothEnabled, isFalse);
      expect(service.isAirplayEnabled, isFalse);
      expect(service.isWirelessActive, isFalse);
    });

    test('Bluetooth and AirPlay are mutually exclusive and release/reclaim DAC',
        () async {
      final commands = <String>[];
      int released = 0;
      int reclaimed = 0;
      int restored = 0;

      final service = WirelessAudioService.forTesting(
        runCommand: (exe, args) async {
          commands.add('$exe ${args.join(' ')}');
          if (exe == 'bluetoothctl' && args.contains('Connected')) {
            return ProcessResult(0, 0, 'Device AA:BB:CC:DD:EE:FF iPhone 16\n', '');
          }
          return ProcessResult(0, 0, '', '');
        },
        releaseLocalOutput: () => released++,
        reclaimLocalOutput: () => reclaimed++,
        restoreDac: () async => restored++,
      );
      addTearDown(service.dispose);

      await service.setBluetoothEnabled(true);
      expect(service.isBluetoothEnabled, isTrue);
      expect(service.isAirplayEnabled, isFalse);
      expect(service.connectedBluetoothDevice, 'iPhone 16');
      expect(released, 1);
      expect(commands, contains('sudo systemctl start bluealsa-aplay'));
      expect(commands, contains('sudo systemctl stop shairport-sync'));

      commands.clear();
      await service.setAirplayEnabled(true);
      expect(service.isBluetoothEnabled, isFalse);
      expect(service.isAirplayEnabled, isTrue);
      expect(service.connectedBluetoothDevice, isNull);
      expect(released, 2);
      expect(commands, contains('sudo systemctl stop bluealsa-aplay'));
      expect(commands, contains('sudo systemctl start shairport-sync'));

      await service.ensureLocalPlaybackReady();
      expect(service.activeMode, WirelessAudioMode.none);
      expect(reclaimed, 1);
      expect(restored, 1);
    });

    test('rolls back to local playback if starting receiver fails', () async {
      int reclaimed = 0;
      final service = WirelessAudioService.forTesting(
        runCommand: (exe, args) async {
          if (args.contains('shairport-sync') && args.contains('start')) {
            return ProcessResult(0, 1, '', 'unit failed');
          }
          return ProcessResult(0, 0, '', '');
        },
        releaseLocalOutput: () {},
        reclaimLocalOutput: () => reclaimed++,
        restoreDac: () async {},
      );
      addTearDown(service.dispose);

      await service.setAirplayEnabled(true);
      expect(service.activeMode, WirelessAudioMode.none);
      expect(service.errorMessage, contains('unit failed'));
      expect(reclaimed, 1);
    });
  });

  group('Wireless Play UI', () {
    testWidgets('Sidebar renders 无线播放 below WiFi传歌 and selects wirelessPlay',
        (tester) async {
      SidebarTab? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: HifiTheme.darkTheme,
          home: Scaffold(
            body: MacSidebarWidget(
              currentTab: SidebarTab.wifiTransfer,
              playlists: const [],
              selectedPlaylistId: 0,
              onTabSelected: (t) => selected = t,
              onPlaylistSelected: (_) {},
              onCreatePlaylist: () {},
              onDacClicked: () {},
            ),
          ),
        ),
      );

      final wifiCenter = tester.getCenter(find.text('WiFi传歌'));
      final wirelessCenter = tester.getCenter(find.text('无线播放'));
      expect(wirelessCenter.dy, greaterThan(wifiCenter.dy));

      await tester.tap(find.text('无线播放'));
      expect(selected, SidebarTab.wirelessPlay);
    });

    testWidgets('MacWirelessAudioView shows 蓝牙 and AirPlay switches default OFF',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: HifiTheme.darkTheme,
          home: const Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: MacWirelessAudioView(),
            ),
          ),
        ),
      );

      expect(find.text('无线播放'), findsOneWidget);
      expect(find.text('蓝牙'), findsOneWidget);
      expect(find.text('AirPlay'), findsOneWidget);

      final btSwitch = tester
          .widget<Switch>(find.byKey(const Key('wireless-bluetooth-switch')));
      final airSwitch = tester
          .widget<Switch>(find.byKey(const Key('wireless-airplay-switch')));
      expect(btSwitch.value, isFalse);
      expect(airSwitch.value, isFalse);
    });
  });
}
