import 'dart:math';
import 'package:flutter/material.dart';

/// 经典麦景图 (McIntosh) 湖蓝夜光双动圈大表头 - 高保真物理拟真版
/// 具备：双重对数刻度 (瓦数 + 分贝)、动圈红针动态视差投影、玻璃反光、角隅六角螺栓、双白炽灯漫射背光与透镜高光
class McIntoshMeterPainter extends CustomPainter {
  final double leftAngle;   // 已经过物理阻尼滤波的弧度
  final double rightAngle;  // 已经过物理阻尼滤波的弧度
  final String title;
  final Color? accentColor;

  static const double minAngle = -pi * 0.74;
  static const double sweepAngle = pi * 0.48;

  // 麦景图经典发烧配色规范
  static const Color chassisBg = Color(0xFF030509);        // 深邃黑曜石拉丝底板
  static const Color meterBgDark = Color(0xFF010E20);      // 表盘深邃暗蓝底色
  static const Color meterBgMid = Color(0xFF021B38);       // 弧面过渡海蓝
  static const Color glowCore = Color(0xB800C4EF);         // 灯泡核心强光
  static const Color glowOuter = Color(0x400077B6);        // 弥散外层柔和湖蓝
  static const Color bezelOuter = Color(0xFF253040);       // 压铸金属外框
  static const Color bezelInner = Color(0xFF0B121C);       // 框内倒角阴影
  static const Color arcWattsColor = Color(0xFFBAE6FD);    // 瓦数主刻度弧线
  static const Color arcDbColor = Color(0xCC7DD3FC);       // 分贝主刻度弧线
  static const Color tickSafe = Color(0xF0E0F2FE);         // 安全刻度线
  static const Color tickTextSafe = Color(0xEEBAE6FD);     // 安全刻度文字
  static const Color overloadRed = Color(0xFFFF2519);      // 过载警示红 (>=0dB / >100W)
  static const Color needleColor = Color(0xFFFF2B1D);      // 亮红动圈指针
  static const Color needleShadow = Color(0x80010E20);     // 指针投影在表盘的视差背影
  static const Color pivotBase = Color(0xFF161E28);        // 轴心石墨底座
  static const Color pivotRing = Color(0xFF94A3B8);        // 轴心外圈金属圈
  static const Color footerBadge = Color(0xB438BDF8);      // 底部铭牌青
  static const Color pgLedGreen = Color(0xFF00F5D4);       // POWER GUARD 祖母绿指示灯

  McIntoshMeterPainter({
    required this.leftAngle,
    required this.rightAngle,
    this.title = 'McIntosh Precision Power Output Meter · Bit-Perfect 192kHz/24Bit ALSA',
    this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 底板：微拉丝质感深空机架底色
    final bgPaint = Paint()..color = chassisBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 细致拉丝光栅横向微纹理
    final brushPaint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 1.0;
    for (double y = 4; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), brushPaint);
    }

    // 2. 发烧级横屏黄金比例排版 (左右双大表头)
    const paddingX = 16.0;
    const paddingY = 14.0;
    const footerH = 28.0;

    final availableW = size.width - paddingX * 3;
    final availableH = size.height - paddingY * 2 - footerH;
    if (availableW <= 100 || availableH <= 100) return;

    final rawMeterW = availableW * 0.5;
    final idealMeterH = rawMeterW * 0.76;
    final meterH = min(availableH, idealMeterH);
    final meterW = rawMeterW;

    final offsetY = paddingY + (availableH - meterH) * 0.5;

    final leftRect = Rect.fromLTWH(paddingX, offsetY, meterW, meterH);
    final rightRect = Rect.fromLTWH(paddingX * 2 + meterW, offsetY, meterW, meterH);

    _drawSingleMeter(canvas, leftRect, leftAngle, 'LEFT CHANNEL');
    _drawSingleMeter(canvas, rightRect, rightAngle, 'RIGHT CHANNEL');

