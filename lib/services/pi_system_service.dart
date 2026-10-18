import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'music_database_service.dart';
import 'web_remote_service.dart';

/// 树莓派 5 专属硬件系统监控与深度遥测服务
/// 读取 BCM2712 四核 CPU 负载、时钟主频、SoC 核心温度、主动散热风扇 RPM/PWM、
/// 内存/交换分区矩阵、ALSA 音频直通链路与系统存储状态
class PiSystemService extends ChangeNotifier {
  static final PiSystemService instance = PiSystemService._();

  // 1. 温度与散热遥测
  double _socTemperature = 53.5;
  double get socTemperature => _socTemperature;

  int _fanSpeedRpm = 2963;
  int get fanSpeedRpm => _fanSpeedRpm;

  int _fanPwm = 75; // 0 - 255
  int get fanPwm => _fanPwm;

  int _fanLevel = 1; // 0 - 4
  int get fanLevel => _fanLevel;

  // 2. CPU 综合与 4 核心独立负载
  double _cpuPercent = 18.5;
  double get cpuPercent => _cpuPercent;

  List<double> _corePercents = [18.0, 15.0, 24.0, 17.0];
  List<double> get corePercents => _corePercents;

  double _cpuFreqMHz = 2400.0;
  double get cpuFreqMHz => _cpuFreqMHz;

  List<double> _loadAvg = [1.85, 2.04, 2.02];
  List<double> get loadAvg => _loadAvg;

  // 3. 内存与交换矩阵
  int _memTotalMB = 1014;
  int get memTotalMB => _memTotalMB;

  int _memAvailableMB = 483;
  int get memAvailableMB => _memAvailableMB;

  int _memUsedMB = 531;
  int get memUsedMB => _memUsedMB;

  int _buffersCachedMB = 410;
  int get buffersCachedMB => _buffersCachedMB;

  int _swapTotalMB = 990;
  int get swapTotalMB => _swapTotalMB;

  int _swapUsedMB = 125;
  int get swapUsedMB => _swapUsedMB;

  double get memUsedPercent => _memTotalMB > 0 ? (_memUsedMB / _memTotalMB * 100).clamp(0.0, 100.0) : 0.0;

  // 4. 音频与硬件直通
  String _dacDeviceName = 'AK4191 + AK4499EX';
  String get dacDeviceName => _dacDeviceName;

  String _alsaCard = 'hw:0,0 (I2S Master Clock)';
  String get alsaCard => _alsaCard;

  int _screenSaverTimeoutMinutes = 3;
  int get screenSaverTimeoutMinutes => _screenSaverTimeoutMinutes;

  // 上一次 /proc/stat 时间戳与统计缓存
  int _prevTotalTime = 0;
  int _prevIdleTime = 0;
  final List<int> _prevCoreTotalTimes = [0, 0, 0, 0];
  final List<int> _prevCoreIdleTimes = [0, 0, 0, 0];

  Timer? _monitorTimer;

