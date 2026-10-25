import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../services/dac_setting_service.dart';
import '../../services/mobile_system_service.dart';
import '../../services/music_database_service.dart';
import '../../services/theme_service.dart';

/// The iPad composition, populated only from this device's native measurements.
class MobileTelemetryDashboardWidget extends StatefulWidget {
  const MobileTelemetryDashboardWidget({super.key, this.systemService});
  final MobileSystemService? systemService;

  @override
  State<MobileTelemetryDashboardWidget> createState() =>
      _MobileTelemetryDashboardWidgetState();
}

class _MobileTelemetryDashboardWidgetState
    extends State<MobileTelemetryDashboardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late final MobileSystemService _system;

  @override
  void initState() {
    super.initState();
    _system = widget.systemService ?? MobileSystemService.instance;
    _animation =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat();
    _system.startMonitoring();
  }

  @override
  void dispose() {
    _system.stopMonitoring();
    _animation.dispose();
    super.dispose();
  }

  String _bytes(int? bytes) {
    if (bytes == null) return '未提供';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }

  String _thermal(String? state) => switch (state) {
        'nominal' => '正常',
        'fair' => '温暖',
        'serious' => '高温',
        'critical' => '临界',
        _ => '未提供',
      };
  String _time(DateTime? value) => value == null
      ? '尚无成功采样'
      : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([
          _system,
          HifiAudioService.instance,
          DacSettingService.instance,
          MusicDatabaseService.instance,
          ThemeService.instance
        ]),
        builder: (context, _) {
          final system = _system.snapshot;
          final audio = HifiAudioService.instance;
          final dac = DacSettingService.instance;
          final tracks = MusicDatabaseService.instance.tracks;
          final accent = ThemeService.instance.accentColor;
          final appUsed = system.appFootprintBytes ?? system.appMemoryBytes;
          final appRatio = system.physicalMemoryBytes != null && appUsed != null
              ? appUsed / system.physicalMemoryBytes!
              : null;
          final freeRatio = system.storageTotalBytes != null &&
                  system.storageFreeBytes != null
              ? system.storageFreeBytes! / system.storageTotalBytes!
              : null;
          final routeName = system.audioOutputName ?? dac.currentDevice?.name;
          final runtimeRate = dac.audioRuntime.negotiatedSampleRate;
          final outputRate = system.audioSampleRate ??
              (runtimeRate > 0 ? runtimeRate.toDouble() : null);
          final diagnostic = _system.lastError ??
              '原生采样 ${_time(system.sampledAt)}\n${system.metricErrors.entries.map((e) => '${e.key}: ${e.value}').join('\n')}';
          String field(String key, String? value) =>
              value ?? system.unavailableLabel(key);
          return LayoutBuilder(builder: (context, constraints) {
            final scale = math
                .min(constraints.maxWidth / 1000, constraints.maxHeight / 660)
                .clamp(.01, 1.0);
            return Center(
                child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: constraints.maxWidth / scale,
                    height: constraints.maxHeight / scale,
                    child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, _) => DecoratedBox(
                              decoration:
                                  const BoxDecoration(color: Color(0xFF060913)),
                              child: Stack(fit: StackFit.expand, children: [
                                CustomPaint(painter: _TelemetryGrid(accent)),
                                Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(children: [
                                      Row(children: [
                                        Icon(Icons.memory_rounded,
                                            color: accent, size: 27),
                                        const SizedBox(width: 10),
                                        Text('iPhone 硬件大师',
                                            style: TextStyle(
                                                color: accent,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 2)),
                                        const SizedBox(width: 14),
                                        Expanded(
                                            child: _label(
                                                'SYSTEM TELEMETRY / AUDIO MATRIX',
                                                accent.withValues(alpha: .6))),
                                        _label(
                                            system.systemVersion == null
                                                ? '系统信息未提供'
                                                : '${system.systemName ?? 'iOS'} ${system.systemVersion}',
                                            accent),
                                      ]),
                                      const SizedBox(height: 7),
                                      Align(
                                          alignment: Alignment.centerLeft,
                                          child: _label(
                                              system.isSimulator == true
                                                  ? '模拟器环境 · CPU / 内存 / 存储来自宿主 Mac，电池与手机传感器不可用'
                                                  : '真机系统测量 · APP 可用额度不同于物理空闲内存；CPU 主频与芯片温度不由 iOS 公开',
                                              Colors.white54)),
                                      const SizedBox(height: 9),
                                      Expanded(
                                          child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                            Expanded(
                                                flex: 26,
                                                child: Column(children: [
                                                  Expanded(
                                                      child: _card(
                                                          '处理器 / PROCESSOR',
                                                          accent,
                                                          Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                _value(
                                                                    system.deviceName ??
                                                                        system
                                                                            .modelName ??
                                                                        system
                                                                            .model ??
                                                                        '设备型号未提供',
                                                                    accent),
                                                                _label(
                                                                    system.model ??
                                                                        '硬件标识未提供',
                                                                    Colors
                                                                        .white70),
                                                                const SizedBox(
                                                                    height: 5),
                                                                _row(
                                                                    '核心',
                                                                    system.processorCount ==
                                                                            null
                                                                        ? '核心数未提供'
                                                                        : '${system.activeProcessorCount ?? system.processorCount} / ${system.processorCount}',
                                                                    accent),
                                                                _row(
                                                                    'APP CPU',
                                                                    field(
                                                                        'appCpuPercent',
                                                                        system.appCpuPercent ==
                                                                                null
                                                                            ? null
                                                                            : '${system.appCpuPercent!.toStringAsFixed(1)}%'),
                                                                    accent),
                                                                _label(
                                                                    '单核满载 = 100% · 多核可超过 100%',
                                                                    Colors
                                                                        .white54),
                                                              ]))),
                                                  const SizedBox(height: 8),
                                                  Expanded(
                                                      child: _card(
                                                          '内存 / MEMORY',
                                                          accent,
                                                          Row(children: [
                                                            SizedBox(
                                                                width: 68,
                                                                height: 68,
                                                                child: CustomPaint(
                                                                    painter: _MetricRing(
                                                                        accent,
                                                                        appRatio))),
                                                            const SizedBox(
                                                                width: 10),
                                                            Expanded(
                                                                child: Column(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                  _row(
                                                                      '物理总量',
                                                                      _bytes(system
                                                                          .physicalMemoryBytes),
                                                                      accent),
                                                                  _row(
                                                                      '物理空闲',
                                                                      field(
                                                                          'physicalFreeMemoryBytes',
                                                                          system.physicalFreeMemoryBytes == null
                                                                              ? null
                                                                              : _bytes(system.physicalFreeMemoryBytes)),
                                                                      accent),
                                                                  _row(
                                                                      'APP 占用',
                                                                      field(
                                                                          'appFootprintBytes',
                                                                          system.appFootprintBytes == null
                                                                              ? null
                                                                              : _bytes(system.appFootprintBytes)),
                                                                      accent),
                                                                  _row(
                                                                      'APP 驻留',
                                                                      _bytes(system
                                                                          .appMemoryBytes),
                                                                      accent),
                                                                  _row(
                                                                      'APP 可用额度',
                                                                      field(
                                                                          'appAvailableMemoryBytes',
                                                                          system.appAvailableMemoryBytes == null
                                                                              ? null
                                                                              : _bytes(system.appAvailableMemoryBytes)),
                                                                      accent),
                                                                ])),
                                                          ]))),
                                                  const SizedBox(height: 8),
                                                  Expanded(
                                                      child: _card(
                                                          '供电 / THERMAL & POWER',
                                                          accent,
                                                          Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                _row(
                                                                    '热状态',
                                                                    _thermal(system
                                                                        .thermalState),
                                                                    accent),
                                                                _row(
                                                                    '电量',
                                                                    field(
                                                                        'batteryLevel',
                                                                        system.batteryLevel ==
                                                                                null
                                                                            ? null
                                                                            : '${(system.batteryLevel! * 100).round()}%'),
                                                                    accent),
                                                                _row(
                                                                    '供电',
                                                                    field(
                                                                        'batteryState',
                                                                        switch (
                                                                            system.batteryState) {
                                                                          'charging' =>
                                                                            '充电中',
                                                                          'full' =>
                                                                            '已充满',
                                                                          'unplugged' =>
                                                                            '电池供电',
                                                                          _ =>
                                                                            null,
                                                                        }),
                                                                    accent),
                                                                _row(
                                                                    '低电量模式',
                                                                    system.lowPowerMode ==
                                                                            null
                                                                        ? '未提供'
                                                                        : system.lowPowerMode!
                                                                            ? '已开启'
                                                                            : '已关闭',
                                                                    accent),
                                                                _row(
                                                                    '芯片温度 / 主频',
                                                                    'iOS 未开放',
                                                                    accent),
                                                              ]))),
                                                ])),
                                            const SizedBox(width: 10),
                                            Expanded(
                                                flex: 48,
                                                child: Column(children: [
                                                  Expanded(
                                                      flex: 5,
                                                      child: _card(
                                                          '音频核心 / CORE AUDIO',
                                                          accent,
                                                          Column(children: [
                                                            Expanded(
                                                                child: CustomPaint(
                                                                    size: Size
                                                                        .infinite,
                                                                    painter: _AudioRadar(
                                                                        accent,
                                                                        _animation
                                                                            .value,
                                                                        audio
                                                                            .state
                                                                            .spectrumLevels,
                                                                        audio
                                                                            .state
                                                                            .isPlaying))),
                                                            _value(
                                                                routeName ??
                                                                    '未检测到音频输出',
                                                                accent),
                                                          ]))),
                                                  const SizedBox(height: 8),
                                                  SizedBox(
                                                      height: 75,
                                                      child: Row(children: [
                                                        Expanded(
                                                            child: _kpi(
                                                                '当前会话采样率',
                                                                outputRate ==
                                                                        null
                                                                    ? '未提供'
                                                                    : '${(outputRate / 1000).toStringAsFixed(1)} kHz',
                                                                accent)),
                                                        const SizedBox(
                                                            width: 8),
                                                        Expanded(
                                                            child: _kpi(
                                                                '曲库',
                                                                '${tracks.length} 首',
                                                                accent)),
                                                        const SizedBox(
                                                            width: 8),
                                                        Expanded(
                                                            child: _kpi(
                                                                '播放状态',
                                                                audio.state
                                                                        .isPlaying
                                                                    ? '播放中'
                                                                    : audio.state
                                                                            .isPaused
                                                                        ? '已暂停'
                                                                        : '已停止',
                                                                accent)),
                                                      ])),
                                                  const SizedBox(height: 8),
                                                  Expanded(
                                                      flex: 3,
                                                      child: _card(
                                                          '实时频谱 / AUDIO SPECTRUM',
                                                          accent,
                                                          CustomPaint(
                                                              size:
                                                                  Size.infinite,
                                                              painter: _TelemetrySpectrum(
                                                                  accent,
                                                                  audio.state
                                                                          .isPlaying
                                                                      ? audio
                                                                          .state
                                                                          .spectrumLevels
                                                                      : const [])))),
                                                ])),
                                            const SizedBox(width: 10),
                                            Expanded(
                                                flex: 26,
                                                child: Column(children: [
                                                  Expanded(
                                                      child: _card(
                                                          '存储 / DEVICE STORAGE',
                                                          accent,
                                                          Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                _value(
                                                                    _bytes(system
                                                                        .storageFreeBytes),
                                                                    accent),
                                                                _label(
                                                                    '空闲 / 总容量 ${_bytes(system.storageTotalBytes)}',
                                                                    Colors
                                                                        .white70),
                                                                const SizedBox(
                                                                    height: 15),
                                                                LinearProgressIndicator(
                                                                    value: freeRatio?.clamp(
                                                                            0,
                                                                            1) ??
                                                                        0,
                                                                    color:
                                                                        accent,
                                                                    backgroundColor:
                                                                        accent.withValues(
                                                                            alpha:
                                                                                .12)),
                                                                const SizedBox(
                                                                    height: 9),
                                                                _label(
                                                                    freeRatio ==
                                                                            null
                                                                        ? field(
                                                                            'storageFreeBytes',
                                                                            null)
                                                                        : '空闲 ${(freeRatio * 100).toStringAsFixed(1)}%',
                                                                    accent),
                                                              ]))),
                                                  const SizedBox(height: 8),
                                                  Expanded(
                                                      child: _card(
                                                          '曲库 / LIBRARY FORMATS',
                                                          accent,
                                                          Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                for (final format
                                                                    in [
                                                                  'FLAC',
                                                                  'WAV',
                                                                  'DSD',
                                                                  'ALAC',
                                                                  'MP3'
                                                                ])
                                                                  _row(
                                                                      format,
                                                                      '${tracks.where((t) => t.format.name.toUpperCase().startsWith(format)).length}',
                                                                      accent),
                                                              ]))),
                                                  const SizedBox(height: 8),
                                                  Expanded(
                                                      child: _card(
                                                          '硬件总线 / AUDIO ROUTE',
                                                          accent,
                                                          Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                _row(
                                                                    '传输总线',
                                                                    dac.currentDevice
                                                                            ?.transport ??
                                                                        field(
                                                                            'audioTransport',
                                                                            system.audioTransport),
                                                                    accent),
                                                                _row(
                                                                    '输出声道',
                                                                    field(
                                                                        'audioChannels',
                                                                        system
                                                                            .audioChannels
                                                                            ?.toString()),
                                                                    accent),
                                                                _row(
                                                                    '会话缓冲',
                                                                    field(
                                                                        'audioBufferFrames',
                                                                        system.audioBufferFrames ==
                                                                                null
                                                                            ? null
                                                                            : '${system.audioBufferFrames} 帧'),
                                                                    accent),
                                                                _row(
                                                                    '缓冲时长',
                                                                    field(
                                                                        'audioBufferDurationMs',
                                                                        system.audioBufferDurationMs ==
                                                                                null
                                                                            ? null
                                                                            : '${system.audioBufferDurationMs!.toStringAsFixed(1)} ms'),
                                                                    accent),
                                                                _row(
                                                                    '输出延迟',
                                                                    field(
                                                                        'audioOutputLatencyMs',
                                                                        system.audioOutputLatencyMs ==
                                                                                null
                                                                            ? null
                                                                            : '${system.audioOutputLatencyMs!.toStringAsFixed(1)} ms'),
                                                                    accent),
                                                              ]))),
                                                ])),
                                          ])),
                                      const SizedBox(height: 5),
                                      Row(children: [
                                        Expanded(
                                            child: Tooltip(
                                                message: diagnostic,
                                                child: _label(
                                                    '${_system.statusLabel} · 更新 ${_time(_system.updatedAt)}'
                                                    '${_system.consecutiveFailures == 0 ? '' : ' · 连续失败 ${_system.consecutiveFailures} 次'}',
                                                    _system.lastError == null
                                                        ? accent.withValues(
                                                            alpha: .7)
                                                        : Colors
                                                            .orangeAccent))),
                                        IconButton(
                                            tooltip: '刷新硬件数据',
                                            constraints:
                                                const BoxConstraints.tightFor(
                                                    width: 28, height: 24),
                                            padding: EdgeInsets.zero,
                                            iconSize: 18,
                                            color: accent,
                                            onPressed: () =>
                                                unawaited(_system.refresh()),
                                            icon: const Icon(
                                                Icons.refresh_rounded)),
                                      ]),
                                    ])),
                              ]),
                            )),
                  )),
            ));
          });
        },
      );

  Widget _label(String text, Color color) => Text(text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 11, fontFamily: 'monospace'));
  Widget _value(String text, Color color) => Text(text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.bold));
  Widget _row(String name, String value, Color accent) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        _label(name, Colors.white54),
        const SizedBox(width: 7),
        Expanded(
            child: Align(
                alignment: Alignment.centerRight,
                child: _label(value, accent))),
      ]));
  Widget _kpi(String label, String value, Color accent) => _card(
      '',
      accent,
      Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_label(label, Colors.white54), _value(value, accent)]));
  Widget _card(String title, Color accent, Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xD90A1423),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: accent.withValues(alpha: .3)),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: .035), blurRadius: 12)
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title.isNotEmpty) ...[
          _label(title, accent),
          const SizedBox(height: 9)
        ],
        Expanded(child: child),
      ]));
}

