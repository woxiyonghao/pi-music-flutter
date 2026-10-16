import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../services/mseb_service.dart';
import '../../../theme/hifi_theme.dart';
import '../../common/glass_card.dart';

/// 树莓派 1024x600 专属双模发烧调音抽屉 (图形均衡器 EQ + 调音魔棒 MSEB)
/// 100% 针对 7寸触控屏优化：大按键热区、实时连通音频引擎与 SQLite 双向持久化
class PiTuningDrawer extends StatefulWidget {
  final VoidCallback onClose;

  const PiTuningDrawer({super.key, required this.onClose});

  @override
  State<PiTuningDrawer> createState() => _PiTuningDrawerState();
}

class _PiTuningDrawerState extends State<PiTuningDrawer> {
  int _activeTab = 0; // 0: 10段图形均衡器, 1: MSEB 调音魔棒

  final List<String> _freqLabels = [
    '31Hz', '62Hz', '125Hz', '250Hz', '500Hz',
    '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'
  ];

  static const List<Map<String, String>> _msebDefs = [
    {'title': '全局音温', 'desc': '冰爽清冽 ↔ 浓厚温暖'},
    {'title': '低频下潜', 'desc': '紧致收敛 ↔ 深沉弹性'},
    {'title': '低频质感', 'desc': '监听直白 ↔ 蓬松饱满'},
    {'title': '音场空间', 'desc': '凝聚贴耳 ↔ 宏大开阔'},
    {'title': '人声结像', 'desc': '靠后微润 ↔ 贴面凸显'},
    {'title': '高频延展', 'desc': '柔顺内敛 ↔ 华丽空气感'},
    {'title': '瞬态齿音', 'desc': '丝绒柔化 ↔ 原汁原味'},
    {'title': '空气残响', 'desc': '录音棚干声 ↔ 厅堂泛音'},
    {'title': '动态冲击力', 'desc': '细腻舒缓 ↔ 劲道爆发'},
    {'title': '背景黑度', 'desc': '模拟微暖 ↔ 漆黑深邃'},
  ];

  @override
  void initState() {
    super.initState();
    HifiAudioService.instance.addListener(_onAudioServiceChanged);
    MsebService.instance.addListener(_onMsebServiceChanged);
  }

  @override
  void dispose() {
    HifiAudioService.instance.removeListener(_onAudioServiceChanged);
    MsebService.instance.removeListener(_onMsebServiceChanged);
    super.dispose();
  }

  void _onAudioServiceChanged() {
    if (mounted) setState(() {});
  }

  void _onMsebServiceChanged() {
    if (mounted) setState(() {});
  }

