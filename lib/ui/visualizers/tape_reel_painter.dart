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
  final double levelL;        // 0.0 ~ 1.0 (左声道/低频电平)
  final double levelCenter;   // 0.0 ~ 1.0 (中央/峰值电平)
  final double levelR;        // 0.0 ~ 1.0 (右声道/高频电平)
  final List<double>? spectrumLevels;

  static const Color chassisBg = Color(0xFF0C0906);        // 铸铁深邃黑曜底板
  static const Color panelBg = Color(0xFF16120E);          // 复古暖棕黑拉丝面板
  static const Color tapeDark = Color(0xFF22160F);         // 高密度氧化铁磁带主体
  static const Color tapeSpecular = Color(0xFF5A3E2C);     // 磁带表面微反光环
  static const Color tapeEdgeGleam = Color(0xFF7C563D);    // 磁带外圈光亮切面
  static const Color aluminum = Color(0xFFCAD4DE);         // 阳极氧化铝外盘
  static const Color aluminumGlow = Color(0xFFEEF2F6);     // 铝合金镜面倒角高光
  static const Color hubDark = Color(0xFF0B0E14);          // 3孔镂空内部机械暗腔
  static const Color brassCap = Color(0xFFD4AF37);         // 黄铜三芒星卡齿锁扣
  static const Color headBlockBg = Color(0xFF141820);      // 磁头/数显表头仓深邃基座
  static const Color badgeGold = Color(0xFFD2B478);        // 经典发烧铭牌金

  TapeReelPainter({
    required this.progress,
    required this.leftAngle,
    required this.rightAngle,
    required this.isPlaying,
    this.elapsedSec = 0.0,
    this.accentColor,
    this.levelL = 0.0,
    this.levelCenter = 0.0,
    this.levelR = 0.0,
    this.spectrumLevels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 底板：深空复古发烧机架底板
    final bgPaint = Paint()..color = chassisBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    const padding = 16.0;
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

    // 2. 双开盘/卡座带轮几何排版 (左右大轮盘：按要求减小 12px，并优化左右间距)
    final maxReelRadius = max(30.0, min(w * 0.22, h * 0.38) - 12.0);
    final minHubRadius = maxReelRadius * 0.36;

    // 磁带随进度转移：左盘减小，右盘增大 (严格遵循磁带物理面积平方守恒定律)
    final prog = progress.clamp(0.0, 1.0);
    final leftTapeR = sqrt(pow(maxReelRadius, 2) - prog * (pow(maxReelRadius, 2) - pow(minHubRadius, 2)));
    final rightTapeR = sqrt(pow(minHubRadius, 2) + prog * (pow(maxReelRadius, 2) - pow(minHubRadius, 2)));

    final reelY = panelRect.top + h * 0.39;
    // 左右间距优化：从原先的 0.28 / 0.72 适当拉开至 0.26 / 0.74，形成舒展典雅的卡座机械轮廓
    final reelLx = panelRect.left + w * 0.26;
    final reelRx = panelRect.left + w * 0.74;

    final leftCenter = Offset(reelLx, reelY);
    final rightCenter = Offset(reelRx, reelY);

    // 3. 走带路径 (磁带连接线与精密导向滚轮)
    _drawTapePathAndRollers(canvas, leftCenter, rightCenter, maxReelRadius, leftTapeR, rightTapeR, panelRect);

    // 4. 左右两大阳极氧化铝开盘轮毂 (随播放状态平滑旋转)
    _drawSingleReel(canvas, leftCenter, maxReelRadius, leftTapeR, leftAngle);
    _drawSingleReel(canvas, rightCenter, maxReelRadius, rightTapeR, rightAngle);

    // 5. 中央高保真磁头与数显电平柱长方体组 (随音频声音大小实时跳动高度)
    _drawHeadBlock(canvas, Offset(panelRect.left + w * 0.5, panelRect.top + h * 0.74), max(190.0, maxReelRadius * 1.60), h * 0.24);

    // 6. 中央数码荧光管走带时间计数器 [ MM : SS ]
    _drawCounter(canvas, Offset(panelRect.left + w * 0.5, reelY - maxReelRadius * 0.68));

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
        ..color = const Color(0x40000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0,
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

    // 1. 磁头仓/数显长方体金属底盘 (铸铁深邃边框 + 微内阴影)
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(const Offset(0, 4)), const Radius.circular(8)),
      Paint()..color = const Color(0x60000000),
    );

    // 坡莫合金屏蔽罩金属面板
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = headBlockBg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..color = const Color(0x40FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 4角发烧紧固微六角螺钉
    const screwOffset = 7.0;
    final screwPaint = Paint()..color = const Color(0xFF4A5568);
    final screwRim = Paint()
      ..color = const Color(0x80CAD4DE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final corner in [
      rect.topLeft + const Offset(screwOffset, screwOffset),
      rect.topRight + const Offset(-screwOffset, screwOffset),
      rect.bottomLeft + const Offset(screwOffset, -screwOffset),
      rect.bottomRight + const Offset(-screwOffset, -screwOffset),
    ]) {
      canvas.drawCircle(corner, 2.5, screwPaint);
      canvas.drawCircle(corner, 2.5, screwRim);
      canvas.drawLine(corner - const Offset(1.5, 0), corner + const Offset(1.5, 0), Paint()..color = const Color(0xFF1A202C)..strokeWidth = 0.6);
    }

    // 顶部铭文
    final topBadgeTp = TextPainter(
      text: const TextSpan(
        text: '· 3-HEAD PEAK MONITOR / FLUORESCENT LEVEL SYSTEM ·',
        style: TextStyle(
          color: Color(0xFF718096),
          fontSize: 6.8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    topBadgeTp.paint(canvas, Offset(center.dx - topBadgeTp.width * 0.5, rect.top + 4.5));

    // 2. 三组精密数显光柱 (左声道 CH-L, 中央峰值 PEAK, 右声道 CH-R)
    final headGap = width / 4.0;
    final headLabels = ['CH - L', 'PEAK', 'CH - R'];
    final headSubLabels = ['ERASE', 'REC', 'PLAY'];
    final levels = [levelL, levelCenter, levelR];

    const int segmentCount = 13;

    for (int h = 0; h < 3; ++h) {
      final hx = rect.left + (h + 1) * headGap;
      final slotWidth = min(32.0, width * 0.20);
      final slotHeight = height * 0.65;
      final slotCenter = Offset(hx, center.dy + 3.0);
      final hRect = Rect.fromCenter(center: slotCenter, width: slotWidth, height: slotHeight);

      // 深色内嵌荧光数显槽基底
      canvas.drawRRect(
        RRect.fromRectAndRadius(hRect, const Radius.circular(4)),
        Paint()..color = const Color(0xFF0C0F15),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(hRect, const Radius.circular(4)),
        Paint()
          ..color = const Color(0xFF334155)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // 音频响应电平 (0.0 ~ 1.0)
      final val = levels[h].clamp(0.0, 1.0);
      final litCount = (val * segmentCount).round();

      final innerTop = hRect.top + 5.0;
      final innerBottom = hRect.bottom - 10.0;
      final innerH = innerBottom - innerTop;
      final segH = (innerH / segmentCount) - 1.2;

      // 逐级绘制数显梯级 (自底向上：底区温暖琥珀金，中区亮金，顶区+3dB红色峰值)
      for (int s = 0; s < segmentCount; ++s) {
        final segY = innerBottom - (s + 1) * (innerH / segmentCount);
        final segRect = Rect.fromLTWH(hRect.left + 3.5, segY, slotWidth - 7.0, segH);

        final isLit = s < litCount;
        Color segColor;
        if (s >= 10) {
          // 红色过载峰值区 (+3dB ~ +6dB)
          segColor = isLit ? const Color(0xFFEF4444) : const Color(0x18EF4444);
        } else if (s >= 7) {
          // 黄金过渡区 (0dB ~ +2dB)
          segColor = isLit ? const Color(0xFFFBBF24) : const Color(0x18FBBF24);
        } else {
          // 安全温暖基调区 (-20dB ~ -1dB)
          segColor = isLit ? (accentColor ?? const Color(0xFFF59E0B)) : const Color(0x15FFFFFF);
        }

        final segPaint = Paint()..color = segColor;
        canvas.drawRRect(RRect.fromRectAndRadius(segRect, const Radius.circular(1.2)), segPaint);

        // 如果是最高亮起的一格 (Peak Hold)，添加发光光晕
        if (isLit && s == litCount - 1 && isPlaying) {
          final glowPaint = Paint()
            ..color = segColor.withValues(alpha: 0.65)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
          canvas.drawRRect(RRect.fromRectAndRadius(segRect, const Radius.circular(1.5)), glowPaint);
        }
      }

      // 中央高精微隙光柱 (动态高度随声音大小实时律动)
      final beamH = innerH * val;
      if (beamH > 1.0) {
        final beamY = innerBottom - beamH;
        final beamPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              (accentColor ?? const Color(0xFFF59E0B)).withValues(alpha: 0.7),
              val > 0.8 ? const Color(0xFFEF4444) : const Color(0xFFFBBF24),
            ],
          ).createShader(Rect.fromLTWH(hx - 1.0, beamY, 2.0, beamH))
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(hx, innerBottom), Offset(hx, beamY), beamPaint);
      }

      // 顶部微型标尺刻度
      final dbText = h == 1 ? (val > 0.8 ? '+3' : '0') : (h == 0 ? 'L' : 'R');
      final dbTp = TextPainter(
        text: TextSpan(
          text: dbText,
          style: TextStyle(
            color: (val > 0.8) ? const Color(0xFFEF4444) : const Color(0xFF64748B),
            fontSize: 6.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dbTp.paint(canvas, Offset(hx - dbTp.width * 0.5, hRect.top + 1.2));

      // 底部数显主标牌 (CH-L / PEAK / CH-R)
      final mainTp = TextPainter(
        text: TextSpan(
          text: headLabels[h],
          style: TextStyle(
            color: (litCount > 0) ? (accentColor ?? const Color(0xFFFF9E3D)) : const Color(0xFF94A3B8),
            fontSize: 7.8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      mainTp.paint(canvas, Offset(hx - mainTp.width * 0.5, hRect.bottom + 2.5));

      // 次标牌 (ERASE / REC / PLAY)
      final subTp = TextPainter(
        text: TextSpan(
          text: headSubLabels[h],
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 6.0,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      subTp.paint(canvas, Offset(hx - subTp.width * 0.5, hRect.bottom + 11.5));
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
        oldDelegate.accentColor != accentColor ||
        oldDelegate.levelL != levelL ||
        oldDelegate.levelCenter != levelCenter ||
        oldDelegate.levelR != levelR;
  }
}
