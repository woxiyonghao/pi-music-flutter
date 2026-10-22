import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/hifi_audio_bindings.dart';
import '../core/platform_helper.dart';
import '../models/dac_device_info.dart';
import 'music_database_service.dart';

/// DAC 解码设置跨端双向同步与动态外设管理服务
/// 具备：根据 C++ 实时探测的硬件声卡动态生成设备卡片 (如【本机解码器】与【外接解码器: TOPPING DX12】)，
/// 彻底告别写死芯片列表，仅显示实际连接设备的专有滤波与调教参数。
class DacSettingService extends ChangeNotifier {
  static final DacSettingService instance = DacSettingService._();

  List<DacDeviceInfo> _connectedDevices = [];
  List<DacDeviceInfo> get connectedDevices =>
      List.unmodifiable(_connectedDevices);

  int _selectedDeviceIndex = 0;
  int get selectedDeviceIndex => _selectedDeviceIndex;

  DacDeviceInfo? get currentDevice {
    if (_connectedDevices.isEmpty) return null;
    if (_selectedDeviceIndex >= 0 &&
        _selectedDeviceIndex < _connectedDevices.length) {
      return _connectedDevices[_selectedDeviceIndex];
    }
    return followsSystemOutput ? null : _connectedDevices.first;
  }

  DacDeviceInfo? get builtinDevice {
    final list = _connectedDevices.where((d) => d.isBuiltIn).toList();
    return list.isNotEmpty ? list.first : null;
  }

  DacDeviceInfo? get externalDevice {
    final list = _connectedDevices.where((d) => !d.isBuiltIn).toList();
    return list.isNotEmpty ? list.first : null;
  }

  bool get hasExternalDac =>
      _connectedDevices.any((d) => !d.isBuiltIn) || _selectedChip > 0;

  // 兼容老版本芯片索引 (0: 本机, 1: ESS, 2: AKM, 3: CS, 4: R-2R, 5: ROHM)
  int _selectedChip = 0;
  int get selectedChip => _selectedChip;

  final Map<String, int> _params = {};
  Map<String, int> get allParams => Map.unmodifiable(_params);

  VoidCallback? onBroadcastNeeded;

  final String Function()? _readDevices;
  final bool Function(String)? _selectOutput;
  final bool? _followsSystemOutputOverride;

  /// macOS 的播放设备由系统管理；列表用于显示连接状态，不在播放中试切声卡。
  bool get followsSystemOutput =>
      _followsSystemOutputOverride ??
      (Platform.isMacOS && HifiAudioBindings.instance.isLoaded);

  bool canSelectDevice(int index) =>
      !followsSystemOutput &&
      index >= 0 &&
      index < _connectedDevices.length &&
      index != _selectedDeviceIndex;

  DacSettingService._()
      : _readDevices = null,
        _selectOutput = null,
        _followsSystemOutputOverride = null {
    _loadFromDatabase();
    refreshDevices();
  }

