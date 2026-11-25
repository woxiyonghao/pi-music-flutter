import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/hifi_audio_service.dart';
import 'dac_setting_service.dart';

enum WirelessAudioMode {
  none,
  bluetooth,
  airplay,
}

typedef WirelessCommandRunner = Future<ProcessResult> Function(
    String executable, List<String> arguments);

/// Coordinates Raspberry Pi wireless audio receiver modes (Bluetooth A2DP sink
/// and AirPlay) with local playback so both share the USB DAC cleanly.
///
/// Default state is [WirelessAudioMode.none] (both switches OFF, local music
/// active), with [WirelessAudioMode.bluetooth] as the preferred wireless mode.
class WirelessAudioService extends ChangeNotifier {
  static final WirelessAudioService instance = WirelessAudioService._();

  static const String deviceBroadcastName = 'PhonoraMusic';

  final WirelessCommandRunner _runCommand;
  final void Function() _releaseLocalOutput;
  final void Function() _reclaimLocalOutput;
  final Future<void> Function() _restoreDac;
  final bool _isLinuxOverride;

  WirelessAudioMode _activeMode = WirelessAudioMode.none;
  WirelessAudioMode get activeMode => _activeMode;

  /// Default wireless selection (shown first in UI).
  final WirelessAudioMode defaultWirelessMode = WirelessAudioMode.bluetooth;

  bool get isBluetoothEnabled => _activeMode == WirelessAudioMode.bluetooth;
  bool get isAirplayEnabled => _activeMode == WirelessAudioMode.airplay;
  bool get isWirelessActive => _activeMode != WirelessAudioMode.none;

  bool _isSwitching = false;
  bool get isSwitching => _isSwitching;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _connectedBluetoothDevice;
  String? get connectedBluetoothDevice => _connectedBluetoothDevice;

  bool _initialized = false;
  Timer? _btPollTimer;

  WirelessAudioService._()
      : _runCommand = Process.run,
        _releaseLocalOutput = HifiAudioService.instance.releaseOutput,
        _reclaimLocalOutput = HifiAudioService.instance.reclaimOutput,
        _restoreDac = DacSettingService.instance.restoreDx1iiHardwareSettings,
        _isLinuxOverride = false;

  @visibleForTesting
  WirelessAudioService.forTesting({
    required WirelessCommandRunner runCommand,
    required void Function() releaseLocalOutput,
    required void Function() reclaimLocalOutput,
    required Future<void> Function() restoreDac,
    bool isLinux = true,
  })  : _runCommand = runCommand,
        _releaseLocalOutput = releaseLocalOutput,
        _reclaimLocalOutput = reclaimLocalOutput,
        _restoreDac = restoreDac,
        _isLinuxOverride = isLinux;

  bool get _isLinux => _isLinuxOverride || Platform.isLinux;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    HifiAudioService.instance.beforeLocalPlaybackHook =
        ensureLocalPlaybackReady;

