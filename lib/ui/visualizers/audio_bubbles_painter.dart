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

    // 3. 逐个绘制 5 重液态透光气泡
    final r = accentColor.r;
    final g = accentColor.g;
    final b = accentColor.b;

    for (final bubble in bubbles) {
      final drawX = bubble.x + math.sin(bubble.vxPhase) * bubble.vxAmp;
      final drawY = bubble.y;
      final rad = bubble.currentRadius;

      // 视口边界裁剪剔除
      if (drawY < -rad * 2.0 || drawY > size.height + rad * 2.0) continue;

      final center = Offset(drawX, drawY);

      // [层级 1] 柔和外层漫反射辉光
      final glowA = (bubble.alpha * 0.35).clamp(0.0, 1.0);
      final glowPaint = Paint()
        ..color = Color.fromRGBO((r * 255).round(), (g * 255).round(), (b * 255).round(), glowA)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rad * 0.45);
      canvas.drawCircle(center, rad * 1.35, glowPaint);

      // [层级 2] 半透明液态玻璃主体 (径向渐变，中心通透，边缘微蓄光)
      final bodyRect = Rect.fromCircle(center: center, radius: rad);
      final bodyPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO((r * 255).round(), (g * 255).round(), (b * 255).round(), (bubble.alpha * 0.15).clamp(0.0, 1.0)),
            Color.fromRGBO((r * 255).round(), (g * 255).round(), (b * 255).round(), (bubble.alpha * 0.55).clamp(0.0, 1.0)),
          ],
          stops: const [0.4, 1.0],
        ).createShader(bodyRect);
      canvas.drawCircle(center, rad, bodyPaint);

      // [层级 3] 微光边缘轮廓线 (液态透镜边缘)
      final rimA = (bubble.alpha * 0.75).clamp(0.0, 1.0);
      final rimPaint = Paint()
        ..color = Color.fromRGBO((r * 255).round(), (g * 255).round(), (b * 255).round(), rimA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, rad, rimPaint);

      // [层级 4] 左上角高光反光 (Crescent Specular Highlight)
      final hlCenter = Offset(drawX - rad * 0.32, drawY - rad * 0.32);
      final hlRad = rad * 0.28;
      final hlA = (bubble.alpha * (0.85 + treble * 0.15)).clamp(0.0, 1.0);
      final hlPaint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, hlA)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(hlCenter, hlRad, hlPaint);

      // [层级 5] 右下角微弱次级反光 (Secondary Rim Sheen)
      final subCenter = Offset(drawX + rad * 0.35, drawY + rad * 0.35);
      final subRad = rad * 0.16;
      final subA = (bubble.alpha * (0.35 + mid * 0.20)).clamp(0.0, 1.0);
      final subPaint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, subA)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(subCenter, subRad, subPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AudioBubblesPainter oldDelegate) => true;
}
