import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';
import 'package:hide_player_flutter/services/mseb_service.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/services/web_remote_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await WebRemoteService.instance.stop();
    DacSettingService.instance.setChip(0);
  });

  group('DacSettingService Tests', () {
    test('setChip updates selectedChip and persists', () {
      final dac = DacSettingService.instance;
      bool notified = false;
      void listener() {
        notified = true;
      }
      dac.addListener(listener);

      dac.setChip(1); // ES9038PRO
      expect(dac.selectedChip, equals(1));
      expect(dac.dacName, equals('ES9038PRO'));
      expect(dac.hasExternalDac, isTrue);
      expect(notified, isTrue);
      expect(MusicDatabaseService.instance.getSetting('setting_dac_selected_chip', ''), equals('1'));

      dac.removeListener(listener);
    });

    test('setParam updates parameters and persists correctly', () {
      final dac = DacSettingService.instance;
      dac.setParam('pcm_filter', 3);
      expect(dac.getParam('pcm_filter'), equals(3));
      expect(MusicDatabaseService.instance.getSetting('setting_dac_pcm_filter', ''), equals('3'));

      // Test key with prefix
      dac.setParam('setting_dac_akm_color', 2);
      expect(dac.getParam('akm_color'), equals(2));
      expect(MusicDatabaseService.instance.getSetting('setting_dac_akm_color', ''), equals('2'));
    });
  });

  group('EQ Atomic and Preset Updates', () {
    test('setEqAndBands updates both enabled and bands synchronously', () {
      final audio = HifiAudioService.instance;
      final trebleBoost = [0.0, 0.0, 0.5, 1.0, 2.0, 3.5, 5.0, 6.5, 7.5, 8.0];

      audio.setEqAndBands(true, trebleBoost, selectedPreset: 3);
      expect(audio.eqEnabled, isTrue);
      expect(audio.eqBands, equals(trebleBoost));
      expect(MusicDatabaseService.instance.getSetting('eq_selected_preset', ''), equals('3'));
    });
  });

  group('MSEB Auto-Enable & Persistence', () {
    test('setParam auto-enables and updates value', () {
      final mseb = MsebService.instance;
      mseb.setEnabled(false);
      expect(mseb.isEnabled, isFalse);

      mseb.setParam(0, 5.0);
      expect(mseb.isEnabled, isTrue);
      expect(mseb.values[0], equals(5.0));
      expect(MusicDatabaseService.instance.getSetting('mseb_enabled', ''), equals('1'));
      expect(MusicDatabaseService.instance.getSetting('mseb_val_0', ''), equals('5.0'));
    });
  });

  group('WebRemoteService to DAC WebSocket Sync Tests', () {
    test('WebSocket receives DAC update on set_dac_chip and set_dac_param', () async {
      final remote = WebRemoteService.instance;
      final started = await remote.start(port: 18099);
      expect(started, isTrue);

      final ws = await WebSocket.connect('ws://127.0.0.1:18099');
      final messages = <Map<String, dynamic>>[];

      final sub = ws.listen((data) {
        if (data is String) {
          try {
            messages.add(jsonDecode(data) as Map<String, dynamic>);
          } catch (_) {}
        }
      });

      // Wait for initial handshake messages
      await Future.delayed(const Duration(milliseconds: 150));
      final initialDac = messages.firstWhere((m) => m['type'] == 'dac', orElse: () => {});
      expect(initialDac.isNotEmpty, isTrue);

      // Client sends set_dac_chip
      ws.add(jsonEncode({
        'action': 'set_dac_chip',
        'chip': 2, // AK4499EX
      }));
      await Future.delayed(const Duration(milliseconds: 150));

      expect(DacSettingService.instance.selectedChip, equals(2));
      final chipUpdate = messages.lastWhere((m) => m['type'] == 'dac');
      expect(chipUpdate['selected_chip'], equals(2));
      expect(chipUpdate['dac_name'], equals('AK4499EX'));

      // Client sends set_dac_param
      ws.add(jsonEncode({
        'action': 'set_dac_param',
        'key': 'akm_filter',
        'val': 4,
      }));
      await Future.delayed(const Duration(milliseconds: 150));

      expect(DacSettingService.instance.getParam('akm_filter'), equals(4));
      final paramUpdate = messages.lastWhere((m) => m['type'] == 'dac');
      expect(paramUpdate['params']['akm_filter'], equals(4));

      await sub.cancel();
      await ws.close();
    });
  });
}
