import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../core/platform_helper.dart';
import '../../services/dac_setting_service.dart';

/// 表头多品牌发烧视觉调色板 (1:1 严格对齐 C++ VUMeterRenderer.cpp 8大品牌名机 + Custom HSV 动态调色)
class _MeterPalette {
  final Color chassisBg;
  final Color meterBgDark;
  final Color meterBgMid;
  final Color meterBgBottom;
  final Color glowCore;
  final Color glowOuter;
  final Color topGlow;
  final Color bezelOuter;
  final Color bezelInner;
  final Color arcWattsColor;
  final Color arcDbColor;
  final Color tickSafe;
  final Color tickTextSafe;
  final Color overloadRed;
  final Color needleColor;
  final Color needleShadow;
  final Color pivotBase;
  final Color pivotRing;
  final Color footerBadge;
  final Color pgLedGreen;
  final String subLabel;
  final String footerLeft;
  final String footerRight;

  const _MeterPalette({
    required this.chassisBg,
    required this.meterBgDark,
    required this.meterBgMid,
    required this.meterBgBottom,
    required this.glowCore,
    required this.glowOuter,
    required this.topGlow,
    required this.bezelOuter,
    required this.bezelInner,
    required this.arcWattsColor,
    required this.arcDbColor,
    required this.tickSafe,
    required this.tickTextSafe,
    required this.overloadRed,
    required this.needleColor,
    required this.needleShadow,
    required this.pivotBase,
    required this.pivotRing,
    required this.footerBadge,
    required this.pgLedGreen,
    required this.subLabel,
    required this.footerLeft,
    required this.footerRight,
  });
}

/// 经典名机动态双动圈大表头 - 高保真物理拟真版 (支持麦景图湖蓝、金嗓子香槟金、复古琥珀、马兰士翡翠等8大名机及自定义色全量动态映射)
/// 具备：双重对数刻度 (瓦数 + 分贝)、动圈红针动态视差投影、玻璃反光、角隅六角螺栓、双白炽灯漫射背光与透镜高光
class McIntoshMeterPainter extends CustomPainter {
  final double leftAngle;   // 已经过物理阻尼滤波的弧度
  final double rightAngle;  // 已经过物理阻尼滤波的弧度
  final String? title;
  final int themeId;
  final Color? accentColor;
  final HifiPlatformType? platform;

  static const double minAngle = -pi * 0.74;
  static const double sweepAngle = pi * 0.48;

  McIntoshMeterPainter({
    required this.leftAngle,
    required this.rightAngle,
    this.title,
    this.themeId = 1,
    this.accentColor,
    this.platform,
  });

