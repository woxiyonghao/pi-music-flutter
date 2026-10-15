import 'dart:math';
import 'package:flutter/material.dart';

/// 经典开盘磁带机 (Studer Revox Master Tape Deck) 动效绘制 - 高保真物理拟真版
/// 具备：3孔镂空 NAB 铝合金轮毂带斜角倒角高光、磁带卷盘真实守恒动态转移、双精密导带滚轮、
/// 坡莫合金三磁头屏蔽罩 (消音/录音/放音)、数码荧光管走带计时器与发烧名机金属拉丝面板
class TapeReelPainter extends CustomPainter {
  final double progress;      // 0.0 ~ 1.0 (歌曲播放进度)
  final double leftAngle;     // 随时间递增的旋转角度
  final double rightAngle;    // 随时间递增的旋转角度
  final bool isPlaying;
  final double elapsedSec;    // 播放时间秒数
  final Color? accentColor;

  static const Color chassisBg = Color(0xFF0C0906);        // 铸铁深邃黑曜底板
  static const Color panelBg = Color(0xFF16120E);          // 复古暖棕黑拉丝面板
  static const Color tapeDark = Color(0xFF22160F);         // 高密度氧化铁磁带主体
  static const Color tapeSpecular = Color(0xFF5A3E2C);     // 磁带表面微反光环
  static const Color tapeEdgeGleam = Color(0xFF7C563D);    // 磁带外圈光亮切面
  static const Color aluminum = Color(0xFFCAD4DE);         // 阳极氧化铝外盘
  static const Color aluminumGlow = Color(0xFFEEF2F6);     // 铝合金镜面倒角高光
  static const Color hubDark = Color(0xFF0B0E14);          // 3孔镂空内部机械暗腔
  static const Color brassCap = Color(0xFFD4AF37);         // 黄铜三芒星卡齿锁扣
  static const Color headBlockBg = Color(0xFF1A1F29);      // 磁头基座屏蔽罩
  static const Color badgeGold = Color(0xFFD2B478);        // 经典发烧铭牌金

  TapeReelPainter({
    required this.progress,
    required this.leftAngle,
    required this.rightAngle,
    required this.isPlaying,
    this.elapsedSec = 0.0,
    this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 底板：深空复古发烧机架底板
    final bgPaint = Paint()..color = chassisBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final padding = 16.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;
    if (w <= 100 || h <= 100) return;

    // 面板微圆角实体底框与拉丝微纹理
    final panelRect = Rect.fromLTWH(padding, padding, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(16)),
      Paint()..color = panelBg,
    );

    final brushPaint = Paint()
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 1.0;
    for (double y = padding + 6; y < panelRect.bottom; y += 8) {
      canvas.drawLine(Offset(panelRect.left, y), Offset(panelRect.right, y), brushPaint);
    }

    // 面板外金属框
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(16)),
      Paint()
        ..color = const Color(0xFF382E22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // 2. 双开盘带轮几何排版 (左右大轮盘)
    final maxReelRadius = min(w * 0.22, h * 0.38);
    final minHubRadius = maxReelRadius * 0.36;

    // 磁带随进度转移：左盘减小，右盘增大 (严格遵循磁带物理面积平方守恒定律)
    final prog = progress.clamp(0.0, 1.0);
    final leftTapeR = sqrt(pow(maxReelRadius, 2) - prog * (pow(maxReelRadius, 2) - pow(minHubRadius, 2)));
    final rightTapeR = sqrt(pow(minHubRadius, 2) + prog * (pow(maxReelRadius, 2) - pow(minHubRadius, 2)));

    final reelY = panelRect.top + h * 0.42;
    final reelLx = panelRect.left + w * 0.28;
    final reelRx = panelRect.left + w * 0.72;

    final leftCenter = Offset(reelLx, reelY);
    final rightCenter = Offset(reelRx, reelY);

    // 3. 走带路径 (磁带连接线与精密导向滚轮)
    _drawTapePathAndRollers(canvas, leftCenter, rightCenter, maxReelRadius, leftTapeR, rightTapeR, panelRect);

    // 4. 左右两大阳极氧化铝开盘轮毂 (随播放状态平滑旋转)
    _drawSingleReel(canvas, leftCenter, maxReelRadius, leftTapeR, leftAngle);
    _drawSingleReel(canvas, rightCenter, maxReelRadius, rightTapeR, rightAngle);

    // 5. 中央高保真磁头组 (Erase, Record, Playback 坡莫合金金属屏蔽罩)
    _drawHeadBlock(canvas, Offset(panelRect.left + w * 0.5, panelRect.top + h * 0.76), maxReelRadius * 1.35, h * 0.20);

    // 6. 中央数码荧光管走带时间计数器 [ MM : SS ]
    _drawCounter(canvas, Offset(panelRect.left + w * 0.5, reelY - maxReelRadius * 0.65));

    // 7. 底部经典开盘机铭牌
    _drawFooter(canvas, panelRect);
  }