class _TelemetryGrid extends CustomPainter {
  final Color accent;
  _TelemetryGrid(this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = accent.withValues(alpha: .045)
      ..strokeWidth = .5;
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), pen);
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pen);
    }
  }

  @override
  bool shouldRepaint(covariant _TelemetryGrid old) => accent != old.accent;
}

class _MetricRing extends CustomPainter {
  final Color accent;
  final double? fraction;
  _MetricRing(this.accent, this.fraction);
  @override
  void paint(Canvas canvas, Size size) {
    final circle = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.shortestSide / 2 - 5);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawArc(circle, 0, math.pi * 2, false,
        pen..color = accent.withValues(alpha: .1));
    if (fraction != null) {
      canvas.drawArc(circle, -math.pi / 2, math.pi * 2 * fraction!.clamp(0, 1),
          false, pen..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _MetricRing old) =>
      accent != old.accent || fraction != old.fraction;
}

class _AudioRadar extends CustomPainter {
  final Color accent;
  final double time;
  final List<double> levels;
  final bool playing;
  _AudioRadar(this.accent, this.time, this.levels, this.playing);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .42;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4,
          pen..color = accent.withValues(alpha: .12 + i * .04));
    }
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        time * math.pi * 2,
        math.pi * .8,
        false,
        pen
          ..color = accent
          ..strokeWidth = 3);
    for (var i = 0; i < 32; i++) {
      final angle = i * math.pi * 2 / 32;
      final level = playing && levels.isNotEmpty
          ? levels[i % levels.length].clamp(0, 1)
          : 0.0;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
          center + direction * radius * .5,
          center + direction * radius * (.55 + level * .35),
          pen
            ..color = accent.withValues(alpha: .65)
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioRadar old) => true;
}

class _TelemetrySpectrum extends CustomPainter {
  final Color accent;
  final List<double> levels;
  _TelemetrySpectrum(this.accent, this.levels);
  @override
  void paint(Canvas canvas, Size size) {
    const bands = 48;
    final width = size.width / bands;
    final pen = Paint()..color = accent;
    for (var i = 0; i < bands; i++) {
      final level =
          levels.isEmpty ? 0.0 : levels[i * levels.length ~/ bands].clamp(0, 1);
      canvas.drawRect(
          Rect.fromLTWH(i * width, size.height * (1 - level),
              math.max(1, width - 3), math.max(1, size.height * level)),
          pen);
    }
  }

  @override
  bool shouldRepaint(covariant _TelemetrySpectrum old) => true;
}