  static _MeterPalette _resolvePalette(int themeId, Color? customCol, [HifiPlatformType? platform]) {
    if (themeId == 4 || (customCol != null && themeId != 0 && themeId != 1 && themeId != 2 && themeId != 3 && themeId != 5 && themeId != 6 && themeId != 7 && themeId != 8)) {
      final col = customCol ?? const Color(0xFF00B4D8);
      final rf = col.r;
      final gf = col.g;
      final bf = col.b;

      final chassisR = (rf * 14.0 + 3.0).round().clamp(0, 255);
      final chassisG = (gf * 14.0 + 3.0).round().clamp(0, 255);
      final chassisB = (bf * 14.0 + 4.0).round().clamp(0, 255);

      final bgR = (rf * 28.0 + 4.0).round().clamp(0, 255);
      final bgG = (gf * 28.0 + 4.0).round().clamp(0, 255);
      final bgB = (bf * 28.0 + 6.0).round().clamp(0, 255);

      final coreR = (rf * 160.0 + 95.0).round().clamp(0, 255);
      final coreG = (gf * 160.0 + 95.0).round().clamp(0, 255);
      final coreB = (bf * 160.0 + 95.0).round().clamp(0, 255);

      final arcR = (rf * 180.0 + 75.0).round().clamp(0, 255);
      final arcG = (gf * 180.0 + 75.0).round().clamp(0, 255);
      final arcB = (bf * 180.0 + 75.0).round().clamp(0, 255);

      return _MeterPalette(
        chassisBg: Color.fromARGB(255, chassisR, chassisG, chassisB),
        meterBgDark: Color.fromARGB(255, bgR, bgG, bgB),
        meterBgMid: Color.fromARGB(255, (bgR * 1.8).round().clamp(0, 255), (bgG * 1.8).round().clamp(0, 255), (bgB * 1.8).round().clamp(0, 255)),
        meterBgBottom: Color.fromARGB(255, (bgR * 2.6).round().clamp(0, 255), (bgG * 2.6).round().clamp(0, 255), (bgB * 2.6).round().clamp(0, 255)),
        glowCore: Color.fromARGB(180, coreR, coreG, coreB),
        glowOuter: col.withValues(alpha: 0.35),
        topGlow: col.withValues(alpha: 0.22),
        bezelOuter: Color.fromARGB(255, (chassisR * 2.5).round().clamp(0, 255), (chassisG * 2.5).round().clamp(0, 255), (chassisB * 2.5).round().clamp(0, 255)),
        bezelInner: const Color(0xFF0B121C),
        arcWattsColor: Color.fromARGB(220, arcR, arcG, arcB),
        arcDbColor: Color.fromARGB(200, (arcR * 0.9).round(), (arcG * 0.9).round(), (arcB * 0.9).round()),
        tickSafe: Color.fromARGB(235, min(255, arcR + 20), min(255, arcG + 20), min(255, arcB + 20)),
        tickTextSafe: Color.fromARGB(220, arcR, arcG, arcB),
        overloadRed: const Color(0xFFEF4444),
        needleColor: const Color(0xFFFF2B1D),
        needleShadow: Color.fromARGB(128, bgR, bgG, bgB),
        pivotBase: const Color(0xFF161E28),
        pivotRing: col.withValues(alpha: 0.75),
        footerBadge: col.withValues(alpha: 0.85),
        pgLedGreen: col,
        subLabel: 'DECIBELS / WATTS',
        footerLeft: 'Audiophile Custom Precision Power Output Meter · Bit-Perfect Direct Drive',
        footerRight: 'VELVET SOUND ULTRA · FEMTOSECOND CLOCK',
      );
    }

    switch (themeId) {
      case 2: // Accuphase 金嗓子香槟金
        return const _MeterPalette(
          chassisBg: Color(0xFF0E0B08),
          meterBgDark: Color(0xFF20190E),
          meterBgMid: Color(0xFF382B18),
          meterBgBottom: Color(0xFF523E1E),
          glowCore: Color(0xC0FFDC6E),
          glowOuter: Color(0x55D9A028),
          topGlow: Color(0x35EAB308),
          bezelOuter: Color(0xFF483A28),
          bezelInner: Color(0xFF181511),
          arcWattsColor: Color(0xFFFEF3C7),
          arcDbColor: Color(0xCCFDE68A),
          tickSafe: Color(0xF0FDE68A),
          tickTextSafe: Color(0xEEFEF0B4),
          overloadRed: Color(0xFFF97316),
          needleColor: Color(0xFFF53C23),
          needleShadow: Color(0x8020190E),
          pivotBase: Color(0xFF282014),
          pivotRing: Color(0xFFD2B478),
          footerBadge: Color(0xC8EAB308),
          pgLedGreen: Color(0xFF00EB96),
          subLabel: 'DECIBELS / PEAK WATTS',
          footerLeft: 'Accuphase Laboratory, Inc. · 40th Anniversary Dual Balanced',
          footerRight: 'VELVET SOUND ULTRA · FEMTOSECOND CLOCK',
        );
      case 3: // RetroTape 复古琥珀卡座
        return const _MeterPalette(
          chassisBg: Color(0xFF0E0906),
          meterBgDark: Color(0xFF1C1009),
          meterBgMid: Color(0xFF341E10),
          meterBgBottom: Color(0xFF4E2C16),
          glowCore: Color(0xC0FFB446),
          glowOuter: Color(0x50F97316),
          topGlow: Color(0x35F97316),
          bezelOuter: Color(0xFF422818),
          bezelInner: Color(0xFF1A0E08),
          arcWattsColor: Color(0xFFFED7AA),
          arcDbColor: Color(0xCCFDBA74),
          tickSafe: Color(0xF0FDBA74),
          tickTextSafe: Color(0xEEFED7AA),
          overloadRed: Color(0xFFEF4444),
          needleColor: Color(0xFFFF453A),
          needleShadow: Color(0x801C1009),
          pivotBase: Color(0xFF23160F),
          pivotRing: Color(0xFFB4825A),
          footerBadge: Color(0xC8F97316),
          pgLedGreen: Color(0xFFF59E0B),
          subLabel: 'NAB / IEC EQUALIZATION',
          footerLeft: 'Studer Revox Master Tape · Pure Analog Direct Calibration',
          footerRight: '15 IPS 2-TRACK MASTER · 0VU = +4dBu',
        );
      case 0: // ModernCrimson 现代深空玫红
        return const _MeterPalette(
          chassisBg: Color(0xFF0C060A),
          meterBgDark: Color(0xFF16080E),
          meterBgMid: Color(0xFF2E0F1D),
          meterBgBottom: Color(0xFF48142C),
          glowCore: Color(0xB8FF6482),
          glowOuter: Color(0x45FA2D48),
          topGlow: Color(0x35FA2D48),
          bezelOuter: Color(0xFF3D202A),
          bezelInner: Color(0xFF160A10),
          arcWattsColor: Color(0xFFFFDCE6),
          arcDbColor: Color(0xCCFECDD3),
          tickSafe: Color(0xF0FECDD3),
          tickTextSafe: Color(0xEEFFDCE6),
          overloadRed: Color(0xFFFFD700),
          needleColor: Color(0xFFFF2D55),
          needleShadow: Color(0x8016080E),
          pivotBase: Color(0xFF1E1016),
          pivotRing: Color(0xFFB48296),
          footerBadge: Color(0xC8FA2D48),
          pgLedGreen: Color(0xFFFF3366),
          subLabel: 'LUFS / TRUE PEAK AUDIO',
          footerLeft: 'Studio Reference Monitor · Bit-Perfect 384kHz 32-Bit Float',
          footerRight: 'APPLE LOSSLESS AUDIO · ULTRA HI-RES',
        );
      case 5: // Marantz 经典马兰士
        return const _MeterPalette(
          chassisBg: Color(0xFF030E0A),
          meterBgDark: Color(0xFF041812),
          meterBgMid: Color(0xFF0A2E22),
          meterBgBottom: Color(0xFF0F4231),
          glowCore: Color(0xB834D399),
          glowOuter: Color(0x5010B981),
          topGlow: Color(0x3510B981),
          bezelOuter: Color(0xFF1C3A2C),
          bezelInner: Color(0xFF0A1C14),
          arcWattsColor: Color(0xFFA7F3D0),
          arcDbColor: Color(0xCCD1FAE5),
          tickSafe: Color(0xF0D1FAE5),
          tickTextSafe: Color(0xEEA7F3D0),
          overloadRed: Color(0xFFEF4444),
          needleColor: Color(0xFFFF3B30),
          needleShadow: Color(0x80041812),
          pivotBase: Color(0xFF14241C),
          pivotRing: Color(0xFF6EE7B7),
          footerBadge: Color(0xB410B981),
          pgLedGreen: Color(0xFF10B981),
          subLabel: 'SA-CD / DSD DIRECT STREAM',
          footerLeft: 'Marantz Reference Porthole · Pure Class-A Discrete HDAM-SA3',
          footerRight: 'MUSICAL MASTERING · ZERO NEGATIVE FEEDBACK',
        );
      case 6: // Burmester 柏林之声冷银
        return const _MeterPalette(
          chassisBg: Color(0xFF080B10),
          meterBgDark: Color(0xFF101620),
          meterBgMid: Color(0xFF1E2838),
          meterBgBottom: Color(0xFF2C3A50),
          glowCore: Color(0xB8F1F5F9),
          glowOuter: Color(0x4594A3B8),
          topGlow: Color(0x30CBD5E1),
          bezelOuter: Color(0xFF334155),
          bezelInner: Color(0xFF0F172A),
          arcWattsColor: Color(0xFFF1F5F9),
          arcDbColor: Color(0xCCE2E8F0),
          tickSafe: Color(0xF0E2E8F0),
          tickTextSafe: Color(0xEEF1F5F9),
          overloadRed: Color(0xFFEF4444),
          needleColor: Color(0xFFFF453A),
          needleShadow: Color(0x80101620),
          pivotBase: Color(0xFF1E293B),
          pivotRing: Color(0xFFE2E8F0),
          footerBadge: Color(0xB4CBD5E1),
          pgLedGreen: Color(0xFF38BDF8),
          subLabel: 'PRECISION POWER / BALANCED',
          footerLeft: 'Burmester Audiosysteme Berlin · Reference Line Direct Drive',
          footerRight: 'CHROME PRECISION · DUAL-MONO X-AMP',
        );
      case 7: // NaimAudio 英国名暗夜翠
        return const _MeterPalette(
          chassisBg: Color(0xFF070C08),
          meterBgDark: Color(0xFF0C160E),
          meterBgMid: Color(0xFF162B1A),
          meterBgBottom: Color(0xFF1E3D24),
          glowCore: Color(0xB84ADE80),
          glowOuter: Color(0x5022C55E),
          topGlow: Color(0x3522C55E),
          bezelOuter: Color(0xFF1E3824),
          bezelInner: Color(0xFF0B1A0E),
          arcWattsColor: Color(0xFFBBF7D0),
          arcDbColor: Color(0xCCD1FAE5),
          tickSafe: Color(0xF0DCFCE7),
          tickTextSafe: Color(0xEEBBF7D0),
          overloadRed: Color(0xFFEF4444),
          needleColor: Color(0xFFFF3B30),
          needleShadow: Color(0x800C160E),
          pivotBase: Color(0xFF16241A),
          pivotRing: Color(0xFF4ADE80),
          footerBadge: Color(0xB422C55E),
          pgLedGreen: Color(0xFF22C55E),
          subLabel: 'PACE, RHYTHM & TIMING (PRaT)',
          footerLeft: 'Naim Audio Salisbury · Discrete Regulated Power Supply (DR)',
          footerRight: 'STATEMENT TOPOLOGY · ULTRA-LOW NOISE FLOOR',
        );
      case 8: // MarkLevinson 马克莱文森赤晶
        return const _MeterPalette(
          chassisBg: Color(0xFF0E0608),
          meterBgDark: Color(0xFF1A0A0E),
          meterBgMid: Color(0xFF32121A),
          meterBgBottom: Color(0xFF4D1A27),
          glowCore: Color(0xB8F87171),
          glowOuter: Color(0x50EF4444),
          topGlow: Color(0x35EF4444),
          bezelOuter: Color(0xFF3A1C22),
          bezelInner: Color(0xFF160A0D),
          arcWattsColor: Color(0xFFFECACA),
          arcDbColor: Color(0xCCFEE2E2),
          tickSafe: Color(0xF0FEE2E2),
          tickTextSafe: Color(0xEEFECACA),
          overloadRed: Color(0xFFFFD700),
          needleColor: Color(0xFFFF3B30),
          needleShadow: Color(0x801A0A0E),
          pivotBase: Color(0xFF241216),
          pivotRing: Color(0xFFF87171),
          footerBadge: Color(0xB4EF4444),
          pgLedGreen: Color(0xFFEF4444),
          subLabel: 'PURE PATH DUAL-MONAURAL',
          footerLeft: 'Mark Levinson Reference · Pure Path Direct-Coupled Architecture',
          footerRight: 'PRECISION LINK DAC · 32-BIT ESS PRO CALIBRATED',
        );
      case 1: // McIntosh 麦景图湖蓝
      default:
        final currentPlat = platform ?? PlatformHelper.currentPlatform;
        final isIpad = currentPlat == HifiPlatformType.ipad || (PlatformHelper.overridePlatform == null && Platform.isIOS);
        final isMac = currentPlat == HifiPlatformType.mac || (PlatformHelper.overridePlatform == null && Platform.isMacOS);
        return _MeterPalette(
          chassisBg: const Color(0xFF030712),
          meterBgDark: const Color(0xFF010E20),
          meterBgMid: const Color(0xFF021B38),
          meterBgBottom: const Color(0xFF03264C),
          glowCore: const Color(0xB800C4EF),
          glowOuter: const Color(0x400077B6),
          topGlow: const Color(0x3500B4D8),
          bezelOuter: const Color(0xFF253040),
          bezelInner: const Color(0xFF0B121C),
          arcWattsColor: const Color(0xFFBAE6FD),
          arcDbColor: const Color(0xCC7DD3FC),
          tickSafe: const Color(0xF0E0F2FE),
          tickTextSafe: const Color(0xEEBAE6FD),
          overloadRed: const Color(0xFFFF2519),
          needleColor: const Color(0xFFFF2B1D),
          needleShadow: const Color(0x80010E20),
          pivotBase: const Color(0xFF161E28),
          pivotRing: const Color(0xFF94A3B8),
          footerBadge: const Color(0xB438BDF8),
          pgLedGreen: const Color(0xFF00F5D4),
          subLabel: 'DECIBELS / WATTS',
          footerLeft: isIpad
              ? 'McIntosh Precision Power Output Meter · Apple Silicon AOP Direct'
              : (isMac
                  ? 'McIntosh Precision Power Output Meter · Bit-Perfect CoreAudio Engine'
                  : 'McIntosh Precision Power Output Meter · ${DacSettingService.instance.sampleRateMode > 0 ? "Forced ${(DacSettingService.instance.effectiveOutputSampleRate / 1000).round()}kHz" : "Bit-Perfect ${(HifiAudioService.instance.currentTrack?.sampleRate ?? 192000) ~/ 1000}kHz"}/24Bit ALSA'),
          footerRight: isIpad
              ? 'APPLE SILICON AOP · STUDIO GRADE MASTER CLOCK'
              : (isMac
                  ? 'APPLE STUDIO GRADE DIRECT BUS · FEMTOSECOND MASTER CLOCK'
                  : '${DacSettingService.instance.dacName.toUpperCase()} · HIGH PRECISION MASTER CLOCK'),
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pal = _resolvePalette(themeId, accentColor, platform);

    // 1. 底板：微拉丝质感深空机架底色
    final bgPaint = Paint()..color = pal.chassisBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 细致拉丝光栅横向微纹理
    final brushPaint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 1.0;
    for (double y = 4; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), brushPaint);
    }

    // 2. 发烧级横屏黄金比例排版 (左右双大表头)
    const paddingX = 16.0;
    const paddingY = 14.0;
    const footerH = 28.0;

    final availableW = size.width - paddingX * 3;
    final availableH = size.height - paddingY * 2 - footerH;
    if (availableW <= 100 || availableH <= 100) return;

    final rawMeterW = availableW * 0.5;
    final idealMeterH = rawMeterW * 0.76;
    final meterH = min(availableH, idealMeterH);
    final meterW = rawMeterW;

    final offsetY = paddingY + (availableH - meterH) * 0.5;

    final leftRect = Rect.fromLTWH(paddingX, offsetY, meterW, meterH);
    final rightRect = Rect.fromLTWH(paddingX * 2 + meterW, offsetY, meterW, meterH);

    _drawSingleMeter(canvas, leftRect, leftAngle, 'LEFT CHANNEL', pal);
    _drawSingleMeter(canvas, rightRect, rightAngle, 'RIGHT CHANNEL', pal);

    // 3. 底部发烧铭牌
    _drawFooter(canvas, size, paddingX, pal);
  }

