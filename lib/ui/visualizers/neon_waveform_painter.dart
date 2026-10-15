import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 电光霓虹声波绘制器 (1:1 严格对齐 C++ NeonWaveformRenderer.cpp)
/// 呈现 48 列柔和全屏全频漫射光柱阴影、水平全景霓虹氛围带与高频密集抗锯齿电光脉冲核心
class NeonWaveformPainter extends CustomPainter {
  final List<double> levels; // 12 频段数据
  final double animTime;     // 随时间演进的相位
  final Color accentColor;
  final bool isPlaying;

  const NeonWaveformPainter({
    required this.levels,
    required this.animTime,
    this.accentColor = const Color(0xFF00F0FF),
    this.isPlaying = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 发烧深空纯净底板
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF060911),
    );

    final centerY = size.height * 0.48;
    final nBands = levels.isNotEmpty ? math.min(levels.length, 16) : 0;

    // 平滑插值频段能量
    double totalEnergy = 0.0;
    if (isPlaying && levels.isNotEmpty) {
      for (int i = 0; i < nBands; ++i) {
        totalEnergy += levels[i];
      }
    }
    final avgEnergy = nBands > 0 ? (totalEnergy / nBands).clamp(0.0, 1.0) : 0.0;

    // 2. 背景层：暗态垂直多频段漫射光柱阴影 (48列连续平滑插值，彻底根除左侧聚集突兀感)
    const numBars = 48;
    final barSpacing = size.width / numBars;
    final barW = barSpacing * 0.72;

    for (int i = 0; i < numBars; ++i) {
      final normI = i / (numBars - 1);
      final bandPos = normI * math.max(1, nBands - 1);
      final idx0 = bandPos.floor().clamp(0, nBands - 1);
      final idx1 = math.min(idx0 + 1, nBands - 1);
      final frac = bandPos - idx0;

      final lvl0 = (isPlaying && levels.isNotEmpty) ? levels[idx0] : 0.0;
      final lvl1 = (isPlaying && levels.isNotEmpty) ? levels[idx1] : 0.0;
      final bandLvl = (lvl0 * (1.0 - frac) + lvl1 * frac).clamp(0.0, 1.0);

      final barH = 12.0 + bandLvl * (size.height * 0.32);
      final bx = i * barSpacing + (barSpacing - barW) * 0.5;

      // 柔和羽化渐变 (无硬直角边缘)
      final shadowAlpha = (0.05 + bandLvl * 0.28).clamp(0.0, 0.35);

      final pillarShader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.0),
          accentColor.withValues(alpha: shadowAlpha),
          accentColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(bx, centerY - barH, barW, barH * 2));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, centerY - barH, barW, barH * 2),
          Radius.circular(barW * 0.5),
        ),
        Paint()..shader = pillarShader,
      );
    }

    // 3. 中间层：水平全景霓虹氛围漫射微光带
    final auraAlpha = (0.08 + avgEnergy * 0.22).clamp(0.0, 0.32);
    final auraShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        accentColor.withValues(alpha: 0.0),
        accentColor.withValues(alpha: auraAlpha),
        accentColor.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromLTWH(0, centerY - 65.0, size.width, 130.0));

    canvas.drawRect(
      Rect.fromLTWH(0, centerY - 65.0, size.width, 130.0),
      Paint()..shader = auraShader,
    );

    // 4. 前景层：电光霓虹脉冲波浪核心 (高频密集抗锯齿多道光带)
    const wavePts = 280;
    final pts = <Offset>[];

    for (int k = 0; k < wavePts; ++k) {
      final normX = k / (wavePts - 1);
      final x = normX * size.width;

      final bandPos = normX * math.max(1, nBands - 1);
      final b0 = bandPos.floor().clamp(0, nBands - 1);
      final b1 = math.min(b0 + 1, nBands - 1);
      final f = bandPos - b0;
      final lvl0 = (isPlaying && levels.isNotEmpty) ? levels[b0] : 0.0;
      final lvl1 = (isPlaying && levels.isNotEmpty) ? levels[b1] : 0.0;
      final e = lvl0 * (1.0 - f) + lvl1 * f;

      // 快速高频锐利音频震荡波
      final highPulse = math.sin(normX * 80.0 - animTime * 3.5) * 0.45 +
          math.cos(normX * 140.0 + animTime * 4.8) * 0.25;

      // 柔和低频大起伏基波
      final baseWave = math.sin(normX * 6.28 * 2.2 + animTime * 1.5) * 0.75 +
          math.sin(normX * 6.28 * 4.5 - animTime * 2.0) * 0.35;

      // 两侧边缘高斯平滑衰减
      final edgeFade = math.sin(normX * math.pi);
      final amp = (10.0 + e * 65.0) * edgeFade;
      final y = centerY + (baseWave + highPulse * (0.3 + e * 0.7)) * amp;

      pts.add(Offset(x, y));
    }

    if (pts.length > 1) {
      final wavePath = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; ++i) {
        wavePath.lineTo(pts[i].dx, pts[i].dy);
      }

      // [光带 1: 最外层弥散大光晕]
      canvas.drawPath(
        wavePath,
        Paint()
          ..color = accentColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10.0
          ..strokeCap = StrokeCap.round,
      );

      // [光带 2: 次级高饱和霓虹晕]
      canvas.drawPath(
        wavePath,
        Paint()
          ..color = accentColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round,
      );

      // [光带 3: 核心极致纤细高亮白芯]
      canvas.drawPath(
        wavePath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant NeonWaveformPainter oldDelegate) {
    return true;
  }
}
