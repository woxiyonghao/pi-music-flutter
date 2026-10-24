import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Values reported by iOS itself. Unsupported metrics remain unavailable.
class MobileSystemSnapshot {
  final String? model;
  final String? systemVersion;
  final int? processorCount;
  final int? physicalMemoryBytes;
  final int? appMemoryBytes;
  final String? thermalState;
  final double? batteryLevel;
  final String? batteryState;
  final int? storageTotalBytes;
  final int? storageFreeBytes;

  const MobileSystemSnapshot({
    this.model,
    this.systemVersion,
    this.processorCount,
    this.physicalMemoryBytes,
    this.appMemoryBytes,
    this.thermalState,
    this.batteryLevel,
    this.batteryState,
    this.storageTotalBytes,
    this.storageFreeBytes,
  });

  factory MobileSystemSnapshot.fromMap(Map<Object?, Object?> map) {
    int? number(String key) {
      final value = map[key];
      return value is num && value >= 0 ? value.toInt() : null;
    }

    String? string(String key) {
      final value = map[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final battery = map['batteryLevel'];
    return MobileSystemSnapshot(
      model: string('model'),
      systemVersion: string('systemVersion'),
      processorCount: number('processorCount'),
      physicalMemoryBytes: number('physicalMemoryBytes'),
      appMemoryBytes: number('appMemoryBytes'),
      thermalState: string('thermalState'),
      batteryLevel: battery is num && battery >= 0 && battery <= 1
          ? battery.toDouble()
          : null,
      batteryState: string('batteryState'),
      storageTotalBytes: number('storageTotalBytes'),
      storageFreeBytes: number('storageFreeBytes'),
    );
  }
}

class MobileSystemService extends ChangeNotifier {
  static final instance = MobileSystemService._();
  static const channel = MethodChannel('hifi/system');
  MobileSystemService._();

  @visibleForTesting
  MobileSystemService.forTesting();

  MobileSystemSnapshot _snapshot = const MobileSystemSnapshot();
  MobileSystemSnapshot get snapshot => _snapshot;
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  Timer? _timer;
  bool _refreshing = false;
  int _listeners = 0;

  void startMonitoring() {
    _listeners++;
    unawaited(refresh());
    if (Platform.isIOS && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _timer ??= Timer.periodic(const Duration(seconds: 2), (_) => refresh());
    }
  }

  void stopMonitoring() {
    if (_listeners > 0) _listeners--;
    if (_listeners == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final map =
          await channel.invokeMapMethod<Object?, Object?>('getSystemInfo');
      if (map != null) {
        _snapshot = MobileSystemSnapshot.fromMap(map);
        _updatedAt = DateTime.now();
        notifyListeners();
      }
    } on MissingPluginException {
      // Preview/test environments have no iOS system bridge.
    } on PlatformException catch (error) {
      debugPrint('System telemetry unavailable: ${error.code}');
    } finally {
      _refreshing = false;
    }
  }
}
