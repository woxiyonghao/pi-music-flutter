import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class _MonitoringStopped implements Exception {
  const _MonitoringStopped();
}

/// Independent public iOS measurements. An unavailable sensor never erases
/// other fields, and unsupported chip sensors have no invented fallback.
class MobileSystemSnapshot {
  final String? model, deviceName, modelName, systemName, systemVersion;
  final bool? isSimulator, lowPowerMode;
  final String? metricScope;
  final int? bridgeVersion, processorCount, activeProcessorCount;
  final int? physicalMemoryBytes, physicalFreeMemoryBytes;
  final int? appMemoryBytes, appFootprintBytes, appAvailableMemoryBytes;
  final double? appCpuPercent, batteryLevel;
  final String? thermalState, batteryState;
  final int? storageTotalBytes, storageFreeBytes;
  final String? audioOutputName, audioTransport;
  final int? audioChannels, audioBufferFrames;
  final double? audioSampleRate, audioBufferDurationMs, audioOutputLatencyMs;
  final DateTime? sampledAt;
  final Map<String, String> metricErrors;

  const MobileSystemSnapshot({
    this.model,
    this.deviceName,
    this.modelName,
    this.systemName,
    this.systemVersion,
    this.isSimulator,
    this.lowPowerMode,
    this.metricScope,
    this.bridgeVersion,
    this.processorCount,
    this.activeProcessorCount,
    this.physicalMemoryBytes,
    this.physicalFreeMemoryBytes,
    this.appMemoryBytes,
    this.appFootprintBytes,
    this.appAvailableMemoryBytes,
    this.appCpuPercent,
    this.thermalState,
    this.batteryLevel,
    this.batteryState,
    this.storageTotalBytes,
    this.storageFreeBytes,
    this.audioOutputName,
    this.audioTransport,
    this.audioChannels,
    this.audioBufferFrames,
    this.audioSampleRate,
    this.audioBufferDurationMs,
    this.audioOutputLatencyMs,
    this.sampledAt,
    this.metricErrors = const {},
  });

