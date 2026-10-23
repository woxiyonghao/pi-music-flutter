import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/hifi_audio_bindings.dart';
import '../core/hifi_audio_service.dart';
import '../core/platform_helper.dart';
import '../models/dac_device_info.dart';
import 'music_database_service.dart';

/// DAC 解码设置跨端双向同步与动态外设管理服务
/// 具备：根据 C++ 实时探测的硬件声卡动态生成设备卡片 (如【本机解码器】与【外接解码器: TOPPING DX12】)，
/// 彻底告别写死芯片列表，仅显示实际连接设备的专有滤波与调教参数。
class DacSettingService extends ChangeNotifier {
  static final DacSettingService instance = DacSettingService._();

  List<DacDeviceInfo> _connectedDevices = [];
  List<DacDeviceInfo> get connectedDevices => List.unmodifiable(_connectedDevices);

  int _selectedDeviceIndex = 0;
  int get selectedDeviceIndex => _selectedDeviceIndex;

  DacDeviceInfo? get currentDevice {
    if (_connectedDevices.isEmpty) return null;
    if (_selectedDeviceIndex >= 0 && _selectedDeviceIndex < _connectedDevices.length) {
      return _connectedDevices[_selectedDeviceIndex];
    }
    return _connectedDevices.first;
  }

  DacDeviceInfo? get builtinDevice {
    final list = _connectedDevices.where((d) => d.isBuiltIn).toList();
    return list.isNotEmpty ? list.first : null;
  }

  DacDeviceInfo? get externalDevice {
    final list = _connectedDevices.where((d) => !d.isBuiltIn).toList();
    return list.isNotEmpty ? list.first : null;
  }

  bool get hasExternalDac => _connectedDevices.any((d) => !d.isBuiltIn);

  // 兼容老版本芯片索引 (0: 本机, 1: ESS, 2: AKM, 3: CS, 4: R-2R, 5: ROHM)
  int _selectedChip = 0;
  int get selectedChip => _selectedChip;

  final Map<String, int> _params = {};
  Map<String, int> get allParams => Map.unmodifiable(_params);

  VoidCallback? onBroadcastNeeded;

  DacSettingService._() {
    _loadFromDatabase();
    refreshDevices();
    Future.microtask(() => restoreDx1iiHardwareSettings());
  }

  static const List<String> chips = [
    'Apple 直通',
    'ES9038PRO',
    'AK4499EX',
    'CS43198',
    'R-2R 纯电阻',
    'ROHM 34301',
  ];

  String get dacName {
    if (_selectedChip > 0 && _selectedChip < chips.length) {
      return chips[_selectedChip];
    }
    if (currentDevice != null) {
      return currentDevice!.name;
    }
    if (_selectedChip == 0 && PlatformHelper.isPi) {
      return 'ALSA 直通';
    }
    if (PlatformHelper.isPi) {
      return '树莓派 ALSA 纯音硬件';
    }
    return PlatformHelper.isIpad ? 'iPad AOP 纯音硬件' : 'Mac Direct 纯音硬件';
  }

  String get activeOutput {
    if (currentDevice != null) {
      return currentDevice!.isBuiltIn ? '本机音频直通' : '外接发烧解码器 (${currentDevice!.model})';
    }
    if (PlatformHelper.isPi) {
      return _selectedChip == 0 ? 'ALSA 物理硬件直通' : '外接音频 / 高保真 DAC';
    }
    if (PlatformHelper.isIpad) {
      return _selectedChip == 0 ? 'iPad 内置扬声器 / 耳机' : 'USB-C / 外部数字 DAC';
    }
    return _selectedChip == 0 ? 'Mac 内置扬声器' : '外接音频 / 高保真 DAC';
  }

