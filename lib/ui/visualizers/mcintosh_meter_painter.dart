import 'dart:math';
import 'package:flutter/material.dart';

/// 经典麦景图 (McIntosh) 湖蓝夜光双动圈表头
class McIntoshMeterPainter extends CustomPainter {
  final double leftAngle;   // 已经过物理阻尼滤波的弧度
  final double rightAngle;  // 已经过物理阻尼滤波的弧度
  final String title;

  static const double minAngle = -pi * 0.75;
  static const double sweepAngle = pi * 0.50;

  // 麦景图经典发烧配色
  static const Color chassisBg = Color(0xFF030712);        // 深空机架底板
  static const Color meterBgBase = Color(0xFF021026);      // 表盘深邃暗蓝底色
  static const Color glowCore = Color(0x8200B4FF);         // 轴心核心灯泡强光
  static const Color glowOuter = Color(0x550064B4);        // 弥散外层柔和湖蓝
  static const Color border = Color(0x9638BDF8);           // 荧光外框
  static const Color arcColor = Color(0xD7BAE6FD);         // 主刻度弧线
  static const Color tickSafe = Color(0xE6E0F2FE);         // 安全刻度线
  static const Color tickTextSafe = Color(0xD7BAE6FD);     // 安全刻度文字
  static const Color overloadRed = Color(0xFFFF3B30);      // 过载警示红 (>=0dB)
  static const Color needleColor = Color(0xFFFF3B30);      // 亮红动圈指针
  static const Color needleGlow = Color(0x40FF3B30);       // 指针背光阴影
  static const Color pivotBase = Color(0xFF1E293B);        // 轴心石墨底座
  static const Color pivotRing = Color(0xFF94A3B8);        // 轴心外圈金属圈
  static const Color footerBadge = Color(0xB438BDF8);      // 底部铭牌青

  McIntoshMeterPainter({
    required this.leftAngle,
    required this.rightAngle,
    this.title = 'McIntosh Precision Power Meter · Bit-Perfect 192kHz/24Bit ALSA',
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 底板
    final bgPaint = Paint()..color = chassisBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. 左右对称排版
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

    // 3. 底部发烧铭牌
    _drawFooter(canvas, size, paddingX);
  }

  void _drawSingleMeter(Canvas canvas, Rect rect, double angle, String channelLabel) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));

    // 1. 表盘基底暗色
    final basePaint = Paint()..color = meterBgBase;
    canvas.drawRect(rect, basePaint);

    final center = Offset(rect.center.dx, rect.bottom - 25.0);
    final radius = rect.width * 0.44;

    // 2. 硬件级双重径向通透漫射光晕
    // 外层弥散柔光
    final outerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [glowOuter, glowOuter.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(center.dx, center.dy - 15.0), radius: radius * 1.18));
    canvas.drawCircle(Offset(center.dx, center.dy - 15.0), radius * 1.18, outerGlowPaint);

    // 内层核心灯泡高光
    final coreGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [glowCore, glowCore.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(center.dx, center.dy - 10.0), radius: radius * 0.58));
    canvas.drawCircle(Offset(center.dx, center.dy - 10.0), radius * 0.58, coreGlowPaint);

    canvas.restore();

    // 3. 表盘发光外框
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)), borderPaint);

    // 4. 刻度弧线与标度
    _drawScaleAndTicks(canvas, center, radius);

    // 5. 动圈红针与金属机械轴盖
    _drawNeedle(canvas, center, radius, angle);

    // 6. 居中绘制声道标牌与单位
    _drawLabels(canvas, rect, center, channelLabel);
  }

  void _drawScaleAndTicks(Canvas canvas, Offset center, double radius) {
    // 主刻度弧线
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

    // 10 档经典对数 dB 分度
    const marks = [-20, -10, -7, -5, -3, -1, 0, 1, 2, 3];
    for (int i = 0; i < marks.length; i++) {
      final db = marks[i];
      final t = i / (marks.length - 1);
      final a = minAngle + sweepAngle * t;

      final isMajor = (i % 2 == 0);
      final tickLen = isMajor ? 16.0 : 9.0;
      final isRed = db >= 0;

      final pOuter = Offset(
        center.dx + cos(a) * (radius - 2.0),
        center.dy + sin(a) * (radius - 2.0),
      );
      final pInner = Offset(
        center.dx + cos(a) * (radius - tickLen),
        center.dy + sin(a) * (radius - tickLen),
      );

      final tickPaint = Paint()
        ..color = isRed ? overloadRed : tickSafe
        ..strokeWidth = isRed ? 2.5 : 1.8;
      canvas.drawLine(pInner, pOuter, tickPaint);

      // 标度文字
      if (isMajor) {
        final text = db > 0 ? '+$db' : '$db';
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: isRed ? overloadRed : tickTextSafe,
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

    // 指针柔和发光阴影层
    final glowPaint = Paint()
      ..color = needleGlow
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, glowPaint);

    // 指针实体红针
    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, needlePaint);

    // 双层机械金属轴盖
    final pivotBasePaint = Paint()..color = pivotBase;
    canvas.drawCircle(center, 12.0, pivotBasePaint);

    final pivotRingPaint = Paint()
      ..color = pivotRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 12.0, pivotRingPaint);

    final corePivotPaint = Paint()..color = Colors.black;
    canvas.drawCircle(center, 4.0, corePivotPaint);
  }

  void _drawLabels(Canvas canvas, Rect rect, Offset center, String channelLabel) {
    // 顶部声道标题
    final titleTp = TextPainter(
      text: TextSpan(
        text: channelLabel,
        style: const TextStyle(
          color: arcColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(canvas, Offset(rect.center.dx - titleTp.width * 0.5, rect.top + 28.0));

    // 中心单位标牌
    final subTp = TextPainter(
      text: const TextSpan(
        text: 'DECIBELS / WATTS',
        style: TextStyle(
          color: arcColor,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(canvas, Offset(rect.center.dx - subTp.width * 0.5, center.dy - 50.0));
  }

  void _drawFooter(Canvas canvas, Size size, double paddingX) {
    final leftTp = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(color: footerBadge, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    leftTp.paint(canvas, Offset(paddingX + 4.0, size.height - 22.0));

    final rightTp = TextPainter(
      text: const TextSpan(
        text: 'AK4191EQ + AK4499EX VELVET SOUND',
        style: TextStyle(color: footerBadge, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rightTp.paint(canvas, Offset(size.width - rightTp.width - paddingX - 4.0, size.height - 22.0));
  }

  @override
  bool shouldRepaint(covariant McIntoshMeterPainter oldDelegate) {
    return oldDelegate.leftAngle != leftAngle || oldDelegate.rightAngle != rightAngle;
  }
}
