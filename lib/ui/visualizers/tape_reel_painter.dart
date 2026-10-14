import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/hifi_theme.dart';

/// 经典开盘磁带机 (Studer Revox) 动效绘制
class TapeReelPainter extends CustomPainter {
  final double progress;      // 0.0 ~ 1.0 (歌曲播放进度)
  final double leftAngle;     // 随时间递增的旋转角度
  final double rightAngle;    // 随时间递增的旋转角度
  final bool isPlaying;

  static const Color chassisBg = Color(0xFF0E0906);        // 复古暖黑机架底
  static const Color panelBg = Color(0xFF181410);          // 铸铝拉丝面板
  static const Color tapeDark = Color(0xFF221710);         // 高密度磁带本体
  static const Color tapeEdge = Color(0xFF4A3425);         // 磁带边缘反光
  static const Color aluminum = Color(0xFFC0CAD5);         // 阳极氧化铝外盘
  static const Color aluminumGlow = Color(0xFFE2E8F0);     // 铝合金高光倒角
  static const Color hubDark = Color(0xFF0F131A);          // 3孔镂空暗区
  static const Color centerCap = Color(0xFFD4AF37);        // 中心黄铜/金色锁扣

  TapeReelPainter({
    required this.progress,
    required this.leftAngle,
    required this.rightAngle,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 底板
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = chassisBg);

    final padding = 16.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    // 面板微圆角底框
    final panelRect = Rect.fromLTWH(padding, padding, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(16)),
      Paint()..color = panelBg,
    );

    // 2. 计算左右磁带盘几何尺寸与动态缠绕半径
    final maxReelRadius = min(w * 0.23, h * 0.40);
    final minHubRadius = maxReelRadius * 0.38;

    // 磁带随进度转移：左盘减小，右盘增大 (按面积平方守恒物理模型)
    final prog = progress.clamp(0.0, 1.0);
    final leftTapeR = sqrt(pow(maxReelRadius, 2) - prog * (pow(maxReelRadius, 2) - pow(minHubRadius, 2)));
    final rightTapeR = sqrt(pow(minHubRadius, 2) + prog * (pow(maxReelRadius, 2) - pow(minHubRadius, 2)));

    final leftCenter = Offset(padding + w * 0.28, padding + h * 0.42);
    final rightCenter = Offset(padding + w * 0.72, padding + h * 0.42);

    // 3. 绘制两轮之间穿行的磁带走带路径
    _drawTapePath(canvas, leftCenter, rightCenter, leftTapeR, rightTapeR, h);

    // 4. 绘制左右两大开盘轮毂
    _drawSingleReel(canvas, leftCenter, maxReelRadius, leftTapeR, leftAngle);
    _drawSingleReel(canvas, rightCenter, maxReelRadius, rightTapeR, rightAngle);

