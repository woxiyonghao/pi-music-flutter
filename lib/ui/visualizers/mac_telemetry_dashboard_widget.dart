import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../models/track.dart';
import '../../services/mac_system_service.dart';
import '../../services/music_database_service.dart';
import '../../services/theme_service.dart';

/// Mac counterpart of the iPad hardware screen, backed by native macOS counters.
class MacTelemetryDashboardWidget extends StatefulWidget {
  final MacSystemService? systemService;
  const MacTelemetryDashboardWidget({super.key, this.systemService});

  @override
  State<MacTelemetryDashboardWidget> createState() =>
      _MacTelemetryDashboardWidgetState();
}

class _MacTelemetryDashboardWidgetState
    extends State<MacTelemetryDashboardWidget>
    with SingleTickerProviderStateMixin {
  late MacSystemService _system;
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _system = widget.systemService ?? MacSystemService.instance;
    _system.attach();
  }

  @override
  void didUpdateWidget(covariant MacTelemetryDashboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.systemService != oldWidget.systemService) {
      _system.detach();
      _system = widget.systemService ?? MacSystemService.instance;
      _system.attach();
    }
  }

  @override
  void dispose() {
    _system.detach();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = HifiAudioService.instance;
    final db = MusicDatabaseService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _system,
        ThemeService.instance,
        audio.currentTrackNotifier,
        audio.isPlayingNotifier,
        db,
      ]),
      builder: (context, _) {
        final accent = ThemeService.instance.accentColor;
        final data = _system.snapshot;
        final cpu = data?.cpuPercent;
        final track = audio.currentTrack;
        return ColoredBox(
          color: const Color(0xFF060B15),
          child: CustomPaint(
            painter: _GridPainter(accent),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Column(children: [
                _header(accent, data),
                const SizedBox(height: 12),
                Expanded(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Expanded(
                          flex: 26,
                          child: Column(children: [
                            Expanded(flex: 36, child: _cpuCard(accent, data)),
                            const SizedBox(height: 10),
                            Expanded(
                                flex: 34, child: _memoryCard(accent, data)),
                            const SizedBox(height: 10),
                            Expanded(flex: 30, child: _powerCard(accent, data)),
                          ])),
                      const SizedBox(width: 12),
                      Expanded(
                          flex: 48,
                          child: Column(children: [
                            Expanded(
                                flex: 58,
                                child: _radar(
                                    accent, data, audio.state.isPlaying)),
                            const SizedBox(height: 10),
                            SizedBox(
                                height: 57,
                                child: Row(children: [
                                  Expanded(
                                      child: _kpi(
                                          'CPU 综合负载',
                                          cpu == null
                                              ? '采样中'
                                              : '${cpu.toStringAsFixed(1)}%',
                                          accent)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: _kpi(
                                          '内存占用',
                                          _percent(data?.memoryRatio),
                                          const Color(0xFF8F9DFF))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: _kpi(
                                          '输出采样率',
                                          _sampleRate(
                                              data?.number('outputSampleRate')),
                                          const Color(0xFF42E6B5))),
                                ])),
                            const SizedBox(height: 10),
                            Expanded(flex: 34, child: _waveCard(accent, audio)),
                          ])),
                      const SizedBox(width: 12),
                      Expanded(
                          flex: 26,
                          child: Column(children: [
                            Expanded(
                                flex: 36, child: _storageCard(accent, data)),
                            const SizedBox(height: 10),
                            Expanded(
                                flex: 34,
                                child: _libraryCard(accent, db.tracks)),
                            const SizedBox(height: 10),
                            Expanded(
                                flex: 30,
                                child: _audioCard(accent, data, track,
                                    audio.state.isPlaying)),
                          ])),
                    ])),
                const SizedBox(height: 9),
                Row(children: [
                  _label('MAC HARDWARE MASTER  /  LIVE SYSTEM TELEMETRY',
                      size: 8, color: accent.withValues(alpha: .6)),
                  const Spacer(),
                  _label(
                      _system.isUnavailable
                          ? '系统数据暂不可用 · 保留上次读数'
                          : 'macOS 原生采样 · 1 秒刷新',
                      size: 8,
                      color: _system.isUnavailable
                          ? Colors.amber
                          : Colors.white38),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _header(Color accent, MacSystemSnapshot? data) {
    final time = _system.updatedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return SizedBox(
        height: 38,
        child: Row(children: [
          Expanded(
              child: Row(children: [
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _system.isUnavailable ? Colors.amber : accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: accent.withValues(alpha: .5), blurRadius: 8)
                  ],
                )),
            const SizedBox(width: 8),
            Expanded(child: _label(data?.text('model') ?? '等待系统数据', size: 10)),
          ])),
          Container(
            width: 330,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                accent.withValues(alpha: .02),
                accent.withValues(alpha: .18),
                accent.withValues(alpha: .02)
              ]),
              border: Border.symmetric(
                  horizontal: BorderSide(color: accent.withValues(alpha: .6))),
            ),
            child: Text('Mac 硬件大师数据大屏',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: accent.withValues(alpha: .8), blurRadius: 12)
                  ],
                )),
          ),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.only(right: 56),
                  child: _label(
                      time == null
                          ? '--:--:--'
                          : '${time.year}.${two(time.month)}.${two(time.day)}  ${two(time.hour)}:${two(time.minute)}:${two(time.second)}',
                      size: 10,
                      color: accent,
                      align: TextAlign.right))),
        ]));
  }

  Widget _cpuCard(Color accent, MacSystemSnapshot? data) {
    final cores = data?.corePercents ?? const <double>[];
    return _Panel(
        title: '处理器 · 逐核负载',
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: _label(data?.text('processor') ?? '等待处理器信息',
                      size: 11, color: Colors.white)),
              const SizedBox(width: 4),
              _label('${data?.number('coreCount')?.toInt() ?? '—'} 核',
                  size: 9, color: accent),
            ]),
            const SizedBox(height: 9),
            Expanded(
                child: cores.isEmpty
                    ? Center(
                        child: _label(
                            _system.isUnavailable
                                ? '系统数据暂不可用'
                                : '正在采样 CPU 计数器…',
                            size: 10))
                    : GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 20,
                                crossAxisSpacing: 9),
                        itemCount: cores.length,
                        itemBuilder: (context, i) => Row(children: [
                          SizedBox(
                              width: 24,
                              child:
                                  _label('${i + 1}'.padLeft(2, '0'), size: 9)),
                          Expanded(child: _bar(cores[i] / 100, accent)),
                          SizedBox(
                              width: 30,
                              child: _label('${cores[i].round()}%',
                                  size: 8, align: TextAlign.right)),
                        ]),
                      )),
          ],
        ));
  }

  Widget _memoryCard(Color accent, MacSystemSnapshot? data) {
    return _Panel(
        title: '物理内存 · 实时分布',
        accent: accent,
        child: Row(children: [
          Expanded(flex: 40, child: _ring(data?.memoryRatio, accent, '已用')),
          const SizedBox(width: 10),
          Expanded(
              flex: 60,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _metric('物理内存', _bytes(data?.number('memoryTotalBytes'))),
                    _metric('系统已用', _bytes(data?.number('memoryUsedBytes'))),
                    _metric(
                        '内存压缩', _bytes(data?.number('memoryCompressedBytes'))),
                    _metric('播放器占用', _bytes(data?.number('appMemoryBytes'))),
                  ])),
        ]));
  }

  Widget _powerCard(Color accent, MacSystemSnapshot? data) {
    final battery = data?.number('batteryPercent');
    final lowPower = data?.flag('lowPowerMode');
    return _Panel(
        title: '供电与系统热状态',
        accent: accent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _metric('当前电源', data?.powerLabel ?? '—',
                valueColor: const Color(0xFF42E6B5)),
            if (battery != null)
              _metric('电池电量',
                  '${battery.round()}%${data?.flag('batteryCharging') == true ? ' · 充电中' : ''}'),
            _metric('系统热状态', data?.thermalLabel ?? '—',
                valueColor: data?.text('thermalState') == 'nominal'
                    ? const Color(0xFF42E6B5)
                    : Colors.amber),
            _metric(
                '低电量模式',
                lowPower == null
                    ? '—'
                    : lowPower
                        ? '开启'
                        : '关闭'),
            _metric('连续运行', _uptime(data?.number('uptimeSeconds'))),
          ],
        ));
  }

  Widget _radar(Color accent, MacSystemSnapshot? data, bool playing) {
    return SizedBox.expand(
      key: const ValueKey('mac.hardware.radar'),
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
            child: RepaintBoundary(
                child: CustomPaint(painter: _RadarPainter(accent, _orbit)))),
        Column(mainAxisSize: MainAxisSize.min, children: [
          _label(playing ? 'AUDIO PLAYING' : 'AUDIO STANDBY',
              color: const Color(0xFF42E6B5), size: 9),
          const SizedBox(height: 8),
          _label(data?.text('processor') ?? 'Mac',
              color: Colors.white, size: 22, bold: true),
          const SizedBox(height: 6),
          _label('SYSTEM CORE', color: accent, size: 10),
        ]),
        Positioned(left: 4, top: 6, child: _satellite('系统', 'macOS', accent)),
        Positioned(
            right: 4,
            top: 6,
            child: _satellite('音频后端', 'CoreAudio', const Color(0xFF42E6B5))),
        Positioned(
            left: 4,
            bottom: 6,
            child: _satellite('物理内存', _bytes(data?.number('memoryTotalBytes')),
                const Color(0xFF8F9DFF))),
        Positioned(
            right: 4,
            bottom: 6,
            child: _satellite('逻辑核心',
                '${data?.number('coreCount')?.toInt() ?? '—'} CORES', accent)),
      ]),
    );
  }

  Widget _waveCard(Color accent, HifiAudioService audio) {
    return _Panel(
        title: '实时音频频谱 · 能量追踪',
        accent: accent,
        child: RepaintBoundary(
          child: ListenableBuilder(
              listenable: audio,
              builder: (context, _) => CustomPaint(
                    painter: _SpectrumPainter(
                        accent,
                        audio.state.isPlaying
                            ? audio.state.spectrumLevels
                            : const []),
                    child: const SizedBox.expand(),
                  )),
        ));
  }

  Widget _storageCard(Color accent, MacSystemSnapshot? data) {
    return _Panel(
        title: '本机存储 · 用户数据卷',
        accent: accent,
        child: Column(children: [
          Expanded(
              child: Row(children: [
            Expanded(
                flex: 45,
                child: _ring(
                    data?.storageFreeRatio, const Color(0xFF42E6B5), '可用')),
            const SizedBox(width: 12),
            Expanded(
                flex: 55,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _metric('总容量', _bytes(data?.number('storageTotalBytes'))),
                      _metric('可用空间', _bytes(data?.number('storageFreeBytes'))),
                    ])),
          ])),
          const SizedBox(height: 6),
          _label(data?.text('storageName') ?? '等待存储信息',
              size: 9, color: Colors.white54),
        ]));
  }

  Widget _libraryCard(Color accent, List<Track> tracks) {
    final counts = [0, 0, 0, 0];
    for (final track in tracks) {
      final isDsd = track.format == AudioFormat.dsdDsf ||
          track.format == AudioFormat.dsdDff;
      counts[isDsd
          ? 0
          : track.sampleRate > 48000
              ? 1
              : track.sampleRate > 0
                  ? 2
                  : 3]++;
    }
    const labels = ['DSD', 'PCM > 48k', 'PCM ≤ 48k', '规格未识别'];
    final colors = [
      const Color(0xFFE18BFF),
      accent,
      const Color(0xFF42E6B5),
      Colors.blueGrey
    ];
    return _Panel(
        title: '曲库规格分布 · ${tracks.length} 首',
        accent: accent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
              4,
              (i) => Row(children: [
                    SizedBox(width: 76, child: _label(labels[i], size: 9)),
                    Expanded(
                        child: _bar(
                            tracks.isEmpty ? 0 : counts[i] / tracks.length,
                            colors[i])),
                    const SizedBox(width: 6),
                    SizedBox(
                        width: 28,
                        child: _label('${counts[i]}',
                            size: 9, align: TextAlign.right)),
                  ])),
        ));
  }

  Widget _audioCard(
      Color accent, MacSystemSnapshot? data, Track? track, bool playing) {
    return _Panel(
        title: '系统音频输出',
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _label(data?.text('outputName') ?? '未检测到输出设备',
                size: 11, color: accent, bold: true),
            _metric('输出状态', playing ? '播放中' : '待机'),
            _metric('源文件规格', _sourceFormat(track)),
            _metric(
                '设备缓冲',
                data?.number('outputBufferFrames') == null
                    ? '—'
                    : '${data!.number('outputBufferFrames')!.toInt()} 帧'),
          ],
        ));
  }

  Widget _satellite(String title, String value, Color accent) => Container(
        width: 100,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: const Color(0xE60C1726),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: accent.withValues(alpha: .35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(title, size: 8),
          const SizedBox(height: 2),
          _label(value, size: 10, color: accent, bold: true),
        ]),
      );

  Widget _kpi(String title, String value, Color accent) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: const Color(0xFF0D1828),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: accent.withValues(alpha: .35))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _label(title, size: 9),
              const SizedBox(height: 4),
              _label(value, size: 16, color: accent, bold: true),
            ]),
      );

  Widget _ring(double? ratio, Color accent, String title) =>
      LayoutBuilder(builder: (context, constraints) {
        final diameter =
            math.min(constraints.maxWidth, constraints.maxHeight) - 4;
        return Center(
            child: SizedBox(
                width: diameter,
                height: diameter,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(
                      child: CircularProgressIndicator(
                          value: ratio ?? 0,
                          strokeWidth: 6,
                          color: accent,
                          backgroundColor: accent.withValues(alpha: .1))),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    _label(title, size: 9),
                    const SizedBox(height: 3),
                    _label(_percent(ratio),
                        color: accent, size: 17, bold: true),
                  ]),
                ])));
      });

  Widget _metric(String title, String value,
          {Color valueColor = const Color(0xFFD7E4F2)}) =>
      Row(children: [
        Expanded(child: _label(title, size: 9)),
        const SizedBox(width: 5),
        Flexible(
            flex: 2,
            child: _label(value,
                size: 10, color: valueColor, align: TextAlign.right)),
      ]);

  Widget _bar(double ratio, Color color) => ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: ratio.clamp(0, 1),
        minHeight: 4,
        color: color,
        backgroundColor: color.withValues(alpha: .1),
      ));

  static String _percent(double? ratio) =>
      ratio == null ? '—' : '${(ratio * 100).round()}%';
  static String _sampleRate(double? rate) => rate == null
      ? '—'
      : '${(rate / 1000).toStringAsFixed(rate % 1000 == 0 ? 0 : 1)} kHz';
  static String _bytes(double? value) {
    if (value == null) return '—';
    const gib = 1024 * 1024 * 1024;
    return value >= gib
        ? '${(value / gib).toStringAsFixed(1)} GiB'
        : '${(value / (1024 * 1024)).round()} MiB';
  }

  static String _sourceFormat(Track? track) {
    if (track == null) return '未载入';
    if (track.sampleRate <= 0) return '未识别';
    if (track.format == AudioFormat.dsdDsf ||
        track.format == AudioFormat.dsdDff) {
      return 'DSD ${(track.sampleRate / 44100).round()}x';
    }
    return '${_sampleRate(track.sampleRate.toDouble())}${track.bitDepth > 0 ? ' / ${track.bitDepth}bit' : ''}';
  }

  static String _uptime(double? seconds) {
    if (seconds == null) return '—';
    final duration = Duration(seconds: seconds.toInt());
    return '${duration.inDays}天 ${duration.inHours % 24}时 ${duration.inMinutes % 60}分';
  }
}

