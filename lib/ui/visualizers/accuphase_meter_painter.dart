import 'dart:math';
import 'package:flutter/material.dart';

/// 经典金嗓子 (Accuphase) 香槟金旗舰双动圈大表头 - 高保真物理拟真版
/// 1:1 严格对齐 C++ 原版 AccuphaseMeterRenderer.cpp：
/// 梯形双色带分度、0dB~+5dB 标志性 3 根倾斜红色梳齿、纯白高精动圈指针、中央祖母绿 Accuphase 徽标呼吸微光、7段数码管音量读数与半球金属旋转轴盖
class AccuphaseMeterPainter extends CustomPainter {
  final double leftAngle;
  final double rightAngle;
  final double? leftValue;      // 归一化电平 0.0 ~ 1.0
  final double? rightValue;     // 归一化电平 0.0 ~ 1.0
  final double animTime;        // 呼吸微光演进时间
  final int volumePercent;      // 当前音量百分比 (0 ~ 100)
  final int themeId;            // 主题 ID (2: Accuphase 原机香槟金)
  final Color? accentColor;     // 自由调色强调色
  final String title;

  static const double minAngle = -pi * 0.74;
  static const double sweepAngle = pi * 0.48;

  // 金嗓子发烧调色板规范
  static const Color chassisBg = Color(0xFF0E0B08);        // 香槟黑曜石底板
  static const Color meterBg = Color(0xFF07080A);          // 表盘深邃黑晶底面
  static const Color bezelOuter = Color(0xFF483A28);       // 金属压铸外框
  static const Color bezelInner = Color(0xFF181511);       // 倒角暗影
  static const Color ribbonIceBlue = Color(0xFFD4E8FC);    // 原机标志性冰青暖玉色带
  static const Color overloadRed = Color(0xFFEB2618);      // 过载警示纯红
  static const Color tickSafe = Color(0xFFE4F0FC);         // 安全刻度文字与刻度线
  static const Color needleColor = Color(0xFFFFFFFF);      // 纯白高精纤细指针
  static const Color needleGlow = Color(0x50D4E8FC);       // 指针透光辉光
  static const Color needleShadow = Color(0x90000000);     // 指针在底板上的视差背影
  static const Color emblemGreen = Color(0xFF00EB96);      // 标志性 Accuphase 祖母绿徽标
  static const Color champagneGold = Color(0xFFD2B478);    // 香槟金铭牌字

  AccuphaseMeterPainter({
    this.leftAngle = minAngle,
    this.rightAngle = minAngle,
    this.leftValue,
    this.rightValue,
    this.animTime = 0.0,
    this.volumePercent = 80,
    this.themeId = 2,
    this.accentColor,
    this.title = 'Accuphase Precision Power Meter · Dual Balanced Class-A Instrumentation',
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 底板：香槟黑曜石微拉丝底板
    final bgPaint = Paint()..color = chassisBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final brushPaint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 1.0;
    for (double y = 4; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), brushPaint);
    }

    // 2. 左右排版与中央徽标区域
    const padX = 20.0;
    const gapX = 36.0;
    const footerH = 30.0;

    final availableW = size.width - padX * 2 - gapX;
    final availableH = size.height - padX - footerH;
    if (availableW <= 100 || availableH <= 100) return;

    final rawMeterW = availableW * 0.5;
    final idealMeterH = rawMeterW * 0.74;
    final meterH = min(availableH - 24.0, idealMeterH);
    final meterW = rawMeterW;

    final padY = 46.0 + (availableH - 24.0 - meterH) * 0.45;

    final leftRect = Rect.fromLTWH(padX, padY, meterW, meterH);
    final rightRect = Rect.fromLTWH(padX + meterW + gapX, padY, meterW, meterH);

    // 计算归一化指针值 (0.0 ~ 1.0)
    final valL = (leftValue ?? ((leftAngle - minAngle) / sweepAngle)).clamp(0.0, 1.0);
    final valR = (rightValue ?? ((rightAngle - minAngle) / sweepAngle)).clamp(0.0, 1.0);

