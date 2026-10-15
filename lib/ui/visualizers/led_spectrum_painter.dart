import 'package:flutter/material.dart';
import '../../theme/hifi_theme.dart';

/// 发烧级阶梯式多通道 LED 频谱分析仪 (带峰值保持与重力衰减)
class LedSpectrumPainter extends CustomPainter {
  final List<double> levels;      // 实时 12 频段数据 (0.0 ~ 1.0)
  final List<double> peakHold;    // 峰值保持高度 (0.0 ~ 1.0)

  static const Color ledGreen = Color(0xFF10B981);
  static const Color ledAmber = Color(0xFFF59E0B);
  static const Color ledRed = Color(0xFFEF4444);
  static const Color ledOff = Color(0xFF18202C);

  final Color? accentColor;

  LedSpectrumPainter({
    required this.levels,
    required this.peakHold,
    this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF080C14));

    final numBands = levels.isEmpty ? 12 : levels.length;
    final padding = 16.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    const numSegments = 24; // 垂直 24 级阶梯 LED
    final totalGapX = 8.0 * (numBands - 1);
    final barW = (w - totalGapX) / numBands;
    final segH = (h - (numSegments - 1) * 3.0) / numSegments;

    // 频率标度标注文字
    const freqs = ['31', '62', '125', '250', '500', '1k', '2k', '4k', '8k', '12k', '16k', '20k'];

    for (int b = 0; b < numBands; b++) {
      final bx = padding + b * (barW + 8.0);
      final lvl = (b < levels.length) ? levels[b].clamp(0.0, 1.0) : 0.0;
      final peak = (b < peakHold.length) ? peakHold[b].clamp(0.0, 1.0) : 0.0;

      final activeSegments = (lvl * numSegments).round();
      final peakSegment = (peak * numSegments).clamp(0, numSegments - 1).toInt();

      // 从下往上绘制每一个 LED 块
      for (int s = 0; s < numSegments; s++) {
        final by = padding + h - (s + 1) * (segH + 3.0);
        final rect = Rect.fromLTWH(bx, by, barW, segH);

        final isActive = s < activeSegments;
        final isPeak = s == peakSegment;

        Color segColor;
        if (accentColor != null) {
          if (s < numSegments * 0.70) {
            segColor = accentColor!;
          } else if (s < numSegments * 0.88) {
            segColor = Color.lerp(accentColor!, Colors.white, 0.45)!;
          } else {
            segColor = ledRed;
          }
        } else {
          if (s < numSegments * 0.65) {
            segColor = ledGreen;
          } else if (s < numSegments * 0.88) {
            segColor = ledAmber;
          } else {
            segColor = ledRed;
          }
        }

        if (isActive) {
          // 点亮的 LED (带光晕)
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            Paint()..color = segColor,
          );
        } else if (isPeak) {
          // 峰值保持亮块
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            Paint()..color = (s >= numSegments * 0.88) ? Colors.white : segColor,
          );
        } else {
          // 未点亮的暗底 LED
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            Paint()..color = ledOff,
          );
        }
      }

      // 底部频率标牌
      if (b < freqs.length) {
        final tp = TextPainter(
          text: TextSpan(
            text: freqs[b],
            style: const TextStyle(color: HifiTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(bx + (barW - tp.width) * 0.5, size.height - 14.0));
      }
    }
  }

  @override
  bool shouldRepaint(covariant LedSpectrumPainter oldDelegate) {
    return true; // 每一帧根据实时频谱更新
  }
}
