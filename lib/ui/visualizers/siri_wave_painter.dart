import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 经典 Apple Siri 流光声波绘制器 (1:1 严格对齐 C++ SiriWaveformRenderer.cpp)
/// 呈现四重交错流体波浪 (电光青蓝、鲜亮玫红、极光紫罗兰、中央聚核白光高亮核心)
/// 采用高阶高斯衰减包络与 Smoothstep 边缘渐隐，彻底消除硬边界与生硬折线
class SiriWavePainter extends CustomPainter {
  final List<double> spectrumLevels;
  final double animTime;
  final bool isPlaying;

  // 经典 Siri 发烧配色矩阵
  static const Color colCyanTop = Color(0xFF00F2FE);
  static const Color colCyanBot = Color(0xFF00B4D8);

  static const Color colMagTop = Color(0xFFFF0844);
  static const Color colMagBot = Color(0xFFFA2D48);

  static const Color colPurTop = Color(0xFFA855F7);
  static const Color colPurBot = Color(0xFF7928CA);

  static const Color colCoreTop = Color(0xFFFFFFFF);
  static const Color colCoreBot = Color(0xFFE2E8F0);

  final Color? accentColor;

  const SiriWavePainter({
    required this.spectrumLevels,
    required this.animTime,
    this.accentColor,
    this.isPlaying = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 深空黑底板
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF070A11),
    );

    final centerX = size.width * 0.5;
    final centerY = size.height * 0.48;
    final totalW = math.min(size.width * 0.88, 880.0);

    // 提取音频动态总能量
    double energy = 0.0;
    if (isPlaying && spectrumLevels.isNotEmpty) {
      final len = spectrumLevels.length;
      final bass = (spectrumLevels[0] + (len > 1 ? spectrumLevels[1] : 0.0)) * 0.5;
      final mid = len > 4 ? spectrumLevels[3] : 0.0;
      final treble = len > 8 ? spectrumLevels[8] : 0.0;
      energy = bass * 0.55 + mid * 0.30 + treble * 0.15;
    }
    final smoothEnergy = energy.clamp(0.0, 1.0);

    // 2. 贯穿两端的激光水平微光基准线 (两端平滑归零渐隐)
    _drawLaserBaseline(canvas, centerX, centerY, totalW);

    // 基础静音待机波幅 ~12px，播放时随音乐大动态激荡至 45~95px
    final baseAmp = 14.0 + smoothEnergy * 75.0;

    // 3. 渲染 4 层经典 Siri 多彩交错流体波浪 (Cyan / Magenta / Purple / White Core)
    // [波层 1: 电光青蓝 Cyan Ribbon]
    _drawWaveRibbon(
      canvas: canvas,
      centerX: centerX,
      centerY: centerY,
      width: totalW,
      amp: baseAmp * 0.95,
      freq: 2.2,
      phase: 0.0,
      speedT: animTime * 1.0,
      colTop: (accentColor != null ? accentColor!.withValues(alpha: 0.58) : colCyanTop.withValues(alpha: 0.55)),
      colBot: (accentColor != null ? accentColor!.withValues(alpha: 0.20) : colCyanBot.withValues(alpha: 0.18)),
      maxHalfH: 90.0,
      gaussianPow: 3.5,
    );

    // [波层 2: 鲜亮玫红 Magenta Ribbon]
    _drawWaveRibbon(
      canvas: canvas,
      centerX: centerX,
      centerY: centerY,
      width: totalW,
      amp: baseAmp * 1.12,
      freq: 2.8,
      phase: 1.85,
      speedT: animTime * 1.15,
      colTop: colMagTop.withValues(alpha: 0.58),
      colBot: colMagBot.withValues(alpha: 0.18),
      maxHalfH: 95.0,
      gaussianPow: 3.5,
    );

    // [波层 3: 极光紫罗兰 Violet Ribbon]
    _drawWaveRibbon(
      canvas: canvas,
      centerX: centerX,
      centerY: centerY,
      width: totalW,
      amp: baseAmp * 0.82,
      freq: 1.8,
      phase: 3.42,
      speedT: animTime * 0.85,
      colTop: colPurTop.withValues(alpha: 0.52),
      colBot: colPurBot.withValues(alpha: 0.16),
      maxHalfH: 85.0,
      gaussianPow: 3.5,
    );

