import 'dart:math';
import 'package:flutter/material.dart';

/// Siri 流体发光能量球 (Siri Orb)
class SiriOrbPainter extends CustomPainter {
  final double energy;    // 0.0 ~ 1.0 (实时音频总能量)
  final double animTime;  // 随时间演进的相位

  static const Color neonCyan = Color(0xFF00F5D4);
  static const Color neonPurple = Color(0xFF7B2CBF);
  static const Color neonPink = Color(0xFFFF007F);
  static const Color neonBlue = Color(0xFF0077B6);

  SiriOrbPainter({
    required this.energy,
    required this.animTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF060911));

    final center = Offset(size.width * 0.5, size.height * 0.48);
    final baseRadius = min(size.width * 0.22, size.height * 0.35);
    final dynamicRadius = baseRadius * (1.0 + energy * 0.25);

    // 1. 深度环境柔和泛光 (Ambience Glow)
    final ambiencePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          neonPurple.withValues(alpha: 0.35 + energy * 0.25),
          neonBlue.withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: dynamicRadius * 1.8));
    canvas.drawCircle(center, dynamicRadius * 1.8, ambiencePaint);

    // 2. 差分多重色相旋转流体层 (Chromatic Blob Layers)
    for (int layer = 0; layer < 4; layer++) {
      final layerPhase = animTime * (1.2 + layer * 0.3) + layer * (pi * 0.5);
      final layerRadius = dynamicRadius * (0.85 + sin(layerPhase) * 0.12);

      final offsetDist = dynamicRadius * (0.15 + energy * 0.1);
      final blobCenter = Offset(
        center.dx + cos(layerPhase) * offsetDist,
        center.dy + sin(layerPhase * 1.3) * offsetDist,
      );

      Color blobColor;
      switch (layer) {
        case 0:
          blobColor = neonCyan;
          break;
        case 1:
          blobColor = neonPink;
          break;
        case 2:
          blobColor = neonPurple;
          break;
        default:
          blobColor = neonBlue;
      }

      final blobPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            blobColor.withValues(alpha: 0.65),
            blobColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: blobCenter, radius: layerRadius));

      canvas.drawCircle(blobCenter, layerRadius, blobPaint);
    }

    // 3. 核心强光球 (Core White Hotspot)
    final coreRadius = dynamicRadius * 0.45;
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.9),
          neonCyan.withValues(alpha: 0.4),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));
    canvas.drawCircle(center, coreRadius, corePaint);

    // 4. 外围脉冲光环 (Resonance Ring)
    final ringRadius = dynamicRadius * (1.1 + sin(animTime * 2.0) * 0.05);
    final ringPaint = Paint()
      ..color = neonCyan.withValues(alpha: 0.3 + energy * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, ringRadius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant SiriOrbPainter oldDelegate) {
    return true;
  }
}