  void _loadFromDatabase() {
    final db = MusicDatabaseService.instance;
    _selectedChip = int.tryParse(db.getSetting('setting_dac_selected_chip', '0'))?.clamp(0, 5) ?? 0;
    _selectedDeviceIndex = int.tryParse(db.getSetting('setting_dac_device_index', '0')) ?? 0;

    // 常用参数列表
    final keys = [
      // 拓品 TOPPING DX12 / DX1 II (ES9039Q2M)
      'topping_sample_rate_mode',
      'topping_filter', 'topping_dpll', 'topping_dsd_cutoff', 'topping_uac_mode',
      'topping_lineout_bypass', 'topping_gain',
      // Apple / 本机直通
      'apple_exclusive', 'apple_sample_rate', 'apple_drive', 'apple_bit_depth', 'selected_device',
      'builtin_buffer_size', 'builtin_bypass_volume',
      // ESS 老参数兼容
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

    // 2. 拓品 DX1 II 专用持久化表 (dac_dx1ii_settings) 深度本地化读取与迁移
    final dx1Settings = db.getAllDacDx1iiSettings();
    if (dx1Settings.isNotEmpty) {
      for (final entry in dx1Settings.entries) {
        final k = entry.key;
        final v = int.tryParse(entry.value);
        if (v != null) {
          final paramKey = k.startsWith('topping_') ? k : 'topping_$k';
          _params[paramKey] = v;
        }
      }
    } else {
      // 本地表尚无数据时，将现有拓品参数自动镜像写入专用表 dac_dx1ii_settings
      const dx1SubKeys = [
        'sample_rate_mode',
        'filter',
        'dpll',
        'dsd_cutoff',
        'uac_mode',
        'lineout_bypass',
        'gain',
      ];
      for (final sub in dx1SubKeys) {
        final val = _params['topping_$sub'] ?? 0;
        db.setDacDx1iiSetting(sub, val.toString());
        db.setDacDx1iiSetting('topping_$sub', val.toString());
      }
    }
  }

  static DacDeviceInfo createToppingDx1iiDeviceInfo({
    String id = 'usb_topping_dx1_ii',
    String name = 'TOPPING DX1 II',
    bool isDefault = true,
    int? currentSampleRate,
  }) {
    return DacDeviceInfo(
      id: id,
      name: name,
      isBuiltIn: false,
      isDefault: isDefault,
      transport: 'USB',
      currentSampleRate: currentSampleRate ?? 384000,
      maxSampleRate: 384000,
      maxBitDepth: 32,
      brand: 'TOPPING (拓品)',
      model: 'DX1 II (桌面平衡解码耳放)',
      chipModel: 'ESS Sabre (ES9039Q2M)',
      usbInterface: 'XMOS XU316 超低抖动异步传输',
      maxDsdRate: 'DSD256 (Native / DoP)',
      supportsDsd: true,
      supportsHogMode: true,
      supportsUacMode: true,
      supportsDpll: true,
      supportsGainControl: true,
      supportsLineOutBypass: true,
      digitalFilters: const [
        '最小相位快速滚降 (Fast Roll-off, Minimum Phase)',
        '线性相位快速滚降 (Fast Roll-off, Linear Phase)',
        '最小相位慢速滚降 (Slow Roll-off, Minimum Phase)',
        '线性相位慢速滚降 (Slow Roll-off, Linear Phase)',
        '切趾快速滚降 (Apodizing Fast Roll-off)',
        '混合滤波 (Hybrid)',
        '砖墙滤波 (Brickwall)',
        '低色散滤波 (Low Dispersion)',
      ],
      filterDescriptions: const [
        '[默认推荐] 瞬态极佳，无预振铃，人声与现代流行音乐首选',
        '声场开阔自然，交响乐、大编制与古典弦乐首选',
        '温暖醇厚，消除高频数码毛刺，听感柔和耐听',
        '模拟黑胶唱片般的温润质感，音质厚实自然',
        '抑制瞬态冲激预振铃失真，极高保真母带重现',
        '兼顾空间结像深度与低频瞬态打击力度',
        '极陡峭阻带截止，高频细节与线条感极强',
        '全音频频带降低群延迟与相位失真',
      ],
    );
  }

  /// 从底层 C++ 实时刷新所连接的全部音频硬件设备列表 (JSON 反序列化 + 树莓派真实物理声卡自愈)
  void refreshDevices() {
    final parsed = <DacDeviceInfo>[];
    try {
      final bindings = HifiAudioBindings.instance;
      final jsonStr = bindings.getConnectedDevicesJson();
      if (jsonStr.isNotEmpty && jsonStr != '[]') {
        final List<dynamic> list = jsonDecode(jsonStr);
        parsed.addAll(list.map((item) => DacDeviceInfo.fromJson(item as Map<String, dynamic>)));
      }
    } catch (e) {
      debugPrint('[DacSettingService] refreshDevices error: $e');
    }

    // 在 Linux / 树莓派上：直接读取系统真实的物理 ALSA 声卡 (/proc/asound/cards)
    if (Platform.isLinux) {
      try {
        final cardsFile = File('/proc/asound/cards');
        if (cardsFile.existsSync()) {
          final content = cardsFile.readAsStringSync();
          final lines = content.split('\n');
          final reg = RegExp(r'^\s*(\d+)\s+\[([^\]]+)\]:\s+([^-]+)\s*-\s*(.+)$');
          bool foundDx1 = false;
          final alsaCards = <DacDeviceInfo>[];

          for (final line in lines) {
            final match = reg.firstMatch(line);
            if (match != null) {
              final cardNum = match.group(1)!;
              final shortName = match.group(2)!.trim();
              final longName = match.group(4)!.trim();
              final combined = '$shortName $longName'.toLowerCase();

              if (combined.contains('dx1') || combined.contains('topping')) {
                foundDx1 = true;
                alsaCards.add(createToppingDx1iiDeviceInfo(
                  id: 'alsa_hw_$cardNum',
                  name: 'TOPPING DX1 II (Card $cardNum)',
                  isDefault: true,
                ));
              }
            }
          }

          if (foundDx1) {
            // 移除可能存在的未完整匹配的通用条目，替换为精准的 DX1 II 专用画像
            parsed.removeWhere((d) =>
                d.name.toLowerCase().contains('dx1') ||
                d.model.toLowerCase().contains('dx1') ||
                d.id.startsWith('alsa_hw_'));
            parsed.insertAll(0, alsaCards);
          } else if (parsed.isEmpty) {
            // 没有 DX1 时，如果存在系统内置 ALSA，添加内置直通卡片
            parsed.add(const DacDeviceInfo(
              id: 'alsa_builtin_pi',
              name: '树莓派 ALSA 直通声卡',
              isBuiltIn: true,
              isDefault: true,
              transport: 'BuiltIn (ALSA)',
              currentSampleRate: 192000,
              maxSampleRate: 192000,
              maxBitDepth: 32,
              brand: 'Raspberry Pi / Linux',
              model: '树莓派 ALSA 硬件直通',
              chipModel: 'BCM2712 Direct / I2S Master Clock',
              usbInterface: 'Broadcom I2S / DMA Direct',
              maxDsdRate: '无',
              supportsDsd: false,
              supportsHogMode: false,
              supportsUacMode: false,
              supportsDpll: false,
              supportsGainControl: false,
              supportsLineOutBypass: true,
              digitalFilters: ['ALSA 物理硬件直通 (Bit-Perfect)'],
              filterDescriptions: ['无重采样、无色彩渲染的系统级纯音直通'],
            ));
          }
        }
      } catch (e) {
        debugPrint('[DacSettingService] Linux ALSA 物理声卡探测异常: $e');
      }
    }

    if (parsed.isNotEmpty) {
      _connectedDevices = parsed;
      // 优先选择外接的 HiFi 解码器 (如拓品 DX1 II)
      final dx1Index = _connectedDevices.indexWhere((d) =>
          d.name.toLowerCase().contains('dx1') ||
          d.model.toLowerCase().contains('dx1') ||
          d.brand.toLowerCase().contains('topping'));
      if (dx1Index >= 0) {
        _selectedDeviceIndex = dx1Index;
      } else if (_selectedDeviceIndex >= _connectedDevices.length || _selectedDeviceIndex < 0) {
        _selectedDeviceIndex = 0;
      }
      notifyListeners();
      return;
    }

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _connectedDevices = [];
      _selectedDeviceIndex = -1;
      notifyListeners();
      return;
    }

    // 降级回退或测试模式默认设备列表 (根据当前平台类型智能匹配本机解码器)
    final isIpad = PlatformHelper.isIpad;
    final isPi = PlatformHelper.isPi;
    final builtinName = isIpad
        ? 'iPad 本机解码器'
        : (isPi ? '树莓派 ALSA 直通声卡' : 'Mac 本机解码器');
    final builtinModel = isIpad
        ? 'iPad 原生发烧音频总线'
        : (isPi ? '树莓派 ALSA 硬件直通' : 'Apple 内置音频输出');
    final builtinChip = isIpad
        ? 'Apple Studio Grade AOP (Audio Output Processor)'
        : (isPi ? 'BCM2712 Direct / I2S Master Clock' : 'Apple Studio Grade CoreAudio Engine');
    final builtinTransport = isIpad ? 'BuiltIn (AOP)' : (isPi ? 'BuiltIn (I2S)' : 'BuiltIn');

    final fallbackList = <DacDeviceInfo>[
      DacDeviceInfo(
        id: isIpad ? 'builtin_ipad' : (isPi ? 'alsa_hw_0_0' : 'builtin_apple'),
        name: builtinName,
        isBuiltIn: true,
        isDefault: true,
        transport: builtinTransport,
        currentSampleRate: isPi ? 192000 : 48000,
        maxSampleRate: isPi ? 192000 : 96000,
        maxBitDepth: 32,
        brand: isPi ? 'Raspberry Pi / Linux' : 'Apple Inc.',
        model: builtinModel,
        chipModel: builtinChip,
        usbInterface: isIpad
            ? 'Apple Silicon Direct AOP 零延迟总线'
            : (isPi ? 'Broadcom I2S / DMA Direct' : 'Apple Silicon Direct Bus'),
        maxDsdRate: '无',
        supportsDsd: false,
        supportsHogMode: !isIpad,
        supportsUacMode: false,
        supportsDpll: false,
        supportsGainControl: false,
        supportsLineOutBypass: true,
        digitalFilters: [
          isIpad ? 'Apple AOP 原生 64-bit 浮点无损滤波' : 'Apple 原生 64-bit 浮点线性滤波 (Bit-Perfect)',
          '系统自适应低延迟模式',
        ],
        filterDescriptions: const [
          '苹果底层极低失真浮点抗混叠直通',
          '优化系统响应延迟，适合快速监听与多任务',
        ],
      ),
    ];

    // 仅在显式开启外接模拟模式时才追加 TOPPING DX12
    if (HifiAudioBindings.instance.isExternalDeviceMock()) {
      fallbackList.add(
        const DacDeviceInfo(
          id: 'usb_topping_dx12',
          name: 'TOPPING DX12',
          isBuiltIn: false,
          isDefault: false,
          transport: 'USB',
          currentSampleRate: 384000,
          maxSampleRate: 384000,
          maxBitDepth: 32,
          brand: 'TOPPING (拓品)',
          model: 'DX12 / DX1 II (桌面平衡解码耳放)',
          chipModel: 'ESS Sabre (ES9039Q2M)',
          usbInterface: 'XMOS XU316 超低抖动异步传输',
          maxDsdRate: 'DSD256 (Native / DoP)',
          supportsDsd: true,
          supportsHogMode: true,
          supportsUacMode: true,
          supportsDpll: true,
          supportsGainControl: true,
          supportsLineOutBypass: true,
          digitalFilters: [
            '最小相位快速滚降 (Fast Roll-off, Minimum Phase)',
            '线性相位快速滚降 (Fast Roll-off, Linear Phase)',
            '最小相位慢速滚降 (Slow Roll-off, Minimum Phase)',
            '线性相位慢速滚降 (Slow Roll-off, Linear Phase)',
            '切趾快速滚降 (Apodizing Fast Roll-off)',
            '混合滤波 (Hybrid)',
            '砖墙滤波 (Brickwall)',
            '低色散滤波 (Low Dispersion)',
          ],
          filterDescriptions: [
            '[默认推荐] 瞬态极佳，无预振铃，人声与现代流行音乐首选',
            '声场开阔自然，交响乐、大编制与古典弦乐首选',
            '温暖醇厚，消除高频数码毛刺，听感柔和耐听',
            '模拟黑胶唱片般的温润质感，音质厚实自然',
            '抑制瞬态冲激预振铃失真，极高保真母带重现',
            '兼顾空间结像深度与低频瞬态打击力度',
            '极陡峭阻带截止，高频细节与线条感极强',
            '全音频频带降低群延迟与相位失真',
          ],
        ),
      );
    }

    _connectedDevices = fallbackList;
    if (_selectedDeviceIndex >= _connectedDevices.length) {
      _selectedDeviceIndex = 0;
    }
    notifyListeners();
  }

