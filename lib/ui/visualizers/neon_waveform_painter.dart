import 'dart:math';
import 'package:flutter/material.dart';

/// 极光赛博重低音波形瀑布 (Neon Waveform)
class NeonWaveformPainter extends CustomPainter {
  final List<double> levels; // 12 频段数据
  final double animTime;     // 随时间演进的相位

  static const Color cyan = Color(0xFF00F0FF);
  static const Color purple = Color(0xFFBD00FF);
  static const Color pink = Color(0xFFFF007F);

  NeonWaveformPainter({
    required this.levels,
    required this.animTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 深空黑底板
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF05070B));

    final centerY = size.height * 0.50;

    // 提取低频能量和高频能量
    final bassEnergy = levels.isNotEmpty ? (levels[0] + (levels.length > 1 ? levels[1] : 0.0)) * 0.5 : 0.0;
    final trebleEnergy = levels.length > 8 ? levels[8] : 0.0;

    // 2. 背景层：暗态垂直多频段漫射光柱 (Radiant Pillars)
    const numBars = 36;
    final barSpacing = size.width / numBars;
    final barW = barSpacing * 0.65;

    for (int i = 0; i < numBars; i++) {
      final normI = i / (numBars - 1);
      final bandIdx = (normI * (levels.isEmpty ? 1 : levels.length - 1)).clamp(0, levels.length - 1).toInt();
      final lvl = levels.isNotEmpty ? levels[bandIdx] : 0.0;

      final barH = 10.0 + lvl * (size.height * 0.38);
      final bx = i * barSpacing + (barSpacing - barW) * 0.5;

      final pillarShader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          cyan.withValues(alpha: 0.0),
          cyan.withValues(alpha: 0.25 * lvl),
          cyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(bx, centerY - barH, barW, barH * 2));

      canvas.drawRect(
        Rect.fromLTWH(bx, centerY - barH, barW, barH * 2),
        Paint()..shader = pillarShader,
      );
    }

    // 3. 多重谐波霓虹流体波形
    _drawHarmonicWave(canvas, size, centerY, animTime, 1.0, 40.0 * (1.0 + bassEnergy * 2.0), cyan, 2.5);
    _drawHarmonicWave(canvas, size, centerY, animTime * 1.3 + pi * 0.5, 2.0, 28.0 * (1.0 + trebleEnergy * 2.5), purple, 2.0);
    _drawHarmonicWave(canvas, size, centerY, animTime * 0.7 + pi, 0.5, 55.0 * (0.8 + bassEnergy * 1.5), pink, 1.8);
  }

  void _drawHarmonicWave(
    Canvas canvas,
    Size size,
    double centerY,
    double phase,
    double freqMultiplier,
    double amplitude,
    Color waveColor,
    double strokeWidth,
  ) {
    final path = Path();
    const steps = 120;
    final dx = size.width / steps;

    for (int i = 0; i <= steps; i++) {
      final x = i * dx;
      final normX = i / steps;

      // 窗函数加权 (两侧衰减至 0，避免突兀截断)
      final envelope = sin(normX * pi);

      final y = centerY +
          sin(normX * 4 * pi * freqMultiplier + phase) * amplitude * envelope +
          cos(normX * 8 * pi * freqMultiplier - phase * 0.5) * (amplitude * 0.3) * envelope;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // 外发光层
    final glowPaint = Paint()
      ..color = waveColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.5;
    canvas.drawPath(path, glowPaint);

    // 核心高亮线
    final corePaint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant NeonWaveformPainter oldDelegate) {
    return true;
  }
}
