import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'music_database_service.dart';
import 'web_remote_service.dart';

/// 树莓派 5 专属硬件系统监控与状态服务
/// 读取 BCM2712 SoC 核心温度、ALSA 音频接口状态、局域网 IP 与防烧屏配置
class PiSystemService extends ChangeNotifier {
  static final PiSystemService instance = PiSystemService._();

  double _socTemperature = 42.0;
  double get socTemperature => _socTemperature;

  String _dacDeviceName = 'AK4191 + AK4499EX';
  String get dacDeviceName => _dacDeviceName;

  String _alsaCard = 'hw:0,0 (I2S Master Clock)';
  String get alsaCard => _alsaCard;

  int _screenSaverTimeoutMinutes = 3;
  int get screenSaverTimeoutMinutes => _screenSaverTimeoutMinutes;

  Timer? _monitorTimer;

  PiSystemService._() {
    _loadSettings();
    _updateTemperature();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _startMonitoring();
    }
  }

  void _loadSettings() {
    final db = MusicDatabaseService.instance;
    final savedSaver = db.getSetting('pi_screensaver_timeout', '3');
    _screenSaverTimeoutMinutes = int.tryParse(savedSaver) ?? 3;

    final savedDac = db.getSetting('pi_dac_device', 'AK4191 + AK4499EX');
    if (savedDac.isNotEmpty) {
      _dacDeviceName = savedDac;
    }

    final savedAlsa = db.getSetting('pi_alsa_card', 'hw:0,0 (I2S Master Clock)');
    if (savedAlsa.isNotEmpty) {
      _alsaCard = savedAlsa;
    }
  }

  void _startMonitoring() {
    _monitorTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _updateTemperature();
    });
  }

  void _updateTemperature() {
    if (Platform.isLinux) {
      try {
        final thermalFile = File('/sys/class/thermal/thermal_zone0/temp');
        if (thermalFile.existsSync()) {
          final content = thermalFile.readAsStringSync().trim();
          final rawVal = int.tryParse(content);
          if (rawVal != null) {
            _socTemperature = rawVal / 1000.0;
            notifyListeners();
            return;
          }
        }
      } catch (_) {}
    }

    // 非树莓派 Linux 环境 (macOS 开发预览 / 模拟) 提供真实感微波动
    final rand = (Random().nextDouble() - 0.5) * 0.4;
    _socTemperature = (41.8 + rand).clamp(35.0, 65.0);
    notifyListeners();
  }

  void setDacDevice(String dacName, String alsaCard) {
    _dacDeviceName = dacName;
    _alsaCard = alsaCard;
    final db = MusicDatabaseService.instance;
    db.setSetting('pi_dac_device', dacName);
    db.setSetting('pi_alsa_card', alsaCard);
    notifyListeners();
  }

  void setScreenSaverTimeout(int minutes) {
    _screenSaverTimeoutMinutes = minutes;
    MusicDatabaseService.instance.setSetting('pi_screensaver_timeout', minutes.toString());
    notifyListeners();
  }

  String get localIp => WebRemoteService.instance.localIp;
  int get webRemotePort => WebRemoteService.instance.port;

  /// 温度状态颜色指示
  String get tempColorHex {
    if (_socTemperature < 50.0) return 'cyan'; // 正常低温
    if (_socTemperature < 70.0) return 'amber'; // 适中温升
    return 'red'; // 高温警示
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }
}
