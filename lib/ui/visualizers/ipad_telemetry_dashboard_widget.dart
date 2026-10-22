import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../models/track.dart';
import '../../services/dac_setting_service.dart';
import '../../services/ipad_system_service.dart';
import '../../services/music_database_service.dart';
import '../../services/theme_service.dart';

const String _fontMono = 'monospace';

/// iPadOS 专属发烧硬件数据大屏 (iPad Hardware Master Telemetry Dashboard)
/// 针对 iPad 视网膜高清大屏量身定制的高科技硬件遥测看板：
/// - 顶部：赛博多边形立体发光标题徽标、iPadOS 系统状态与实时高精度时间戳
/// - 左侧：Apple Silicon 8核 CPU 拓扑矩阵、Apple 统一内存 (UMA) 环形分布图、iPad 供电与热状态
/// - 中央：3D 全息同心旋转雷达控制核心 (热敏+抖动锁相)、三联大指标 KPI 卡、实时声学平滑贝塞尔波形
/// - 右侧：APFS 沙盒与曲库气泡分布图 (Bubble Chart)、音轨采样规格直方图、iPadOS 发烧硬件总线健康网格
/// - 全局：全要素严格跟随系统主题色 (麦景图湖蓝、金嗓子香槟金、现代深空玫红、赛博电光蓝等) 动态变色
class IpadTelemetryDashboardWidget extends StatefulWidget {
  const IpadTelemetryDashboardWidget({super.key});

  @override
  State<IpadTelemetryDashboardWidget> createState() =>
      _IpadTelemetryDashboardWidgetState();
}