    // 5. 绘制中央磁头组件 (Head Block)
    _drawHeadBlock(canvas, Offset(padding + w * 0.5, padding + h * 0.78), maxReelRadius * 1.2, h * 0.22);
  }

  void _drawSingleReel(Canvas canvas, Offset center, double radius, double tapeRadius, double angle) {
    // 1. 漫射阴影
    canvas.drawCircle(center + const Offset(2, 4), radius, Paint()..color = Colors.black.withValues(alpha: 0.55));

    // 2. 外金属轮盘实体
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1C222C));

    // 3. 磁带卷层 (深棕黑磁性材料，带同心圆纹理)
    if (tapeRadius > 25.0) {
      canvas.drawCircle(center, tapeRadius, Paint()..color = tapeDark);
      canvas.drawCircle(center, tapeRadius, Paint()..color = tapeEdge..style = PaintingStyle.stroke..strokeWidth = 1.2);
      canvas.drawCircle(center, (tapeRadius + 25) * 0.5, Paint()..color = tapeEdge.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    // 4. 金属外法兰盘倒角光晕
    final rimPaint = Paint()
      ..color = aluminum
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, radius, rimPaint);
    canvas.drawCircle(center, radius - 2.0, Paint()..color = aluminumGlow.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 0.8);

    // 5. 经典 3 孔镂空 NAB 轮毂 (随 angle 旋转)
    final holeDist = radius * 0.58;
    final holeRadius = radius * 0.22;

    for (int k = 0; k < 3; k++) {
      final a = angle + k * (2 * pi / 3.0);
      final hCenter = Offset(center.dx + cos(a) * holeDist, center.dy + sin(a) * holeDist);

      // 镂空大孔
      canvas.drawCircle(hCenter, holeRadius, Paint()..color = hubDark);
      canvas.drawCircle(hCenter, holeRadius, Paint()..color = aluminum.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }

    // 6. 中央 NAB 金属锁扣与三芒星锁定卡齿
    canvas.drawCircle(center, 28.0, Paint()..color = const Color(0xFF1E2430));
    canvas.drawCircle(center, 28.0, Paint()..color = aluminumGlow..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // 三芒星锁定卡齿
    for (int k = 0; k < 3; k++) {
      final a = angle + k * (2 * pi / 3.0);
      final pIn = Offset(center.dx + cos(a) * 6.0, center.dy + sin(a) * 6.0);
      final pOut = Offset(center.dx + cos(a) * 20.0, center.dy + sin(a) * 20.0);
      canvas.drawLine(pIn, pOut, Paint()..color = centerCap..strokeWidth = 2.0);
    }

    // 中心紧固轴心
    canvas.drawCircle(center, 5.0, Paint()..color = centerCap);
    canvas.drawCircle(center, 1.8, Paint()..color = Colors.black);
  }

  void _drawTapePath(Canvas canvas, Offset leftC, Offset rightC, double leftR, double rightR, double h) {
    final guideY = leftC.dy + h * 0.28;
    final leftGuide = Offset(leftC.dx - leftR * 0.6, guideY);
    final rightGuide = Offset(rightC.dx + rightR * 0.6, guideY);

    final tapePath = Path()
      ..moveTo(leftC.dx, leftC.dy + leftR)
      ..lineTo(leftGuide.dx, leftGuide.dy)
      ..lineTo(rightGuide.dx, rightGuide.dy)
      ..lineTo(rightC.dx, rightC.dy + rightR);

    final tapePaint = Paint()
      ..color = const Color(0xFF3B271A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawPath(tapePath, tapePaint);

    // 导带滚轮 (Guide Rollers)
    canvas.drawCircle(leftGuide, 6.0, Paint()..color = aluminum);
    canvas.drawCircle(leftGuide, 2.0, Paint()..color = Colors.black);
    canvas.drawCircle(rightGuide, 6.0, Paint()..color = aluminum);
    canvas.drawCircle(rightGuide, 2.0, Paint()..color = Colors.black);
  }

  void _drawHeadBlock(Canvas canvas, Offset center, double width, double height) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = const Color(0xFF161B24),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = HifiTheme.cardBorder..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );

    // 磁头 (消音磁头、录音磁头、放音磁头)
    for (int i = -1; i <= 1; i++) {
      final hCenter = Offset(center.dx + i * (width * 0.28), center.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: hCenter, width: 14, height: height * 0.55), const Radius.circular(3)),
        Paint()..color = const Color(0xFF2C3442),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: hCenter, width: 14, height: height * 0.55), const Radius.circular(3)),
        Paint()..color = aluminum..style = PaintingStyle.stroke..strokeWidth = 0.8,
      );
    }

    // 铭牌文字
    final tp = TextPainter(
      text: const TextSpan(
        text: 'STUDER REVOX MASTER RECORDER · 15 IPS 2-TRACK',
        style: TextStyle(color: HifiTheme.accuphaseGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width * 0.5, rect.bottom - 16.0));
  }

  @override
  bool shouldRepaint(covariant TapeReelPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.leftAngle != leftAngle ||
        oldDelegate.rightAngle != rightAngle ||
        oldDelegate.isPlaying != isPlaying;
  }
}