    // 3. 渲染左右两只金嗓子原机梯形大表头
    _drawSingleMeter(canvas, leftRect, valL, 'LEFT CHANNEL');
    _drawSingleMeter(canvas, rightRect, valR, 'RIGHT CHANNEL');

    // 4. 中央标志性 Accuphase 徽标呼吸微光与数码管音量读数
    _drawCenterDisplay(canvas, size.width * 0.5, padY, meterH);

    // 5. 底部金嗓子发烧铭牌
    _drawFooter(canvas, size, padX);
  }

  void _drawCenterDisplay(Canvas canvas, double centerX, double topY, double meterH) {
    // 1. Accuphase 徽标呼吸微光
    final logoPulse = (sin(animTime * 1.5) + 1.0) * 0.5;
    final glowAlpha = 0.12 + 0.18 * logoPulse;

    final emblemColor = (themeId == 2)
        ? emblemGreen
        : (accentColor ?? emblemGreen);

    final glowRect = Rect.fromCenter(
      center: Offset(centerX, topY - 22.0),
      width: 140.0,
      height: 36.0,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glowRect, const Radius.circular(8)),
      Paint()..color = emblemColor.withValues(alpha: glowAlpha),
    );

    // 2. Accuphase 经典手写英文字体
    final logoTp = TextPainter(
      text: TextSpan(
        text: 'Accuphase',
        style: TextStyle(
          color: emblemColor,
          fontSize: 19,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          letterSpacing: 2.0,
          shadows: [
            Shadow(
              color: emblemColor.withValues(alpha: 0.8),
              blurRadius: 10.0,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    logoTp.paint(canvas, Offset(centerX - logoTp.width * 0.5, topY - 32.0));

    // 3. 经典红光 7 段数码管音量读数 (-24 dB / -- dB)
    final vol = volumePercent / 100.0;
    final dbAtten = (vol > 0.01) ? ((1.0 - vol) * -50.0).round() : -99;
    final dbText = (dbAtten <= -99) ? '-- dB' : '${dbAtten.abs() == 0 ? "0" : "-${dbAtten.abs()}"} dB';

    final dispRect = Rect.fromCenter(
      center: Offset(centerX, topY + meterH * 0.52),
      width: 72.0,
      height: 28.0,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(dispRect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF140707),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(dispRect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF4A1818)..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );

    final volTp = TextPainter(
      text: TextSpan(
        text: dbText,
        style: const TextStyle(
          color: Color(0xFFFF2A20),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          letterSpacing: 1.0,
          shadows: [
            Shadow(color: Color(0x99FF2A20), blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    volTp.paint(canvas, Offset(centerX - volTp.width * 0.5, dispRect.top + 6.0));

    // 4. 数码管上方 VOLUME 标签
    final volLabelTp = TextPainter(
      text: const TextSpan(
        text: 'VOLUME',
        style: TextStyle(
          color: Color(0xFF8A7346),
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    volLabelTp.paint(canvas, Offset(centerX - volLabelTp.width * 0.5, dispRect.top - 12.0));
  }

  void _drawSingleMeter(Canvas canvas, Rect rect, double needleVal, String channelLabel) {
    final w = rect.width;
    final h = rect.height;
    final cx = rect.center.dx;

    // 1. 外层压铸金属拉丝框
    _drawMeterBezel(canvas, rect);

    // 2. 表盘内部区域 (开启剪裁)
    final dialRect = rect.deflate(6.0);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(dialRect, const Radius.circular(8)));

    // 表盘纯黑底面
    canvas.drawRect(dialRect, Paint()..color = meterBg);

    // 机械指针枢轴点 (位于表盘底部正中)
    final pivot = Offset(cx, dialRect.bottom - 4.0);

    // 水平双层色带基准纵向坐标 (对齐 C++ 原版公式)
    final yTop = dialRect.top + h * 0.36;
    final yBot = yTop + 14.0;
    const yGap = 4.0;
    final yLowTop = yBot + yGap;
    final yLowBot = yLowTop + 4.5;

    // 水平色带左右跨度
    final spanL = w * 0.44;
    final xStart = cx - spanL;
    final xEnd = cx + spanL;

    // 动圈径向射线方程闭包：计算经过 (u, yTop) 并在任意 y 处的投影 x 坐标
    double getRayX(double u, double y) {
      final xRef = xStart + u * (xEnd - xStart);
      return pivot.dx + (xRef - pivot.dx) * (y - pivot.dy) / (yTop - pivot.dy);
    }

    // 表盘透光柔和背光微光晕
    final ribbonColor = (themeId == 2)
        ? ribbonIceBlue
        : (accentColor ?? ribbonIceBlue);

    final glowCenter = Offset(cx, yTop + 8.0);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [ribbonColor.withValues(alpha: 0.15), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: glowCenter, radius: spanL * 0.70));
    canvas.drawCircle(glowCenter, spanL * 0.70, glowPaint);

    // 3. 精确物理刻度归一化位置 (对齐 Accuphase 原机照片与 C++ 代码)
    const uMinus = 0.040;
    const u50    = 0.120;
    const u40    = 0.235;
    const u30    = 0.355;
    const u20    = 0.470;
    const u10    = 0.590;
    const u5Safe = 0.700;
    const u0     = 0.795; // 0 dB 临界过载点 (红色区起始)
    const u5Peak = 0.885; // +5 dB
    const uPlus  = 0.950; // + 标度

    // 4. 绘制上层梯形主色带 (Safe 强调色区 + Overload 警示红区)
    _drawUpperRibbon(canvas, yTop, yBot, getRayX, ribbonColor, u0, u5Peak, uPlus);

    // 5. 绘制下层细长梯形色带
    _drawLowerRibbon(canvas, yLowTop, yLowBot, getRayX, ribbonColor, uPlus);

    // 6. 绘制上方 dB 刻度线与读数
    _drawDbScale(canvas, pivot, yTop, getRayX, ribbonColor, uMinus, u50, u40, u30, u20, u10, u5Safe, u0, u5Peak, uPlus);

    // 7. 绘制下方 % 功率百分比刻度线与读数
    _drawPercentScale(canvas, pivot, yLowBot, getRayX, ribbonColor, u50, u40, u30, u20, u10, u0, u5Peak, uPlus);

    // 8. 居中绘制标牌：dB 与 PEAK POWER LEVEL 及声道指示
    _drawLabels(canvas, dialRect, cx, channelLabel, ribbonColor);

    // 9. 动圈指针 (白金纤细纯白钢针 + 动态视差投射阴影)
    _drawNeedle(canvas, pivot, yTop, getRayX, needleVal, uMinus, uPlus);

    // 10. 底部机械半球金属旋转轴盖 (Dome Cap)
    _drawDomeCap(canvas, pivot);

    // 11. 光学表镜弧形高光反射
    _drawGlassReflections(canvas, dialRect);

    canvas.restore();

    // 四角精密螺丝
    _drawCornerScrews(canvas, rect);
  }

  void _drawMeterBezel(Canvas canvas, Rect rect) {
    // 外层金属压铸框
    final outerBezelPaint = Paint()
      ..color = bezelOuter
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), outerBezelPaint);

    // 镀金倒角高光
    final highlightBezel = Paint()
      ..color = const Color(0x40D2B478)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), highlightBezel);

    // 内凹阴影线
    final innerShadowRect = rect.deflate(4.0);
    final innerShadowPaint = Paint()
      ..color = bezelInner
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(RRect.fromRectAndRadius(innerShadowRect, const Radius.circular(9)), innerShadowPaint);
  }

  void _drawUpperRibbon(Canvas canvas, double yTop, double yBot, double Function(double, double) getRayX,
      Color ribbonColor, double u0, double u5Peak, double uPlus) {
    // 1. 左侧安全主色块 (uRibL ~ u0)
    const uRibL = 0.030;
    final pathSafe = Path()
      ..moveTo(getRayX(uRibL - 0.02, yTop), yTop)
      ..lineTo(getRayX(u0, yTop), yTop)
      ..lineTo(getRayX(u0, yBot), yBot)
      ..lineTo(getRayX(uRibL, yBot), yBot)
      ..close();
    canvas.drawPath(pathSafe, Paint()..color = ribbonColor);

    // 2. 0dB ~ +5dB 警示红带底部连贯基座
    final yRedMid = yBot - 4.5;
    final pathRedBase = Path()
      ..moveTo(getRayX(u0, yRedMid), yRedMid)
      ..lineTo(getRayX(u5Peak + 0.02, yRedMid), yRedMid)
      ..lineTo(getRayX(u5Peak + 0.02, yBot), yBot)
      ..lineTo(getRayX(u0, yBot), yBot)
      ..close();
    canvas.drawPath(pathRedBase, Paint()..color = overloadRed);

    // 3. 0dB ~ +5dB 原机标志性 3 根倾斜红色梳齿
    final uTeeth = [u0, (u0 + u5Peak) * 0.5, u5Peak];
    const toothW = 2.5;
    for (final uTooth in uTeeth) {
      final pathTooth = Path()
        ..moveTo(getRayX(uTooth, yTop) - toothW * 0.5, yTop)
        ..lineTo(getRayX(uTooth, yTop) + toothW * 0.5, yTop)
        ..lineTo(getRayX(uTooth, yRedMid) + toothW * 0.5, yRedMid)
        ..lineTo(getRayX(uTooth, yRedMid) - toothW * 0.5, yRedMid)
        ..close();
      canvas.drawPath(pathTooth, Paint()..color = overloadRed);
    }

    // 4. 右侧延伸主色块
    final pathRight = Path()
      ..moveTo(getRayX(u5Peak + 0.02, yTop), yTop)
      ..lineTo(getRayX(uPlus + 0.03, yTop), yTop)
      ..lineTo(getRayX(uPlus + 0.01, yBot), yBot)
      ..lineTo(getRayX(u5Peak + 0.02, yBot), yBot)
      ..close();
    canvas.drawPath(pathRight, Paint()..color = ribbonColor);
  }

  void _drawLowerRibbon(Canvas canvas, double yLowTop, double yLowBot, double Function(double, double) getRayX,
      Color ribbonColor, double uPlus) {
    const uRibL = 0.030;
    final pathLower = Path()
      ..moveTo(getRayX(uRibL + 0.02, yLowTop), yLowTop)
      ..lineTo(getRayX(uPlus + 0.01, yLowTop), yLowTop)
      ..lineTo(getRayX(uPlus - 0.01, yLowBot), yLowBot)
      ..lineTo(getRayX(uRibL + 0.04, yLowBot), yLowBot)
      ..close();
    canvas.drawPath(pathLower, Paint()..color = ribbonColor);
  }

  void _drawDbScale(Canvas canvas, Offset pivot, double yTop, double Function(double, double) getRayX,
      Color ribbonColor, double uMinus, double u50, double u40, double u30, double u20, double u10,
      double u5Safe, double u0, double u5Peak, double uPlus) {
    final dbMarks = [
      (uMinus, '-', true),
      (u50, '50', true),
      ((u50 + u40) * 0.5, '', false),
      (u40, '40', true),
      ((u40 + u30) * 0.5, '', false),
      (u30, '30', true),
      ((u30 + u20) * 0.5, '', false),
      (u20, '20', true),
      ((u20 + u10) * 0.5, '', false),
      (u10, '10', true),
      ((u10 + u5Safe) * 0.5, '', false),
      (u5Safe, '5', true),
      (u0, '0', true),
      ((u0 + u5Peak) * 0.5, '', false),
      (u5Peak, '5', true),
      (uPlus, '+', true),
    ];

    for (final m in dbMarks) {
      final u = m.$1;
      final label = m.$2;
      final isMajor = m.$3;

      final isRed = (u >= u0 - 0.005 && u <= u5Peak + 0.005);
      final tickCol = isRed ? overloadRed : tickSafe;
      final tickLen = isMajor ? 14.0 : 8.5;

      final xTop = getRayX(u, yTop);
      final dx = xTop - pivot.dx;
      final dy = yTop - pivot.dy;
      final dist = sqrt(dx * dx + dy * dy);
      final ux = dx / dist;
      final uy = dy / dist; // 向上延伸 (负值)

      final p0 = Offset(xTop, yTop);
      final p1 = Offset(xTop + ux * tickLen, yTop + uy * tickLen);
      canvas.drawLine(p0, p1, Paint()..color = tickCol..strokeWidth = isMajor ? 1.8 : 1.0);

      if (label.isNotEmpty) {
        final tx = xTop + ux * (tickLen + 10.0);
        final ty = yTop + uy * (tickLen + 10.0);

        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: isRed ? overloadRed : tickSafe,
              fontSize: 9.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(tx - tp.width * 0.5, ty - tp.height * 0.5));
      }
    }
  }

  void _drawPercentScale(Canvas canvas, Offset pivot, double yLowBot, double Function(double, double) getRayX,
      Color ribbonColor, double u50, double u40, double u30, double u20, double u10, double u0,
      double u5Peak, double uPlus) {
    final pctMarks = [
      (u50 + 0.04, '0'),
      (u40, '0.01'),
      (u30, '0.1'),
      (u20, '1'),
      (u10, '10'),
      (u0, '100'),
      (u5Peak - 0.03, '200'),
      (uPlus - 0.02, '%'),
    ];

    for (final pm in pctMarks) {
      final u = pm.$1;
      final label = pm.$2;

      final xLow = getRayX(u, yLowBot);
      final dx = xLow - pivot.dx;
      final dy = yLowBot - pivot.dy;
      final dist = sqrt(dx * dx + dy * dy);
      final ux = dx / dist;
      final uy = dy / dist;

      final p0 = Offset(xLow, yLowBot);
      final p1 = Offset(xLow - ux * 5.0, yLowBot - uy * 5.0); // 向下延伸
      canvas.drawLine(p0, p1, Paint()..color = tickSafe..strokeWidth = 1.0);

      final tx = xLow - ux * 13.0;
      final ty = yLowBot - uy * 13.0;

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: tickSafe,
            fontSize: 8.0,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(tx - tp.width * 0.5, ty - tp.height * 0.5));
    }
  }

  void _drawLabels(Canvas canvas, Rect dialRect, double cx, String channelLabel, Color ribbonColor) {
    // 1. 声道指示 (位于表盘顶部)
    final chTp = TextPainter(
      text: TextSpan(
        text: channelLabel,
        style: const TextStyle(
          color: tickSafe,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    chTp.paint(canvas, Offset(cx - chTp.width * 0.5, dialRect.top + 14.0));

    // 2. 居中绘制：dB 标识
    final dbTp = TextPainter(
      text: const TextSpan(
        text: 'dB',
        style: TextStyle(
          color: tickSafe,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dbTp.paint(canvas, Offset(cx - dbTp.width * 0.5, dialRect.bottom - 105.0));

    // 3. PEAK POWER LEVEL 标牌
    final peakTp = TextPainter(
      text: const TextSpan(
        text: 'PEAK POWER LEVEL',
        style: TextStyle(
          color: tickSafe,
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    peakTp.paint(canvas, Offset(cx - peakTp.width * 0.5, dialRect.bottom - 78.0));
  }

  void _drawNeedle(Canvas canvas, Offset pivot, double yTop, double Function(double, double) getRayX,
      double needleVal, double uMinus, double uPlus) {
    final clampedVal = needleVal.clamp(0.0, 1.0);
    final uNeedle = uMinus + clampedVal * (uPlus - uMinus);
    final tipY = yTop - 26.0;
    final tipX = getRayX(uNeedle, tipY);
    final tip = Offset(tipX, tipY);

    // 1. 动圈指针在黑曜石底板上的物理投射阴影 (向右下偏移 4px)
    final shadowTip = Offset(tip.dx + 4.0, tip.dy + 5.0);
    final shadowPaint = Paint()
      ..color = needleShadow
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawLine(pivot + const Offset(2, 3), shadowTip, shadowPaint);

    // 2. 指针透光微辉光
    final glowPaint = Paint()
      ..color = needleGlow
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pivot, tip, glowPaint);

    // 3. 纯白高精度动圈实体钢针
    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pivot, tip, needlePaint);
  }

  void _drawDomeCap(Canvas canvas, Offset pivot) {
    const rCap = 24.0;

    // 1. 外圈暗金属底盘 (半球上半部)
    final pathOuter = Path()
      ..arcTo(Rect.fromCircle(center: pivot, radius: rCap), pi, pi, false)
      ..close();
    canvas.drawPath(pathOuter, Paint()..color = const Color(0xFF262A30));
    canvas.drawPath(pathOuter, Paint()..color = const Color(0xFF878E9B)..style = PaintingStyle.stroke..strokeWidth = 2.0);

    // 2. 中层高光金属球冠
    final pathMid = Path()
      ..arcTo(Rect.fromCircle(center: pivot, radius: rCap * 0.75), pi, pi, false)
      ..close();
    canvas.drawPath(pathMid, Paint()..color = const Color(0xFFA5ACB6));

    // 3. 顶端反光微弧
    final pathTop = Path()
      ..arcTo(Rect.fromCircle(center: pivot, radius: rCap * 0.45), pi, pi, false)
      ..close();
    canvas.drawPath(pathTop, Paint()..color = const Color(0xFFDCE4EE));

    // 4. 指针进入轴心的机械深色凹槽
    canvas.drawRect(
      Rect.fromLTWH(pivot.dx - 3.5, pivot.dy - 13.0, 7.0, 11.0),
      Paint()..color = const Color(0xFF14161A),
    );
  }

  void _drawGlassReflections(Canvas canvas, Rect rect) {
    final glassPath = Path();
    glassPath.moveTo(rect.left, rect.top);
    glassPath.lineTo(rect.right, rect.top);
    glassPath.lineTo(rect.right, rect.top + rect.height * 0.20);
    glassPath.quadraticBezierTo(
      rect.center.dx,
      rect.top + rect.height * 0.38,
      rect.left,
      rect.top + rect.height * 0.12,
    );
    glassPath.close();

    final glareShader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Colors.white.withValues(alpha: 0.08),
        Colors.white.withValues(alpha: 0.01),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(rect);

    canvas.drawPath(glassPath, Paint()..shader = glareShader);
  }

  void _drawCornerScrews(Canvas canvas, Rect rect) {
    const offset = 8.5;
    final corners = [
      rect.topLeft + const Offset(offset, offset),
      rect.topRight + const Offset(-offset, offset),
      rect.bottomLeft + const Offset(offset, -offset),
      rect.bottomRight + const Offset(-offset, -offset),
    ];

    for (final c in corners) {
      canvas.drawCircle(c, 3.8, Paint()..color = const Color(0xFF282014));
      canvas.drawCircle(c, 3.8, Paint()..color = const Color(0xFF8A7346)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      canvas.drawCircle(c, 2.5, Paint()..color = const Color(0xFFD2B478));
      canvas.drawCircle(c, 1.2, Paint()..color = const Color(0xFF181511));
    }
  }

  void _drawFooter(Canvas canvas, Size size, double padX) {
    final leftTp = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: champagneGold,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rightTp = TextPainter(
      text: const TextSpan(
        text: 'BALANCED AAVA · PURE CLASS A OPERATION · MDS+ DAC',
        style: TextStyle(
          color: champagneGold,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final available = size.width - padX * 2;
    if (leftTp.width + rightTp.width + 24.0 <= available) {
      leftTp.paint(canvas, Offset(padX + 4.0, size.height - 20.0));
      rightTp.paint(canvas, Offset(size.width - rightTp.width - padX - 4.0, size.height - 20.0));
    } else {
      leftTp.paint(canvas, Offset(padX + 4.0, size.height - 20.0));
    }
  }

  @override
  bool shouldRepaint(covariant AccuphaseMeterPainter oldDelegate) {
    return oldDelegate.leftAngle != leftAngle ||
        oldDelegate.rightAngle != rightAngle ||
        oldDelegate.leftValue != leftValue ||
        oldDelegate.rightValue != rightValue ||
        oldDelegate.animTime != animTime ||
        oldDelegate.volumePercent != volumePercent ||
        oldDelegate.themeId != themeId ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.title != title;
  }
}
