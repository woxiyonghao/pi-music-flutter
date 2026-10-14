import 'dart:math';
import 'package:flutter/material.dart';

/// 经典金嗓子 (Accuphase) 40周年香槟金发烧动圈双表头
class AccuphaseMeterPainter extends CustomPainter {
  final double leftAngle;
  final double rightAngle;

  static const double minAngle = -pi * 0.75;
  static const double sweepAngle = pi * 0.50;

  // 金嗓子经典发烧配色
  static const Color chassisBg = Color(0xFF0E0B08);        // 深空古铜黑
  static const Color meterBgBase = Color(0xFF20190E);      // 香槟暗金底
  static const Color glowCore = Color(0x8CFFDC6E);         // 暖黄白炽灯芯强光
  static const Color glowOuter = Color(0x50D9A028);        // 外层柔和琥珀金
  static const Color border = Color(0xAAEAB308);           // 香槟金边框
  static const Color arcColor = Color(0xDCFEF3C7);         // 主刻度弧线
  static const Color tickSafe = Color(0xE6FDE68A);         // 安全刻度线
  static const Color tickTextSafe = Color(0xDCFEF0B4);     // 安全刻度文字
  static const Color overloadOrange = Color(0xFFF97316);   // 警示橙红 (>=0dB)
  static const Color needleColor = Color(0xFFF53C23);      // 金嗓子朱红动圈指针
  static const Color needleGlow = Color(0x40EAB308);       // 指针金色背光
  static const Color pivotBase = Color(0xFF282014);        // 铸铜轴心底座
  static const Color pivotRing = Color(0xFFD2B478);        // 镀金高光外圈
  static const Color footerBadge = Color(0xC8EAB308);      // 底部铭牌金

  AccuphaseMeterPainter({
    required this.leftAngle,
    required this.rightAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 底板
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = chassisBg);

    final paddingX = 16.0;
    final paddingY = 16.0;
    final footerH = 28.0;
    final meterW = (size.width - paddingX * 3) * 0.5;
    final meterH = size.height - paddingY * 2 - footerH;

    if (meterW <= 50 || meterH <= 50) return;

    final leftRect = Rect.fromLTWH(paddingX, paddingY, meterW, meterH);
    final rightRect = Rect.fromLTWH(paddingX * 2 + meterW, paddingY, meterW, meterH);

    _drawSingleMeter(canvas, leftRect, leftAngle, 'LEFT CHANNEL');
    _drawSingleMeter(canvas, rightRect, rightAngle, 'RIGHT CHANNEL');

    _drawFooter(canvas, size, paddingX);
  }

  void _drawSingleMeter(Canvas canvas, Rect rect, double angle, String channelLabel) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));

    // 1. 底色
    canvas.drawRect(rect, Paint()..color = meterBgBase);

    final center = Offset(rect.center.dx, rect.bottom - 25.0);
    final radius = rect.width * 0.44;

    // 2. 暖色白炽灯漫射光晕
    final outerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [glowOuter, glowOuter.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(center.dx, center.dy - 15.0), radius: radius * 1.18));
    canvas.drawCircle(Offset(center.dx, center.dy - 15.0), radius * 1.18, outerGlowPaint);

    final coreGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [glowCore, glowCore.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(center.dx, center.dy - 10.0), radius: radius * 0.58));
    canvas.drawCircle(Offset(center.dx, center.dy - 10.0), radius * 0.58, coreGlowPaint);

    canvas.restore();

    // 3. 边框
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)), borderPaint);

    // 4. 刻度与弧线
    _drawScaleAndTicks(canvas, center, radius);

    // 5. 朱红动圈指针
    _drawNeedle(canvas, center, radius, angle);

    // 6. 声道标题与铭牌
    _drawLabels(canvas, rect, center, channelLabel);
  }

  void _drawScaleAndTicks(Canvas canvas, Offset center, double radius) {
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      minAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    const marks = [-20, -10, -7, -5, -3, -1, 0, 1, 2, 3];
    for (int i = 0; i < marks.length; i++) {
      final db = marks[i];
      final t = i / (marks.length - 1);
      final a = minAngle + sweepAngle * t;

      final isMajor = (i % 2 == 0);
      final tickLen = isMajor ? 16.0 : 9.0;
      final isRed = db >= 0;

      final pOuter = Offset(center.dx + cos(a) * (radius - 2.0), center.dy + sin(a) * (radius - 2.0));
      final pInner = Offset(center.dx + cos(a) * (radius - tickLen), center.dy + sin(a) * (radius - tickLen));

      final tickPaint = Paint()
        ..color = isRed ? overloadOrange : tickSafe
        ..strokeWidth = isRed ? 2.5 : 1.8;
      canvas.drawLine(pInner, pOuter, tickPaint);

      if (isMajor) {
        final text = db > 0 ? '+$db' : '$db';
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: isRed ? overloadOrange : tickTextSafe,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final textPos = Offset(
          center.dx + cos(a) * (radius - 26.0) - tp.width * 0.5,
          center.dy + sin(a) * (radius - 26.0) - tp.height * 0.5,
        );
        tp.paint(canvas, textPos);
      }
    }
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius, double angle) {
    final needleTip = Offset(
      center.dx + cos(angle) * (radius - 6.0),
      center.dy + sin(angle) * (radius - 6.0),
    );

    final glowPaint = Paint()
      ..color = needleGlow
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, glowPaint);

    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, needlePaint);

    canvas.drawCircle(center, 12.0, Paint()..color = pivotBase);
    canvas.drawCircle(center, 12.0, Paint()..color = pivotRing..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawCircle(center, 4.0, Paint()..color = Colors.black);
  }

  void _drawLabels(Canvas canvas, Rect rect, Offset center, String channelLabel) {
    final titleTp = TextPainter(
      text: TextSpan(
        text: channelLabel,
        style: const TextStyle(color: arcColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(canvas, Offset(rect.center.dx - titleTp.width * 0.5, rect.top + 28.0));

    final subTp = TextPainter(
      text: const TextSpan(
        text: 'DECIBELS / PEAK WATTS',
        style: TextStyle(color: arcColor, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(canvas, Offset(rect.center.dx - subTp.width * 0.5, center.dy - 50.0));
  }

  void _drawFooter(Canvas canvas, Size size, double paddingX) {
    final leftTp = TextPainter(
      text: const TextSpan(
        text: 'Accuphase Laboratory, Inc. · 40th Anniversary Dual Balanced',
        style: TextStyle(color: footerBadge, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    leftTp.paint(canvas, Offset(paddingX + 4.0, size.height - 22.0));

    final rightTp = TextPainter(
      text: const TextSpan(
        text: 'VELVET SOUND ULTRA · FEMTOSECOND CLOCK',
        style: TextStyle(color: footerBadge, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rightTp.paint(canvas, Offset(size.width - rightTp.width - paddingX - 4.0, size.height - 22.0));
  }

  @override
  bool shouldRepaint(covariant AccuphaseMeterPainter oldDelegate) {
    return oldDelegate.leftAngle != leftAngle || oldDelegate.rightAngle != rightAngle;
  }
}