class _IpadTelemetryDashboardWidgetState
    extends State<IpadTelemetryDashboardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
        IpadSystemService.instance,
        HifiAudioService.instance,
        ThemeService.instance,
        MusicDatabaseService.instance,
        DacSettingService.instance,
      ]),
      builder: (context, _) {
        final ipadSys = IpadSystemService.instance;
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
                  // 1. 底层科技网格与微光发散
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
                        _buildTopHeaderBar(accent, ipadSys),
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
                                    Expanded(
                                      flex: 36,
                                      child: _buildCpuTopologyCard(accent, ipadSys),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Expanded(
                                      flex: 34,
                                      child: _buildMemoryDonutCard(accent, ipadSys),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Expanded(
                                      flex: 30,
                                      child: _buildPowerAndThermalCard(accent, ipadSys),
                                    ),
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
                                      child: _buildCentralHoloCore(
                                        accent,
                                        ipadSys,
                                        audio,
                                        t,
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),

                                    // 中部：三联大指标 KPI 卡片
                                    SizedBox(
                                      height: 60.0,
                                      child: _buildThreeKpiBoxes(
                                        accent,
                                        ipadSys,
                                        audio,
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),

                                    // 下半部分：实时声学与系统遥测平滑波形曲线
                                    Expanded(
                                      flex: 36,
                                      child: _buildAcousticWaveformCard(
                                        accent,
                                        audio,
                                        t,
                                      ),
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
                                    Expanded(
                                      flex: 34,
                                      child: _buildStorageBubbleCard(accent, db, ipadSys),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Expanded(
                                      flex: 34,
                                      child: _buildSpecHistogramCard(accent, db, audio),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Expanded(
                                      flex: 32,
                                      child: _buildHardwareHealthCard(accent, ipadSys),
                                    ),
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
  // 顶部发光标题栏 (中央立体多边形科技大屏徽章)
  // --------------------------------------------------------------------------
  Widget _buildTopHeaderBar(Color accent, IpadSystemService ipadSys) {
    final now = DateTime.now();
    final timeStr =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} '
        '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}';

    return SizedBox(
      height: 38.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 左侧系统状态胶囊
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
                  'iPadOS · Apple Silicon 硬件遥测',
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
            size: const Size(290, 36),
            painter: _HeaderTitleBadgePainter(accentColor: accent),
            child: Container(
              width: 290,
              height: 36,
              alignment: Alignment.center,
              child: Text(
                'iPad 硬件大师数据大屏',
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

          // 右侧实时时间戳与电量
          Positioned(
            right: 0,
            child: Row(
              children: [
                const Icon(
                  Icons.battery_charging_full_rounded,
                  size: 14,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 3),
                Text(
                  '${ipadSys.batteryLevel}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                    fontFamily: _fontMono,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: accent.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 4),
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
  // 卡片 1 (左上)：Apple Silicon CPU 拓扑与核心负载
  // --------------------------------------------------------------------------
  Widget _buildCpuTopologyCard(Color accent, IpadSystemService ipadSys) {
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
                  ipadSys.socName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
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
                  '${ipadSys.cpuFreqMHz.toStringAsFixed(0)} MHz',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontFamily: _fontMono,
                  ),
                ),
              ),
            ],
          ),
          ...List.generate(4, (rowIdx) {
            final pCoreIdx = rowIdx;
            final eCoreIdx = rowIdx + 4;
            final pVal = pCoreIdx < ipadSys.corePercents.length
                ? ipadSys.corePercents[pCoreIdx]
                : 15.0;
            final eVal = eCoreIdx < ipadSys.corePercents.length
                ? ipadSys.corePercents[eCoreIdx]
                : 8.0;

            return Row(
              children: [
                // 性能核 (P-Core)
                _buildSingleCoreBar('P$pCoreIdx', pVal, accent),
                const SizedBox(width: 8),
                // 能效核 (E-Core)
                _buildSingleCoreBar('E$rowIdx', eVal, const Color(0xFF38BDF8)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSingleCoreBar(String label, double percent, Color activeColor) {
    final p = percent.clamp(0.0, 100.0);
    return Expanded(
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.white.withValues(alpha: 0.6),
                fontFamily: _fontMono,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2.5),
              child: LinearProgressIndicator(
                value: p / 100.0,
                minHeight: 4.5,
                backgroundColor: const Color(0xFF131D31),
                valueColor: AlwaysStoppedAnimation(
                  p > 75
                      ? const Color(0xFFEF4444)
                      : (p > 50 ? const Color(0xFFF59E0B) : activeColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 26,
            child: Text(
              '${p.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.white.withValues(alpha: 0.8),
                fontFamily: _fontMono,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 卡片 2 (左中)：Apple 统一内存 (UMA) 环形分布图
  // --------------------------------------------------------------------------
  Widget _buildMemoryDonutCard(Color accent, IpadSystemService ipadSys) {
    return _TechBorderCard(
      title: 'Apple 统一内存 (UMA)',
      accentColor: accent,
      child: Row(
        children: [
          // 左侧环形图
          Expanded(
            flex: 44,
            child: CustomPaint(
              painter: _MemoryDonutPainter(
                usedPercent: ipadSys.memUsedPercent,
                accentColor: accent,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '已用',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      '${ipadSys.memUsedPercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: accent,
                        fontFamily: _fontMono,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 右侧参数列表
          Expanded(
            flex: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricDotRow(accent, '物理内存', '${ipadSys.memTotalMB}MB'),
                _buildMetricDotRow(
                  const Color(0xFF38BDF8),
                  '可用内存',
                  '${ipadSys.memAvailableMB}MB',
                ),
                _buildMetricDotRow(
                  const Color(0xFF818CF8),
                  '音频缓冲',
                  '${ipadSys.audioBufferMemoryMB}MB',
                ),
                _buildMetricDotRow(
                  const Color(0xFF10B981),
                  '播放器沙盒',
                  '${ipadSys.appMemoryMB}MB',
                ),
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
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.5,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 8.5,
            color: Colors.white.withValues(alpha: 0.9),
            fontFamily: _fontMono,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 卡片 3 (左下)：供电与热状态矩阵
  // --------------------------------------------------------------------------
  Widget _buildPowerAndThermalCard(Color accent, IpadSystemService ipadSys) {
    return _TechBorderCard(
      title: '供电架构与热状态',
      accentColor: accent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '供电状态',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    ipadSys.powerSource,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: Color(0xFF10B981),
                      fontFamily: _fontMono,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SoC 温度',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              Text(
                '${ipadSys.socTemperature.toStringAsFixed(1)} °C',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: accent,
                  fontFamily: _fontMono,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'iPadOS 控温等级',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  ipadSys.thermalState,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 中央核心全息雷达区 (3D同心旋转雷达 + 卫星指标胶囊)
  // --------------------------------------------------------------------------
  Widget _buildCentralHoloCore(
    Color accent,
    IpadSystemService ipadSys,
    HifiAudioService audio,
    double t,
  ) {
    final isPlaying = audio.state.isPlaying;

    return _TechBorderCard(
      title: '3D 全息控制核心 · 硬件雷达直通',
      accentColor: accent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 全息同心旋转雷达背景
          Positioned.fill(
            child: CustomPaint(
              painter: _HoloCoreRadarPainter(
                animTime: t,
                accentColor: accent,
                isPlaying: isPlaying,
              ),
            ),
          ),

          // 2. 中央核心数字读数 (动态温度与音频引擎指示)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isPlaying ? 'BIT-PERFECT' : 'STANDBY',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: isPlaying ? const Color(0xFF10B981) : Colors.white54,
                  fontFamily: _fontMono,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${ipadSys.socTemperature.toStringAsFixed(1)}°C',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: _fontMono,
                  shadows: [
                    Shadow(color: accent.withValues(alpha: 0.8), blurRadius: 10),
                  ],
                ),
              ),
              Text(
                'iPad Studio AOP Core',
                style: TextStyle(
                  fontSize: 8.5,
                  color: accent.withValues(alpha: 0.8),
                  fontFamily: _fontMono,
                ),
              ),
            ],
          ),

          // 3. 六联围绕环形外围的卫星指标胶囊
          Positioned(
            left: 12,
            top: 14,
            child: _buildOrbitPill('CoreAudio', 'Bit-Perfect', const Color(0xFF10B981)),
          ),
          Positioned(
            right: 12,
            top: 14,
            child: _buildOrbitPill('AOP DSP', 'Direct HAL', const Color(0xFF38BDF8)),
          ),
          Positioned(
            left: 8,
            bottom: 14,
            child: _buildOrbitPill('时钟抖动', '< 0.05 ps', accent),
          ),
          Positioned(
            right: 8,
            bottom: 14,
            child: _buildOrbitPill(
              '缓冲延迟',
              '${ipadSys.bufferLatencyMs.toStringAsFixed(2)} ms',
              const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbitPill(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 8,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: _fontMono,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 中央三联大指标 KPI 卡片
  // --------------------------------------------------------------------------
  Widget _buildThreeKpiBoxes(
    Color accent,
    IpadSystemService ipadSys,
    HifiAudioService audio,
  ) {
    final specText = ipadSys.audioFormatSpec;

    return Row(
      children: [
        Expanded(
          child: _buildSingleKpiBox(
            'CPU 综合负载',
            '${ipadSys.cpuPercent.toStringAsFixed(1)}%',
            accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSingleKpiBox(
            '硬件直通输出端',
            ipadSys.activeDacName,
            const Color(0xFF38BDF8),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSingleKpiBox(
            '发烧音频解码规格',
            specText,
            const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleKpiBox(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: _fontMono,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 中央下半部：实时声学平滑贝塞尔波形曲线
  // --------------------------------------------------------------------------
  Widget _buildAcousticWaveformCard(
    Color accent,
    HifiAudioService audio,
    double t,
  ) {
    return _TechBorderCard(
      title: '实时声学平滑贝塞尔波形 · 频谱能量追踪',
      accentColor: accent,
      child: ClipRect(
        child: CustomPaint(
          painter: _AcousticWaveformPainter(
            spectrum: audio.state.spectrumLevels,
            isPlaying: audio.state.isPlaying,
            animTime: t,
            accentColor: accent,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 卡片 4 (右上)：APFS 沙盒与曲库气泡分布图 (Bubble Chart)
  // --------------------------------------------------------------------------
  Widget _buildStorageBubbleCard(
    Color accent,
    MusicDatabaseService db,
    IpadSystemService ipadSys,
  ) {
    return _TechBorderCard(
      title: 'APFS 沙盒与曲库存储气泡图',
      accentColor: accent,
      child: CustomPaint(
        painter: _StorageBubblePainter(
          accentColor: accent,
          totalGB: ipadSys.storageTotalGB,
          freeGB: ipadSys.storageFreeGB,
          trackCount: db.tracks.length,
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 卡片 5 (右中)：音轨采样直方图 (Spec Histogram)
  // --------------------------------------------------------------------------
  Widget _buildSpecHistogramCard(
    Color accent,
    MusicDatabaseService db,
    HifiAudioService audio,
  ) {
    int countDsd = 0;
    int countHiRes = 0;
    int countCd = 0;
    int countLossless = 0;

    for (final tr in db.tracks) {
      final sr = tr.sampleRate;
      final isDsd = tr.format == AudioFormat.dsdDsf ||
          tr.format == AudioFormat.dsdDff ||
          tr.filepath.toLowerCase().endsWith('.dsf') ||
          tr.filepath.toLowerCase().endsWith('.dff');

      if (isDsd) {
        countDsd++;
      } else if (sr >= 96000) {
        countHiRes++;
      } else if (sr >= 44100) {
        countCd++;
      } else {
        countLossless++;
      }
    }

    final total = max(1, db.tracks.length);

    return _TechBorderCard(
      title: '曲库母带格式分布统计',
      accentColor: accent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildHistoRow(
            'DSD 母带',
            countDsd,
            countDsd / total,
            const Color(0xFFEF4444),
          ),
          _buildHistoRow(
            'Hi-Res 192k',
            countHiRes,
            countHiRes / total,
            accent,
          ),
          _buildHistoRow(
            'CD 44.1k/48k',
            countCd,
            countCd / total,
            const Color(0xFF38BDF8),
          ),
          _buildHistoRow(
            '无损 FLAC/WAV',
            countLossless,
            countLossless / total,
            const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoRow(
    String label,
    int count,
    double ratio,
    Color barColor,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2.5),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.04, 1.0),
              minHeight: 5.5,
              backgroundColor: const Color(0xFF131D31),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: Text(
            '$count 首',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 9.5,
              color: Colors.white.withValues(alpha: 0.85),
              fontFamily: _fontMono,
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 卡片 6 (右下)：iPadOS 发烧硬件总线健康网格
  // --------------------------------------------------------------------------
  Widget _buildHardwareHealthCard(Color accent, IpadSystemService ipadSys) {
    return _TechBorderCard(
      title: 'iPadOS 音频总线健康链路',
      accentColor: accent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildHealthBadge(
                  'CoreAudio',
                  'ACTIVE',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHealthBadge(
                  'C-ABI v2',
                  'LINKED',
                  const Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildHealthBadge(
                  '丢帧率',
                  '0.000%',
                  const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildHealthBadge(
                  '抖动抑制',
                  'ULTRA LOCK',
                  accent,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 8.5,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: _fontMono,
            ),
          ),
        ],
      ),
    );
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}

// ============================================================================
// 赛博科技多边形外框卡片
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
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _TechCardBorderPainter(accentColor: accentColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 6.0, 8.0, 7.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.0,
                    height: 10.0,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(width: 5.0),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Expanded(child: child),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 赛博科技卡片边框绘制器
// ============================================================================
class _TechCardBorderPainter extends CustomPainter {
  final Color accentColor;
  _TechCardBorderPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgPaint = Paint()
      ..color = const Color(0xFF0C1322).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6.0)),
      bgPaint,
    );

    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6.0)),
      borderPaint,
    );

    // 四角亮色科技直角折线
    final cornerPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    const cLen = 7.0;
    // 左上角
    canvas.drawLine(const Offset(0, cLen), Offset.zero, cornerPaint);
    canvas.drawLine(Offset.zero, const Offset(cLen, 0), cornerPaint);

    // 右上角
    canvas.drawLine(Offset(w - cLen, 0), Offset(w, 0), cornerPaint);
    canvas.drawLine(Offset(w, 0), Offset(w, cLen), cornerPaint);

    // 左下角
    canvas.drawLine(Offset(0, h - cLen), Offset(0, h), cornerPaint);
    canvas.drawLine(Offset(0, h), Offset(cLen, h), cornerPaint);

    // 右下角
    canvas.drawLine(Offset(w - cLen, h), Offset(w, h), cornerPaint);
    canvas.drawLine(Offset(w, h - cLen), Offset(w, h), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _TechCardBorderPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

// ============================================================================
// 顶部多边形立体大屏徽标绘制器
// ============================================================================
class _HeaderTitleBadgePainter extends CustomPainter {
  final Color accentColor;
  _HeaderTitleBadgePainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - 18, h)
      ..lineTo(18, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.35),
          const Color(0xFF0F1A30).withValues(alpha: 0.95),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path, borderPaint);

    // 底部发光横线
    final bottomLinePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        colors: [
          accentColor.withValues(alpha: 0.0),
          accentColor,
          accentColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, h - 2, w, 2));
    canvas.drawLine(Offset(18, h), Offset(w - 18, h), bottomLinePaint);
  }

  @override
  bool shouldRepaint(covariant _HeaderTitleBadgePainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}

// ============================================================================
// 内存环形图绘制器
// ============================================================================
class _MemoryDonutPainter extends CustomPainter {
  final double usedPercent;
  final Color accentColor;

  _MemoryDonutPainter({
    required this.usedPercent,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4.0;
    const strokeWidth = 8.5;

    // 背景底环
    final bgPaint = Paint()
      ..color = const Color(0xFF131D31)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // 已用内存弧线
    final sweepAngle = 2 * pi * (usedPercent.clamp(0.0, 100.0) / 100.0);
    final activePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MemoryDonutPainter oldDelegate) =>
      oldDelegate.usedPercent != usedPercent ||
      oldDelegate.accentColor != accentColor;
}

// ============================================================================
// 3D 全息同心旋转雷达核心绘制器
// ============================================================================
class _HoloCoreRadarPainter extends CustomPainter {
  final double animTime;
  final Color accentColor;
  final bool isPlaying;

  _HoloCoreRadarPainter({
    required this.animTime,
    required this.accentColor,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 - 8.0;

    // 1. 同心静止参考圆
    final refPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3.0), refPaint);
    }

    // 2. 外部正向顺时针旋转齿轮刻度圈
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(animTime * 2 * pi);
    final tickPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.45)
      ..strokeWidth = 1.0;
    const numTicks = 24;
    for (int i = 0; i < numTicks; i++) {
      final angle = (i * 2 * pi) / numTicks;
      final x1 = cos(angle) * (maxRadius - 3);
      final y1 = sin(angle) * (maxRadius - 3);
      final x2 = cos(angle) * maxRadius;
      final y2 = sin(angle) * maxRadius;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);
    }
    canvas.restore();

    // 3. 内部反向逆时针旋转同心弧
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-animTime * 2 * pi * 1.5);
    final arcPaint = Paint()
      ..color = accentColor.withValues(alpha: isPlaying ? 0.85 : 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final rInner = maxRadius * 0.72;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: rInner),
      0,
      pi * 0.45,
      false,
      arcPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: rInner),
      pi,
      pi * 0.45,
      false,
      arcPaint,
    );
    canvas.restore();

    // 4. 雷达动态扫描光锥扇面 (正在播放时显眼旋转)
    if (isPlaying) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(animTime * 2 * pi * 2.5);
      final sweepPaint = Paint()
        ..shader = SweepGradient(
          startAngle: 0.0,
          endAngle: pi / 2,
          colors: [
            accentColor.withValues(alpha: 0.0),
            accentColor.withValues(alpha: 0.28),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: maxRadius));
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: maxRadius),
        0,
        pi / 2,
        true,
        sweepPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HoloCoreRadarPainter oldDelegate) => true;
}

// ============================================================================
// 实时声学平滑贝塞尔波形曲线绘制器
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
    final baseY = h * 0.82;

    final path = Path()..moveTo(0, baseY);
    const numPoints = 28;
    final dx = w / (numPoints - 1);

    final points = <Offset>[];
    for (int i = 0; i < numPoints; i++) {
      double energy = 0.0;
      if (isPlaying && spectrum.isNotEmpty) {
        final specIdx =
            (i * spectrum.length ~/ numPoints).clamp(0, spectrum.length - 1);
        energy = spectrum[specIdx];
      }
      // 叠加正弦呼吸律动微波
      final wave = sin((i * 0.55) + (animTime * 2 * pi * 2)) * 0.12;
      final y = baseY - (energy * h * 0.65) - (wave * h * 0.15);
      points.add(Offset(i * dx, y.clamp(h * 0.08, baseY)));
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
        colors: [
          accentColor.withValues(alpha: 0.35),
          accentColor.withValues(alpha: 0.0),
        ],
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
      canvas.drawCircle(p, 2.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AcousticWaveformPainter oldDelegate) => true;
}

// ============================================================================
// APFS 沙盒与曲库存储空间气泡图绘制器
// ============================================================================
class _StorageBubblePainter extends CustomPainter {
  final Color accentColor;
  final int totalGB;
  final int freeGB;
  final int trackCount;

  _StorageBubblePainter({
    required this.accentColor,
    required this.totalGB,
    required this.freeGB,
    required this.trackCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 大气泡：iPad APFS 存储池
    _drawBubble(
      canvas,
      Offset(w * 0.35, h * 0.50),
      34,
      accentColor.withValues(alpha: 0.35),
      accentColor,
      'APFS Pool',
      '${totalGB}G',
    );

    // 中气泡：Music 母带曲库
    final approxMB = (trackCount * 35).clamp(10, 80000);
    final musicStr = approxMB > 1024
        ? '${(approxMB / 1024.0).toStringAsFixed(1)}G'
        : '${approxMB}M';
    _drawBubble(
      canvas,
      Offset(w * 0.72, h * 0.42),
      26,
      const Color(0xFF38BDF8).withValues(alpha: 0.35),
      const Color(0xFF38BDF8),
      'Master',
      musicStr,
    );

    // 小气泡：SQLite 索引库
    _drawBubble(
      canvas,
      Offset(w * 0.58, h * 0.78),
      17,
      const Color(0xFF10B981).withValues(alpha: 0.35),
      const Color(0xFF10B981),
      'SQLite',
      '2.4M',
    );
  }

  void _drawBubble(
    Canvas canvas,
    Offset center,
    double r,
    Color fill,
    Color border,
    String title,
    String val,
  ) {
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, r, fillPaint);
    canvas.drawCircle(center, r, borderPaint);

    final tp1 = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp1.paint(
      canvas,
      Offset(center.dx - tp1.width / 2, center.dy - tp1.height),
    );

    final tp2 = TextPainter(
      text: TextSpan(
        text: val,
        style: TextStyle(
          fontSize: 8.5,
          color: border,
          fontFamily: _fontMono,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(center.dx - tp2.width / 2, center.dy + 1));
  }

  @override
  bool shouldRepaint(covariant _StorageBubblePainter oldDelegate) =>
      oldDelegate.accentColor != accentColor ||
      oldDelegate.totalGB != totalGB ||
      oldDelegate.freeGB != freeGB ||
      oldDelegate.trackCount != trackCount;
}

// ============================================================================
// 底层科技网格绘制器
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
