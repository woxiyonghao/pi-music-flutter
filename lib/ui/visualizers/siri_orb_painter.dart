import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 经典 Apple Siri 悬浮微光流体玻璃球 (1:1 严格对齐 C++ SiriOrbRenderer.cpp)
/// 外层主题色柔和漫射光晕与半透明磨砂玻璃罩，里层四色经典旋转流体光团
/// 呈现 3D 镜面弧度高光与焦散内折射，无任何生硬外层线框 (严格去除最外层线框)
class SiriOrbPainter extends CustomPainter {
  final double energy;       // 0.0 ~ 1.0 (实时音频总能量)
  final double animTime;     // 随时间演进的相位
  final Color accentColor;   // 随主题动态联动的主题强调色
  final bool isPlaying;

  static const Color cyanBlob = Color(0xFF00F2FE);
  static const Color magBlob = Color(0xFFFF0844);
  static const Color purBlob = Color(0xFFA855F7);
  static const Color ambBlob = Color(0xFFF59E0B);

  const SiriOrbPainter({
    required this.energy,
    required this.animTime,
    this.accentColor = const Color(0xFF00F0FF),
    this.isPlaying = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 发烧深空纯净暗色底板
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF060911),
    );

    final center = Offset(size.width * 0.5, size.height * 0.46);
    // 基准半径：随音频能量平滑呼吸膨胀
    final smoothE = energy.clamp(0.0, 1.0);
    final orbRadius = math.min(size.width * 0.22, 175.0) * (1.0 + smoothE * 0.12);

    // 2. 外层：主题色漫射超柔和环境光晕 (Ambience Halo, 无任何硬线框)
    final haloRadius = orbRadius * 1.65;
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: 0.25 + smoothE * 0.25),
          accentColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: haloRadius));
    canvas.drawCircle(center, haloRadius, haloPaint);

    // 3. 开启精确圆形裁剪区域，让里层经典多彩光团完美包裹在玻璃球体内
    canvas.save();
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: orbRadius));
    canvas.clipPath(clipPath);

    // 4. 外层玻璃材质暗基底
    final glassBasePaint = Paint()
      ..color = const Color.fromRGBO(10, 14, 22, 0.92);
    canvas.drawCircle(center, orbRadius, glassBasePaint);

    // 5. 里层保留经典 Siri 颜色：电光青、热力粉红、极光紫罗兰、琥珀金旋转交融
    final t = animTime;
    final orbitR = orbRadius * (0.35 + smoothE * 0.15);

    // [Blob 1: 电光青蓝 Cyan Blob]
    final cCyan = Offset(
      center.dx + math.cos(t * 1.0) * orbitR,
      center.dy + math.sin(t * 1.0) * orbitR,
    );
    _drawRadialBlob(canvas, cCyan, orbRadius * 0.75, cyanBlob.withValues(alpha: 0.72));

    // [Blob 2: 鲜亮玫红 Magenta Blob]
    final cMag = Offset(
      center.dx + math.cos(t * 1.25 + 2.1) * orbitR,
      center.dy + math.sin(t * 1.25 + 2.1) * orbitR,
    );
    _drawRadialBlob(canvas, cMag, orbRadius * 0.72, magBlob.withValues(alpha: 0.70));

    // [Blob 3: 极光紫罗兰 Purple Blob]
    final cPur = Offset(
      center.dx + math.cos(t * 0.9 + 4.2) * orbitR,
      center.dy + math.sin(t * 0.9 + 4.2) * orbitR,
    );
    _drawRadialBlob(canvas, cPur, orbRadius * 0.70, purBlob.withValues(alpha: 0.68));

    // [Blob 4: 温暖琥珀金次要光晕 Amber Blob]
    final cAmb = Offset(
      center.dx + math.cos(-t * 1.4 + 1.2) * (orbitR * 0.8),
      center.dy + math.sin(-t * 1.4 + 1.2) * (orbitR * 0.8),
    );
    _drawRadialBlob(canvas, cAmb, orbRadius * 0.55, ambBlob.withValues(alpha: 0.55));

    // [Blob 5: 核心白光聚核 Luminous Core]
    _drawRadialBlob(canvas, center, orbRadius * 0.45, Colors.white.withValues(alpha: 0.88));

    canvas.restore();

    // ==============================================================================
    // 6. 外层玻璃材质质感微透镜层 (3D 弧面高光与折射，严格无最外层多余线框)
    // ==============================================================================
    // [1] 主题色半透明磨砂玻璃罩 (Frosted Theme Glass Tint)
    final tintPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.14);
    canvas.drawCircle(center, orbRadius, tintPaint);

    // [2] 菲涅尔球体自然柔化微外沿 (极纤细 0.8px，柔和融于背景，绝非突兀的大线框)
    final fresnelPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, orbRadius, fresnelPaint);

    // [3] 左上角 3D 玻璃镜面弧度高光 (Specular Glass Crescent Highlight)
    final hlCenter = Offset(center.dx - orbRadius * 0.38, center.dy - orbRadius * 0.38);
    final hlR = orbRadius * 0.30;
    _drawRadialBlob(canvas, hlCenter, hlR, Colors.white.withValues(alpha: 0.55));

    // [4] 右下角次级内部折射高光 (Secondary Caustic Glow)
    final subCenter = Offset(center.dx + orbRadius * 0.40, center.dy + orbRadius * 0.40);
    final subR = orbRadius * 0.24;
    _drawRadialBlob(canvas, subCenter, subR, accentColor.withValues(alpha: 0.40));
  }

  void _drawRadialBlob(Canvas canvas, Offset blobCenter, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: blobCenter, radius: radius));
    canvas.drawCircle(blobCenter, radius, paint);
  }

  @override
  bool shouldRepaint(covariant SiriOrbPainter oldDelegate) {
    return true;
  }
}