  PiSystemService._() {
    _loadSettings();
    _updateHardwareTelemetry();
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
    // 1秒高精度脉动刷新，保持数据大屏实时流光与仪表动态
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateHardwareTelemetry();
    });
  }

  void _updateHardwareTelemetry() {
    if (Platform.isLinux) {
      _readLinuxSysfsStats();
    } else {
      _simulateRealisticTelemetry();
    }
    notifyListeners();
  }

  void _readLinuxSysfsStats() {
    // 1. SoC 温度
    try {
      final thermalFile = File('/sys/class/thermal/thermal_zone0/temp');
      if (thermalFile.existsSync()) {
        final val = int.tryParse(thermalFile.readAsStringSync().trim());
        if (val != null) _socTemperature = val / 1000.0;
      }
    } catch (_) {}

    // 2. 树莓派 5 主动散热风扇转速 (RPM) 与 PWM
    try {
      // 常见树莓派 5 官方散热器 hwmon 路径
      File fanRpmFile = File('/sys/devices/platform/cooling_fan/hwmon/hwmon2/fan1_input');
      if (!fanRpmFile.existsSync()) {
        final dir = Directory('/sys/devices/platform/cooling_fan/hwmon');
        if (dir.existsSync()) {
          for (final sub in dir.listSync()) {
            final f = File('${sub.path}/fan1_input');
            if (f.existsSync()) {
              fanRpmFile = f;
              break;
            }
          }
        }
      }
      if (fanRpmFile.existsSync()) {
        final val = int.tryParse(fanRpmFile.readAsStringSync().trim());
        if (val != null) _fanSpeedRpm = val;
      }

      File fanPwmFile = File('/sys/devices/platform/cooling_fan/hwmon/hwmon2/pwm1');
      if (!fanPwmFile.existsSync()) {
        final dir = Directory('/sys/devices/platform/cooling_fan/hwmon');
        if (dir.existsSync()) {
          for (final sub in dir.listSync()) {
            final f = File('${sub.path}/pwm1');
            if (f.existsSync()) {
              fanPwmFile = f;
              break;
            }
          }
        }
      }
      if (fanPwmFile.existsSync()) {
        final val = int.tryParse(fanPwmFile.readAsStringSync().trim());
        if (val != null) _fanPwm = val;
      }

      final coolingLevelFile = File('/sys/class/thermal/cooling_device0/cur_state');
      if (coolingLevelFile.existsSync()) {
        final val = int.tryParse(coolingLevelFile.readAsStringSync().trim());
        if (val != null) _fanLevel = val;
      }
    } catch (_) {}

    // 3. CPU 当前主频 (MHz)
    try {
      final freqFile = File('/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq');
      if (freqFile.existsSync()) {
        final val = int.tryParse(freqFile.readAsStringSync().trim());
        if (val != null) _cpuFreqMHz = val / 1000.0;
      }
    } catch (_) {}

    // 4. CPU 总体与 4 核利用率 (/proc/stat)
    try {
      final statFile = File('/proc/stat');
      if (statFile.existsSync()) {
        final lines = statFile.readAsLinesSync();
        for (final line in lines) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.isEmpty) continue;
          final tag = parts[0];

          if (tag == 'cpu' && parts.length >= 5) {
            final user = int.tryParse(parts[1]) ?? 0;
            final nice = int.tryParse(parts[2]) ?? 0;
            final system = int.tryParse(parts[3]) ?? 0;
            final idle = int.tryParse(parts[4]) ?? 0;
            final iowait = parts.length > 5 ? (int.tryParse(parts[5]) ?? 0) : 0;
            final irq = parts.length > 6 ? (int.tryParse(parts[6]) ?? 0) : 0;
            final softirq = parts.length > 7 ? (int.tryParse(parts[7]) ?? 0) : 0;
            final steal = parts.length > 8 ? (int.tryParse(parts[8]) ?? 0) : 0;

            final idleTime = idle + iowait;
            final totalTime = user + nice + system + idle + iowait + irq + softirq + steal;

            if (_prevTotalTime > 0) {
              final dTotal = totalTime - _prevTotalTime;
              final dIdle = idleTime - _prevIdleTime;
              if (dTotal > 0) {
                _cpuPercent = ((1.0 - (dIdle / dTotal)) * 100.0).clamp(0.0, 100.0);
              }
            }
            _prevTotalTime = totalTime;
            _prevIdleTime = idleTime;
          } else if (tag.startsWith('cpu') && tag.length == 4) {
            final coreIdx = int.tryParse(tag.substring(3));
            if (coreIdx != null && coreIdx >= 0 && coreIdx < 4 && parts.length >= 5) {
              final user = int.tryParse(parts[1]) ?? 0;
              final nice = int.tryParse(parts[2]) ?? 0;
              final system = int.tryParse(parts[3]) ?? 0;
              final idle = int.tryParse(parts[4]) ?? 0;
              final iowait = parts.length > 5 ? (int.tryParse(parts[5]) ?? 0) : 0;
              final irq = parts.length > 6 ? (int.tryParse(parts[6]) ?? 0) : 0;
              final softirq = parts.length > 7 ? (int.tryParse(parts[7]) ?? 0) : 0;
              final steal = parts.length > 8 ? (int.tryParse(parts[8]) ?? 0) : 0;

              final idleTime = idle + iowait;
              final totalTime = user + nice + system + idle + iowait + irq + softirq + steal;

              if (_prevCoreTotalTimes[coreIdx] > 0) {
                final dTotal = totalTime - _prevCoreTotalTimes[coreIdx];
                final dIdle = idleTime - _prevCoreIdleTimes[coreIdx];
                if (dTotal > 0) {
                  _corePercents[coreIdx] = ((1.0 - (dIdle / dTotal)) * 100.0).clamp(0.0, 100.0);
                }
              }
              _prevCoreTotalTimes[coreIdx] = totalTime;
              _prevCoreIdleTimes[coreIdx] = idleTime;
            }
          }
        }
      }
    } catch (_) {}

    // 5. 内存与交换分区 (/proc/meminfo)
    try {
      final memFile = File('/proc/meminfo');
      if (memFile.existsSync()) {
        int total = 0, avail = 0, buffers = 0, cached = 0, swapTotal = 0, swapFree = 0;
        final lines = memFile.readAsLinesSync();
        for (final line in lines) {
          final parts = line.split(':');
          if (parts.length < 2) continue;
          final key = parts[0].trim();
          final val = int.tryParse(parts[1].trim().split(' ')[0]) ?? 0;
          if (key == 'MemTotal') total = val ~/ 1024;
          if (key == 'MemAvailable') avail = val ~/ 1024;
          if (key == 'Buffers') buffers = val ~/ 1024;
          if (key == 'Cached') cached = val ~/ 1024;
          if (key == 'SwapTotal') swapTotal = val ~/ 1024;
          if (key == 'SwapFree') swapFree = val ~/ 1024;
        }
        if (total > 0) _memTotalMB = total;
        if (avail > 0) _memAvailableMB = avail;
        _memUsedMB = max(0, _memTotalMB - _memAvailableMB);
        _buffersCachedMB = buffers + cached;
        if (swapTotal > 0) _swapTotalMB = swapTotal;
        _swapUsedMB = max(0, swapTotal - swapFree);
      }
    } catch (_) {}

    // 6. 系统平均负载 (/proc/loadavg)
    try {
      final loadFile = File('/proc/loadavg');
      if (loadFile.existsSync()) {
        final parts = loadFile.readAsStringSync().trim().split(' ');
        if (parts.length >= 3) {
          _loadAvg = [
            double.tryParse(parts[0]) ?? 1.85,
            double.tryParse(parts[1]) ?? 2.04,
            double.tryParse(parts[2]) ?? 2.02,
          ];
        }
      }
    } catch (_) {}
  }

  void _simulateRealisticTelemetry() {
    // 模拟环境下提供生动呼吸的真实感数据波动
    final rand = Random();
    final rTemp = (rand.nextDouble() - 0.5) * 0.4;
    _socTemperature = (53.2 + rTemp).clamp(42.0, 68.0);

    final rFan = (rand.nextDouble() - 0.5) * 40;
    _fanSpeedRpm = (2960 + rFan.round()).clamp(2400, 3800);
    _fanPwm = 75 + (rand.nextInt(5) - 2);
    _fanLevel = 1;

    final rCpu = (rand.nextDouble() - 0.5) * 3.0;
    _cpuPercent = (18.5 + rCpu).clamp(10.0, 45.0);
    _corePercents = [
      (16.0 + rand.nextDouble() * 5).clamp(5.0, 60.0),
      (14.0 + rand.nextDouble() * 6).clamp(5.0, 60.0),
      (22.0 + rand.nextDouble() * 8).clamp(5.0, 80.0),
      (15.0 + rand.nextDouble() * 5).clamp(5.0, 60.0),
    ];
    _cpuFreqMHz = 2400.0;
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

  /// 动态探测树莓派 Linux 系统物理挂载的 ALSA 声卡 (/proc/asound/cards)
  List<Map<String, dynamic>> getDetectedAlsaDevices() {
    final list = <Map<String, dynamic>>[];
    if (Platform.isLinux) {
      try {
        final cardsFile = File('/proc/asound/cards');
        if (cardsFile.existsSync()) {
          final lines = cardsFile.readAsLinesSync();
          final reg = RegExp(r'^\s*(\d+)\s+\[([^\]]+)\]:\s+([^-]+)\s*-\s*(.+)$');
          for (final line in lines) {
            final match = reg.firstMatch(line);
            if (match != null) {
              final cardNum = match.group(1)!;
              final shortName = match.group(2)!.trim();
              final longName = match.group(4)!.trim();
              list.add({
                'name': longName.isNotEmpty ? longName : shortName,
                'card': 'hw:$cardNum,0',
                'desc': '物理硬件声卡直通 · Card $cardNum',
                'chipIndex': 0,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('[PiSystemService] 探测 ALSA 声卡失败: $e');
      }
    }
    return list;
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }
}