  bool get isMockExternalEnabled => HifiAudioBindings.instance.isExternalDeviceMock();

  void toggleMockExternal(bool enable) {
    HifiAudioBindings.instance.setExternalDeviceMock(enable);
    refreshDevices();
  }

  void selectDevice(int index) {
    if (index < 0 || index >= _connectedDevices.length) return;
    _selectedDeviceIndex = index;
    final dev = _connectedDevices[index];
    HifiAudioBindings.instance.selectOutputDevice(dev.id);
    MusicDatabaseService.instance.setSetting('setting_dac_device_index', index.toString());
    notifyListeners();
    onBroadcastNeeded?.call();
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
    final cleanKey = key.startsWith('setting_dac_')
        ? key.substring('setting_dac_'.length)
        : key;
    _params[cleanKey] = val;
    MusicDatabaseService.instance
        .setSetting('setting_dac_$cleanKey', val.toString());

    // 拓品 DX1 II 专用表 (dac_dx1ii_settings) 本地化持久化
    if (cleanKey.startsWith('topping_')) {
      final dx1Key = cleanKey.substring('topping_'.length);
      MusicDatabaseService.instance.setDacDx1iiSetting(dx1Key, val.toString());
      MusicDatabaseService.instance.setDacDx1iiSetting(cleanKey, val.toString());
    }

    notifyListeners();
    onBroadcastNeeded?.call();
  }

