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
    // 0: 声音冷暖 (Sound Temperature): 偏冷通透 (-10) <-> 偏暖醇厚 (+10)
    [5.0, 4.0, 3.2, 2.0, 1.0, -0.5, -1.8, -3.0, -4.2, -5.0],
    // 1: 低音下潜 (Bass Extension): 紧致轻盈 (-10) <-> 深沉澎湃 (+10) - 强力下潜至 31.25Hz 与 62.5Hz
    [9.5, 7.5, 3.5, 0.8, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    // 2: 低音质感 (Bass Texture): 速度迅捷 (-10) <-> 蓬松弹性 (+10) - 覆盖 62.5Hz, 125Hz, 250Hz 打击质感
    [1.5, 5.5, 8.5, 5.0, 1.2, 0.0, 0.0, 0.0, 0.0, 0.0],
    // 3: 音符厚度 (Note Thickness): 纤细轻盈 (-10) <-> 扎实饱满 (+10) - 基频 125Hz-500Hz
    [0.5, 2.0, 5.5, 7.5, 4.0, 1.5, 0.0, 0.0, 0.0, 0.0],
    // 4: 人声位置 (Vocal Distance): 舞台后缩 (-10) <-> 贴耳靠前 (+10) - 1kHz-2kHz 结像
    [0.0, 0.0, -0.5, -1.5, 2.0, 6.5, 8.0, 3.0, 0.0, 0.0],
    // 5: 女声甜度 (Female Overtones): 自然平直 (-10) <-> 润泽甜美 (+10) - 2kHz-4kHz 泛音
    [0.0, 0.0, 0.0, 0.0, 0.5, 2.5, 7.0, 7.5, 1.0, 0.0],
    // 6: 齿音消除 (Sibilance Control): 柔化去刺 (-10) <-> 原生锋芒 (+10) - 4kHz-8kHz 唇齿音
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -0.8, 4.0, 8.5, 3.0],
    // 7: 瞬态存在感 (Attack Presence): 柔和松弛 (-10) <-> 硬朗凌厉 (+10) - 2kHz-4kHz 打击瞬态
    [0.0, 0.0, -1.0, -2.0, 0.0, 2.5, 6.5, 8.0, 2.5, 0.0],
    // 8: 空气感 (Air & Treble): 凝聚内敛 (-10) <-> 空灵弥漫 (+10) - 8kHz-16kHz 极高频
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 6.0, 9.5],
    // 9: 声场明亮度 (Stage Brightness): 紧凑聚焦 (-10) <-> 宏大宽广 (+10)
    [-2.0, -2.5, -2.5, -1.5, 0.0, 1.5, 3.5, 5.5, 7.0, 5.0],
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
