import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/hifi_theme.dart';

/// 经典麦景图 (McIntosh) 湖蓝夜光动圈双表头
class VuMeterWidget extends StatelessWidget {
  final double leftLevel;  // 0.0 ~ 1.0
  final double rightLevel; // 0.0 ~ 1.0
  final double height;

  const VuMeterWidget({
    super.key,
    required this.leftLevel,
    required this.rightLevel,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: HifiTheme.mcIntoshMeterBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HifiTheme.mcIntoshBlue.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: HifiTheme.mcIntoshBlue.withOpacity(0.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _SingleMeterPainter(level: leftLevel, label: 'LEFT CHANNEL'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: CustomPaint(
              painter: _SingleMeterPainter(level: rightLevel, label: 'RIGHT CHANNEL'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleMeterPainter extends CustomPainter {
  final double level; // 0.0 ~ 1.0
  final String label;

  _SingleMeterPainter({required this.level, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 1.05);
    final radius = size.height * 0.95;

    // 1. 绘制弧形刻度背景
    final arcPaint = Paint()
      ..color = HifiTheme.mcIntoshGlow.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const startAngle = -pi * 0.75;
    const sweepAngle = pi * 0.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // 2. 刻度线
    final tickPaint = Paint()
      ..color = HifiTheme.mcIntoshGlow.withOpacity(0.7)
      ..strokeWidth = 1.5;

    final redTickPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.0;

    for (int i = 0; i <= 20; i++) {
      final t = i / 20.0;
      final angle = startAngle + sweepAngle * t;
      final isMajor = i % 5 == 0;
      final tickLen = isMajor ? 12.0 : 6.0;
      final isRed = t >= 0.85;

      final p1 = Offset(
        center.dx + (radius - tickLen) * cos(angle),
        center.dy + (radius - tickLen) * sin(angle),
      );
      final p2 = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      canvas.drawLine(p1, p2, isRed ? redTickPaint : tickPaint);
    }

    // 3. 动态指针 (带物理阻尼映射)
    final clampedLevel = level.clamp(0.0, 1.0);
    final needleAngle = startAngle + sweepAngle * clampedLevel;

    final needlePaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final needleTip = Offset(
      center.dx + (radius - 4) * cos(needleAngle),
      center.dy + (radius - 4) * sin(needleAngle),
    );

    // 指针微弱投影
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center + const Offset(1, 2), needleTip + const Offset(1, 2), shadowPaint);

    canvas.drawLine(center, needleTip, needlePaint);

    // 轴心圆盘
    final pivotPaint = Paint()..color = const Color(0xFFD4AF37);
    canvas.drawCircle(center, 5.0, pivotPaint);

    // 4. 文字标牌
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: HifiTheme.mcIntoshGlow.withOpacity(0.8),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height * 0.1),
    );
  }

  @override
  bool shouldRepaint(covariant _SingleMeterPainter oldDelegate) {
    return oldDelegate.level != level;
  }
}