  static const MethodChannel _macSystemChannel =
      MethodChannel('pihifi/macos_system');

  /// 检测拓品 TOPPING DX1 II 是否处于连接激活状态
  Future<bool> checkDx1iiConnected() async {
    // 1. 优先从已探知设备列表中匹配 (兼容 Linux/ALSA 及各端物理外设名称)
    final hasInDevices = _connectedDevices.any((d) =>
        d.name.toLowerCase().contains('dx1') ||
        d.model.toLowerCase().contains('dx1') ||
        d.brand.toLowerCase().contains('topping'));
    if (hasInDevices) return true;

    // 2. Linux / 树莓派底层 ALSA 物理声卡直查
    if (Platform.isLinux) {
      try {
        final cardsFile = File('/proc/asound/cards');
        if (cardsFile.existsSync()) {
          final content = cardsFile.readAsStringSync().toLowerCase();
          if (content.contains('dx1') || content.contains('topping')) {
            return true;
          }
        }
      } catch (_) {}
    }

    // 3. macOS 专属底层 CoreAudio 实时查询
    if (Platform.isMacOS) {
      try {
        final info = await _macSystemChannel
            .invokeMapMethod<String, dynamic>('getAudioDeviceInfo');
        if (info != null && info['isToppingDx1ii'] == true) {
          return true;
        }
      } catch (e) {
        debugPrint('[DacSettingService] 查询音频设备信息异常: $e');
      }
    }
    return false;
  }

