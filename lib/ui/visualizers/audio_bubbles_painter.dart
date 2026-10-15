import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 单个声学微光气泡模型 (1:1 严格对齐 C++ AudioBubblesRenderer.cpp)
class AudioBubble {
  double x;
  double y;
  double vy;
  double vxPhase;
  double vxSpeed;
  double vxAmp;
  double baseRadius;
  double currentRadius;
  double alpha;
  int freqBand; // 0: 重低音(大球), 1: 中低音, 2: 中高音, 3: 高音(小球)

  AudioBubble({
    required this.x,
    required this.y,
    required this.vy,
    required this.vxPhase,
    required this.vxSpeed,
    required this.vxAmp,
    required this.baseRadius,
    required this.currentRadius,
    required this.alpha,
    required this.freqBand,
  });
}

/// 音乐微光气泡背景动效绘制器 (1:1 严格对齐 C++ AudioBubblesRenderer)
/// 呈现发烧级五重液态高光、呼吸膨胀物理与低频环境光晕
class AudioBubblesPainter extends CustomPainter {
  final List<AudioBubble> bubbles;
  final Color accentColor;
  final bool isPlaying;
  final List<double> spectrumLevels;
  final double animTime;

  AudioBubblesPainter({
    required this.bubbles,
    required this.accentColor,
    required this.isPlaying,
    required this.spectrumLevels,
    required this.animTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bubbles.isEmpty) return;

    // 1. 发烧深空纯净暗色底板
    final bgPaint = Paint()..color = const Color(0xFF0C1018);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. 底部低频氛围光晕 (随低音呼吸涌动)
    double bass = 0.0;
    double mid = 0.0;
    double treble = 0.0;
    if (isPlaying && spectrumLevels.isNotEmpty) {
      final len = spectrumLevels.length;
      bass = (spectrumLevels[0] + (len > 1 ? spectrumLevels[1] : 0.0) + (len > 2 ? spectrumLevels[2] : 0.0)) / 3.0;
      if (len > 6) {
        mid = (spectrumLevels[3] + spectrumLevels[4] + spectrumLevels[5] + spectrumLevels[6]) / 4.0;
      }
      if (len > 10) {
        treble = (spectrumLevels[7] + spectrumLevels[8] + spectrumLevels[9] + spectrumLevels[10]) / 4.0;
      }
    }

    if (bass > 0.03) {
      final glowRect = Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.55);
      final glowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withValues(alpha: 0.0),
            accentColor.withValues(alpha: (bass * 0.22).clamp(0.0, 0.35)),
          ],
        ).createShader(glowRect);
      canvas.drawRect(glowRect, glowPaint);
    }

    // 3. 逐个绘制拟真 3D 液态透光气泡
    for (final bubble in bubbles) {
      final drawX = bubble.x + math.sin(bubble.vxPhase) * bubble.vxAmp;
      final drawY = bubble.y;
      final rad = bubble.currentRadius;

      // 视口边界裁剪剔除
      if (drawY < -rad * 2.0 || drawY > size.height + rad * 2.0) continue;

      final center = Offset(drawX, drawY);

      // [层级 1] 柔和外层漫反射辉光 (采用径向渐变，高帧率纯 GPU 渲染)
      final glowA = (bubble.alpha * 0.28).clamp(0.0, 1.0);
      final glowRect = Rect.fromCircle(center: center, radius: rad * 1.4);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            accentColor.withValues(alpha: glowA),
            accentColor.withValues(alpha: 0.0),
          ],
          stops: const [0.65, 1.0],
        ).createShader(glowRect);
      canvas.drawCircle(center, rad * 1.4, glowPaint);

      // [层级 2] 半透明液态玻璃主体 (径向渐变：中心通透暗深，边缘微蓄光)
      final bodyRect = Rect.fromCircle(center: center, radius: rad);
      final bodyPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.25),
          colors: [
            accentColor.withValues(alpha: (bubble.alpha * 0.06).clamp(0.0, 1.0)),
            accentColor.withValues(alpha: (bubble.alpha * 0.22).clamp(0.0, 1.0)),
            accentColor.withValues(alpha: (bubble.alpha * 0.65).clamp(0.0, 1.0)),
          ],
          stops: const [0.0, 0.68, 1.0],
        ).createShader(bodyRect);
      canvas.drawCircle(center, rad, bodyPaint);

      // [层级 3] 色散虹彩边缘 (Thin-Film Iridescence Rim)
      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = SweepGradient(
          startAngle: 0.0,
          endAngle: math.pi * 2,
          colors: [
            accentColor.withValues(alpha: (bubble.alpha * 0.85).clamp(0.0, 1.0)),
            const Color(0xFF67E8F9).withValues(alpha: (bubble.alpha * 0.70).clamp(0.0, 1.0)), // 青玉色散
            const Color(0xFFE879F9).withValues(alpha: (bubble.alpha * 0.65).clamp(0.0, 1.0)), // 洋红偏振
            accentColor.withValues(alpha: (bubble.alpha * 0.85).clamp(0.0, 1.0)),
          ],
          stops: const [0.0, 0.35, 0.75, 1.0],
        ).createShader(bodyRect);
      canvas.drawCircle(center, rad, rimPaint);

      // [层级 4] 左上角新月形弧形高光 (Crescent Specular Arc - 杜绝死板实心圆点)
      if (rad > 6.0) {
        final arcRadius = rad * 0.76;
        final arcRect = Rect.fromCircle(center: center, radius: arcRadius);
        final specularA = (bubble.alpha * (0.80 + treble * 0.20)).clamp(0.0, 1.0);
        final specularPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (rad * 0.12).clamp(1.5, 4.0)
          ..color = Colors.white.withValues(alpha: specularA);
        // 在 -140° 到 -80° 绘制一段优雅的高光新月弧线
        canvas.drawArc(arcRect, -math.pi * 0.78, math.pi * 0.38, false, specularPaint);

        // 弧线内侧极细晶亮高光核
        final coreGlintPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (rad * 0.06).clamp(1.0, 2.0)
          ..color = Colors.white.withValues(alpha: (specularA * 0.95).clamp(0.0, 1.0));
        canvas.drawArc(arcRect, -math.pi * 0.66, math.pi * 0.18, false, coreGlintPaint);
      }

      // [层级 5] 右下角柔和次级焦散反光 (Secondary Caustic Sheen)
      if (rad > 10.0) {
        final subArcRect = Rect.fromCircle(center: center, radius: rad * 0.82);
        final subA = (bubble.alpha * (0.30 + mid * 0.25)).clamp(0.0, 0.7);
        final subPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.4
          ..color = Colors.white.withValues(alpha: subA);
        canvas.drawArc(subArcRect, math.pi * 0.24, math.pi * 0.28, false, subPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AudioBubblesPainter oldDelegate) => true;
}
