import 'package:flutter/material.dart';
import 'music_database_service.dart';

/// 预设主题实体 (1:1 严格对齐 C++ ThemeManager::ThemePresetInfo)
class ThemePreset {
  final int id;
  final String name;
  final String englishName;
  final String soundStyle;
  final Color accentColor;
  final Color litColor;
  final Color peakColor;
  final int defaultVisualMode;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.englishName,
    required this.soundStyle,
    required this.accentColor,
    required this.litColor,
    required this.peakColor,
    required this.defaultVisualMode,
  });
}

/// 全局主题响应式服务单例 (严格对齐 C++ ThemeManager，并支持 SQLite 完整持久化)
class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._internal();

  static const List<ThemePreset> presets = [
    ThemePreset(
      id: 0,
      name: '现代深空玫红',
      englishName: 'Modern Crimson',
      soundStyle: '高解析流行 · 极简通透',
      accentColor: Color(0xFFFA2D48),
      litColor: Color.fromRGBO(250, 45, 72, 140 / 255),
      peakColor: Color.fromRGBO(255, 120, 140, 230 / 255),
      defaultVisualMode: 0,
    ),
    ThemePreset(
      id: 1,
      name: '麦景图湖蓝',
      englishName: 'McIntosh Blue Eyes',
      soundStyle: '大动态交响 · 磅礴大气',
      accentColor: Color(0xFF00B4D8),
      litColor: Color.fromRGBO(0, 180, 240, 150 / 255),
      peakColor: Color.fromRGBO(239, 68, 68, 240 / 255),
      defaultVisualMode: 1,
    ),
    ThemePreset(
      id: 2,
      name: '金嗓子香槟金',
      englishName: 'Accuphase Champagne',
      soundStyle: '甜美人声 · 温暖弦乐',
      accentColor: Color(0xFFE2C792),
      litColor: Color.fromRGBO(226, 199, 146, 150 / 255),
      peakColor: Color.fromRGBO(249, 115, 22, 240 / 255),
      defaultVisualMode: 2,
    ),
    ThemePreset(
      id: 3,
      name: '复古琥珀卡座',
      englishName: 'Vintage Amber Tape',
      soundStyle: '模拟黑胶 · 温润模拟味',
      accentColor: Color(0xFFF97316),
      litColor: Color.fromRGBO(249, 115, 22, 150 / 255),
      peakColor: Color.fromRGBO(239, 68, 68, 240 / 255),
      defaultVisualMode: 3,
    ),
    ThemePreset(
      id: 5,
      name: '经典马兰士',
      englishName: 'Marantz Emerald',
      soundStyle: '甜润醇厚 · 模拟乐感',
      accentColor: Color(0xFF10B981),
      litColor: Color.fromRGBO(16, 185, 129, 150 / 255),
      peakColor: Color.fromRGBO(52, 211, 153, 240 / 255),
      defaultVisualMode: 1,
    ),
    ThemePreset(
      id: 6,
      name: '柏林之声冷银',
      englishName: 'Burmester Pure Silver',
      soundStyle: '极高解析 · 德国精密',
      accentColor: Color(0xFFE2E8F0),
      litColor: Color.fromRGBO(148, 163, 184, 150 / 255),
      peakColor: Color.fromRGBO(248, 250, 252, 250 / 255),
      defaultVisualMode: 1,
    ),
    ThemePreset(
      id: 7,
      name: '英国名暗夜翠',
      englishName: 'Naim Classic Green',
      soundStyle: '音乐节奏 · 饱满弹跳',
      accentColor: Color(0xFF22C55E),
      litColor: Color.fromRGBO(34, 197, 94, 150 / 255),
      peakColor: Color.fromRGBO(74, 222, 128, 240 / 255),
      defaultVisualMode: 1,
    ),
    ThemePreset(
      id: 8,
      name: '马克莱文森赤晶',
      englishName: 'Mark Levinson Ruby Red',
      soundStyle: '沉稳权威 · 宽广纵深',
      accentColor: Color(0xFFEF4444),
      litColor: Color.fromRGBO(239, 68, 68, 150 / 255),
      peakColor: Color.fromRGBO(252, 165, 165, 240 / 255),
      defaultVisualMode: 1,
    ),
    ThemePreset(
      id: 9,
      name: 'iPad 硬件大师',
      englishName: 'iPad Hardware Master',
      soundStyle: '赛博极客 · 硬件遥测直通',
      accentColor: Color(0xFF00E5FF),
      litColor: Color.fromRGBO(0, 229, 255, 150 / 255),
      peakColor: Color.fromRGBO(255, 110, 180, 240 / 255),
      defaultVisualMode: 11,
    ),
  ];

  static const List<String> visualModeLabels = [
    '48列全景 LED 频谱',
    '名机动圈大表头',
    '金嗓子旗舰大表头',
    '复古开盘磁带机',
    'Siri 流光声波',
    'Siri 悬浮微光球',
    '音乐微光气泡',
    '极简纯黑纯音直通',
    '电光霓虹声波',
    '赛博粒子网格',
    '液态玻璃时钟',
    'iPad 硬件大师大屏',
  ];

  int _currentThemeId = 0;
  Color _accentColor = const Color(0xFFFA2D48);
  int _backgroundVisualMode = 0;
  double _customHue = 352.0;
  double _customSat = 0.74;
  double _customVal = 0.98;

  int get currentThemeId => _currentThemeId;
  Color get accentColor => _accentColor;
  int get backgroundVisualMode => _backgroundVisualMode;
  double get customHue => _customHue;
  double get customSat => _customSat;
  double get customVal => _customVal;

  ThemeService._internal() {
    _loadFromDatabase();
  }

  void _loadFromDatabase() {
    final db = MusicDatabaseService.instance;
    final savedThemeStr = db.getSetting('theme_id', '0');
    final savedBgStr = db.getSetting('bg_visual_mode', '0');
    final savedThemeId = int.tryParse(savedThemeStr) ?? 0;
    final savedBgMode = int.tryParse(savedBgStr) ?? 0;

    _backgroundVisualMode = savedBgMode.clamp(0, visualModeLabels.length - 1);

    if (savedThemeId == 4) {
      // 4: Custom 自定义调色
      _currentThemeId = 4;
      final cr = double.tryParse(db.getSetting('theme_custom_r', '0.98')) ?? 0.98;
      final cg = double.tryParse(db.getSetting('theme_custom_g', '0.18')) ?? 0.18;
      final cb = double.tryParse(db.getSetting('theme_custom_b', '0.28')) ?? 0.28;
      _accentColor = Color.fromRGBO(
        (cr * 255).round().clamp(0, 255),
        (cg * 255).round().clamp(0, 255),
        (cb * 255).round().clamp(0, 255),
        1.0,
      );
      final hsv = HSVColor.fromColor(_accentColor);
      _customHue = hsv.hue;
      _customSat = hsv.saturation;
      _customVal = hsv.value;
    } else {
      final preset = presets.firstWhere((p) => p.id == savedThemeId, orElse: () => presets.first);
      _currentThemeId = preset.id;
      _accentColor = preset.accentColor;
      final hsv = HSVColor.fromColor(_accentColor);
      _customHue = hsv.hue;
      _customSat = hsv.saturation;
      _customVal = hsv.value;
    }
  }

  void setTheme(int id) {
    final preset = presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
    _currentThemeId = preset.id;
    _accentColor = preset.accentColor;
    _backgroundVisualMode = preset.defaultVisualMode;
    final hsv = HSVColor.fromColor(_accentColor);
    _customHue = hsv.hue;
    _customSat = hsv.saturation;
    _customVal = hsv.value;

    final db = MusicDatabaseService.instance;
    db.setSetting('theme_id', preset.id.toString());
    db.setSetting('bg_visual_mode', _backgroundVisualMode.toString());

    notifyListeners();
  }

  void setCustomHsv(double h, double s, double v) {
    _customHue = h.clamp(0.0, 360.0);
    _customSat = s.clamp(0.0, 1.0);
    _customVal = v.clamp(0.05, 1.0);
    _accentColor = HSVColor.fromAHSV(1.0, _customHue, _customSat, _customVal).toColor();
    _currentThemeId = 4; // 标记为自定义 (ThemeId::Custom = 4)

    final db = MusicDatabaseService.instance;
    db.setSetting('theme_id', '4');
    db.setSetting('theme_custom_r', _accentColor.r.toStringAsFixed(4));
    db.setSetting('theme_custom_g', _accentColor.g.toStringAsFixed(4));
    db.setSetting('theme_custom_b', _accentColor.b.toStringAsFixed(4));

    notifyListeners();
  }

  void setBackgroundVisualMode(int mode) {
    if (mode >= 0 && mode < visualModeLabels.length) {
      _backgroundVisualMode = mode;
      MusicDatabaseService.instance.setSetting('bg_visual_mode', mode.toString());
      notifyListeners();
    }
  }

  void resetToDefault() {
    setTheme(0);
    setBackgroundVisualMode(0);
  }
}