  /// 启动或重连时，如果连接了 DX1 II 且本地有专属表，反向向硬件设置采样率
  Future<void> restoreDx1iiHardwareSettings() async {
    final db = MusicDatabaseService.instance;
    final hasTable = db.hasDacDx1iiSettings();
    if (!hasTable) {
      debugPrint('[DacSettingService] 本地未发现 dac_dx1ii_settings 表数据，跳过反向设置');
      return;
    }

    final isConnected = await checkDx1iiConnected();
    if (!isConnected) {
      debugPrint('[DacSettingService] 拓品 DX1 II 未连接，跳过反向硬件设置');
      return;
    }

    final mode = sampleRateMode;
    debugPrint(
        '[DacSettingService] 识别到拓品 DX1 II 已连接，且本地存在 dac_dx1ii_settings 表配置: sampleRateMode=$mode');

    if (mode == 0) {
      // 0: 自动模式 (Bit-Perfect 源码直出)，同步当前曲目或默认母带采样率
      final currentRate =
          HifiAudioService.instance.currentTrack?.sampleRate ?? 44100;
      _updateDeviceSampleRate(currentRate);
      await syncPlaybackSampleRate(currentRate.toDouble());
      debugPrint(
          '[DacSettingService] 已向拓品 DX1 II 反向设置当前母带采样率: $currentRate Hz (自动直出)');
    } else {
      final targetRate = supportedSampleRates[mode];
      _updateDeviceSampleRate(targetRate.round());
      final ok = await _applyNativeSampleRate(targetRate);
      debugPrint(
          '[DacSettingService] 已向拓品 DX1 II 反向恢复硬件采样率: $targetRate Hz, 状态: $ok');
    }
    notifyListeners();
  }