  factory MobileSystemSnapshot.fromMap(Map<Object?, Object?> map) {
    double? decimal(String key) {
      final value = map[key];
      return value is num && value.isFinite && value >= 0
          ? value.toDouble()
          : null;
    }

    int? number(String key) => decimal(key)?.toInt();
    int? positive(String key) {
      final value = number(key);
      return value != null && value > 0 ? value : null;
    }

    String? string(String key) {
      final value = map[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    bool? boolean(String key) => map[key] is bool ? map[key] as bool : null;
    final battery = decimal('batteryLevel');
    final timestamp = number('sampledAtUnixMs');
    final errors = map['metricErrors'];
    return MobileSystemSnapshot(
      model: string('model'),
      deviceName: string('deviceName'),
      modelName: string('modelName'),
      systemName: string('systemName'),
      systemVersion: string('systemVersion'),
      isSimulator: boolean('isSimulator'),
      lowPowerMode: boolean('lowPowerMode'),
      metricScope: string('metricScope'),
      bridgeVersion: positive('bridgeVersion'),
      processorCount: positive('processorCount'),
      activeProcessorCount: positive('activeProcessorCount'),
      physicalMemoryBytes: positive('physicalMemoryBytes'),
      physicalFreeMemoryBytes: number('physicalFreeMemoryBytes'),
      appMemoryBytes: number('appMemoryBytes'),
      appFootprintBytes: number('appFootprintBytes'),
      appAvailableMemoryBytes: number('appAvailableMemoryBytes'),
      appCpuPercent: decimal('appCpuPercent'),
      thermalState: string('thermalState'),
      batteryLevel: battery != null && battery <= 1 ? battery : null,
      batteryState: string('batteryState'),
      storageTotalBytes: positive('storageTotalBytes'),
      storageFreeBytes: number('storageFreeBytes'),
      audioOutputName: string('audioOutputName'),
      audioTransport: string('audioTransport'),
      audioChannels: positive('audioChannels'),
      audioBufferFrames: positive('audioBufferFrames'),
      audioSampleRate: decimal('audioSampleRate'),
      audioBufferDurationMs: decimal('audioBufferDurationMs'),
      audioOutputLatencyMs: decimal('audioOutputLatencyMs'),
      sampledAt: timestamp != null && timestamp <= 8640000000000000
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null,
      metricErrors: Map.unmodifiable({
        if (errors is Map)
          for (final entry in errors.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
      }),
    );
  }

  int get availableMetricCount => [
        model,
        deviceName,
        systemVersion,
        processorCount,
        activeProcessorCount,
        physicalMemoryBytes,
        physicalFreeMemoryBytes,
        appMemoryBytes,
        appFootprintBytes,
        appAvailableMemoryBytes,
        appCpuPercent,
        thermalState,
        batteryLevel,
        batteryState,
        lowPowerMode,
        storageTotalBytes,
        storageFreeBytes,
        audioOutputName,
        audioTransport,
        audioChannels,
        audioBufferFrames,
        audioSampleRate,
        audioBufferDurationMs,
        audioOutputLatencyMs,
      ].where((value) => value != null).length;

  String unavailableLabel(String key) {
    final error = metricErrors[key];
    if (error == 'sampling') return '采样中';
    if (error == 'not_public') return '系统未开放';
    if (error?.startsWith('simulator_') == true) return '模拟器不提供';
    if (error == 'battery_not_ready') return '等待电池状态';
    return error == null ? '未提供' : '读取失败';
  }
}

class MobileSystemService extends ChangeNotifier {
  static final instance = MobileSystemService._();
  static const channel = MethodChannel('hifi/system');
  static Future<Map<Object?, Object?>?> _readNative() =>
      channel.invokeMapMethod<Object?, Object?>('getSystemInfo');

  MobileSystemService._()
      : _readSystemInfo = _readNative,
        _clock = DateTime.now,
        _requestTimeout = const Duration(seconds: 5);

  @visibleForTesting
  MobileSystemService.forTesting({
    Future<Map<Object?, Object?>?> Function()? readSystemInfo,
    DateTime Function()? clock,
    Duration requestTimeout = const Duration(seconds: 5),
  })  : _readSystemInfo = readSystemInfo ?? _readNative,
        _clock = clock ?? DateTime.now,
        _requestTimeout = requestTimeout;

  final Future<Map<Object?, Object?>?> Function() _readSystemInfo;
  final DateTime Function() _clock;
  final Duration _requestTimeout;
  MobileSystemSnapshot _snapshot = const MobileSystemSnapshot();
  MobileSystemSnapshot get snapshot => _snapshot;
  DateTime? _updatedAt, _lastAttemptAt;
  DateTime? get updatedAt => _updatedAt;
  DateTime? get lastAttemptAt => _lastAttemptAt;
  String? _lastError;
  String? get lastError => _lastError;
  int _consecutiveFailures = 0;
  int get consecutiveFailures => _consecutiveFailures;
  Timer? _timer;
  Timer? _requestTimer;
  Completer<Map<Object?, Object?>?>? _requestCompletion;
  Future<void>? _inFlight;
  bool _disposed = false;
  int _listeners = 0;
  bool get isRefreshing => _inFlight != null;

  String get statusLabel {
    if (_lastError != null) {
      return _updatedAt == null ? '原生遥测读取失败' : '读取失败，保留上次数据';
    }
    if (_updatedAt == null) return '等待原生遥测连接';
    final version = snapshot.bridgeVersion;
    return '原生遥测${version == null ? '' : ' v$version'} · ${snapshot.availableMetricCount} 项';
  }

  void startMonitoring() {
    if (_disposed) return;
    _listeners++;
    unawaited(refresh());
    if ((Platform.isIOS || Platform.isAndroid) &&
        !Platform.environment.containsKey('FLUTTER_TEST')) {
      _timer ??= Timer.periodic(const Duration(seconds: 2), (_) => refresh());
    }
  }

  Future<bool> ensureStoragePermission() async {
    if (!Platform.isAndroid ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    try {
      final result =
          await channel.invokeMethod<bool>('ensureStoragePermission');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  void stopMonitoring() {
    if (_listeners > 0) _listeners--;
    if (_listeners == 0) {
      _timer?.cancel();
      _timer = null;
      _cancelPendingRead();
    }
  }

  Future<void> refresh() {
    if (_disposed) return Future<void>.value();
    final existing = _inFlight;
    if (existing != null) return existing;
    late final Future<void> operation;
    operation = _refresh().whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  Future<Map<Object?, Object?>?> _readWithTimeout() {
    final completion = Completer<Map<Object?, Object?>?>();
    final timer = Timer(_requestTimeout, () {
      if (!completion.isCompleted) {
        completion
            .completeError(TimeoutException('Native telemetry timed out'));
      }
    });
    _requestCompletion = completion;
    _requestTimer = timer;
    Future<Map<Object?, Object?>?>.sync(_readSystemInfo).then<void>((value) {
      if (!completion.isCompleted) completion.complete(value);
    }, onError: (Object error, StackTrace stack) {
      if (!completion.isCompleted) completion.completeError(error, stack);
    });
    return completion.future.whenComplete(() {
      timer.cancel();
      if (identical(_requestCompletion, completion)) {
        _requestCompletion = null;
        _requestTimer = null;
      }
    });
  }

  void _cancelPendingRead() {
    _requestTimer?.cancel();
    _requestTimer = null;
    final completion = _requestCompletion;
    _requestCompletion = null;
    _inFlight = null;
    if (completion != null && !completion.isCompleted) {
      completion.completeError(const _MonitoringStopped());
    }
  }

  Future<void> _refresh() async {
    _lastAttemptAt = _clock();
    try {
      final map = await _readWithTimeout();
      if (_disposed) return;
      if (map == null || map.isEmpty) {
        throw const FormatException('empty_response');
      }
      final next = MobileSystemSnapshot.fromMap(map);
      if (next.availableMetricCount == 0) {
        throw const FormatException('no_recognized_metrics');
      }
      _snapshot = next;
      _updatedAt = _clock();
      _lastError = null;
      _consecutiveFailures = 0;
    } on _MonitoringStopped {
      // Leaving the dashboard cancels its deadline, not an OS error.
    } on MissingPluginException {
      _recordFailure('bridge_missing：请重新安装包含原生桥的完整构建');
    } on TimeoutException {
      _recordFailure('bridge_timeout：原生系统信息读取超时');
    } on PlatformException catch (error) {
      _recordFailure('${error.code}：${error.message ?? '原生读取失败'}');
    } on FormatException catch (error) {
      _recordFailure('invalid_response：${error.message}');
    } catch (error) {
      _recordFailure('bridge_error：$error');
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  void _recordFailure(String error) {
    _lastError = error;
    _consecutiveFailures++;
    debugPrint('[SystemTelemetry] $error');
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _cancelPendingRead();
    super.dispose();
  }
}