  void _drawSingleMeter(Canvas canvas, Rect rect, double angle, String channelLabel, _MeterPalette pal) {
    // 1. 外层金属机械压铸外框与内凹倒角阴影
    _drawMetalBezel(canvas, rect, pal);

    // 2. 表盘内部区域 (开启圆角裁剪)
    final dialRect = rect.deflate(6.0);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(dialRect, const Radius.circular(10)));

    // 表盘透光导光底板 (双灯泡多重径向与线性混合光效)
    _drawDialLighting(canvas, dialRect, pal);

    // 计算表头几何圆心与半径 (黄金比例定位，表针枢轴居中靠下)
    final radius = min(dialRect.width * 0.60, dialRect.height * 0.88);
    final center = Offset(dialRect.center.dx, dialRect.bottom - dialRect.height * 0.04);

    // 绘制双重对数分度刻度 (上方 WATTS 瓦数标度 + 下方 DECIBELS 分贝标度)
    _drawScales(canvas, center, radius, pal);

    // 声道标牌与经典指示灯
    _drawLabelsAndLeds(canvas, dialRect, center, radius, channelLabel, pal);

    // 绘制物理动圈红针 (包含真实 3D 投射阴影、背部黄铜平衡尾柄与机械枢轴)
    _drawRealisticNeedle(canvas, center, radius, angle, pal);

