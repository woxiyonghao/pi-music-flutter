import 'package:flutter/material.dart';
import '../../theme/hifi_theme.dart';

/// 12 频段发烧级音频实时频谱分析仪
class SpectrumAnalyzerWidget extends StatelessWidget {
  final List<double> levels; // 12 频段数据
  final double height;

  const SpectrumAnalyzerWidget({
    super.key,
    required this.levels,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: HifiTheme.cardBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HifiTheme.cardBorder, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barCount = levels.isEmpty ? 12 : levels.length;
          final totalSpacing = 6.0 * (barCount - 1);
          final barWidth = (constraints.maxWidth - totalSpacing) / barCount;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(barCount, (i) {
              final level = (i < levels.length) ? levels[i].clamp(0.0, 1.0) : 0.0;
              final barHeight = (constraints.maxHeight * level).clamp(4.0, constraints.maxHeight);

              return Container(
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      HifiTheme.mcIntoshBlue,
                      HifiTheme.mcIntoshGlow,
                      if (level > 0.8) HifiTheme.accuphaseAmber,
                      if (level > 0.95) Colors.redAccent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HifiTheme.mcIntoshGlow.withOpacity(0.3 * level),
                      blurRadius: 6,
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
