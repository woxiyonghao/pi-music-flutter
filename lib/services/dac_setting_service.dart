import 'dart:io';
import 'package:flutter/foundation.dart';
import 'music_database_service.dart';

/// DAC 解码设置跨端双向同步与持久化服务
class DacSettingService extends ChangeNotifier {
  static final DacSettingService instance = DacSettingService._();

  int _selectedChip = 0; // 0: Apple, 1: ESS, 2: AKM, 3: CS, 4: R-2R, 5: ROHM
  int get selectedChip => _selectedChip;

  final Map<String, int> _params = {};
  Map<String, int> get allParams => Map.unmodifiable(_params);

  VoidCallback? onBroadcastNeeded;

  DacSettingService._() {
    _loadFromDatabase();
  }

  static const List<String> chips = [
    'Apple 直通',
    'ES9038PRO',
    'AK4499EX',
    'CS43198',
    'R-2R 纯电阻',
    'ROHM 34301',
  ];

  bool get hasExternalDac => _selectedChip != 0;

  String get dacName {
    if (_selectedChip >= 0 && _selectedChip < chips.length) {
      if (_selectedChip == 0 && Platform.isLinux) {
        return 'ALSA 直通';
      }
      return chips[_selectedChip];
    }
    if (Platform.isLinux) {
      return '树莓派 ALSA 纯音硬件';
    }
    return Platform.isIOS ? 'iPad AOP 纯音硬件' : 'Mac Direct 纯音硬件';
  }

  String get activeOutput {
    if (Platform.isLinux) {
      return _selectedChip == 0 ? 'ALSA 物理硬件直通' : '外接音频 / 高保真 DAC';
    }
    if (Platform.isIOS) {
      return _selectedChip == 0 ? 'iPad 内置扬声器 / 耳机' : 'USB-C / 外部数字 DAC';
    }
    return _selectedChip == 0 ? 'Mac 内置扬声器' : '外接音频 / 高保真 DAC';
  }

  void _loadFromDatabase() {
    final db = MusicDatabaseService.instance;
    _selectedChip = int.tryParse(db.getSetting('setting_dac_selected_chip', '0'))?.clamp(0, 5) ?? 0;

    // 参数列表
    final keys = [
      // Apple
      'apple_exclusive', 'apple_sample_rate', 'apple_drive', 'apple_bit_depth', 'selected_device',
      // ESS
      'pcm_filter', 'dsd_bypass', 'dsd_cutoff', 'pcm_dpll', 'thd_comp', 'mono_mode', 'output_mode', 'phase',
      // AKM
      'akm_filter', 'akm_color', 'akm_dsd', 'akm_exdf',
      // CS
      'cs_filter', 'cs_dsd', 'cs_drive', 'cs_impedance',
      // R-2R
      'r2r_mode', 'r2r_dsd', 'r2r_clock', 'r2r_phase',
      // ROHM
      'rohm_filter', 'rohm_clock', 'rohm_dsd',
    ];

    for (final k in keys) {
      final valStr = db.getSetting('setting_dac_$k', '0');
      _params[k] = int.tryParse(valStr) ?? 0;
    }
  }

  int getParam(String key, [int defaultVal = 0]) {
    final cleanKey = key.startsWith('setting_dac_') ? key.substring('setting_dac_'.length) : key;
    return _params[cleanKey] ?? defaultVal;
  }

  void setChip(int chip) {
    final c = chip.clamp(0, 5);
    if (_selectedChip == c) return;
    _selectedChip = c;
    MusicDatabaseService.instance.setSetting('setting_dac_selected_chip', c.toString());
    notifyListeners();
    onBroadcastNeeded?.call();
  }

  void setParam(String key, int val) {
    final cleanKey = key.startsWith('setting_dac_') ? key.substring('setting_dac_'.length) : key;
    if (_params[cleanKey] == val) return;
    _params[cleanKey] = val;
    MusicDatabaseService.instance.setSetting('setting_dac_$cleanKey', val.toString());
    notifyListeners();
    onBroadcastNeeded?.call();
  }
}
