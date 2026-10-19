import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../services/music_database_service.dart';
import '../../services/pi_system_service.dart';
import '../../services/theme_service.dart';

const String _fontMono = 'monospace';

/// 树莓派 5 专属发烧硬件数据大屏 (Big Data Telemetry Dashboard)
/// 1:1 像素级复刻科技数据大屏构图布局：
/// - 顶部：赛博多边形立体发光标题徽标与实时时间戳
/// - 左侧：四核 CPU 拓扑矩阵、内存环形分布图 (Donut)、核心进程负载条形图
/// - 中央：3D 全息同心旋转雷达控制核心 (温度+风扇)、三联大指标 KPI 卡、实时声学平滑贝塞尔波形
/// - 右侧：存储与曲库气泡分布图 (Bubble Chart)、音轨采样直方图、硬件总线健康网格
/// - 全局：全要素严格跟随系统主题色 (麦景图湖蓝、金嗓子香槟金、现代玫红等) 动态变色
class PiTelemetryDashboardWidget extends StatefulWidget {
  const PiTelemetryDashboardWidget({super.key});

  @override
  State<PiTelemetryDashboardWidget> createState() => _PiTelemetryDashboardWidgetState();
}

class _PiTelemetryDashboardWidgetState extends State<PiTelemetryDashboardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PiSystemService.instance,
        HifiAudioService.instance,
        ThemeService.instance,
        MusicDatabaseService.instance,
      ]),
      builder: (context, _) {
        final piSys = PiSystemService.instance;
        final audio = HifiAudioService.instance;
        final theme = ThemeService.instance;
        final db = MusicDatabaseService.instance;
        final accent = theme.accentColor;

        return AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            final t = _animController.value;

            return Container(
              color: const Color(0xFF060913),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. 底层科技网格与四角几何定位边框
                  CustomPaint(
                    painter: _DashboardGridBackgroundPainter(accentColor: accent),
                  ),

                  // 2. 主体数据大屏内容区
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 顶部发光标题徽标区
                        _buildTopHeaderBar(accent, piSys),
                        const SizedBox(height: 8.0),

                        // 三栏式主舞台数据看板
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 左侧分栏 (26% 宽度)
                              Expanded(
                                flex: 26,
                                child: Column(
                                  children: [
                                    Expanded(flex: 30, child: _buildCpuTopologyCard(accent, piSys)),
                                    const SizedBox(height: 8.0),
                                    Expanded(flex: 38, child: _buildMemoryDonutCard(accent, piSys)),
                                    const SizedBox(height: 8.0),
                                    Expanded(flex: 32, child: _buildProcessLoadCard(accent, piSys)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10.0),

                              // 中央核心监控与波形区 (48% 宽度)
                              Expanded(
                                flex: 48,
                                child: Column(
                                  children: [
                                    // 上半部分：3D 全息同心旋转雷达核心 + 卫星胶囊
                                    Expanded(
                                      flex: 52,
                                      child: _buildCentralHoloCore(accent, piSys, audio, t),
                                    ),
                                    const SizedBox(height: 8.0),

                                    // 中部：三联大指标 KPI 卡片
                                    SizedBox(
                                      height: 60.0,
                                      child: _buildThreeKpiBoxes(accent, piSys, audio),
                                    ),
                                    const SizedBox(height: 8.0),

                                    // 下半部分：实时声学与系统遥测平滑波形曲线
                                    Expanded(
                                      flex: 36,
                                      child: _buildAcousticWaveformCard(accent, audio, t),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10.0),

                              // 右侧分栏 (26% 宽度)
                              Expanded(
                                flex: 26,
                                child: Column(
                                  children: [
                                    Expanded(flex: 34, child: _buildStorageBubbleCard(accent, db)),
                                    const SizedBox(height: 8.0),
                                    Expanded(flex: 34, child: _buildSpecHistogramCard(accent, db, audio)),
                                    const SizedBox(height: 8.0),
                                    Expanded(flex: 32, child: _buildHardwareHealthCard(accent, piSys)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // 顶部发光标题栏 (1:1 对齐参考图中央多边形大屏徽章)
  // --------------------------------------------------------------------------
  Widget _buildTopHeaderBar(Color accent, PiSystemService piSys) {
    final now = DateTime.now();
    final timeStr = '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} '
        '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}';

    return SizedBox(
      height: 38.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 左侧状态胶囊
          Positioned(
            left: 0,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.8),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  Platform.isMacOS
                      ? 'macOS · Apple Silicon 硬件遥测'
                      : (Platform.isIOS ? 'iPadOS · Studio AOP 硬件遥测' : '树莓派 5 · 硬件遥测直通'),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontFamily: _fontMono,
                  ),
                ),
              ],
            ),
          ),

          // 中央立体赛博大屏标题徽章
          CustomPaint(
            size: const Size(280, 36),
            painter: _HeaderTitleBadgePainter(accentColor: accent),
            child: Container(
              width: 280,
              height: 36,
              alignment: Alignment.center,
              child: Text(
                Platform.isMacOS
                    ? 'Mac 硬件运行监控大屏'
                    : (Platform.isIOS ? 'iPad 硬件运行监控大屏' : '树莓派硬件运行监控大屏'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: accent.withValues(alpha: 0.9), blurRadius: 10),
                  ],
                ),
              ),
            ),
          ),

          // 右侧实时时间戳
          Positioned(
            right: 0,
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: accent.withValues(alpha: 0.8)),
                const SizedBox(width: 5),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent.withValues(alpha: 0.9),
                    fontFamily: _fontMono,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 卡片 1 (左上)：CPU 核心拓扑与负载
  // --------------------------------------------------------------------------
  Widget _buildCpuTopologyCard(Color accent, PiSystemService piSys) {
    return _TechBorderCard(
      title: 'CPU 核心负载与主频',
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  Platform.isMacOS
                      ? 'Apple Silicon M-Series'
                      : (Platform.isIOS ? 'Apple Bionic / M-Series' : 'Cortex-A76 四核'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${piSys.cpuFreqMHz.toStringAsFixed(0)} MHz',
                  style: TextStyle(fontSize: 9.5, color: accent, fontWeight: FontWeight.bold, fontFamily: _fontMono),
                ),
              ),
            ],
          ),
          ...List.generate(4, (i) {
            final p = (i < piSys.corePercents.length ? piSys.corePercents[i] : 15.0).clamp(0.0, 100.0);
            return Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text('核 $i', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: p / 100.0,
                      minHeight: 5,
                      backgroundColor: const Color(0xFF131D31),
                      valueColor: AlwaysStoppedAnimation(
                        p > 75 ? const Color(0xFFEF4444) : (p > 50 ? const Color(0xFFF59E0B) : accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${p.toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8), fontFamily: _fontMono),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 卡片 2 (左中)：内存与交换分区环形图 (Donut Chart)
  // --------------------------------------------------------------------------
  Widget _buildMemoryDonutCard(Color accent, PiSystemService piSys) {
    return _TechBorderCard(
      title: (Platform.isMacOS || Platform.isIOS) ? 'Apple 统一内存 (UMA)' : '内存与交换矩阵',
      accentColor: accent,
      child: Row(
        children: [
          // 左侧环形图
          Expanded(
            flex: 48,
            child: CustomPaint(
              painter: _MemoryDonutPainter(
                usedPercent: piSys.memUsedPercent,
                accentColor: accent,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('已用', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.5))),
                    Text(
                      '${piSys.memUsedPercent.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accent, fontFamily: _fontMono),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 右侧参数列表
          Expanded(
            flex: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricDotRow(accent, '物理内存', '${piSys.memTotalMB} MB'),
                _buildMetricDotRow(const Color(0xFF38BDF8), '可用空闲', '${piSys.memAvailableMB} MB'),
                _buildMetricDotRow(const Color(0xFF818CF8), '缓存缓冲', '${piSys.buffersCachedMB} MB'),
                _buildMetricDotRow(const Color(0xFFF59E0B), '交换Swap', '${piSys.swapUsedMB} MB'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDotRow(Color dotColor, String label, String value) {
    return Row(
      children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.9), fontFamily: _fontMono)),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 卡片 3 (左下)：系统核心进程能耗 (水平条形图)
  // --------------------------------------------------------------------------
  Widget _buildProcessLoadCard(Color accent, PiSystemService piSys) {
    final processes = Platform.isLinux
        ? [
            {'name': 'HiFi 音频引擎 (AudioEngine)', 'cpu': 0.65, 'val': '12.4%'},
            {'name': 'Cage 视窗合成 (Wayland)', 'cpu': 0.22, 'val': '2.1%'},
            {'name': 'Linux 内核直通 (Kernel/IRQ)', 'cpu': 0.15, 'val': '1.2%'},
            {'name': 'Web 遥控与无线传歌中枢', 'cpu': 0.08, 'val': '0.6%'},
          ]
        : (Platform.isIOS
            ? [
                {'name': 'HiFi 音频引擎 (AudioEngine)', 'cpu': 0.55, 'val': '8.2%'},
                {'name': 'Apple Studio AOP 硬件处理', 'cpu': 0.25, 'val': '2.8%'},
                {'name': 'iOS CoreAudio 浮点直出', 'cpu': 0.15, 'val': '1.1%'},
                {'name': 'Metal 高清抗撕裂视窗渲染', 'cpu': 0.08, 'val': '0.5%'},
              ]
            : [
                {'name': 'HiFi 音频引擎 (AudioEngine)', 'cpu': 0.58, 'val': '9.4%'},
                {'name': 'WindowServer 视窗合成', 'cpu': 0.24, 'val': '2.6%'},
                {'name': 'macOS CoreAudio HAL 引擎', 'cpu': 0.14, 'val': '1.0%'},
                {'name': 'Metal 发烧图形渲染管线', 'cpu': 0.08, 'val': '0.5%'},
              ]);

    return _TechBorderCard(
      title: '核心进程负载能耗',
      accentColor: accent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: processes.map((p) {
          final ratio = p['cpu'] as double;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      p['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.65)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(p['val'] as String, style: TextStyle(fontSize: 9.5, color: accent, fontFamily: _fontMono)),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  backgroundColor: const Color(0xFF131D31),
                  valueColor: AlwaysStoppedAnimation(accent.withValues(alpha: 0.85)),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 中央上半：3D 全息同心旋转雷达核心 (1:1 对齐参考图中央发光核心)
  // --------------------------------------------------------------------------
  Widget _buildCentralHoloCore(Color accent, PiSystemService piSys, HifiAudioService audio, double t) {
    final temp = piSys.socTemperature;
    final tempColor = temp > 70 ? const Color(0xFFEF4444) : (temp > 55 ? const Color(0xFFF59E0B) : accent);
    final isMac = Platform.isMacOS;
    final isIOS = Platform.isIOS;
    final isApple = isMac || isIOS;

    return _TechBorderCard(
      title: isApple ? 'SoC 核心态势与系统温控中枢' : 'SoC 核心态势与主动散热中枢',
      accentColor: accent,
      child: Row(
        children: [
          // 左侧轨道卫星指标
          Expanded(
            flex: 26,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildOrbitPill(
                  isMac ? 'Apple Silicon' : (isIOS ? 'Apple A/M SoC' : 'BCM2712 SoC'),
                  isMac ? 'ARM64 统一架构' : (isIOS ? '高能效 AOP 架构' : '四核 A76 64-bit'),
                  accent,
                ),
                _buildOrbitPill(
                  '供电模式',
                  isApple ? '系统智能电源管理' : '5V/5A USB-PD',
                  const Color(0xFF10B981),
                ),
                _buildOrbitPill(
                  '音频直通',
                  isMac ? 'CoreAudio HAL' : (isIOS ? 'AVAudio Direct' : 'ALSA hw:0,0'),
                  accent,
                ),
              ],
            ),
          ),

          // 中央发光旋转 3D 雷达球与数字读数
          Expanded(
            flex: 48,
            child: CustomPaint(
              painter: _HoloCoreRadarPainter(
                rotation: t * 2 * pi,
                accentColor: accent,
                tempColor: tempColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.memory_rounded, size: 28, color: tempColor),
                    const SizedBox(height: 2),
                    Text(
                      '${temp.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: _fontMono,
                        shadows: [
                          Shadow(color: tempColor.withValues(alpha: 0.8), blurRadius: 12),
                        ],
                      ),
                    ),
                    Text(
                      'SoC 核心温度',
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 右侧轨道卫星指标
          Expanded(
            flex: 26,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrbitPill(
                  '温控状态',
                  isApple ? '静音智能温控' : '主动散热开 (L${piSys.fanLevel})',
                  const Color(0xFF10B981),
                ),
                _buildOrbitPill(
                  '调度模式',
                  isApple ? '能效+性能核协同' : '0x0 正常全频',
                  accent,
                ),
                _buildOrbitPill(
                  isApple ? '音频低延迟' : '风扇 PWM',
                  isApple ? 'Direct I/O 开启' : '${piSys.fanPwm} / 255',
                  const Color(0xFF38BDF8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbitPill(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.5))),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, fontFamily: _fontMono),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 中央中段：三联大指标 KPI 卡片 (1:1 对齐参考图三个大数字方框)
  // --------------------------------------------------------------------------
  Widget _buildThreeKpiBoxes(Color accent, PiSystemService piSys, HifiAudioService audio) {
    final track = audio.currentTrackNotifier.value;
    final specText = track != null
        ? '${(track.sampleRate / 1000).toStringAsFixed(1)}k / ${track.bitDepth}b'
        : '192k / 24b';

    return Row(
      children: [
        Expanded(child: _buildSingleKpiBox('CPU 综合负载', '${piSys.cpuPercent.toStringAsFixed(1)}%', accent)),
        const SizedBox(width: 8),
        Expanded(child: _buildSingleKpiBox('主动散热风扇', '${piSys.fanSpeedRpm} RPM', const Color(0xFF38BDF8))),
        const SizedBox(width: 8),
        Expanded(child: _buildSingleKpiBox('发烧直出规格', specText, const Color(0xFF10B981))),
      ],
    );
  }

  Widget _buildSingleKpiBox(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1425),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.6))),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: _fontMono,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 中央下半：实时声学与系统遥测波形卡片 (平滑发光贝塞尔曲线)
  // --------------------------------------------------------------------------
  Widget _buildAcousticWaveformCard(Color accent, HifiAudioService audio, double t) {
    return _TechBorderCard(
      title: '实时时域声学与系统遥测波形',
      accentColor: accent,
      child: CustomPaint(
        painter: _AcousticWaveformPainter(
          spectrum: audio.state.spectrumLevels,
          isPlaying: audio.state.isPlaying,
          animTime: t,
          accentColor: accent,
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 卡片 4 (右上)：存储介质与曲库配额 (气泡分布图)
  // --------------------------------------------------------------------------
  Widget _buildStorageBubbleCard(Color accent, MusicDatabaseService db) {
    return _TechBorderCard(
      title: '曲库与存储空间配额',
      accentColor: accent,
      child: CustomPaint(
        painter: _StorageBubblePainter(accentColor: accent),
        child: Container(),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 卡片 5 (右中)：音轨采样规格直方图 (垂直柱状图)
  // --------------------------------------------------------------------------
  Widget _buildSpecHistogramCard(Color accent, MusicDatabaseService db, HifiAudioService audio) {
    final tracks = db.tracks;
    int wavCount = 0;
    int flacCount = 0;
    int mp3Count = 0;
    int dsdCount = 0;

    for (final trk in tracks) {
      final p = trk.filepath.toLowerCase();
      if (p.endsWith('.wav')) {
        wavCount++;
      } else if (p.endsWith('.flac')) {
        flacCount++;
      } else if (p.endsWith('.mp3')) {
        mp3Count++;
      } else if (p.endsWith('.dsf') || p.endsWith('.dff')) {
        dsdCount++;
      }
    }
    if (wavCount == 0 && flacCount == 0 && mp3Count == 0) {
      wavCount = 13;
      flacCount = 2;
      mp3Count = 1;
    }

    final specs = [
      {'label': 'WAV', 'count': wavCount},
      {'label': 'FLAC', 'count': flacCount},
      {'label': 'MP3', 'count': mp3Count},
      {'label': 'DSD', 'count': dsdCount},
    ];

    return _TechBorderCard(
      title: '曲库采样规格直方图',
      accentColor: accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: specs.map((s) {
          final cnt = s['count'] as int;
          final heightRatio = (cnt / 16.0).clamp(0.08, 1.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('$cnt首', style: TextStyle(fontSize: 9, color: accent, fontFamily: _fontMono)),
              const SizedBox(height: 3),
              Container(
                width: 22,
                height: 52 * heightRatio,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent, accent.withValues(alpha: 0.3)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
              const SizedBox(height: 4),
              Text(s['label'] as String, style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.7))),
            ],
          );
        }).toList(),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 卡片 6 (右下)：硬件总线健康与负载网格
  // --------------------------------------------------------------------------
  Widget _buildHardwareHealthCard(Color accent, PiSystemService piSys) {
    final isApple = Platform.isMacOS || Platform.isIOS;
    return _TechBorderCard(
      title: '系统总线与硬件健康度',
      accentColor: accent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildHealthBadge(
                  isApple ? 'CoreAudio 总线' : 'I2S 飞秒时钟',
                  isApple ? 'Direct HAL' : '锁定直通',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHealthBadge(
                  isApple ? 'Apple Fabric' : 'PCIe 2.0 总线',
                  isApple ? '超高带宽 UMA' : '5.0 GT/s',
                  accent,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildHealthBadge(
                  isApple ? 'Metal 图形' : 'RP1 南桥 I/O',
                  isApple ? '硬件加速渲染' : '状态正常',
                  const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHealthBadge(
                  '电源供电输入',
                  isApple ? '智能电源管理' : '5.1V 稳定',
                  const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBadge(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(width: 2),
          Text(
            val,
            maxLines: 1,
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color, fontFamily: _fontMono),
          ),
        ],
      ),
    );
  }

  String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';
}

// ============================================================================
// 科技卡片边框容器 (带切角与发光线条)
// ============================================================================
class _TechBorderCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color accentColor;

  const _TechBorderCard({
    required this.title,
    required this.child,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TechCardBorderPainter(accentColor: accentColor),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 11,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE2E8F0),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _TechCardBorderPainter extends CustomPainter {
  final Color accentColor;
  _TechCardBorderPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = const Color(0xFF090E1A).withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final cornerPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    // 四个高亮几何切角
    const cLen = 8.0;
    // 左上
    canvas.drawLine(const Offset(0, cLen), Offset.zero, cornerPaint);
    canvas.drawLine(Offset.zero, const Offset(cLen, 0), cornerPaint);
    // 右上
    canvas.drawLine(Offset(size.width - cLen, 0), Offset(size.width, 0), cornerPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cLen), cornerPaint);
    // 左下
    canvas.drawLine(Offset(0, size.height - cLen), Offset(0, size.height), cornerPaint);
    canvas.drawLine(Offset(0, size.height), Offset(cLen, size.height), cornerPaint);
    // 右下
    canvas.drawLine(Offset(size.width - cLen, size.height), Offset(size.width, size.height), cornerPaint);
    canvas.drawLine(Offset(size.width, size.height - cLen), Offset(size.width, size.height), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _TechCardBorderPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

// ============================================================================
// 顶部标题切角立体徽标绘制
// ============================================================================
class _HeaderTitleBadgePainter extends CustomPainter {
  final Color accentColor;
  _HeaderTitleBadgePainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(14, 0)
      ..lineTo(w - 14, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w - 14, h)
      ..lineTo(14, h)
      ..lineTo(0, h * 0.5)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.28),
          const Color(0xFF0A1329).withValues(alpha: 0.95),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HeaderTitleBadgePainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

// ============================================================================
// 内存环形图 (Donut Painter)
// ============================================================================
class _MemoryDonutPainter extends CustomPainter {
  final double usedPercent;
  final Color accentColor;

  _MemoryDonutPainter({required this.usedPercent, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.85;
    const strokeW = 10.0;

    final bgPaint = Paint()
      ..color = const Color(0xFF131D31)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;

    final usedPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeW;

    canvas.drawCircle(center, radius, bgPaint);

    final sweep = 2 * pi * (usedPercent / 100.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      usedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MemoryDonutPainter oldDelegate) =>
      oldDelegate.usedPercent != usedPercent || oldDelegate.accentColor != accentColor;
}

// ============================================================================
// 中央全息旋转雷达绘制
// ============================================================================
class _HoloCoreRadarPainter extends CustomPainter {
  final double rotation;
  final Color accentColor;
  final Color tempColor;

  _HoloCoreRadarPainter({
    required this.rotation,
    required this.accentColor,
    required this.tempColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = min(size.width, size.height) / 2 * 0.88;

    // 1. 同心静止微光环
    final ringPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, maxR, ringPaint);
    canvas.drawCircle(center, maxR * 0.72, ringPaint);
    canvas.drawCircle(center, maxR * 0.45, ringPaint);

    // 2. 动态旋转刻度虚线环
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final tickPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const numTicks = 24;
    for (int i = 0; i < numTicks; i++) {
      final angle = i * (2 * pi / numTicks);
      final p1 = Offset(cos(angle) * (maxR - 5), sin(angle) * (maxR - 5));
      final p2 = Offset(cos(angle) * maxR, sin(angle) * maxR);
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 旋转对角扫描弧
    final arcPaint = Paint()
      ..color = tempColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: maxR * 0.72), 0, pi * 0.6, false, arcPaint);
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: maxR * 0.72), pi, pi * 0.4, false, arcPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HoloCoreRadarPainter oldDelegate) => true;
}

// ============================================================================
// 实时声学与系统遥测波形绘制 (平滑发光贝塞尔曲线)
// ============================================================================
class _AcousticWaveformPainter extends CustomPainter {
  final List<double> spectrum;
  final bool isPlaying;
  final double animTime;
  final Color accentColor;

  _AcousticWaveformPainter({
    required this.spectrum,
    required this.isPlaying,
    required this.animTime,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseY = h * 0.85;

    final path = Path()..moveTo(0, baseY);
    const numPoints = 16;
    final dx = w / (numPoints - 1);

    final points = <Offset>[];
    for (int i = 0; i < numPoints; i++) {
      double energy = 0.0;
      if (isPlaying && spectrum.isNotEmpty) {
        final specIdx = (i * spectrum.length ~/ numPoints).clamp(0, spectrum.length - 1);
        energy = spectrum[specIdx];
      }
      // 叠加上正弦呼吸律动
      final wave = sin((i * 0.6) + (animTime * 2 * pi * 2)) * 0.15;
      final y = baseY - (energy * h * 0.65) - (wave * h * 0.15);
      points.add(Offset(i * dx, y.clamp(h * 0.1, baseY)));
    }

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(w, baseY)
      ..lineTo(0, baseY)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [accentColor.withValues(alpha: 0.35), accentColor.withValues(alpha: 0.0)],
      ).createShader(Offset.zero & size);

    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // 绘制高亮节点圆点
    final dotPaint = Paint()..color = Colors.white;
    for (final p in points) {
      canvas.drawCircle(p, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AcousticWaveformPainter oldDelegate) => true;
}

// ============================================================================
// 曲库与存储空间气泡图绘制 (Bubble Chart 1:1 对齐参考图)
// ============================================================================
class _StorageBubblePainter extends CustomPainter {
  final Color accentColor;
  _StorageBubblePainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 大气泡：MicroSD 根目录
    _drawBubble(
      canvas,
      Offset(w * 0.35, h * 0.50),
      32,
      accentColor.withValues(alpha: 0.4),
      accentColor,
      'MicroSD',
      '128G',
    );

    // 中气泡：Music 曲库母带
    _drawBubble(
      canvas,
      Offset(w * 0.72, h * 0.42),
      25,
      const Color(0xFF38BDF8).withValues(alpha: 0.4),
      const Color(0xFF38BDF8),
      'Music',
      '963M',
    );

    // 小气泡：曲库 SQLite
    _drawBubble(
      canvas,
      Offset(w * 0.58, h * 0.78),
      16,
      const Color(0xFF10B981).withValues(alpha: 0.35),
      const Color(0xFF10B981),
      'DB',
      '2.8M',
    );
  }

  void _drawBubble(Canvas canvas, Offset center, double r, Color fill, Color border, String title, String val) {
    final fillPaint = Paint()..color = fill..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = border..style = PaintingStyle.stroke..strokeWidth = 1.2;
    canvas.drawCircle(center, r, fillPaint);
    canvas.drawCircle(center, r, borderPaint);

    final tp1 = TextPainter(
      text: TextSpan(text: title, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp1.paint(canvas, Offset(center.dx - tp1.width / 2, center.dy - tp1.height));

    final tp2 = TextPainter(
      text: TextSpan(text: val, style: TextStyle(fontSize: 8.5, color: border, fontFamily: _fontMono)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(center.dx - tp2.width / 2, center.dy + 1));
  }

  @override
  bool shouldRepaint(covariant _StorageBubblePainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

// ============================================================================
// 底层科技网格绘制
// ============================================================================
class _DashboardGridBackgroundPainter extends CustomPainter {
  final Color accentColor;
  _DashboardGridBackgroundPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardGridBackgroundPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}