    // 玻璃表镜弧形高光反射 (拟真光学镀膜反光)
    _drawGlassReflections(canvas, dialRect);

    canvas.restore();

    // 3. 四角防震精密六角螺丝 (Skeuomorphic Hex Screws)
    _drawCornerScrews(canvas, rect);
  }

  void _drawMetalBezel(Canvas canvas, Rect rect, _MeterPalette pal) {
    // 外层金属压铸框
    final outerBezelRRect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    final outerBezelPaint = Paint()
      ..color = pal.bezelOuter
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawRRect(outerBezelRRect, outerBezelPaint);

    // 外框高光边缘
    final highlightBezel = Paint()
      ..color = const Color(0x30FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(outerBezelRRect, highlightBezel);

    // 内凹阴影线
    final innerShadowRect = rect.deflate(4.0);
    final innerShadowPaint = Paint()
      ..color = pal.bezelInner
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(RRect.fromRectAndRadius(innerShadowRect, const Radius.circular(11)), innerShadowPaint);
  }

  void _drawDialLighting(Canvas canvas, Rect dialRect, _MeterPalette pal) {
    // 纯黑深邃背景
    canvas.drawRect(dialRect, Paint()..color = pal.meterBgDark);

    // 底部弧面向上渐变
    final baseGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [pal.meterBgDark, pal.meterBgMid, pal.meterBgBottom],
      stops: const [0.0, 0.65, 1.0],
    );
    canvas.drawRect(dialRect, Paint()..shader = baseGradient.createShader(dialRect));

    // 底部双白炽灯泡散射 (位于左右两侧底部)
    final lampY = dialRect.bottom - dialRect.height * 0.12;
    final leftLamp = Offset(dialRect.center.dx - dialRect.width * 0.26, lampY);
    final rightLamp = Offset(dialRect.center.dx + dialRect.width * 0.26, lampY);
    final lampRadius = dialRect.width * 0.65;

    final lampShaderL = RadialGradient(
      colors: [pal.glowCore, pal.glowOuter, Colors.transparent],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: leftLamp, radius: lampRadius));

    final lampShaderR = RadialGradient(
      colors: [pal.glowCore, pal.glowOuter, Colors.transparent],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: rightLamp, radius: lampRadius));

    final lampPaint = Paint()..blendMode = BlendMode.screen;
    canvas.drawCircle(leftLamp, lampRadius, lampPaint..shader = lampShaderL);
    canvas.drawCircle(rightLamp, lampRadius, lampPaint..shader = lampShaderR);

    // 顶部水平光晕漫射带 (透光扩散板顶部微亮)
    final topGlow = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [pal.topGlow, Colors.transparent],
    );
    canvas.drawRect(
      Rect.fromLTWH(dialRect.left, dialRect.top, dialRect.width, dialRect.height * 0.28),
      Paint()..shader = topGlow.createShader(dialRect),
    );
  }

  void _drawScales(Canvas canvas, Offset center, double radius, _MeterPalette pal) {
    final wattsRadius = radius;
    final dbRadius = radius - 16.0;

    // 1. 上层 WATTS 瓦数主弧线
    final arcWattsPaint = Paint()
      ..color = pal.arcWattsColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: wattsRadius),
      minAngle,
      sweepAngle,
      false,
      arcWattsPaint,
    );

    // 2. 下层 DECIBELS 分贝主弧线
    final arcDbPaint = Paint()
      ..color = pal.arcDbColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: dbRadius),
      minAngle,
      sweepAngle,
      false,
      arcDbPaint,
    );

    // 3. 经典 WATTS 标度 (8 档对数: .001, .01, .1, 1.0, 10, 100, 200, 400)
    final wattsMarks = [
      (0.00, '.001'),
      (0.14, '.01'),
      (0.28, '.1'),
      (0.42, '1.0'),
      (0.56, '10'),
      (0.72, '100'),
      (0.86, '200'),
      (1.00, '400'),
    ];

    for (final wm in wattsMarks) {
      final t = wm.$1;
      final label = wm.$2;
      final a = minAngle + sweepAngle * t;
      final isOverload = t >= 0.72; // >= 100W 过载警戒

      final pOuter = Offset(center.dx + cos(a) * (wattsRadius + 1.0), center.dy + sin(a) * (wattsRadius + 1.0));
      final pInner = Offset(center.dx + cos(a) * (wattsRadius - 10.0), center.dy + sin(a) * (wattsRadius - 10.0));

      final tickPaint = Paint()
        ..color = isOverload ? pal.overloadRed : pal.tickSafe
        ..strokeWidth = isOverload ? 2.4 : 1.8;
      canvas.drawLine(pInner, pOuter, tickPaint);

      // WATTS 数值文字
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isOverload ? pal.overloadRed : pal.tickTextSafe,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textPos = Offset(
        center.dx + cos(a) * (wattsRadius + 11.0) - tp.width * 0.5,
        center.dy + sin(a) * (wattsRadius + 11.0) - tp.height * 0.5,
      );
      tp.paint(canvas, textPos);
    }

    // 4. 经典 DECIBELS 标度 (-50 到 +3 dB)
    final dbMarks = [
      (0.00, '-50', false),
      (0.14, '-40', false),
      (0.28, '-30', false),
      (0.42, '-20', false),
      (0.56, '-10', true),
      (0.64, '-7', false),
      (0.72, '-4', true),
      (0.80, '-2', false),
      (0.86, '0', true),
      (0.93, '+1', false),
      (0.97, '+2', false),
      (1.00, '+3', true),
    ];

    for (final dm in dbMarks) {
      final t = dm.$1;
      final label = dm.$2;
      final isMajor = dm.$3;
      final a = minAngle + sweepAngle * t;
      final isRed = t >= 0.86; // >= 0dB 红色过载区

      final tickLen = isMajor ? 9.0 : 5.5;
      final pOuter = Offset(center.dx + cos(a) * dbRadius, center.dy + sin(a) * dbRadius);
      final pInner = Offset(center.dx + cos(a) * (dbRadius - tickLen), center.dy + sin(a) * (dbRadius - tickLen));

      final tickPaint = Paint()
        ..color = isRed ? pal.overloadRed : pal.tickSafe.withValues(alpha: 0.85)
        ..strokeWidth = isRed ? 2.0 : (isMajor ? 1.5 : 1.0);
      canvas.drawLine(pInner, pOuter, tickPaint);

      if (isMajor || t <= 0.42) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: isRed ? pal.overloadRed : pal.tickTextSafe.withValues(alpha: 0.90),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final textPos = Offset(
          center.dx + cos(a) * (dbRadius - 19.0) - tp.width * 0.5,
          center.dy + sin(a) * (dbRadius - 19.0) - tp.height * 0.5,
        );
        tp.paint(canvas, textPos);
      }
    }

    // 5. 0dB 到 +3dB 红色安全警示条带
    final redArcPaint = Paint()
      ..color = pal.overloadRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    const redStartAngle = minAngle + sweepAngle * 0.86;
    const redSweep = sweepAngle * 0.14;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: wattsRadius),
      redStartAngle,
      redSweep,
      false,
      redArcPaint,
    );
  }

  void _drawLabelsAndLeds(Canvas canvas, Rect rect, Offset center, double radius, String channelLabel, _MeterPalette pal) {
    // 1. 声道标牌
    final titleTp = TextPainter(
      text: TextSpan(
        text: channelLabel,
        style: TextStyle(
          color: pal.arcWattsColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(canvas, Offset(rect.center.dx - titleTp.width * 0.5, rect.top + 16.0));

    // 2. POWER GUARD 微光宝石指示灯 (左右各一颗)
    final ledY = rect.top + 16.0 + titleTp.height * 0.5;
    final leftLedX = rect.center.dx - titleTp.width * 0.5 - 20.0;
    final rightLedX = rect.center.dx + titleTp.width * 0.5 + 20.0;

    _drawJewelLed(canvas, Offset(leftLedX, ledY), pal.pgLedGreen);
    _drawJewelLed(canvas, Offset(rightLedX, ledY), pal.pgLedGreen);

    // 3. 中心 UNITS 单位标示 (WATTS + DECIBELS)
    final wattsTp = TextPainter(
      text: TextSpan(
        text: 'WATTS',
        style: TextStyle(
          color: pal.arcWattsColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    wattsTp.paint(canvas, Offset(rect.center.dx - wattsTp.width * 0.5, center.dy - radius * 0.44));

    final decibelsTp = TextPainter(
      text: TextSpan(
        text: 'DECIBELS',
        style: TextStyle(
          color: pal.arcDbColor,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    decibelsTp.paint(canvas, Offset(rect.center.dx - decibelsTp.width * 0.5, center.dy - radius * 0.33));
  }

  void _drawJewelLed(Canvas canvas, Offset pos, Color color) {
    // 金属卡座圈
    canvas.drawCircle(pos, 5.0, Paint()..color = const Color(0xFF1E2836));
    canvas.drawCircle(pos, 5.0, Paint()..color = const Color(0xFF8FA3B8)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // 弥散辉光
    canvas.drawCircle(pos, 7.0, Paint()..color = color.withValues(alpha: 0.30));
    // 宝石本体
    canvas.drawCircle(pos, 3.2, Paint()..color = color);
    // 高光反光点
    canvas.drawCircle(pos + const Offset(-0.8, -0.8), 1.2, Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  void _drawRealisticNeedle(Canvas canvas, Offset center, double radius, double angle, _MeterPalette pal) {
    final needleLength = radius + 2.0;
    final needleTip = Offset(center.dx + cos(angle) * needleLength, center.dy + sin(angle) * needleLength);

    // 1. 动圈红针在底层表盘上的物理投射阴影 (立体视差神髓：阴影向右下偏移 4px，随角度动态变化)
    final shadowTip = Offset(
      center.dx + cos(angle - 0.035) * (needleLength - 2.0) + 3.5,
      center.dy + sin(angle - 0.035) * (needleLength - 2.0) + 5.0,
    );
    final shadowPaint = Paint()
      ..color = pal.needleShadow.withValues(alpha: 0.35)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center + const Offset(2.0, 3.0), shadowTip, shadowPaint);

    // 2. 指针后部黄铜平衡配重柄 (Counterweight spade, 延伸至轴心后方 16px)
    final tailAngle = angle + pi;
    final tailTip = Offset(center.dx + cos(tailAngle) * 16.0, center.dy + sin(tailAngle) * 16.0);
    final tailPaint = Paint()
      ..color = const Color(0xFFC5A059) // 机械黄铜
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tailTip, tailPaint);

    // 3. 动圈实体指针本体 (微发光 + 纤细钢针)
    final glowPaint = Paint()
      ..color = pal.needleColor.withValues(alpha: 0.32)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, glowPaint);

    final needlePaint = Paint()
      ..color = pal.needleColor
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, needlePaint);

    // 指针中央金属高光刃线 (消除扁平感)
    final tipShinPaint = Paint()
      ..color = const Color(0x60FFFFFF)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleTip, tipShinPaint);

    // 4. 三层同心机械轴盖 (Machined Hub with Chrome Bevel)
    // 底层石墨固定盘
    canvas.drawCircle(center, 13.0, Paint()..color = pal.pivotBase);
    // 中层阳极氧化铝倒角外圈
    final ringPaint = Paint()
      ..color = pal.pivotRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 13.0, ringPaint);

    // 顶层镀铬紧固轴心
    const chromeGrad = RadialGradient(
      center: Alignment(-0.3, -0.3),
      colors: [Color(0xFFE2E8F0), Color(0xFF64748B), Color(0xFF1E293B)],
      stops: [0.0, 0.6, 1.0],
    );
    canvas.drawCircle(center, 7.5, Paint()..shader = chromeGrad.createShader(Rect.fromCircle(center: center, radius: 7.5)));

    // 轴心螺丝微十字槽
    final slotPaint = Paint()..color = const Color(0xFF0F172A)..strokeWidth = 1.0;
    canvas.drawLine(center - const Offset(3, 0), center + const Offset(3, 0), slotPaint);
  }

  void _drawGlassReflections(Canvas canvas, Rect rect) {
    // 拟真光学级镀膜弧面反射 (模拟斜向环境白光折射)
    final glassPath = Path();
    glassPath.moveTo(rect.left, rect.top);
    glassPath.lineTo(rect.right, rect.top);
    glassPath.lineTo(rect.right, rect.top + rect.height * 0.22);
    glassPath.quadraticBezierTo(
      rect.center.dx,
      rect.top + rect.height * 0.45,
      rect.left,
      rect.top + rect.height * 0.15,
    );
    glassPath.close();

    final glareShader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Colors.white.withValues(alpha: 0.10),
        Colors.white.withValues(alpha: 0.02),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(rect);

    canvas.drawPath(glassPath, Paint()..shader = glareShader);
  }

  void _drawCornerScrews(Canvas canvas, Rect rect) {
    // 四角镀铬六角螺丝
    const offset = 8.5;
    final corners = [
      rect.topLeft + const Offset(offset, offset),
      rect.topRight + const Offset(-offset, offset),
      rect.bottomLeft + const Offset(offset, -offset),
      rect.bottomRight + const Offset(-offset, -offset),
    ];

    for (final c in corners) {
      // 螺丝垫圈
      canvas.drawCircle(c, 3.8, Paint()..color = const Color(0xFF1E2836));
      canvas.drawCircle(c, 3.8, Paint()..color = const Color(0xFF64748B)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      // 螺丝头部高光
      canvas.drawCircle(c, 2.5, Paint()..color = const Color(0xFF94A3B8));
      // 六角孔内凹暗色
      canvas.drawCircle(c, 1.2, Paint()..color = const Color(0xFF0F172A));
    }
  }

  void _drawFooter(Canvas canvas, Size size, double paddingX, _MeterPalette pal) {
    final leftText = title ?? pal.footerLeft;
    final rightText = pal.footerRight;

    final leftTp = TextPainter(
      text: TextSpan(
        text: leftText,
        style: TextStyle(
          color: pal.footerBadge,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rightTp = TextPainter(
      text: TextSpan(
        text: rightText,
        style: TextStyle(
          color: pal.footerBadge,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final available = size.width - paddingX * 2;
    if (leftTp.width + rightTp.width + 24.0 <= available) {
      leftTp.paint(canvas, Offset(paddingX + 4.0, size.height - 20.0));
      rightTp.paint(canvas, Offset(size.width - rightTp.width - paddingX - 4.0, size.height - 20.0));
    } else {
      leftTp.paint(canvas, Offset(paddingX + 4.0, size.height - 20.0));
    }
  }

  @override
  bool shouldRepaint(covariant McIntoshMeterPainter oldDelegate) {
    return oldDelegate.leftAngle != leftAngle ||
        oldDelegate.rightAngle != rightAngle ||
        oldDelegate.title != title ||
        oldDelegate.themeId != themeId ||
        oldDelegate.accentColor != accentColor;
  }
}