    // [波层 4: 中央聚核白光高亮核心]
    _drawWaveRibbon(
      canvas: canvas,
      centerX: centerX,
      centerY: centerY,
      width: totalW,
      amp: baseAmp * 0.55,
      freq: 3.2,
      phase: 0.92,
      speedT: animTime * 1.25,
      colTop: colCoreTop.withValues(alpha: 0.86),
      colBot: colCoreBot.withValues(alpha: 0.38),
      maxHalfH: 45.0,
      gaussianPow: 7.5,
    );
  }

  void _drawLaserBaseline(Canvas canvas, double centerX, double centerY, double totalW) {
    const laserSegs = 64;
    final laserHalfW = totalW * 0.52;

    for (int s = 0; s < laserSegs; ++s) {
      final t0 = s / laserSegs;
      final t1 = (s + 1) / laserSegs;
      final x0 = (centerX - laserHalfW) + t0 * (laserHalfW * 2.0);
      final x1 = (centerX - laserHalfW) + t1 * (laserHalfW * 2.0);

      final midNorm = ((t0 + t1) * 0.5 - 0.5) * 2.0;
      var lFade = (1.0 - midNorm.abs()) / 0.35;
      lFade = lFade.clamp(0.0, 1.0);
      lFade = lFade * lFade * (3.0 - 2.0 * lFade); // smoothstep
      if (lFade <= 0.01) continue;

      final pA = Offset(x0, centerY);
      final pB = Offset(x1, centerY);

      // 外漫射软辉光
      canvas.drawLine(
        pA,
        pB,
        Paint()
          ..color = (accentColor ?? Colors.white).withValues(alpha: 0.15 * lFade)
          ..strokeWidth = 3.0,
      );
      // 核心细白线
      canvas.drawLine(
        pA,
        pB,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.75 * lFade)
          ..strokeWidth = 0.8,
      );
    }
  }

  void _drawWaveRibbon({
    required Canvas canvas,
    required double centerX,
    required double centerY,
    required double width,
    required double amp,
    required double freq,
    required double phase,
    required double speedT,
    required Color colTop,
    required Color colBot,
    required double maxHalfH,
    required double gaussianPow,
  }) {
    // 采用 240 细分微元，彻底消除低采样分段感
    const segments = 240;
    final halfW = width * 0.5;

    final topPts = <Offset>[];
    final botPts = <Offset>[];
    final edgeFades = <double>[];

    for (int i = 0; i <= segments; ++i) {
      final normX = i / segments;
      final normCentered = (normX - 0.5) * 2.0; // -1.0 ~ +1.0
      final absX = normCentered.abs();

      // 高斯钟形平滑衰减包络：两侧两端平滑收缩
      final gaussian = math.exp(-gaussianPow * normCentered * normCentered);

      // 多频高阶谐波平滑正弦行波
      final waveVal = math.sin(normCentered * freq * math.pi - speedT + phase) +
          0.32 * math.sin(normCentered * (freq * 1.85) * math.pi - speedT * 1.25 + phase * 1.4) +
          0.12 * math.sin(normCentered * (freq * 3.1) * math.pi - speedT * 0.75);

      // 两侧端部 smoothstep 极度柔和渐隐
      var fade = (1.0 - absX) / 0.38;
      fade = fade.clamp(0.0, 1.0);
      fade = fade * fade * (3.0 - 2.0 * fade);
      edgeFades.add(fade);

      final halfH = (waveVal.abs() * amp * gaussian).clamp(0.2, maxHalfH);
      final px = centerX - halfW + normX * width;

      topPts.add(Offset(px, centerY - halfH));
      botPts.add(Offset(px, centerY + halfH));
    }

    // 1. 构建填充波形实体多边形
    final ribbonPath = Path()..moveTo(topPts[0].dx, topPts[0].dy);
    for (int i = 1; i <= segments; ++i) {
      ribbonPath.lineTo(topPts[i].dx, topPts[i].dy);
    }
    for (int i = segments; i >= 0; --i) {
      ribbonPath.lineTo(botPts[i].dx, botPts[i].dy);
    }
    ribbonPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colTop, colBot],
      ).createShader(Rect.fromLTWH(centerX - halfW, centerY - maxHalfH, width, maxHalfH * 2));
    canvas.drawPath(ribbonPath, fillPaint);

    // 2. 抗锯齿外层柔化微光晕轮廓
    final glowPaint = Paint()
      ..color = colTop.withValues(alpha: colTop.a * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final topGlowPath = Path()..moveTo(topPts[0].dx, topPts[0].dy);
    for (int i = 1; i <= segments; ++i) {
      topGlowPath.lineTo(topPts[i].dx, topPts[i].dy);
    }
    canvas.drawPath(topGlowPath, glowPaint);

    final botGlowPath = Path()..moveTo(botPts[0].dx, botPts[0].dy);
    for (int i = 1; i <= segments; ++i) {
      botGlowPath.lineTo(botPts[i].dx, botPts[i].dy);
    }
    canvas.drawPath(botGlowPath, glowPaint);

    // 3. 核心平滑亮边线 (1.4px)
    final edgePaint = Paint()
      ..color = colTop.withValues(alpha: colTop.a * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(topGlowPath, edgePaint);
    canvas.drawPath(botGlowPath, edgePaint);
  }

  @override
  bool shouldRepaint(covariant SiriWavePainter old) {
    return true;
  }
}