    if (_isLinux && !Platform.environment.containsKey('FLUTTER_TEST')) {
      // Ensure wireless receivers start OFF on boot so local music owns the DAC.
      await _stopBluetoothServices();
      await _stopAirplayServices();
    }
  }

  Future<void> setBluetoothEnabled(bool enabled) async {
    await _switchTo(enabled ? WirelessAudioMode.bluetooth : WirelessAudioMode.none);
  }

  Future<void> setAirplayEnabled(bool enabled) async {
    await _switchTo(enabled ? WirelessAudioMode.airplay : WirelessAudioMode.none);
  }

  /// Called automatically before playing a local track so the DAC is reclaimed.
  Future<void> ensureLocalPlaybackReady() async {
    if (_activeMode == WirelessAudioMode.none) return;
    await _switchTo(WirelessAudioMode.none);
  }

  Future<void> _switchTo(WirelessAudioMode target) async {
    if (_isSwitching || _activeMode == target) return;
    _isSwitching = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (target == WirelessAudioMode.none) {
        await _disableAll();
        _activeMode = WirelessAudioMode.none;
        _reclaimLocalOutput();
        await _restoreDac();
      } else {
        // Release local ALSA handle before starting an external DAC consumer.
        _releaseLocalOutput();
        await _disableAll();

        if (target == WirelessAudioMode.bluetooth) {
          await _enableBluetooth();
        } else {
          await _enableAirplay();
        }
        _activeMode = target;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      // Best-effort cleanup back to local mode on activation failure.
      if (target != WirelessAudioMode.none) {
        await _disableAll();
        _activeMode = WirelessAudioMode.none;
        _reclaimLocalOutput();
        await _restoreDac();
      }
    } finally {
      _isSwitching = false;
      notifyListeners();
    }
  }

  Future<void> _disableAll() async {
    _stopBluetoothPoll();
    _connectedBluetoothDevice = null;
    if (!_isLinux) return;
    await _stopBluetoothServices();
    await _stopAirplayServices();
  }

  Future<void> _enableBluetooth() async {
    if (!_isLinux) return;
    await _execChecked('sudo', ['bluetoothctl', 'power', 'on']);
    await _execChecked('sudo', ['systemctl', 'start', 'bluealsa']);
    await _execChecked('sudo', ['systemctl', 'start', 'bluealsa-aplay']);
    await _runSafe('sudo', ['systemctl', 'start', 'phonora-bt-agent']);
    await _runSafe('sudo', ['bluetoothctl', 'system-alias', deviceBroadcastName]);
    await _runSafe('sudo', ['bluetoothctl', 'pairable', 'on']);
    await _runSafe('sudo', ['bluetoothctl', 'discoverable', 'on']);
    await _refreshConnectedBluetoothDevice();
    _startBluetoothPoll();
  }

  Future<void> _enableAirplay() async {
    if (!_isLinux) return;
    await _runSafe('sudo', ['systemctl', 'start', 'nqptp']);
    await _execChecked('sudo', ['systemctl', 'start', 'shairport-sync']);
  }

  Future<void> _stopBluetoothServices() async {
    await _runSafe('sudo', ['bluetoothctl', 'discoverable', 'off']);
    await _runSafe('sudo', ['systemctl', 'stop', 'bluealsa-aplay']);
    await _runSafe('sudo', ['systemctl', 'stop', 'bluealsa']);
    await _runSafe('sudo', ['systemctl', 'stop', 'phonora-bt-agent']);
  }

  Future<void> _stopAirplayServices() async {
    await _runSafe('sudo', ['systemctl', 'stop', 'shairport-sync']);
    await _runSafe('sudo', ['systemctl', 'stop', 'nqptp']);
  }

  Future<void> _execChecked(String exe, List<String> args) async {
    final res = await _runCommand(exe, args);
    if (res.exitCode != 0) {
      final err = '${res.stderr}'.trim();
      throw Exception(err.isNotEmpty ? err : '命令执行失败: $exe ${args.join(' ')}');
    }
  }

  Future<ProcessResult?> _runSafe(String exe, List<String> args) async {
    try {
      return await _runCommand(exe, args);
    } catch (_) {
      return null;
    }
  }

  void _startBluetoothPoll() {
    _stopBluetoothPoll();
    if (!_isLinux || Platform.environment.containsKey('FLUTTER_TEST')) return;
    _btPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_activeMode == WirelessAudioMode.bluetooth) {
        await _refreshConnectedBluetoothDevice();
      }
    });
  }

  void _stopBluetoothPoll() {
    _btPollTimer?.cancel();
    _btPollTimer = null;
  }

  Future<void> _refreshConnectedBluetoothDevice() async {
    final res = await _runSafe('bluetoothctl', ['devices', 'Connected']);
    if (res == null || res.exitCode != 0) return;
    final lines = '${res.stdout}'
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('Device '))
        .toList();
    String? name;
    if (lines.isNotEmpty) {
      // Format: "Device AA:BB:CC:DD:EE:FF iPhone"
      final parts = lines.first.split(' ');
      if (parts.length >= 3) {
        name = parts.sublist(2).join(' ').trim();
      }
    }
    if (name != _connectedBluetoothDevice) {
      _connectedBluetoothDevice = name;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopBluetoothPoll();
    super.dispose();
  }
}
