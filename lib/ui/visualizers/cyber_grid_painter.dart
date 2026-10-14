import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 3D 赛博粒子透视网格绘制器 (1:1 严格对齐 C++ CyberGridRenderer.cpp)
/// 满屏全景 3D 纵深透视、多谐波音乐能量地形波动、星尘节点微粒
class CyberGridPainter extends CustomPainter {
  final List<double> spectrumLevels;
  final double animTime;
  final Color accentColor;
  final bool isPlaying;

  CyberGridPainter({
    required this.spectrumLevels,
    required this.animTime,
    required this.accentColor,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 深空黑底板
    final bgPaint = Paint()..color = const Color(0xFF0C1018);
    canvas.drawRect(Offset.zero & size, bgPaint);

    const int cols = 54;
    const int rows = 28;

    final centerX = size.width * 0.5;
    final horizonY = size.height * 0.30;
    const fov = 420.0;
    const camY = -180.0;

    const zNear = 110.0;
    const zFar = 860.0;
    final xSpan = math.max(size.width * 2.8, 2600.0);

    final nBands = math.min(spectrumLevels.length, 16);

    // 顶点缓存
    final pts = List<Offset>.filled(cols * rows, Offset.zero);
    final depthTs = List<double>.filled(cols * rows, 0.0);
    final latFades = List<double>.filled(cols * rows, 0.0);
    final valids = List<bool>.filled(cols * rows, false);

    for (int r = 0; r < rows; ++r) {
      final normZ = r / (rows - 1);
      final z = zFar - normZ * (zFar - zNear);
      final depthT = (zFar - z) / (zFar - zNear);

      for (int c = 0; c < cols; ++c) {
        final normX = c / (cols - 1);
        final centeredX = (normX - 0.5) * 2.0;
        final worldX = centeredX * (xSpan * 0.5);

        // 两端边缘平滑渐隐衰减 (消除硬截断)
        final edgeDist = centeredX.abs();
        double latFade = ((1.0 - edgeDist) / 0.30).clamp(0.0, 1.0);
        latFade = latFade * latFade * (3.0 - 2.0 * latFade);

        // 对应频段能量映射
        double bandEnergy = 0.0;
        if (nBands > 0) {
          final bandPos = normX * math.max(1, nBands - 1);
          final b0 = bandPos.floor().clamp(0, nBands - 1);
          final b1 = (b0 + 1).clamp(0, nBands - 1);
          final f = bandPos - b0;
          final lvl0 = spectrumLevels[b0];
          final lvl1 = spectrumLevels[b1];
          bandEnergy = lvl0 * (1.0 - f) + lvl1 * f;
        }

        // 地形起伏正弦波动计算 (多谐波流动波浪)
        final wave = math.sin(centeredX * 4.2 + animTime * 1.5) *
                math.cos(normZ * 5.5 - animTime * 2.2) * 0.65 +
            math.sin(centeredX * 8.5 - animTime * 3.0 + normZ * 3.0) * 0.35;

        final waveHeight = wave * (12.0 + (isPlaying ? bandEnergy * 95.0 : 0.0));
        final worldY = waveHeight;

        // 3D 透视投影
        final scale = fov / z;
        final px = centerX + worldX * scale;
        final py = horizonY + (worldY - camY) * scale;

        final idx = r * cols + c;
        pts[idx] = Offset(px, py);
        depthTs[idx] = depthT;
        latFades[idx] = latFade;
        valids[idx] = (z > 10.0);
      }
    }

    final linePaint = Paint()..style = PaintingStyle.stroke;

    // 2. 纵向线 (从远到近流向观察者)
    for (int c = 0; c < cols; ++c) {
      for (int r = 0; r < rows - 1; ++r) {
        final i0 = r * cols + c;
        final i1 = (r + 1) * cols + c;
        if (!valids[i0] || !valids[i1]) continue;

        final avgDepth = (depthTs[i0] + depthTs[i1]) * 0.5;
        final avgLat = (latFades[i0] + latFades[i1]) * 0.5;
        final alpha = (avgDepth * avgDepth * 0.68 * avgLat).clamp(0.0, 1.0);
        if (alpha <= 0.01) continue;

        linePaint.color = accentColor.withValues(alpha: alpha);
        linePaint.strokeWidth = 0.7 + avgDepth * 1.1;
        canvas.drawLine(pts[i0], pts[i1], linePaint);
      }
    }

    // 3. 横向线
    for (int r = 0; r < rows; ++r) {
      for (int c = 0; c < cols - 1; ++c) {
        final i0 = r * cols + c;
        final i1 = r * cols + (c + 1);
        if (!valids[i0] || !valids[i1]) continue;

        final avgDepth = depthTs[i0];
        final avgLat = (latFades[i0] + latFades[i1]) * 0.5;
        final alpha = (avgDepth * avgDepth * 0.52 * avgLat).clamp(0.0, 1.0);
        if (alpha <= 0.01) continue;

        linePaint.color = accentColor.withValues(alpha: alpha);
        linePaint.strokeWidth = 0.6 + avgDepth * 0.9;
        canvas.drawLine(pts[i0], pts[i1], linePaint);
      }
    }

    // 4. 发光粒子节点 (精细微粒星芒)
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int r = 0; r < rows; ++r) {
      for (int c = 0; c < cols; ++c) {
        final idx = r * cols + c;
        if (!valids[idx]) continue;

        final d = depthTs[idx];
        if (d < 0.15) continue;

        final lat = latFades[idx];
        if (lat < 0.02) continue;

        final dotRadius = 0.5 + d * 1.0;
        final dotAlpha = (d * 0.85 * lat).clamp(0.0, 1.0);

        dotPaint.color = accentColor.withValues(alpha: dotAlpha);
        canvas.drawCircle(pts[idx], dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CyberGridPainter oldDelegate) => true;
}
