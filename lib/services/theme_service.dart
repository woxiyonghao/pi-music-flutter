import 'package:flutter/material.dart';

/// 预设主题实体
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

/// 全局主题响应式服务单例 (严格对齐 C++ ThemeManager)
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
      id: 4,
      name: '经典马兰士',
      englishName: 'Marantz Emerald',
      soundStyle: '甜润醇厚 · 模拟乐感',
      accentColor: Color(0xFF10B981),
      litColor: Color.fromRGBO(16, 185, 129, 150 / 255),
      peakColor: Color.fromRGBO(52, 211, 153, 240 / 255),
      defaultVisualMode: 1,
    ),
    ThemePreset(
      id: 5,
      name: '柏林之声冷银',
      englishName: 'Burmester Pure Silver',
      soundStyle: '极高解析 · 德国精密',
      accentColor: Color(0xFFE2E8F0),
      litColor: Color.fromRGBO(148, 163, 184, 150 / 255),
      peakColor: Color.fromRGBO(248, 250, 252, 250 / 255),
      defaultVisualMode: 1,
    ),
    ThemePreset(
      id: 6,
      name: '英国名暗夜翠',
      englishName: 'Naim Classic Green',
      soundStyle: '音乐节奏 · 饱满弹跳',
      accentColor: Color(0xFF22C55E),
      litColor: Color.fromRGBO(34, 197, 94, 150 / 255),
      peakColor: Color.fromRGBO(74, 222, 128, 240 / 255),
      defaultVisualMode: 1,
    ),
    ThemePreset(
      id: 7,
      name: '马克莱文森赤晶',
      englishName: 'Mark Levinson Ruby Red',
      soundStyle: '沉稳权威 · 宽广纵深',
      accentColor: Color(0xFFEF4444),
      litColor: Color.fromRGBO(239, 68, 68, 150 / 255),
      peakColor: Color.fromRGBO(252, 165, 165, 240 / 255),
      defaultVisualMode: 1,
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

  ThemeService._internal();

  void setTheme(int id) {
    if (id >= 0 && id < presets.length) {
      _currentThemeId = id;
      _accentColor = presets[id].accentColor;
      _backgroundVisualMode = presets[id].defaultVisualMode;
      final hsv = HSVColor.fromColor(_accentColor);
      _customHue = hsv.hue;
      _customSat = hsv.saturation;
      _customVal = hsv.value;
      notifyListeners();
    }
  }

  void setCustomHsv(double h, double s, double v) {
    _customHue = h.clamp(0.0, 360.0);
    _customSat = s.clamp(0.0, 1.0);
    _customVal = v.clamp(0.05, 1.0);
    _accentColor = HSVColor.fromAHSV(1.0, _customHue, _customSat, _customVal).toColor();
    _currentThemeId = -1; // 标记为自定义
    notifyListeners();
  }

  void setBackgroundVisualMode(int mode) {
    if (mode >= 0 && mode < visualModeLabels.length) {
      _backgroundVisualMode = mode;
      notifyListeners();
    }
  }

  void resetToDefault() {
    setTheme(0);
    setBackgroundVisualMode(0);
  }
}