Widget _label(String text,
        {double size = 10,
        Color color = const Color(0xFF8599B0),
        bool bold = false,
        TextAlign? align}) =>
    Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          fontFamily: 'Menlo',
          decoration: TextDecoration.none),
    );

class _Panel extends StatelessWidget {
  final String title;
  final Color accent;
  final Widget child;
  const _Panel(
      {required this.title, required this.accent, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xEF101E30), Color(0xEE0A1321)]),
          border: Border.all(color: accent.withValues(alpha: .25)),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 3, height: 10, color: accent),
            const SizedBox(width: 7),
            Expanded(
                child: _label(title,
                    size: 10, color: const Color(0xFFD7E4F2), bold: true)),
            _label('···', color: accent),
          ]),
          const SizedBox(height: 10),
          Expanded(child: child),
        ]),
      );
}

class _GridPainter extends CustomPainter {
  final Color accent;
  _GridPainter(this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: .035)
      ..strokeWidth = .5;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
                  colors: [accent.withValues(alpha: .05), Colors.transparent])
              .createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => accent != oldDelegate.accent;
}

class _RadarPainter extends CustomPainter {
  final Color accent;
  final Animation<double> animation;
  _RadarPainter(this.accent, this.animation) : super(repaint: animation);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width * .37, size.height * .43);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
        center,
        radius * 1.16,
        Paint()
          ..shader = RadialGradient(
                  colors: [accent.withValues(alpha: .12), Colors.transparent])
              .createShader(
                  Rect.fromCircle(center: center, radius: radius * 1.16)));
    for (final scale in [.62, .78, .93, 1.0]) {
      pen.color = accent.withValues(alpha: scale == 1 ? .4 : .15);
      canvas.drawCircle(center, radius * scale, pen);
    }
    for (var i = 0; i < 72; i++) {
      final angle = i * math.pi / 36;
      final direction = Offset(math.cos(angle), math.sin(angle));
      pen.color = accent.withValues(alpha: i % 6 == 0 ? .6 : .2);
      canvas.drawLine(center + direction * radius * 1.04,
          center + direction * radius * (i % 6 == 0 ? 1.11 : 1.07), pen);
    }
    pen.strokeWidth = 3;
    for (var i = 0; i < 3; i++) {
      pen.color = accent.withValues(alpha: .7);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius * .88),
          animation.value * 2 * math.pi + i * 2 * math.pi / 3, .65, false, pen);
    }
    pen.strokeWidth = 1;
    pen.color = accent.withValues(alpha: .1);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), pen);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), pen);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      accent != oldDelegate.accent || animation != oldDelegate.animation;
}

class _SpectrumPainter extends CustomPainter {
  final Color accent;
  final List<double> levels;
  _SpectrumPainter(this.accent, this.levels);
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = accent.withValues(alpha: .1)
      ..strokeWidth = .5;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4),
          Offset(size.width, size.height * i / 4), pen);
    }
    final count = levels.isEmpty ? 48 : levels.length;
    final step = size.width / count;
    for (var i = 0; i < count; i++) {
      final level = levels.isEmpty ? 0.0 : levels[i].clamp(0.0, 1.0);
      final height = math.max(1.0, level * size.height * .95);
      final rect = Rect.fromLTWH(
          i * step + 1, size.height - height, math.max(1, step - 2), height);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [accent.withValues(alpha: .15), accent])
                .createShader(rect));
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter oldDelegate) => true;
}
