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
/// and AirPlay 2) through [HifiAudioService] / `audio_engine` via `snd-aloop`,
/// enabling real-time VU meters, 12-band spectrum, and 10-band EQ on wireless streams.
class WirelessAudioService extends ChangeNotifier {
  static final WirelessAudioService instance = WirelessAudioService._();

  static const String deviceBroadcastName = 'PhonoraMusic';
  static const String loopbackCaptureDevice = 'plughw:CARD=PhonoraLoop,DEV=1,SUBDEV=0';

  final WirelessCommandRunner _runCommand;
  final bool Function({required String title, required String subtitle}) _startLiveCapture;
  final void Function() _stopLiveCapture;
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
        _startLiveCapture = (({required String title, required String subtitle}) =>
            HifiAudioService.instance.startLiveWirelessSession(
              title: title,
              subtitle: subtitle,
              captureDevice: loopbackCaptureDevice,
            )),
        _stopLiveCapture = HifiAudioService.instance.stopLiveWirelessSession,
        _restoreDac = DacSettingService.instance.restoreDx1iiHardwareSettings,
        _isLinuxOverride = false;

  @visibleForTesting
  WirelessAudioService.forTesting({
    required WirelessCommandRunner runCommand,
    required bool Function({required String title, required String subtitle})
        startLiveCapture,
    required void Function() stopLiveCapture,
    required Future<void> Function() restoreDac,
    bool isLinux = true,
  })  : _runCommand = runCommand,
        _startLiveCapture = startLiveCapture,
        _stopLiveCapture = stopLiveCapture,
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
    await _switchTo(
        enabled ? WirelessAudioMode.bluetooth : WirelessAudioMode.none);
  }

  Future<void> setAirplayEnabled(bool enabled) async {
    await _switchTo(
        enabled ? WirelessAudioMode.airplay : WirelessAudioMode.none);
  }

  /// Called automatically before playing a local track so wireless receivers stop.
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
        _stopLiveCapture();
        _activeMode = WirelessAudioMode.none;
        await _restoreDac();
      } else {
        await _disableAll();

        final ok = target == WirelessAudioMode.bluetooth
            ? _startLiveCapture(
                title: '蓝牙无线音频',
                subtitle: 'Bluetooth A2DP · PhonoraMusic',
              )
            : _startLiveCapture(
                title: 'AirPlay 2 无线音频',
                subtitle: 'Apple AirPlay 2 · PhonoraMusic',
              );
        if (!ok) {
          throw Exception('音频引擎实时采集通道打开失败 ($loopbackCaptureDevice)');
        }

        if (target == WirelessAudioMode.bluetooth) {
          await _enableBluetooth();
        } else {
          await _enableAirplay();
        }
        _activeMode = target;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (target != WirelessAudioMode.none) {
        await _disableAll();
        _stopLiveCapture();
        _activeMode = WirelessAudioMode.none;
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