  void _applyEqPreset(String name) {
    final audio = HifiAudioService.instance;
    List<double> bands;
    int presetIdx = 0;

    switch (name) {
      case 'FLAT':
        bands = List.filled(10, 0.0);
        presetIdx = 0;
        break;
      case 'VOCAL':
        bands = [-1.0, 0.0, 0.5, 1.5, 2.5, 3.0, 2.0, 1.0, 0.5, 0.0];
        presetIdx = 1;
        break;
      case 'SYMPHONY':
        bands = [3.0, 2.5, 1.0, 0.0, -0.5, 0.0, 1.5, 2.5, 3.0, 3.5];
        presetIdx = 2;
        break;
      case 'WARM_TAPE':
        bands = [1.5, 2.0, 2.5, 1.5, 0.5, 0.0, -0.5, -1.0, -1.5, -2.5];
        presetIdx = 3;
        break;
      case 'TREBLE_BOOST':
        bands = [0.0, 0.0, 0.5, 1.0, 2.0, 3.5, 5.0, 6.5, 7.5, 8.0];
        presetIdx = 4;
        break;
      case 'BASS_BOOST':
        bands = [4.5, 4.0, 3.0, 1.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0];
        presetIdx = 5;
        break;
      default:
        bands = List.filled(10, 0.0);
    }

    audio.setEqAndBands(true, bands, selectedPreset: presetIdx);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: GlassCard(
            borderRadius: 16.0,
            backgroundColor: HifiTheme.cardBackground.withValues(alpha: 0.94),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // 1. 顶部栏：关闭大按钮、分段选择 Tab、开关与归零
                Row(
                  children: [
                    // 关闭大热区按钮 (44x44dp)
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        onTap: widget.onClose,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                            border: Border.all(color: HifiTheme.cardBorder),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Tab 分段选择卡：EQ vs MSEB
                    Row(
                      children: [
                        _buildTabButton(0, '10 段图形均衡器与调音', Icons.equalizer_rounded),
                        const SizedBox(width: 8),
                        _buildTabButton(1, '调音魔棒 (MSEB)', Icons.auto_fix_high_rounded),
                      ],
                    ),

                    const Spacer(),

                    // 右侧状态与复位控制
                    if (_activeTab == 0) ...[
                      // EQ 全局使能开关
                      GestureDetector(
                        onTap: () {
                          final audio = HifiAudioService.instance;
                          audio.setEqEnabled(!audio.eqEnabled);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: HifiAudioService.instance.eqEnabled
                                ? HifiTheme.mcIntoshBlue.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: HifiAudioService.instance.eqEnabled
                                  ? HifiTheme.mcIntoshGlow
                                  : HifiTheme.cardBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                HifiAudioService.instance.eqEnabled
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: HifiAudioService.instance.eqEnabled
                                    ? HifiTheme.mcIntoshGlow
                                    : HifiTheme.textMuted,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                HifiAudioService.instance.eqEnabled ? 'EQ: 已生效' : 'EQ: 旁路直通',
                                style: TextStyle(
                                  color: HifiAudioService.instance.eqEnabled
                                      ? Colors.white
                                      : HifiTheme.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 归零复位
                      GestureDetector(
                        onTap: () {
                          HifiAudioService.instance.setEqAndBands(true, List.filled(10, 0.0), selectedPreset: 0);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: HifiTheme.cardBorder),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('归零', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // MSEB 全局使能开关
                      GestureDetector(
                        onTap: () {
                          final mseb = MsebService.instance;
                          mseb.setEnabled(!mseb.isEnabled);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: MsebService.instance.isEnabled
                                ? HifiTheme.accuphaseGold.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: MsebService.instance.isEnabled
                                  ? HifiTheme.accuphaseGold
                                  : HifiTheme.cardBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                MsebService.instance.isEnabled
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: MsebService.instance.isEnabled
                                    ? HifiTheme.accuphaseGold
                                    : HifiTheme.textMuted,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                MsebService.instance.isEnabled ? '魔棒: 已激活' : '魔棒: 已旁路',
                                style: TextStyle(
                                  color: MsebService.instance.isEnabled
                                      ? HifiTheme.accuphaseGold
                                      : HifiTheme.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // MSEB 复位
                      GestureDetector(
                        onTap: () {
                          MsebService.instance.resetAll();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: HifiTheme.cardBorder),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('重置', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const Divider(color: HifiTheme.cardBorder, height: 16),

                // 2. 主体内容区：EQ 面板或 MSEB 面板
                Expanded(
                  child: _activeTab == 0 ? _buildEqView() : _buildMsebView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (index == 0 ? HifiTheme.mcIntoshBlue : HifiTheme.accuphaseGold.withValues(alpha: 0.3))
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (index == 0 ? HifiTheme.mcIntoshGlow : HifiTheme.accuphaseGold)
                : HifiTheme.cardBorder,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : HifiTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : HifiTheme.textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. 图形均衡器 (EQ) 视图
  // ===========================================================================
  Widget _buildEqView() {
    final audio = HifiAudioService.instance;
    final bands = audio.eqBands;
    final isEnabled = audio.eqEnabled;

    return Column(
      children: [
        // 发烧预设按键区 (直通、人声、交响、黑胶、高音通透、低音)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPresetButton('直通 (Flat)', 'FLAT'),
              const SizedBox(width: 8),
              _buildPresetButton('人声温润 (Vocal)', 'VOCAL'),
              const SizedBox(width: 8),
              _buildPresetButton('交响大动态 (Symphony)', 'SYMPHONY'),
              const SizedBox(width: 8),
              _buildPresetButton('黑胶暖调 (Warm Tape)', 'WARM_TAPE'),
              const SizedBox(width: 8),
              _buildPresetButton('通透高音 (Treble Boost)', 'TREBLE_BOOST'),
              const SizedBox(width: 8),
              _buildPresetButton('低音震撼 (Bass Boost)', 'BASS_BOOST'),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 10 个频段垂直推子 (横向平铺，每列带大热区 touch target)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(10, (index) {
              final freq = _freqLabels[index];
              final gain = index < bands.length ? bands[index] : 0.0;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Column(
                    children: [
                      // 增益数值 (+3.5 dB)
                      Text(
                        gain > 0 ? '+${gain.toStringAsFixed(1)}' : gain.toStringAsFixed(1),
                        style: TextStyle(
                          color: gain.abs() > 0.05
                              ? HifiTheme.mcIntoshGlow
                              : HifiTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // 垂直推子本体
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9.0),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
                              activeTrackColor: isEnabled ? HifiTheme.mcIntoshGlow : HifiTheme.textMuted,
                              inactiveTrackColor: HifiTheme.cardBorder,
                              thumbColor: isEnabled ? Colors.white : HifiTheme.textMuted,
                            ),
                            child: Slider(
                              min: -12.0,
                              max: 12.0,
                              value: gain.clamp(-12.0, 12.0),
                              onChanged: (val) {
                                audio.setEqBand(index, val);
                              },
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // 频点标签 (31Hz, 1kHz 等)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: HifiTheme.cardBorder),
                        ),
                        child: Text(
                          freq,
                          style: const TextStyle(
                            color: HifiTheme.textPrimary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetButton(String label, String presetKey) {
    return GestureDetector(
      onTap: () => _applyEqPreset(presetKey),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HifiTheme.cardBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: HifiTheme.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. 调音魔棒 (MSEB) 视图 (2列 x 5项 宽屏布局，针对 1024x600 黄金分割)
  // ===========================================================================
  Widget _buildMsebView() {
    final mseb = MsebService.instance;
    final values = mseb.values;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 左列 5 项
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(right: 8),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              return _buildMsebRow(idx, values[idx]);
            },
          ),
        ),

        const VerticalDivider(color: HifiTheme.cardBorder, width: 16),

        // 右列 5 项
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(left: 8),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final realIdx = idx + 5;
              return _buildMsebRow(realIdx, values[realIdx]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMsebRow(int index, double value) {
    final def = _msebDefs[index];
    final isNonZero = value.abs() > 0.05;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNonZero
              ? HifiTheme.accuphaseGold.withValues(alpha: 0.4)
              : HifiTheme.cardBorder,
        ),
      ),
      child: Row(
        children: [
          // 标题与说明
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  def['title']!,
                  style: TextStyle(
                    color: isNonZero ? HifiTheme.accuphaseGold : HifiTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  def['desc']!,
                  style: const TextStyle(
                    color: HifiTheme.textMuted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),

          // 双极滑块 (-10.0 ~ +10.0)
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                activeTrackColor: HifiTheme.accuphaseGold,
                inactiveTrackColor: HifiTheme.cardBorder,
                thumbColor: Colors.white,
              ),
              child: Slider(
                min: -10.0,
                max: 10.0,
                value: value.clamp(-10.0, 10.0),
                onChanged: (val) {
                  MsebService.instance.setParam(index, val);
                },
              ),
            ),
          ),

          // 读数指示 (+3.5)
          SizedBox(
            width: 36,
            child: Text(
              value > 0 ? '+${value.toStringAsFixed(1)}' : value.toStringAsFixed(1),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isNonZero ? HifiTheme.accuphaseGold : HifiTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
