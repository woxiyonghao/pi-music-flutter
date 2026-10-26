import 'package:flutter/foundation.dart';
import 'music_database_service.dart';

/// 调音魔棒 (MSEB) 状态持久化与跨端双向同步服务
class MsebService extends ChangeNotifier {
  static final MsebService instance = MsebService._();

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  final List<double> _values = List.filled(10, 0.0);
  List<double> get values => List.unmodifiable(_values);

  /// Independent offsets for the engine's 31 Hz … 16 kHz graphic EQ.
  /// This is a tonal mapping; it does not claim time-domain or stereo DSP.
  List<double> get bandOffsets => bandOffsetsFromValues(_values);

  static const _toneCurves = <List<double>>[
    [1.2, 1.0, 0.8, 0.5, 0.2, 0.0, -0.3, -0.7, -1.0, -1.2],
    [3.0, 1.8, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    [0.3, 1.0, 2.0, 0.5, -0.3, 0.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 0.2, 1.0, 2.0, 1.2, 0.2, 0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, -0.3, 0.5, 1.8, 2.5, 0.8, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 1.5, 2.0, -0.4, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 2.5, 0.4],
    [0.0, 0.0, -0.2, -0.5, 0.0, 0.5, 1.8, 2.5, 0.5, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 1.5, 3.0],
    [0.0, 0.0, -0.4, -1.2, -0.8, 0.0, 0.5, 1.0, 1.5, 1.0],
  ];

  @visibleForTesting
  static List<double> bandOffsetsFromValues(List<double> values) {
    final result = List<double>.filled(10, 0);
    for (var parameter = 0; parameter < 10; parameter++) {
      final value = parameter < values.length && values[parameter].isFinite
          ? values[parameter].clamp(-10.0, 10.0) / 10.0
          : 0.0;
      for (var band = 0; band < 10; band++) {
        result[band] += value * _toneCurves[parameter][band];
      }
    }
    return result.map((value) => value.clamp(-12.0, 12.0)).toList();
  }

  MsebService._() {
    _loadFromDatabase();
  }

  void reloadFromDatabase() {
    _loadFromDatabase();
    notifyListeners();
  }

  void _loadFromDatabase() {
    final db = MusicDatabaseService.instance;
    _isEnabled = db.getSetting('mseb_enabled', '0') == '1';
    for (int i = 0; i < 10; i++) {
      final valStr = db.getSetting('mseb_val_$i', '0.0');
      _values[i] = double.tryParse(valStr)?.clamp(-10.0, 10.0) ?? 0.0;
    }
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    MusicDatabaseService.instance
        .setSetting('mseb_enabled', enabled ? '1' : '0');
    notifyListeners();
  }

  void setParam(int index, double value) {
    if (index < 0 || index >= 10) return;
    if (!value.isFinite) return;
    _values[index] = value.clamp(-10.0, 10.0);
    if (value.abs() > 0.05 && !_isEnabled) {
      _isEnabled = true;
      MusicDatabaseService.instance.setSetting('mseb_enabled', '1');
    }
    MusicDatabaseService.instance
        .setSetting('mseb_val_$index', _values[index].toStringAsFixed(1));
    notifyListeners();
  }

  void resetAll() {
    _isEnabled = false;
    MusicDatabaseService.instance.setSetting('mseb_enabled', '0');
    for (int i = 0; i < 10; i++) {
      _values[i] = 0.0;
      MusicDatabaseService.instance.setSetting('mseb_val_$i', '0.0');
    }
    notifyListeners();
  }
}
