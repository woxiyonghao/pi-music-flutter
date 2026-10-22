import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A snapshot of macOS counters. Missing readings stay unknown, never zero-filled.
@immutable
class MacSystemSnapshot {
  final Map<String, dynamic> _data;
  MacSystemSnapshot.fromMap(Map<String, dynamic> data)
      : _data = Map.unmodifiable(data);

  String? text(String key) {
    final value = _data[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  double? number(String key) {
    final value = _data[key];
    return value is num && value.isFinite && value >= 0
        ? value.toDouble()
        : null;
  }

  bool? flag(String key) => _data[key] is bool ? _data[key] as bool : null;
  double? get cpuPercent => number('cpuPercent')?.clamp(0, 100);
  List<double> get corePercents =>
      (_data['corePercents'] is List ? _data['corePercents'] as List : const [])
          .whereType<num>()
          .where((value) => value.isFinite)
          .map((value) => value.toDouble().clamp(0.0, 100.0))
          .toList(growable: false);

  double? get memoryRatio => _ratio('memoryUsedBytes', 'memoryTotalBytes');
  double? get storageFreeRatio =>
      _ratio('storageFreeBytes', 'storageTotalBytes');
  double? _ratio(String numerator, String denominator) {
    final a = number(numerator);
    final b = number(denominator);
    return a != null && b != null && b > 0 ? (a / b).clamp(0, 1) : null;
  }

  String get thermalLabel => switch (text('thermalState')) {
        'nominal' => '正常',
        'fair' => '温热',
        'serious' => '高温',
        'critical' => '过热',
        _ => '未提供',
      };
  String get powerLabel => switch (text('powerSource')) {
        'AC Power' => '交流电源',
        'Battery Power' => '电池供电',
        'UPS Power' => 'UPS 供电',
        _ => '未提供',
      };
}

/// Polled once per second, only while a hardware dashboard is mounted.
class MacSystemService extends ChangeNotifier {
  static final instance = MacSystemService();
  final MethodChannel _channel;
  Timer? _timer;
  int _clients = 0;
  bool _reading = false;
  bool _disposed = false;
  MacSystemSnapshot? snapshot;
  DateTime? updatedAt;
  bool isUnavailable = false;

  MacSystemService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('pihifi/macos_system');

  void attach() {
    if (_disposed || ++_clients != 1) return;
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  void detach() {
    if (_clients == 0) return;
    if (--_clients == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> refresh() async {
    if (_reading || _disposed) return;
    _reading = true;
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('snapshot');
      if (!_disposed) {
        if (data == null) throw const FormatException('Empty macOS snapshot');
        snapshot = MacSystemSnapshot.fromMap(data);
        updatedAt = DateTime.now();
        isUnavailable = false;
      }
    } catch (_) {
      // Keep the last sample visible, and explicitly mark it as stale.
      if (!_disposed) isUnavailable = true;
    } finally {
      _reading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
