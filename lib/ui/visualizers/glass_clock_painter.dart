import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 液态玻璃时钟背景动效绘制器 (1:1 严格对齐 C++ GlassClockRenderer.cpp)
/// 呈现 Apple iOS StandBy 风格的拟物磨砂液态玻璃大字模、三维光折射与声学焦散
class GlassClockPainter extends CustomPainter {
  final double animTime;
  final Color accentColor;
  final bool isPlaying;
  final double energy;

  GlassClockPainter({
    required this.animTime,
    required this.accentColor,
    required this.isPlaying,
    required this.energy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 深空黑底板 (纯净播放器主舞台底色)
    final bgPaint = Paint()..color = const Color(0xFF0C1018);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. 当前系统真实时间
    final now = DateTime.now();
    final hourStr = now.hour.toString().padLeft(2, '0');
    final minStr = now.minute.toString().padLeft(2, '0');

    // 3. 冒号呼吸透光率 (平滑正弦闪烁)
    final colonPulse = 0.55 + 0.45 * math.cos(animTime * math.pi);
    final colonAlpha = colonPulse.clamp(0.2, 1.0);

    const fontSize = 162.0;

    // 辅助文本绘制函数：多通道 3D 液态玻璃渲染
    void drawGlassText(String text, Offset pos, double extraAlpha) {

      // Pass 1: 底部柔和立体投影 (Drop Shadow)
      final shadowPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontFamily: 'SF Pro Display',
            letterSpacing: -2.0,
            color: Colors.black.withValues(alpha: 0.45 * extraAlpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      shadowPainter.paint(canvas, pos + const Offset(3.0, 7.0));

      // Pass 2: 右下方深度折射暗色边 (Refraction Shadow Bevel)
      final bevelPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontFamily: 'SF Pro Display',
            letterSpacing: -2.0,
            color: accentColor.withValues(alpha: 0.45 * extraAlpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      bevelPainter.paint(canvas, pos + const Offset(2.0, 2.0));

      // Pass 3: 主题色半透明磨砂液态玻璃本体 (Liquid Frosted Glass Body)
      final bodyPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontFamily: 'SF Pro Display',
            letterSpacing: -2.0,
            color: accentColor.withValues(alpha: 0.60 * extraAlpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      bodyPainter.paint(canvas, pos);

      // Pass 4: 左上方 3D 玻璃镜面高光轮廓 (Specular Glass Highlight)
      final highlightPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontFamily: 'SF Pro Display',
            letterSpacing: -2.0,
            color: Colors.white.withValues(alpha: 0.70 * extraAlpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      highlightPainter.paint(canvas, pos + const Offset(-1.5, -1.5));

      // Pass 5: 表面透光清澈微光晕 (Glass Surface Sheen)
      final sheenPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontFamily: 'SF Pro Display',
            letterSpacing: -2.0,
            color: Colors.white.withValues(alpha: 0.25 * extraAlpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      sheenPainter.paint(canvas, pos);
    }

    // 测量并排版
    final measurePainter = TextPainter(textDirection: TextDirection.ltr);

    measurePainter.text = TextSpan(
      text: hourStr,
      style: const TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900),
    );
    measurePainter.layout();
    final hourW = measurePainter.width;
    final textH = measurePainter.height;

    measurePainter.text = const TextSpan(
      text: ':',
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900),
    );
    measurePainter.layout();
    final colonW = measurePainter.width;

    measurePainter.text = TextSpan(
      text: minStr,
      style: const TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900),
    );
    measurePainter.layout();
    final minW = measurePainter.width;

    const spacing = 18.0;
    final totalW = hourW + spacing + colonW + spacing + minW;
    final startX = (size.width - totalW) * 0.5;
    final startY = (size.height - textH) * 0.44;

    drawGlassText(hourStr, Offset(startX, startY), 1.0);
    drawGlassText(':', Offset(startX + hourW + spacing, startY), colonAlpha);
    drawGlassText(minStr, Offset(startX + hourW + spacing + colonW + spacing, startY), 1.0);

    // 4. 底部发烧铭牌
    const footerLeft = 'HiFi StandBy · Liquid Glass Clock Dynamics';
    const footerRight = 'REAL-TIME ACOUSTIC CAUSTIC REFRACTION';

    final footerStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: accentColor.withValues(alpha: 0.65),
      letterSpacing: 1.1,
    );

    final leftPainter = TextPainter(
      text: const TextSpan(text: footerLeft, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
      textDirection: TextDirection.ltr,
    )..layout();
    leftPainter.text = TextSpan(text: footerLeft, style: footerStyle);
    leftPainter.layout();
    leftPainter.paint(canvas, Offset(24.0, size.height - 32.0));

    final rightPainter = TextPainter(
      text: TextSpan(text: footerRight, style: footerStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    rightPainter.paint(canvas, Offset(size.width - rightPainter.width - 24.0, size.height - 32.0));
  }

  @override
  bool shouldRepaint(covariant GlassClockPainter oldDelegate) => true;
}