  /// 硬件输出采样率模式档位：
  /// 0: 自动 (源码直通 · Bit-Perfect)
  /// 1: 44.1 kHz
  /// 2: 48.0 kHz
  /// 3: 96.0 kHz
  /// 4: 192.0 kHz
  /// 5: 384.0 kHz
  int get sampleRateMode => getParam('topping_sample_rate_mode', 0).clamp(0, 5);

  static const List<double> supportedSampleRates = [
    0.0, // 自动
    44100.0,
    48000.0,
    96000.0,
    192000.0,
    384000.0,
  ];

  /// 最终生效的实际硬件直出/升频采样率 (Hz)
  /// 当 sampleRateMode == 0 时为 Bit-Perfect 自动源码跟随曲目；
  /// 当 sampleRateMode > 0 时为用户强制指定/提升的采样率 (如 384000 Hz)
  int get effectiveOutputSampleRate {
    final mode = sampleRateMode;
    if (mode > 0 && mode < supportedSampleRates.length) {
      return supportedSampleRates[mode].round();
    }
    return HifiAudioService.instance.currentTrack?.sampleRate ?? 44100;
  }

  /// 最终生效的实际硬件直出/升频位深 (Bit)
  int get effectiveOutputBitDepth {
    final mode = sampleRateMode;
    if (mode > 0) {
      // 强制升频或锁定硬件采样率时，硬件以 32-Bit 高精浮点/整数直通
      return 32;
    }
    return HifiAudioService.instance.currentTrack?.bitDepth ?? 24;
  }

  /// 发烧直出规格展示文本，例如 "384.0k / 32b" 或 "192.0k / 24b"
  String get effectiveSpecText {
    final rate = effectiveOutputSampleRate;
    final depth = effectiveOutputBitDepth;
    final khz = rate / 1000.0;
    final khzStr = khz.toStringAsFixed(1);
    return '${khzStr}k / ${depth}b';
  }

  void _updateDeviceSampleRate(int rate) {
    if (_connectedDevices.isNotEmpty) {
      for (int i = 0; i < _connectedDevices.length; i++) {
        final dev = _connectedDevices[i];
        if (!dev.isBuiltIn || _connectedDevices.length == 1) {
          _connectedDevices[i] = dev.copyWith(currentSampleRate: rate);
        }
      }
    }
  }

  Future<bool> setSampleRateMode(int modeIndex) async {
    final clamped = modeIndex.clamp(0, 5);
    setParam('topping_sample_rate_mode', clamped);

    // 联动系统全局设置 setting_sample_rate (0: 源码直出, 1: 192k, 2: 384k)
    final sysRateIndex = clamped == 5 ? 2 : (clamped == 4 ? 1 : 0);
    MusicDatabaseService.instance.setSetting('setting_sample_rate', sysRateIndex.toString());

    final targetRate = clamped == 0
        ? (HifiAudioService.instance.currentTrack?.sampleRate ?? 44100).toDouble()
        : supportedSampleRates[clamped];

    _updateDeviceSampleRate(targetRate.round());
    notifyListeners();

    if (clamped == 0) {
      return syncPlaybackSampleRate(targetRate);
    } else {
      return _applyNativeSampleRate(targetRate);
    }
  }

  Future<bool> syncPlaybackSampleRate(double rate) async {
    if (rate <= 0) return false;
    if (sampleRateMode == 0) {
      _updateDeviceSampleRate(rate.round());
      notifyListeners();
      return _applyNativeSampleRate(rate);
    } else {
      // 保持用户设定的强制目标采样率
      final targetRate = supportedSampleRates[sampleRateMode];
      _updateDeviceSampleRate(targetRate.round());
      notifyListeners();
      return _applyNativeSampleRate(targetRate);
    }
  }

  Future<bool> _applyNativeSampleRate(double rate) async {
    if (!Platform.isMacOS) return false;
    try {
      final ok = await _macSystemChannel
          .invokeMethod<bool>('setSampleRate', {'sampleRate': rate});
      debugPrint('[DacSettingService] 硬件采样率已切换为: $rate Hz, 状态: $ok');
      return ok ?? false;
    } catch (e) {
      debugPrint('[DacSettingService] 切换硬件采样率失败: $e');
      return false;
    }
  }
}
