import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/hifi_audio_bindings.dart';
import '../core/platform_helper.dart';
import '../models/dac_device_info.dart';
import '../platform/platform_audio_runtime.dart';
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
    return followsSystemOutput || _runtime.isAndroid
        ? null
        : _connectedDevices.first;
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

  final String Function()? _readDevices;
  final bool Function(String)? _selectOutput;
  final bool? _followsSystemOutputOverride;
  final PlatformAudioRuntime _runtime;
  PlatformAudioRuntime get audioRuntime => _runtime;

  /// macOS 的播放设备由系统管理；列表用于显示连接状态，不在播放中试切声卡。
  bool get followsSystemOutput =>
      _followsSystemOutputOverride ??
      (_runtime.isIOS ||
          (Platform.isMacOS && HifiAudioBindings.instance.isLoaded));

  bool canSelectDevice(int index) =>
      !followsSystemOutput &&
      index >= 0 &&
      index < _connectedDevices.length &&
      index != _selectedDeviceIndex;

  DacSettingService._()
      : _readDevices = null,
        _selectOutput = null,
        _followsSystemOutputOverride = null,
        _runtime = PlatformAudioRuntime.instance {
    _loadFromDatabase();
    _runtime.restoreSampleRateMode(sampleRateMode);
    _restoreAndroidPreferences();
    _runtime.addListener(refreshDevices);
    refreshDevices();
  }

  @visibleForTesting
  DacSettingService.forTesting({
    required String Function() readDevices,
    required bool Function(String) selectOutput,
    required bool followsSystemOutput,
    PlatformAudioRuntime? runtime,
  })  : _readDevices = readDevices,
        _selectOutput = selectOutput,
        _followsSystemOutputOverride = followsSystemOutput,
        _runtime = runtime ?? PlatformAudioRuntime.instance {
    _runtime.addListener(refreshDevices);
    refreshDevices();
  }

  static const List<String> chips = [
    '本机直通',
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
    if (currentDevice != null) {
      return currentDevice!.name;
    }
    if (_selectedChip == 0 && PlatformHelper.isPi) {
      return 'ALSA 直通';
    }
    if (PlatformHelper.isPi) {
      return '树莓派 ALSA 纯音硬件';
    }
    return '未检测到音频输出';
  }

  String get activeOutput {
    if (currentDevice != null) {
      return currentDevice!.isBuiltIn
          ? '本机音频直通'
          : '外接发烧解码器 (${currentDevice!.model})';
    }
    return '等待系统音频输出';
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
      'android_exclusive', 'android_buffer_frames',
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
    _params['topping_sample_rate_mode'] =
        int.tryParse(db.getDacDx1iiSetting('sample_rate_mode', '0'))
                ?.clamp(0, 5) ??
            0;
  }

  void _restoreAndroidPreferences() {
    if (!_runtime.isAndroid) return;
    _runtime.restoreAndroidPreferences(
      // AudioDeviceInfo IDs can be reassigned after reconnecting or rebooting.
      deviceId: 0,
      exclusive: getParam('android_exclusive', 0) == 0,
      bufferFrames: getParam('android_buffer_frames', 0) > 0
          ? getParam('android_buffer_frames')
          : 256,
    );
  }

  /// 从底层 C++ 实时刷新所连接的全部音频硬件设备列表 (JSON 反序列化)
  Future<void> probeOutputs() async {
    if (_runtime.usesHostOutput) {
      await _runtime.probeOutputs();
    } else {
      refreshDevices();
    }
  }

  void refreshDevices() {
    final output = _runtime.output;
    if (_runtime.isAndroid) {
      _connectedDevices = _runtime.outputDevices.map((info) {
        final name = info['name'] as String? ?? 'Android 音频输出';
        final transport = info['transport'] as String? ?? 'System';
        final isDx1ii =
            transport == 'USB' && PlatformAudioRuntime.isDx1iiName(name);
        return DacDeviceInfo.fromJson({
          ...info,
          'id': info['id'].toString(),
          'name': name,
          'isBuiltIn': info['isBuiltIn'] == true || transport == 'BuiltIn',
          'isHostManaged': true,
          'brand': isDx1ii ? 'TOPPING' : 'Android',
          'model': isDx1ii ? 'DX1 II' : name,
          'chipModel': 'AAudio PCM',
          'usbInterface': transport,
          'maxDsdRate': 'DSD 转 PCM',
          'supportsDsd': false,
          'supportsHogMode': false,
          'supportsUacMode': false,
          'supportsDpll': false,
          'supportsGainControl': false,
          'supportsLineOutBypass': false,
          'maxSampleRate': info['maxSampleRate'] ?? 0,
          'maxBitDepth': info['maxBitDepth'] ?? 0,
        });
      }).toList(growable: false);
      _selectedDeviceIndex =
          _connectedDevices.indexWhere((device) => device.isDefault);
      notifyListeners();
      onBroadcastNeeded?.call();
      return;
    }
    if (_runtime.isIOS) {
      final id = output?['id'] as String? ?? '';
      final name = output?['name'] as String? ?? '';
      final transport = output?['transport'] as String? ?? 'System';
      _connectedDevices = id.isEmpty
          ? []
          : [
              DacDeviceInfo(
                id: id,
                name: name,
                isBuiltIn: transport == 'BuiltIn',
                isDefault: true,
                transport: transport,
                isHostManaged: true,
                currentSampleRate: _runtime.negotiatedSampleRate,
                maxSampleRate: _runtime.negotiatedSampleRate,
                maxBitDepth: 0,
                brand: _runtime.isDx1iiConnected
                    ? 'TOPPING'
                    : (Platform.isAndroid ? 'Android' : 'iOS'),
                model: _runtime.isDx1iiConnected ? 'DX1 II' : name,
                chipModel: '系统协商 PCM',
                usbInterface: transport,
                maxDsdRate: 'DSD 转 PCM',
                supportsDsd: false,
                supportsHogMode: false,
                supportsUacMode: false,
                supportsDpll: false,
                supportsGainControl: false,
                supportsLineOutBypass: false,
              )
            ];
      _selectedDeviceIndex = _connectedDevices.isEmpty ? -1 : 0;
      notifyListeners();
      onBroadcastNeeded?.call();
      return;
    }
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

    _connectedDevices = [];
    _selectedDeviceIndex = -1;
    notifyListeners();
  }

  bool get isMockExternalEnabled =>
      HifiAudioBindings.instance.isExternalDeviceMock();

  void toggleMockExternal(bool enable) {
    HifiAudioBindings.instance.setExternalDeviceMock(enable);
    refreshDevices();
  }

  Future<void> selectDevice(int index) async {
    // 同时保护本机界面、HTTP 和 WebSocket，禁止绕过置灰卡片切换系统输出。
    if (!canSelectDevice(index)) return;
    final dev = _connectedDevices[index];
    if (_runtime.isAndroid) {
      await _runtime.selectOutputDevice(dev.id);
      refreshDevices();
      return;
    }
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
    if (cleanKey == 'topping_sample_rate_mode') {
      setSampleRateMode(val);
      return;
    }
    if (cleanKey == 'android_exclusive') {
      _saveParam(cleanKey, val);
      _runtime.setExclusiveOutput(val == 0);
      return;
    }
    if (cleanKey == 'android_buffer_frames') {
      _saveParam(cleanKey, val);
      _runtime.setBufferFrames(val);
      return;
    }
    _saveParam(cleanKey, val);
  }

  void _saveParam(String cleanKey, int val) {
    if (_params[cleanKey] == val) return;
    _params[cleanKey] = val;
    MusicDatabaseService.instance
        .setSetting('setting_dac_$cleanKey', val.toString());
    if (cleanKey.startsWith('topping_')) {
      MusicDatabaseService.instance.setDacDx1iiSetting(
          cleanKey.substring('topping_'.length), val.toString());
    }
    notifyListeners();
    onBroadcastNeeded?.call();
  }

  int get sampleRateMode => getParam('topping_sample_rate_mode', 0).clamp(0, 5);

  Future<void> setSampleRateMode(int mode) async {
    final value = mode.clamp(0, 5);
    _params['topping_sample_rate_mode'] = value;
    MusicDatabaseService.instance
        .setDacDx1iiSetting('sample_rate_mode', '$value');
    notifyListeners();
    onBroadcastNeeded?.call();
    await _runtime.setSampleRateMode(value);
  }

  @override
  void dispose() {
    _runtime.removeListener(refreshDevices);
    super.dispose();
  }
}