  void _drawSingleReel(Canvas canvas, Offset center, double radius, double tapeRadius, double angle) {
    // 1. 底层大盘多阶柔和漫射阴影
    canvas.drawCircle(center + const Offset(4.0, 8.0), radius + 2.0, Paint()..color = const Color(0x60000000));
    canvas.drawCircle(center + const Offset(2.0, 4.0), radius, Paint()..color = const Color(0x90000000));

    // 2. 金属轮盘外圈实体底板
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1A202A));

    // 3. 磁带卷盘实体层 (高密度发烧磁带，同心微纹理与柔和边缘)
    if (tapeRadius > 30.0) {
      canvas.drawCircle(center, tapeRadius, Paint()..color = tapeDark);

      // 磁带微纹理同心环 (模拟万千圈紧密缠绕的磁带纹理)
      final ringPaint = Paint()
        ..color = tapeSpecular.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, tapeRadius * 0.92, ringPaint);
      canvas.drawCircle(center, tapeRadius * 0.80, ringPaint);
      canvas.drawCircle(center, tapeRadius * 0.65, ringPaint);
      canvas.drawCircle(center, tapeRadius * 0.50, ringPaint);

      // 磁带最外圈切面光泽亮环
      final gleamPaint = Paint()
        ..color = tapeEdgeGleam
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(center, tapeRadius, gleamPaint);
    }

    // 4. 金属外法兰盘倒角光晕 (柔和渐变铝合金边缘)
    final rimPaint = Paint()
      ..color = aluminum
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, rimPaint);

    final rimHiPaint = Paint()
      ..color = aluminumGlow.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 2.0, rimHiPaint);

    // 5. 经典 3 孔镂空 NAB 轮毂 (随 angle 旋转)
    final holeDist = radius * 0.58;
    final holeRadius = radius * 0.22;

    for (int k = 0; k < 3; ++k) {
      final a = angle + k * (2.0 * pi / 3.0);
      final hCenter = Offset(center.dx + cos(a) * holeDist, center.dy + sin(a) * holeDist);

      // 镂空大圆孔内深色阴影
      canvas.drawCircle(hCenter, holeRadius, Paint()..color = hubDark);

      // 镂空孔内边缘柔和倒角反光圈
      final holeRimPaint = Paint()
        ..color = aluminum
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(hCenter, holeRadius, holeRimPaint);

      final holeHiPaint = Paint()
        ..color = aluminumGlow.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawCircle(hCenter, holeRadius - 1.2, holeHiPaint);
    }

    // 6. 中央 NAB 金属锁扣与轴心盖 (纯正阳极氧化铝拉丝同心环)
    canvas.drawCircle(center, 36.0, Paint()..color = const Color(0xFF1E2430));
    canvas.drawCircle(center, 36.0, Paint()..color = aluminumGlow..style = PaintingStyle.stroke..strokeWidth = 1.4);

    // 主题色微光外环
    final accent = accentColor ?? const Color(0xFFF97316);
    canvas.drawCircle(center, 24.0, Paint()..color = accent.withValues(alpha: 0.25));
    canvas.drawCircle(center, 24.0, Paint()..color = accent.withValues(alpha: 0.85)..style = PaintingStyle.stroke..strokeWidth = 1.4);

    // 三芒星锁定卡齿 (黄铜镀金卡齿)
    for (int k = 0; k < 3; ++k) {
      final a = angle + k * (2.0 * pi / 3.0);
      final pIn = Offset(center.dx + cos(a) * 7.0, center.dy + sin(a) * 7.0);
      final pOut = Offset(center.dx + cos(a) * 22.0, center.dy + sin(a) * 22.0);
      canvas.drawLine(
        pIn,
        pOut,
        Paint()
          ..color = brassCap
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }

    // 中心精密不锈钢紧固轴心
    canvas.drawCircle(center, 7.0, Paint()..color = const Color(0xFFE2E8F0));
    canvas.drawCircle(center, 7.0, Paint()..color = brassCap..style = PaintingStyle.stroke..strokeWidth = 1.0);
    canvas.drawCircle(center, 2.5, Paint()..color = Colors.black);
  }

  void _drawTapePathAndRollers(Canvas canvas, Offset leftC, Offset rightC, double maxR,
      double leftR, double rightR, Rect panelRect) {
    final guideY = panelRect.top + panelRect.height * 0.76;
    final leftGuide = Offset(leftC.dx - maxR * 0.45, guideY);
    final rightGuide = Offset(rightC.dx + maxR * 0.45, guideY);

    // 磁带实体连接线 (深棕黑微反光实带)
    final tapePath = Path()
      ..moveTo(leftC.dx + leftR * 0.65, leftC.dy + leftR * 0.75)
      ..lineTo(leftGuide.dx, leftGuide.dy)
      ..lineTo(rightGuide.dx, rightGuide.dy)
      ..lineTo(rightC.dx - rightR * 0.65, rightC.dy + rightR * 0.75);

    // 阴影带
    canvas.drawPath(
      tapePath,
      Paint()
        ..color = const Color(0x60000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );

    // 磁带本体
    canvas.drawPath(
      tapePath,
      Paint()
        ..color = const Color(0xFF38261A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6,
    );

    // 磁带微反光亮线
    canvas.drawPath(
      tapePath,
      Paint()
        ..color = const Color(0x50FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // 左右对称导带滚轮 (Guide Rollers)
    _drawRoller(canvas, leftGuide);
    _drawRoller(canvas, rightGuide);
  }

  void _drawRoller(Canvas canvas, Offset pos) {
    // 滚轮底盘
    canvas.drawCircle(pos, 11.0, Paint()..color = const Color(0xFF1E2632));
    // 不锈钢外缘
    canvas.drawCircle(pos, 11.0, Paint()..color = aluminum..style = PaintingStyle.stroke..strokeWidth = 1.4);
    canvas.drawCircle(pos, 9.0, Paint()..color = const Color(0x60FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    // 黄铜中心铆钉
    canvas.drawCircle(pos, 4.0, Paint()..color = brassCap);
    canvas.drawCircle(pos, 1.5, Paint()..color = Colors.black);
  }

  void _drawHeadBlock(Canvas canvas, Offset center, double width, double height) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);

    // 磁头基座屏蔽罩底板
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = headBlockBg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = const Color(0x35FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 三组精密模拟磁头 (消音磁头、录音磁头、放音磁头)
    final headGap = width / 4.0;
    final headLabels = ['ERASE', 'RECORD', 'PLAYBACK'];

    for (int h = 1; h <= 3; ++h) {
      final hx = rect.left + h * headGap;
      final hRect = Rect.fromCenter(center: Offset(hx, center.dy), width: 26.0, height: height * 0.65);

      // 坡莫合金金属屏蔽外壳
      canvas.drawRRect(
        RRect.fromRectAndRadius(hRect, const Radius.circular(4)),
        Paint()..color = const Color(0xFF283242),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(hRect, const Radius.circular(4)),
        Paint()
          ..color = const Color(0xFFC5D1DE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // 磁头工作微隙 (Gap line)
      canvas.drawLine(
        Offset(hx, hRect.top + 3.0),
        Offset(hx, hRect.bottom - 3.0),
        Paint()
          ..color = (accentColor ?? const Color(0xFFF97316))
          ..strokeWidth = 1.4,
      );

      // 磁头微型标牌文字
      final tp = TextPainter(
        text: TextSpan(
          text: headLabels[h - 1],
          style: const TextStyle(
            color: Color(0xFF8A9FB4),
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(hx - tp.width * 0.5, hRect.bottom + 2.0));
    }
  }

  void _drawCounter(Canvas canvas, Offset center) {
    final mins = (elapsedSec / 60.0).floor();
    final secs = (elapsedSec % 60.0).floor();
    final timeStr = '[ ${mins.toString().padLeft(2, '0')} : ${secs.toString().padLeft(2, '0')} ]';

    final textTp = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: TextStyle(
          color: accentColor ?? const Color(0xFFFF9E3D),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          letterSpacing: 1.5,
          shadows: [
            Shadow(color: (accentColor ?? const Color(0xFFFF9E3D)).withValues(alpha: 0.55), blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final cRect = Rect.fromCenter(center: center, width: textTp.width + 24.0, height: textTp.height + 10.0);

    // 计数器圆角深邃底板
    canvas.drawRRect(
      RRect.fromRectAndRadius(cRect, const Radius.circular(6)),
      Paint()..color = const Color(0xFF10141C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cRect, const Radius.circular(6)),
      Paint()
        ..color = (accentColor?.withValues(alpha: 0.55) ?? const Color(0x60D4AF37))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    textTp.paint(canvas, Offset(center.dx - textTp.width * 0.5, center.dy - textTp.height * 0.5));
  }

  void _drawFooter(Canvas canvas, Rect panelRect) {
    const leftText = 'Studer Revox Master Tape Deck · Direct-Drive Dual Reel System';
    const rightText = 'NAB / CCIR MASTER TAPE · 15 IPS 2-TRACK PURE ANALOG';

    final leftTp = TextPainter(
      text: const TextSpan(
        text: leftText,
        style: TextStyle(
          color: badgeGold,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rightTp = TextPainter(
      text: const TextSpan(
        text: rightText,
        style: TextStyle(
          color: badgeGold,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    leftTp.paint(canvas, Offset(panelRect.left + 16.0, panelRect.bottom - 20.0));
    rightTp.paint(canvas, Offset(panelRect.right - rightTp.width - 16.0, panelRect.bottom - 20.0));
  }

  @override
  bool shouldRepaint(covariant TapeReelPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.leftAngle != leftAngle ||
        oldDelegate.rightAngle != rightAngle ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.elapsedSec != elapsedSec ||
        oldDelegate.accentColor != accentColor;
  }
}
