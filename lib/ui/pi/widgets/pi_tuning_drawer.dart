import 'package:flutter/material.dart';
import '../../../theme/hifi_theme.dart';
import '../../common/glass_card.dart';

/// 树莓派 1024x600 专属 10 段发烧图形均衡器与音色调音抽屉
class PiTuningDrawer extends StatefulWidget {
  final VoidCallback onClose;

  const PiTuningDrawer({super.key, required this.onClose});

  @override
  State<PiTuningDrawer> createState() => _PiTuningDrawerState();
}

class _PiTuningDrawerState extends State<PiTuningDrawer> {
  bool _eqEnabled = true;

  final List<String> _freqLabels = [
    '31Hz', '62Hz', '125Hz', '250Hz', '500Hz',
    '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'
  ];

  List<double> _bandGains = [0.0, 1.5, 0.5, 0.0, 1.0, 2.0, 1.5, 0.5, 1.0, 0.5];

  void _applyPreset(String name) {
    setState(() {
      _eqEnabled = true;
      switch (name) {
        case 'FLAT':
          _bandGains = List.filled(10, 0.0);
          break;
        case 'VOCAL':
          _bandGains = [-1.0, 0.0, 0.5, 1.5, 2.5, 3.0, 2.0, 1.0, 0.5, 0.0];
          break;
        case 'SYMPHONY':
          _bandGains = [3.0, 2.5, 1.0, 0.0, -0.5, 0.0, 1.5, 2.5, 3.0, 3.5];
          break;
        case 'WARM_TAPE':
          _bandGains = [1.5, 2.0, 2.5, 1.5, 0.5, 0.0, -0.5, -1.0, -1.5, -2.5];
          break;
        case 'BASS_BOOST':
          _bandGains = [4.5, 4.0, 3.0, 1.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0];
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: GlassCard(
            borderRadius: 16.0,
            backgroundColor: HifiTheme.cardBackground.withValues(alpha: 0.94),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. 顶部标题栏、开关与预设
                Row(
                  children: [
                    // 关闭大热区按钮
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

                    const Text(
                      '10 段图形均衡器与调音',
                      style: TextStyle(
                        color: HifiTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // EQ 硬件滤波旁路/激活开关
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _eqEnabled = !_eqEnabled;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _eqEnabled
                              ? HifiTheme.neonCyan.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _eqEnabled ? HifiTheme.neonCyan : HifiTheme.cardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _eqEnabled ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: _eqEnabled ? HifiTheme.neonCyan : HifiTheme.textMuted,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _eqEnabled ? 'EQ 滤波已启用' : '直通旁路 (Bypass)',
                              style: TextStyle(
                                color: _eqEnabled ? HifiTheme.neonCyan : HifiTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // 发烧预设切换
                    _buildPresetButton('直通', 'FLAT'),
                    const SizedBox(width: 8),
                    _buildPresetButton('发烧人声', 'VOCAL'),
                    const SizedBox(width: 8),
                    _buildPresetButton('交响大动态', 'SYMPHONY'),
                    const SizedBox(width: 8),
                    _buildPresetButton('温暖开盘带', 'WARM_TAPE'),
                    const SizedBox(width: 8),
                    _buildPresetButton('澎湃重低音', 'BASS_BOOST'),
                  ],
                ),

                const Divider(color: HifiTheme.cardBorder, height: 20),

                // 2. 10 频段垂直滑块展示区 (针对 1024 宽屏排布)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(10, (index) {
                      final gain = _bandGains[index];
                      final freq = _freqLabels[index];

                      return Column(
                        children: [
                          // 增益数值指示 (+2.5dB)
                          Text(
                            gain > 0 ? '+${gain.toStringAsFixed(1)}' : gain.toStringAsFixed(1),
                            style: TextStyle(
                              color: gain.abs() > 0.1 ? HifiTheme.mcIntoshGlow : HifiTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // 垂直滑块本体
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4.0,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                                  activeTrackColor: _eqEnabled ? HifiTheme.mcIntoshGlow : HifiTheme.textMuted,
                                  inactiveTrackColor: HifiTheme.cardBorder,
                                  thumbColor: _eqEnabled ? Colors.white : HifiTheme.textMuted,
                                ),
                                child: Slider(
                                  min: -12.0,
                                  max: 12.0,
                                  value: gain.clamp(-12.0, 12.0),
                                  onChanged: _eqEnabled
                                      ? (val) {
                                          setState(() {
                                            _bandGains[index] = val;
                                          });
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // 频点标签 (31Hz, 1kHz 等)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              freq,
                              style: const TextStyle(
                                color: HifiTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, String presetKey) {
    return GestureDetector(
      onTap: () => _applyPreset(presetKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HifiTheme.cardBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: HifiTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
