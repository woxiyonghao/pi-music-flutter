import 'dart:math';
import 'package:flutter/material.dart';

/// 经典金嗓子 (Accuphase) 香槟暖金双动圈表头
class AccuphaseMeterPainter extends CustomPainter {
  final double leftAngle;
  final double rightAngle;
  final String title;

  static const double minAngle = -pi * 0.74;
  static const double sweepAngle = pi * 0.48;

  // 金嗓子经典发烧配色
  static const Color chassisBg = Color(0xFF0C0A08);        // 铸铝深黑底板
  static const Color meterBgBase = Color(0xFF221A10);      // 香槟暗金底
  static const Color glowCore = Color(0x99FFDC6E);         // 暖黄白炽灯芯强光
  static const Color glowOuter = Color(0x40D9A028);        // 外层柔和琥珀金
  static const Color border = Color(0xBBEAB308);           // 香槟金边框
  static const Color arcColor = Color(0xEEFEF3C7);         // 主刻度弧线
  static const Color tickSafe = Color(0xFFFDE68A);         // 安全刻度线
  static const Color tickTextSafe = Color(0xEEFEF0B4);     // 安全刻度文字
  static const Color overloadOrange = Color(0xFFF97316);   // 警示橙红 (>=0dB)
  static const Color needleColor = Color(0xFFF53C23);      // 金嗓子朱红动圈指针
  static const Color needleGlow = Color(0x40EAB308);       // 指针金色背光
  static const Color pivotBase = Color(0xFF282014);        // 铸铜轴心底座
  static const Color pivotRing = Color(0xFFD2B478);        // 镀金高光外圈
  static const Color footerBadge = Color(0xC8EAB308);      // 底部铭牌金

