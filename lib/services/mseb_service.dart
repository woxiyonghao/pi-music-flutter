import 'package:flutter/foundation.dart';
import 'music_database_service.dart';

/// 调音魔棒 (MSEB) 状态持久化与跨端双向同步服务
class MsebService extends ChangeNotifier {
  static final MsebService instance = MsebService._();

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  final List<double> _values = List.filled(10, 0.0);
  List<double> get values => List.unmodifiable(_values);

  MsebService._() {
    _loadFromDatabase();
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
    MusicDatabaseService.instance.setSetting('mseb_enabled', enabled ? '1' : '0');
    notifyListeners();
  }

  void setParam(int index, double value) {
    if (index < 0 || index >= 10) return;
    _values[index] = value.clamp(-10.0, 10.0);
    if (value.abs() > 0.05 && !_isEnabled) {
      _isEnabled = true;
      MusicDatabaseService.instance.setSetting('mseb_enabled', '1');
    }
    MusicDatabaseService.instance.setSetting('mseb_val_$index', _values[index].toStringAsFixed(1));
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
