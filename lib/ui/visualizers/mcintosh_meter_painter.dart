import 'dart:math';
import 'package:flutter/material.dart';

/// 经典麦景图 (McIntosh) 湖蓝夜光双动圈大表头
class McIntoshMeterPainter extends CustomPainter {
  final double leftAngle;   // 已经过物理阻尼滤波的弧度
  final double rightAngle;  // 已经过物理阻尼滤波的弧度
  final String title;

  static const double minAngle = -pi * 0.74;
  static const double sweepAngle = pi * 0.48;

  // 麦景图经典发烧配色规范
  static const Color chassisBg = Color(0xFF03060E);        // 阳极氧化铝黑机架底板
  static const Color meterBgBase = Color(0xFF021026);      // 表盘深邃暗蓝底色
  static const Color glowCore = Color(0x9900B4D8);         // 轴心核心灯泡强光
  static const Color glowOuter = Color(0x350077B6);        // 弥散外层柔和湖蓝
  static const Color border = Color(0x9038BDF8);           // 荧光外框
  static const Color arcColor = Color(0xE0BAE6FD);         // 主刻度弧线
  static const Color tickSafe = Color(0xF0E0F2FE);         // 安全刻度线
  static const Color tickTextSafe = Color(0xE0BAE6FD);     // 安全刻度文字
  static const Color overloadRed = Color(0xFFFF2A20);      // 过载警示红 (>=0dB)
  static const Color needleColor = Color(0xFFFF2A20);      // 亮红动圈指针
  static const Color needleGlow = Color(0x40FF3B30);       // 指针背光阴影
  static const Color pivotBase = Color(0xFF1E293B);        // 轴心石墨底座
  static const Color pivotRing = Color(0xFF94A3B8);        // 轴心外圈金属圈
  static const Color footerBadge = Color(0xB438BDF8);      // 底部铭牌青

  McIntoshMeterPainter({
    required this.leftAngle,
    required this.rightAngle,
    this.title = 'McIntosh Precision Power Output Meter · Bit-Perfect 192kHz/24Bit ALSA',
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 底板
    final bgPaint = Paint()..color = chassisBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. 发烧级横屏黄金比例排版 (自适应居中，防止纵向无限拉伸导致表盘变瘦高)
    const paddingX = 14.0;
    const paddingY = 12.0;
    const footerH = 26.0;

    final availableW = size.width - paddingX * 3;
    final availableH = size.height - paddingY * 2 - footerH;
    if (availableW <= 100 || availableH <= 100) return;

    // 单个表头理想横向比例 (宽:高 约 1.25 : 1 ~ 1.4 : 1)
    final rawMeterW = availableW * 0.5;
    final idealMeterH = rawMeterW * 0.78;
    final meterH = min(availableH, idealMeterH);
    final meterW = rawMeterW;

    // 纵向居中定位
    final offsetY = paddingY + (availableH - meterH) * 0.5;

    final leftRect = Rect.fromLTWH(paddingX, offsetY, meterW, meterH);
    final rightRect = Rect.fromLTWH(paddingX * 2 + meterW, offsetY, meterW, meterH);

    _drawSingleMeter(canvas, leftRect, leftAngle, 'LEFT CHANNEL');
    _drawSingleMeter(canvas, rightRect, rightAngle, 'RIGHT CHANNEL');

    // 3. 底部发烧铭牌 (自适应防重叠)
    _drawFooter(canvas, size, paddingX);
  }

  void _drawSingleMeter(Canvas canvas, Rect rect, double angle, String channelLabel) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));

    // 1. 表盘基底暗夜发烧蓝渐变
    const baseGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF031633), Color(0xFF021026)],
    );
    canvas.drawRect(rect, Paint()..shader = baseGradient.createShader(rect));

    // 计算表盘黄金比例几何参数 (填满卡片 80% 以上)
    final radius = min(rect.width * 0.62, rect.height * 0.86);
    final center = Offset(rect.center.dx, rect.bottom - rect.height * 0.05);

    // 2. 经典湖蓝透光导光板弥散背光
    final glowCenter = Offset(center.dx, center.dy - radius * 0.50);
    final glowPaint = Paint()
      ..shader = const RadialGradient(
        colors: [glowCore, glowOuter, Colors.transparent],
        stops: [0.0, 0.60, 1.0],
      ).createShader(Rect.fromCircle(center: glowCenter, radius: radius * 0.95));
    canvas.drawCircle(glowCenter, radius * 0.95, glowPaint);

    canvas.restore();

    // 3. 表盘发光外框
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)), borderPaint);

    // 4. 刻度弧线与双重标度 (瓦数 + 分贝)
    _drawScaleAndTicks(canvas, center, radius);

    // 5. 居中绘制声道标牌与单位
    _drawLabels(canvas, rect, center, radius, channelLabel);

    // 6. 动圈红针与金属机械轴盖
    _drawNeedle(canvas, center, radius, angle);
  }

  void _drawScaleAndTicks(Canvas canvas, Offset center, double radius) {
    // 主刻度弧线
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

    // 经典麦景图 10 档对数分贝分度
    const marks = [-20, -10, -7, -5, -3, -1, 0, 1, 2, 3];
    for (int i = 0; i < marks.length; i++) {
      final db = marks[i];
      final t = i / (marks.length - 1);
      final a = minAngle + sweepAngle * t;

      final isMajor = (i % 2 == 0);
      final tickLen = isMajor ? 14.0 : 8.0;
      final isRed = db >= 0;

      final pOuter = Offset(
        center.dx + cos(a) * (radius - 1.0),
        center.dy + sin(a) * (radius - 1.0),
      );
      final pInner = Offset(
        center.dx + cos(a) * (radius - tickLen),
        center.dy + sin(a) * (radius - tickLen),
      );

      final tickPaint = Paint()
        ..color = isRed ? overloadRed : tickSafe
        ..strokeWidth = isRed ? 2.2 : 1.5;
      canvas.drawLine(pInner, pOuter, tickPaint);

      // 标度分贝文字
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

    // 指针柔和发光阴影层
    final glowPaint = Paint()
      ..color = needleGlow
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, glowPaint);

    // 指针实体红针
    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, needlePaint);

    // 双层机械金属轴盖
    final pivotBasePaint = Paint()..color = pivotBase;
    canvas.drawCircle(center, 11.0, pivotBasePaint);

    final pivotRingPaint = Paint()
      ..color = pivotRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, 11.0, pivotRingPaint);

    final corePivotPaint = Paint()..color = Colors.black;
    canvas.drawCircle(center, 4.0, corePivotPaint);
  }

  void _drawLabels(Canvas canvas, Rect rect, Offset center, double radius, String channelLabel) {
    // 顶部声道标题 (位于卡片上部)
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

    // POWER GUARD 经典绿色安全指示小灯
    const pgColor = Color(0xFF00F5D4);
    final pgPaint = Paint()..color = pgColor;
    canvas.drawCircle(Offset(rect.center.dx - 45, rect.top + 22.0), 2.5, pgPaint);
    canvas.drawCircle(Offset(rect.center.dx + 45, rect.top + 22.0), 2.5, pgPaint);

    // 中心单位标牌
    final subTp = TextPainter(
      text: const TextSpan(
        text: 'DECIBELS / WATTS',
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
        text: 'AK4191EQ + AK4499EX VELVET SOUND',
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
  bool shouldRepaint(covariant McIntoshMeterPainter oldDelegate) {
    return oldDelegate.leftAngle != leftAngle || oldDelegate.rightAngle != rightAngle;
  }
}