    // 3. 底部发烧铭牌
    _drawFooter(canvas, size, paddingX);
  }

  void _drawSingleMeter(Canvas canvas, Rect rect, double angle, String channelLabel) {
    // 1. 外层金属机械压铸外框与内凹倒角阴影
    _drawMetalBezel(canvas, rect);

    // 2. 表盘内部区域 (开启圆角裁剪)
    final dialRect = rect.deflate(6.0);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(dialRect, const Radius.circular(10)));

    // 表盘透光导光底板 (双灯泡多重径向与线性混合光效)
    _drawDialLighting(canvas, dialRect);

    // 计算表头几何圆心与半径 (黄金比例定位，表针枢轴居中靠下)
    final radius = min(dialRect.width * 0.60, dialRect.height * 0.88);
    final center = Offset(dialRect.center.dx, dialRect.bottom - dialRect.height * 0.04);

    // 绘制双重对数分度刻度 (上方 WATTS 瓦数标度 + 下方 DECIBELS 分贝标度)
    _drawScales(canvas, center, radius);

    // 声道标牌与经典 POWER GUARD 绿色微光指示灯
    _drawLabelsAndLeds(canvas, dialRect, center, radius, channelLabel);

    // 绘制物理动圈红针 (包含真实 3D 投射阴影、背部黄铜平衡尾柄与机械枢轴)
    _drawRealisticNeedle(canvas, center, radius, angle);

    // 玻璃表镜弧形高光反射 (拟真光学镀膜反光)
    _drawGlassReflections(canvas, dialRect);

    canvas.restore();

    // 3. 四角防震精密六角螺丝 (Skeuomorphic Hex Screws)
    _drawCornerScrews(canvas, rect);
  }

  void _drawMetalBezel(Canvas canvas, Rect rect) {
    // 外层金属压铸框
    final outerBezelRRect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    final outerBezelPaint = Paint()
      ..color = bezelOuter
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawRRect(outerBezelRRect, outerBezelPaint);

    // 外框高光边缘
    final highlightBezel = Paint()
      ..color = const Color(0x30FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(outerBezelRRect, highlightBezel);

    // 内凹阴影线
    final innerShadowRect = rect.deflate(4.0);
    final innerShadowPaint = Paint()
      ..color = bezelInner
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(RRect.fromRectAndRadius(innerShadowRect, const Radius.circular(11)), innerShadowPaint);
  }

  void _drawDialLighting(Canvas canvas, Rect dialRect) {
    // 纯黑深邃背景
    canvas.drawRect(dialRect, Paint()..color = meterBgDark);

    // 底部弧面向上渐变
    final baseGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [meterBgDark, meterBgMid, Color(0xFF03264C)],
      stops: const [0.0, 0.65, 1.0],
    );
    canvas.drawRect(dialRect, Paint()..shader = baseGradient.createShader(dialRect));

    // 麦景图标志性底部双灯泡散射 (双白炽灯泡位于左右两侧底部)
    final lampY = dialRect.bottom - dialRect.height * 0.12;
    final leftLamp = Offset(dialRect.center.dx - dialRect.width * 0.26, lampY);
    final rightLamp = Offset(dialRect.center.dx + dialRect.width * 0.26, lampY);
    final lampRadius = dialRect.width * 0.65;

    final lampShaderL = RadialGradient(
      colors: const [glowCore, glowOuter, Colors.transparent],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: leftLamp, radius: lampRadius));

    final lampShaderR = RadialGradient(
      colors: const [glowCore, glowOuter, Colors.transparent],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: rightLamp, radius: lampRadius));

    final lampPaint = Paint()..blendMode = BlendMode.screen;
    canvas.drawCircle(leftLamp, lampRadius, lampPaint..shader = lampShaderL);
    canvas.drawCircle(rightLamp, lampRadius, lampPaint..shader = lampShaderR);

    // 顶部水平光晕漫射带 (透光扩散板顶部微亮)
    final topGlow = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0x3500B4D8), Colors.transparent],
    );
    canvas.drawRect(
      Rect.fromLTWH(dialRect.left, dialRect.top, dialRect.width, dialRect.height * 0.28),
      Paint()..shader = topGlow.createShader(dialRect),
    );
  }

  void _drawScales(Canvas canvas, Offset center, double radius) {
    final wattsRadius = radius;
    final dbRadius = radius - 16.0;

    // 1. 上层 WATTS 瓦数主弧线
    final arcWattsPaint = Paint()
      ..color = arcWattsColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: wattsRadius),
      minAngle,
      sweepAngle,
      false,
      arcWattsPaint,
    );

    // 2. 下层 DECIBELS 分贝主弧线
    final arcDbPaint = Paint()
      ..color = arcDbColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: dbRadius),
      minAngle,
      sweepAngle,
      false,
      arcDbPaint,
    );

    // 3. 经典麦景图 WATTS 标度 (8 档对数: .001, .01, .1, 1.0, 10, 100, 200, 400)
    final wattsMarks = [
      (0.00, '.001'),
      (0.14, '.01'),
      (0.28, '.1'),
      (0.42, '1.0'),
      (0.56, '10'),
      (0.72, '100'),
      (0.86, '200'),
      (1.00, '400'),
    ];

    for (final wm in wattsMarks) {
      final t = wm.$1;
      final label = wm.$2;
      final a = minAngle + sweepAngle * t;
      final isOverload = t >= 0.72; // >= 100W 过载警戒

      final pOuter = Offset(center.dx + cos(a) * (wattsRadius + 1.0), center.dy + sin(a) * (wattsRadius + 1.0));
      final pInner = Offset(center.dx + cos(a) * (wattsRadius - 10.0), center.dy + sin(a) * (wattsRadius - 10.0));

      final tickPaint = Paint()
        ..color = isOverload ? overloadRed : tickSafe
        ..strokeWidth = isOverload ? 2.4 : 1.8;
      canvas.drawLine(pInner, pOuter, tickPaint);

      // WATTS 数值文字
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isOverload ? overloadRed : tickTextSafe,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textPos = Offset(
        center.dx + cos(a) * (wattsRadius + 11.0) - tp.width * 0.5,
        center.dy + sin(a) * (wattsRadius + 11.0) - tp.height * 0.5,
      );
      tp.paint(canvas, textPos);
    }

    // 4. 经典麦景图 DECIBELS 标度 (-50 到 +3 dB)
    final dbMarks = [
      (0.00, '-50', false),
      (0.14, '-40', false),
      (0.28, '-30', false),
      (0.42, '-20', false),
      (0.56, '-10', true),
      (0.64, '-7', false),
      (0.72, '-4', true),
      (0.80, '-2', false),
      (0.86, '0', true),
      (0.93, '+1', false),
      (0.97, '+2', false),
      (1.00, '+3', true),
    ];

    for (final dm in dbMarks) {
      final t = dm.$1;
      final label = dm.$2;
      final isMajor = dm.$3;
      final a = minAngle + sweepAngle * t;
      final isRed = t >= 0.86; // >= 0dB 红色过载区

      final tickLen = isMajor ? 9.0 : 5.5;
      final pOuter = Offset(center.dx + cos(a) * dbRadius, center.dy + sin(a) * dbRadius);
      final pInner = Offset(center.dx + cos(a) * (dbRadius - tickLen), center.dy + sin(a) * (dbRadius - tickLen));

      final tickPaint = Paint()
        ..color = isRed ? overloadRed : tickSafe.withValues(alpha: 0.85)
        ..strokeWidth = isRed ? 2.0 : (isMajor ? 1.5 : 1.0);
      canvas.drawLine(pInner, pOuter, tickPaint);

      if (isMajor || t <= 0.42) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: isRed ? overloadRed : tickTextSafe.withValues(alpha: 0.90),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final textPos = Offset(
          center.dx + cos(a) * (dbRadius - 19.0) - tp.width * 0.5,
          center.dy + sin(a) * (dbRadius - 19.0) - tp.height * 0.5,
        );
        tp.paint(canvas, textPos);
      }
    }

    // 5. 0dB 到 +3dB 红色安全警示条带
    final redArcPaint = Paint()
      ..color = overloadRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    final redStartAngle = minAngle + sweepAngle * 0.86;
    final redSweep = sweepAngle * 0.14;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: wattsRadius),
      redStartAngle,
      redSweep,
      false,
      redArcPaint,
    );
  }

  void _drawLabelsAndLeds(Canvas canvas, Rect rect, Offset center, double radius, String channelLabel) {
    // 1. 声道标牌
    final titleTp = TextPainter(
      text: TextSpan(
        text: channelLabel,
        style: const TextStyle(
          color: arcWattsColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(canvas, Offset(rect.center.dx - titleTp.width * 0.5, rect.top + 16.0));

    // 2. POWER GUARD 祖母绿指示灯 (麦景图传奇标志，左右各一颗)
    final ledY = rect.top + 16.0 + titleTp.height * 0.5;
    final leftLedX = rect.center.dx - titleTp.width * 0.5 - 20.0;
    final rightLedX = rect.center.dx + titleTp.width * 0.5 + 20.0;

    _drawJewelLed(canvas, Offset(leftLedX, ledY), pgLedGreen);
    _drawJewelLed(canvas, Offset(rightLedX, ledY), pgLedGreen);

    // 3. 中心 UNITS 单位标示
    final wattsTp = TextPainter(
      text: const TextSpan(
        text: 'WATTS',
        style: TextStyle(
          color: arcWattsColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    wattsTp.paint(canvas, Offset(rect.center.dx - wattsTp.width * 0.5, center.dy - radius * 0.44));

    final decibelsTp = TextPainter(
      text: const TextSpan(
        text: 'DECIBELS',
        style: TextStyle(
          color: arcDbColor,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    decibelsTp.paint(canvas, Offset(rect.center.dx - decibelsTp.width * 0.5, center.dy - radius * 0.33));
  }

  void _drawJewelLed(Canvas canvas, Offset pos, Color color) {
    // 金属卡座圈
    canvas.drawCircle(pos, 5.0, Paint()..color = const Color(0xFF1E2836));
    canvas.drawCircle(pos, 5.0, Paint()..color = const Color(0xFF8FA3B8)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // 弥散辉光
    canvas.drawCircle(pos, 7.0, Paint()..color = color.withValues(alpha: 0.30));
    // 宝石本体
    canvas.drawCircle(pos, 3.2, Paint()..color = color);
    // 高光反光点
    canvas.drawCircle(pos + const Offset(-0.8, -0.8), 1.2, Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  void _drawRealisticNeedle(Canvas canvas, Offset center, double radius, double angle) {
    final needleLength = radius + 2.0;
    final needleTip = Offset(center.dx + cos(angle) * needleLength, center.dy + sin(angle) * needleLength);

    // 1. 动圈红针在底层表盘上的物理投射阴影 (立体视差神髓：阴影向右下偏移 4px，随角度动态变化)
    final shadowTip = Offset(
      center.dx + cos(angle - 0.035) * (needleLength - 2.0) + 3.5,
      center.dy + sin(angle - 0.035) * (needleLength - 2.0) + 5.0,
    );
    final shadowPaint = Paint()
      ..color = needleShadow
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawLine(center + const Offset(2.0, 3.0), shadowTip, shadowPaint);

    // 2. 指针后部黄铜平衡配重柄 (Counterweight spade, 延伸至轴心后方 16px)
    final tailAngle = angle + pi;
    final tailTip = Offset(center.dx + cos(tailAngle) * 16.0, center.dy + sin(tailAngle) * 16.0);
    final tailPaint = Paint()
      ..color = const Color(0xFFC5A059) // 机械黄铜
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tailTip, tailPaint);

    // 3. 亮红动圈实体指针本体 (微发光 + 纤细纯红钢针)
    final glowPaint = Paint()
      ..color = const Color(0x50FF3B30)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, glowPaint);

    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, needlePaint);

    // 指针中央金属高光刃线 (消除扁平感)
    final tipShinPaint = Paint()
      ..color = const Color(0x60FFFFFF)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, tipShinPaint);

    // 4. 三层同心机械轴盖 (Machined Hub with Chrome Bevel)
    // 底层石墨固定盘
    canvas.drawCircle(center, 13.0, Paint()..color = pivotBase);
    // 中层阳极氧化铝倒角外圈
    final ringPaint = Paint()
      ..color = pivotRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 13.0, ringPaint);

    // 顶层镀铬紧固轴心
    final chromeGrad = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: const [Color(0xFFE2E8F0), Color(0xFF64748B), Color(0xFF1E293B)],
      stops: const [0.0, 0.6, 1.0],
    );
    canvas.drawCircle(center, 7.5, Paint()..shader = chromeGrad.createShader(Rect.fromCircle(center: center, radius: 7.5)));

    // 轴心螺丝微十字槽
    final slotPaint = Paint()..color = const Color(0xFF0F172A)..strokeWidth = 1.0;
    canvas.drawLine(center - const Offset(3, 0), center + const Offset(3, 0), slotPaint);
  }

  void _drawGlassReflections(Canvas canvas, Rect rect) {
    // 拟真光学级镀膜弧面反射 (模拟斜向环境白光折射)
    final glassPath = Path();
    glassPath.moveTo(rect.left, rect.top);
    glassPath.lineTo(rect.right, rect.top);
    glassPath.lineTo(rect.right, rect.top + rect.height * 0.22);
    glassPath.quadraticBezierTo(
      rect.center.dx,
      rect.top + rect.height * 0.45,
      rect.left,
      rect.top + rect.height * 0.15,
    );
    glassPath.close();

    final glareShader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Colors.white.withValues(alpha: 0.10),
        Colors.white.withValues(alpha: 0.02),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(rect);

    canvas.drawPath(glassPath, Paint()..shader = glareShader);
  }

  void _drawCornerScrews(Canvas canvas, Rect rect) {
    // 四角镀铬六角螺丝
    const offset = 8.5;
    final corners = [
      rect.topLeft + const Offset(offset, offset),
      rect.topRight + const Offset(-offset, offset),
      rect.bottomLeft + const Offset(offset, -offset),
      rect.bottomRight + const Offset(-offset, -offset),
    ];

    for (final c in corners) {
      // 螺丝垫圈
      canvas.drawCircle(c, 3.8, Paint()..color = const Color(0xFF1E2836));
      canvas.drawCircle(c, 3.8, Paint()..color = const Color(0xFF64748B)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      // 螺丝头部高光
      canvas.drawCircle(c, 2.5, Paint()..color = const Color(0xFF94A3B8));
      // 六角孔内凹暗色
      canvas.drawCircle(c, 1.2, Paint()..color = const Color(0xFF0F172A));
    }
  }

  void _drawFooter(Canvas canvas, Size size, double paddingX) {
    final leftTp = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: footerBadge,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rightTp = TextPainter(
      text: const TextSpan(
        text: 'AK4191EQ + AK4499EX VELVET SOUND · FEMTOSECOND CLOCK',
        style: TextStyle(
          color: footerBadge,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final available = size.width - paddingX * 2;
    if (leftTp.width + rightTp.width + 24.0 <= available) {
      leftTp.paint(canvas, Offset(paddingX + 4.0, size.height - 20.0));
      rightTp.paint(canvas, Offset(size.width - rightTp.width - paddingX - 4.0, size.height - 20.0));
    } else {
      leftTp.paint(canvas, Offset(paddingX + 4.0, size.height - 20.0));
    }
  }

  @override
  bool shouldRepaint(covariant McIntoshMeterPainter oldDelegate) {
    return oldDelegate.leftAngle != leftAngle ||
        oldDelegate.rightAngle != rightAngle ||
        oldDelegate.title != title ||
        oldDelegate.accentColor != accentColor;
  }
}