  @visibleForTesting
  DacSettingService.forTesting({
    required String Function() readDevices,
    required bool Function(String) selectOutput,
    required bool followsSystemOutput,
  })  : _readDevices = readDevices,
        _selectOutput = selectOutput,
        _followsSystemOutputOverride = followsSystemOutput {
    refreshDevices();
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
    if (HifiAudioBindings.instance.isLoaded &&
        !PlatformHelper.isPi &&
        currentDevice != null) {
      return currentDevice!.name;
    }
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
      return currentDevice!.isBuiltIn
          ? '本机音频直通'
          : '外接发烧解码器 (${currentDevice!.model})';
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
    _selectedChip =
        int.tryParse(db.getSetting('setting_dac_selected_chip', '0'))
                ?.clamp(0, 5) ??
            0;
    _selectedDeviceIndex =
        int.tryParse(db.getSetting('setting_dac_device_index', '0')) ?? 0;

    // 常用参数列表
    final keys = [
      // 拓品 TOPPING DX12 (ES9039Q2M)
      'topping_filter', 'topping_dpll', 'topping_dsd_cutoff',
      'topping_uac_mode',
      'topping_lineout_bypass', 'topping_gain',
      // Apple / 本机直通
      'apple_exclusive', 'apple_sample_rate', 'apple_drive', 'apple_bit_depth',
      'selected_device',
      'builtin_buffer_size', 'builtin_bypass_volume',
      // ESS 老参数兼容
      'pcm_filter', 'dsd_bypass', 'dsd_cutoff', 'pcm_dpll', 'thd_comp',
      'mono_mode', 'output_mode', 'phase',
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

  /// 从底层 C++ 实时刷新所连接的全部音频硬件设备列表 (JSON 反序列化)
  void refreshDevices() {
    try {
      final bindings = HifiAudioBindings.instance;
      final jsonStr =
          _readDevices?.call() ?? bindings.getConnectedDevicesJson();
      if (jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        final parsed = list
            .map((item) => DacDeviceInfo.fromJson(item as Map<String, dynamic>))
            .where((device) => !device.isDisplayOutput)
            .toList();
        if (parsed.isNotEmpty || bindings.isLoaded || _readDevices != null) {
          _connectedDevices = parsed;
          // 原生列表里的 default 才是实际输出；持久化的数组下标会随热插拔变化。
          final activeIndex = parsed.indexWhere((device) => device.isDefault);
          _selectedDeviceIndex = activeIndex >= 0
              ? activeIndex
              : (followsSystemOutput || parsed.isEmpty ? -1 : 0);
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[DacSettingService] refreshDevices error: $e');
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
    final builtinName =
        isIpad ? 'iPad 本机解码器' : (isPi ? '树莓派 ALSA 直通声卡' : 'Mac 本机解码器');
    final builtinModel =
        isIpad ? 'iPad 原生发烧音频总线' : (isPi ? '树莓派 ALSA 硬件直通' : 'Apple 内置音频输出');
    final builtinChip = isIpad
        ? 'Apple Studio Grade AOP (Audio Output Processor)'
        : (isPi
            ? 'BCM2712 Direct / I2S Master Clock'
            : 'Apple Studio Grade CoreAudio Engine');
    final builtinTransport =
        isIpad ? 'BuiltIn (AOP)' : (isPi ? 'BuiltIn (I2S)' : 'BuiltIn');

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
          isIpad
              ? 'Apple AOP 原生 64-bit 浮点无损滤波'
              : 'Apple 原生 64-bit 浮点线性滤波 (Bit-Perfect)',
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

  bool get isMockExternalEnabled =>
      HifiAudioBindings.instance.isExternalDeviceMock();

  void toggleMockExternal(bool enable) {
    HifiAudioBindings.instance.setExternalDeviceMock(enable);
    refreshDevices();
  }

  void selectDevice(int index) {
    // 同时保护本机界面、HTTP 和 WebSocket，禁止绕过置灰卡片切换系统输出。
    if (!canSelectDevice(index)) return;
    final dev = _connectedDevices[index];
    final bindings = HifiAudioBindings.instance;
    final selected = _selectOutput?.call(dev.id) ??
        (!bindings.isLoaded || bindings.selectOutputDevice(dev.id));
    if (!selected) {
      refreshDevices();
      return;
    }
    _selectedDeviceIndex = index;
    MusicDatabaseService.instance
        .setSetting('setting_dac_device_index', index.toString());
    notifyListeners();
    onBroadcastNeeded?.call();
  }

  int getParam(String key, [int defaultVal = 0]) {
    final cleanKey = key.startsWith('setting_dac_')
        ? key.substring('setting_dac_'.length)
        : key;
    return _params[cleanKey] ?? defaultVal;
  }

  void setChip(int chip) {
    final c = chip.clamp(0, 5);
    if (_selectedChip == c) return;
    _selectedChip = c;
    MusicDatabaseService.instance
        .setSetting('setting_dac_selected_chip', c.toString());
    notifyListeners();
    onBroadcastNeeded?.call();
  }

  void setParam(String key, int val) {
    final cleanKey = key.startsWith('setting_dac_')
        ? key.substring('setting_dac_'.length)
        : key;
    if (_params[cleanKey] == val) return;
    _params[cleanKey] = val;
    MusicDatabaseService.instance
        .setSetting('setting_dac_$cleanKey', val.toString());
    notifyListeners();
    onBroadcastNeeded?.call();
  }
}
