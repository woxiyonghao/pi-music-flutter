/// 动态 DAC 硬件设备与芯片画像模型 (对齐 C++ DacDeviceCatalog.hpp)
class DacDeviceInfo {
  final String id;
  final String name;
  final bool isBuiltIn;
  final bool isDefault;
  final String transport;
  final int currentSampleRate;
  final int maxSampleRate;
  final int maxBitDepth;

  // 硬件芯片画像
  final String brand;
  final String model;
  final String chipModel;
  final String usbInterface;
  final String maxDsdRate;
  final bool supportsDsd;
  final bool supportsHogMode;
  final bool supportsUacMode;
  final bool supportsDpll;
  final bool supportsGainControl;
  final bool supportsLineOutBypass;
  final List<String> digitalFilters;
  final List<String> filterDescriptions;

  const DacDeviceInfo({
    required this.id,
    required this.name,
    this.isBuiltIn = false,
    this.isDefault = false,
    this.transport = 'BuiltIn',
    this.currentSampleRate = 44100,
    this.maxSampleRate = 384000,
    this.maxBitDepth = 32,
    required this.brand,
    required this.model,
    required this.chipModel,
    this.usbInterface = '',
    this.maxDsdRate = 'DSD256',
    this.supportsDsd = true,
    this.supportsHogMode = true,
    this.supportsUacMode = true,
    this.supportsDpll = true,
    this.supportsGainControl = true,
    this.supportsLineOutBypass = true,
    this.digitalFilters = const [],
    this.filterDescriptions = const [],
  });

  factory DacDeviceInfo.fromJson(Map<String, dynamic> json) {
    return DacDeviceInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未知设备',
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
      transport: json['transport'] as String? ?? 'External',
      currentSampleRate: json['currentSampleRate'] as int? ?? 44100,
      maxSampleRate: json['maxSampleRate'] as int? ?? 384000,
      maxBitDepth: json['maxBitDepth'] as int? ?? 32,
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      chipModel: json['chipModel'] as String? ?? '',
      usbInterface: json['usbInterface'] as String? ?? '',
      maxDsdRate: json['maxDsdRate'] as String? ?? '无',
      supportsDsd: json['supportsDsd'] as bool? ?? false,
      supportsHogMode: json['supportsHogMode'] as bool? ?? false,
      supportsUacMode: json['supportsUacMode'] as bool? ?? false,
      supportsDpll: json['supportsDpll'] as bool? ?? false,
      supportsGainControl: json['supportsGainControl'] as bool? ?? false,
      supportsLineOutBypass: json['supportsLineOutBypass'] as bool? ?? false,
      digitalFilters: (json['digitalFilters'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      filterDescriptions: (json['filterDescriptions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  /// 规格角标徽章 (如 "384kHz / 32Bit · DSD256")
  String get specBadge {
    final khz = (maxSampleRate / 1000).round();
    final dsdPart = supportsDsd && maxDsdRate != '无' ? ' · $maxDsdRate' : '';
    return '${khz}kHz / ${maxBitDepth}Bit$dsdPart';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isBuiltIn': isBuiltIn,
    'isDefault': isDefault,
    'transport': transport,
    'currentSampleRate': currentSampleRate,
    'maxSampleRate': maxSampleRate,
    'maxBitDepth': maxBitDepth,
    'brand': brand,
    'model': model,
    'chipModel': chipModel,
    'usbInterface': usbInterface,
    'maxDsdRate': maxDsdRate,
    'supportsDsd': supportsDsd,
    'supportsHogMode': supportsHogMode,
    'supportsUacMode': supportsUacMode,
    'supportsDpll': supportsDpll,
    'supportsGainControl': supportsGainControl,
    'supportsLineOutBypass': supportsLineOutBypass,
    'digitalFilters': digitalFilters,
    'filterDescriptions': filterDescriptions,
    'specBadge': specBadge,
  };
}