  AccuphaseMeterPainter({
    required this.leftAngle,
    required this.rightAngle,
    this.title = 'Accuphase Precision Power Meter · Pure Class-A Instrumentation',
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 底板
    final bgPaint = Paint()..color = chassisBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. 左右排版 (自适应黄金比例)
    const paddingX = 14.0;
    const paddingY = 12.0;
    const footerH = 26.0;

    final availableW = size.width - paddingX * 3;
    final availableH = size.height - paddingY * 2 - footerH;
    if (availableW <= 100 || availableH <= 100) return;

    final rawMeterW = availableW * 0.5;
    final idealMeterH = rawMeterW * 0.78;
    final meterH = min(availableH, idealMeterH);
    final meterW = rawMeterW;

    final offsetY = paddingY + (availableH - meterH) * 0.5;

    final leftRect = Rect.fromLTWH(paddingX, offsetY, meterW, meterH);
    final rightRect = Rect.fromLTWH(paddingX * 2 + meterW, offsetY, meterW, meterH);

    _drawSingleMeter(canvas, leftRect, leftAngle, 'LEFT CHANNEL');
    _drawSingleMeter(canvas, rightRect, rightAngle, 'RIGHT CHANNEL');

    // 3. 底部金嗓子发烧铭牌 (自适应防重叠)
    _drawFooter(canvas, size, paddingX);
  }

  void _drawSingleMeter(Canvas canvas, Rect rect, double angle, String channelLabel) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));

    // 1. 香槟金拉丝背光渐变底
    const baseGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2C2214), Color(0xFF1E170E)],
    );
    canvas.drawRect(rect, Paint()..shader = baseGradient.createShader(rect));

    final radius = min(rect.width * 0.62, rect.height * 0.86);
    final center = Offset(rect.center.dx, rect.bottom - rect.height * 0.05);

    // 2. 暖色白炽灯漫射光晕
    final glowCenter = Offset(center.dx, center.dy - radius * 0.50);
    final glowPaint = Paint()
      ..shader = const RadialGradient(
        colors: [glowCore, glowOuter, Colors.transparent],
        stops: [0.0, 0.60, 1.0],
      ).createShader(Rect.fromCircle(center: glowCenter, radius: radius * 0.95));
    canvas.drawCircle(glowCenter, radius * 0.95, glowPaint);

    canvas.restore();

    // 3. 边框
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)), borderPaint);

    // 4. 刻度与弧线
    _drawScaleAndTicks(canvas, center, radius);

    // 5. 声道标题与铭牌
    _drawLabels(canvas, rect, center, radius, channelLabel);

    // 6. 朱红动圈指针
    _drawNeedle(canvas, center, radius, angle);
  }

  void _drawScaleAndTicks(Canvas canvas, Offset center, double radius) {
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      minAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    const marks = [-30, -20, -10, -5, -3, -1, 0, 1, 2, 3];
    for (int i = 0; i < marks.length; i++) {
      final db = marks[i];
      final t = i / (marks.length - 1);
      final a = minAngle + sweepAngle * t;

      final isMajor = (i % 2 == 0);
      final tickLen = isMajor ? 14.0 : 8.0;
      final isOverload = db >= 0;

      final pOuter = Offset(
        center.dx + cos(a) * (radius - 1.0),
        center.dy + sin(a) * (radius - 1.0),
      );
      final pInner = Offset(
        center.dx + cos(a) * (radius - tickLen),
        center.dy + sin(a) * (radius - tickLen),
      );

      final tickPaint = Paint()
        ..color = isOverload ? overloadOrange : tickSafe
        ..strokeWidth = isOverload ? 2.2 : 1.5;
      canvas.drawLine(pInner, pOuter, tickPaint);

      if (isMajor) {
        final text = db > 0 ? '+$db' : '$db';
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: isOverload ? overloadOrange : tickTextSafe,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final textPos = Offset(
          center.dx + cos(a) * (radius - 23.0) - tp.width * 0.5,
          center.dy + sin(a) * (radius - 23.0) - tp.height * 0.5,
        );
        tp.paint(canvas, textPos);
      }
    }
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius, double angle) {
    final needleLength = radius - 4.0;
    final needleTip = Offset(
      center.dx + cos(angle) * needleLength,
      center.dy + sin(angle) * needleLength,
    );

    // 指针暖金背光阴影
    final glowPaint = Paint()
      ..color = needleGlow
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, glowPaint);

    // 朱红实体指针
    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, needlePaint);

    // 铸铜双层机械轴座
    final pivotBasePaint = Paint()..color = pivotBase;
    canvas.drawCircle(center, 11.0, pivotBasePaint);

    final pivotRingPaint = Paint()
      ..color = pivotRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, 11.0, pivotRingPaint);

    final corePivotPaint = Paint()..color = const Color(0xFF15100A);
    canvas.drawCircle(center, 4.0, corePivotPaint);
  }

  void _drawLabels(Canvas canvas, Rect rect, Offset center, double radius, String channelLabel) {
    final titleTp = TextPainter(
      text: TextSpan(
        text: channelLabel,
        style: const TextStyle(
          color: arcColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(canvas, Offset(rect.center.dx - titleTp.width * 0.5, rect.top + 16.0));

    final subTp = TextPainter(
      text: const TextSpan(
        text: 'DECIBELS / PEAK LEVEL',
        style: TextStyle(
          color: arcColor,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(canvas, Offset(rect.center.dx - subTp.width * 0.5, center.dy - radius * 0.40));
  }

  void _drawFooter(Canvas canvas, Size size, double paddingX) {
    final leftTp = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(color: footerBadge, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rightTp = TextPainter(
      text: const TextSpan(
        text: 'MDS+ D/A CONVERTER · ACCUPHASE LAB',
        style: TextStyle(color: footerBadge, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final available = size.width - paddingX * 2;
    if (leftTp.width + rightTp.width + 24.0 <= available) {
      leftTp.paint(canvas, Offset(paddingX + 4.0, size.height - 18.0));
      rightTp.paint(canvas, Offset(size.width - rightTp.width - paddingX - 4.0, size.height - 18.0));
    } else {
      leftTp.paint(canvas, Offset(paddingX + 4.0, size.height - 18.0));
    }
  }

  @override
  bool shouldRepaint(covariant AccuphaseMeterPainter oldDelegate) {
    return oldDelegate.leftAngle != leftAngle || oldDelegate.rightAngle != rightAngle;
  }
}
