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

  static final List<TextPainter> _cachedFreqPainters = () {
    const freqs = ['31', '62', '125', '250', '500', '1k', '2k', '4k', '8k', '12k', '16k', '20k'];
    return freqs.map((f) {
      final tp = TextPainter(
        text: TextSpan(
          text: f,
          style: const TextStyle(color: HifiTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    }).toList();
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF080C14));

    final numBands = levels.isEmpty ? 12 : levels.length;
    const padding = 16.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    const numSegments = 24; // 垂直 24 级阶梯 LED
    final totalGapX = 8.0 * (numBands - 1);
    final barW = (w - totalGapX) / numBands;
    final segH = (h - (numSegments - 1) * 3.0) / numSegments;

    final unlitPath = Path();
    final greenPath = Path();
    final amberPath = Path();
    final redPath = Path();
    final peakPath = Path();

    final Color greenColor = accentColor ?? ledGreen;
    final Color amberColor = accentColor != null ? Color.lerp(accentColor!, Colors.white, 0.45)! : ledAmber;

    for (int b = 0; b < numBands; b++) {
      final bx = padding + b * (barW + 8.0);
      final lvl = (b < levels.length) ? levels[b].clamp(0.0, 1.0) : 0.0;
      final peak = (b < peakHold.length) ? peakHold[b].clamp(0.0, 1.0) : 0.0;

      final activeSegments = (lvl * numSegments).round();
      final peakSegment = (peak * numSegments).clamp(0, numSegments - 1).toInt();

      // 从下往上分层将 LED 块加入对应 Path
      for (int s = 0; s < numSegments; s++) {
        final by = padding + h - (s + 1) * (segH + 3.0);
        final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, barW, segH), const Radius.circular(2));

        final isActive = s < activeSegments;
        final isPeak = s == peakSegment;

        if (isActive) {
          if (s < numSegments * 0.65) {
            greenPath.addRRect(rrect);
          } else if (s < numSegments * 0.88) {
            amberPath.addRRect(rrect);
          } else {
            redPath.addRRect(rrect);
          }
        } else if (isPeak) {
          peakPath.addRRect(rrect);
        } else {
          unlitPath.addRRect(rrect);
        }
      }

      // 绘制预缓存的底部频率标牌 (零运行时 text layout 开销)
      if (b < _cachedFreqPainters.length) {
        final tp = _cachedFreqPainters[b];
        tp.paint(canvas, Offset(bx + (barW - tp.width) * 0.5, size.height - 14.0));
      }
    }

    // 批量提交 GPU 绘制
    canvas.drawPath(unlitPath, Paint()..color = ledOff);
    canvas.drawPath(greenPath, Paint()..color = greenColor);
    canvas.drawPath(amberPath, Paint()..color = amberColor);
    canvas.drawPath(redPath, Paint()..color = ledRed);
    canvas.drawPath(peakPath, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant LedSpectrumPainter oldDelegate) {
    return true; // 每一帧根据实时频谱更新
  }
}
