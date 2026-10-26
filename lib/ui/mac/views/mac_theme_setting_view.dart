import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/platform_helper.dart';
import '../../../services/theme_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';
import '../../common/module_scroll_view.dart';
import '../../visualizers/visualizer_type.dart';

/// 主题与背景动效设置视图 (1:1 严格对齐 C++ ThemeSettingView.cpp)
class MacThemeSettingView extends StatefulWidget {
  final VisualizerType currentVisualizer;
  final ValueChanged<VisualizerType> onVisualizerChanged;

  const MacThemeSettingView({
    super.key,
    required this.currentVisualizer,
    required this.onVisualizerChanged,
  });

  @override
  State<MacThemeSettingView> createState() => _MacThemeSettingViewState();
}

class _MacThemeSettingViewState extends State<MacThemeSettingView> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final theme = ThemeService.instance;
        final accent = theme.accentColor;

        return GlassCard(
          borderRadius: UIConfig.containerRounding,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: ModuleScrollView(
            storageId: 'theme-module-scroll',
            header: [
              // 1. 顶部 Header 栏：主标题「主题」，右侧「恢复名机预设」按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '主题',
                    style: TextStyle(
                      fontSize: UIConfig.fontMedium,
                      fontWeight: FontWeight.bold,
                      color: UIConfig.textActive,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      theme.resetToDefault();
                      widget.onVisualizerChanged(VisualizerType.ledSpectrum);
                    },
                    child: Container(
                      height: 28.0,
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(40, 48, 64, 0.7),
                        borderRadius: BorderRadius.circular(7.0),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.12),
                        ),
                      ),
                      child: const Text(
                        '恢复名机预设',
                        style: TextStyle(
                          fontSize: UIConfig.fontSmall,
                          color: UIConfig.textNormal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14.0),
            ],
            children: [
              // 板块一：预设 (8款名机经典主题)
              _buildSectionContainer(
                title: '预设',
                child: _buildPresetsGrid(theme),
              ),
              const SizedBox(height: 12.0),

              // 板块二：背景律动 (11款律动模式)
              _buildSectionContainer(
                title: '背景律动',
                child: _buildVisualizerModesGrid(theme),
              ),
              const SizedBox(height: 12.0),

              // 板块三：自由调色 (macOS HSV 色轮与调色台)
              _buildSectionContainer(
                title: '自由调色',
                headerTrailing: _buildHexPill(accent),
                child: _buildColorWheelSection(theme),
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        );
      },
    );
  }

  static const List<IconData> _visualModeIcons = [
    Icons.equalizer_rounded, // 48列全景 LED 频谱
    Icons.speed_rounded, // 名机动圈大表头
    Icons.speed_outlined, // 金嗓子旗舰大表头
    Icons.album_rounded, // 复古开盘磁带机
    Icons.waves_rounded, // Siri 流光声波
    Icons.lens_blur_rounded, // Siri 悬浮微光球
    Icons.bubble_chart_rounded, // 音乐微光气泡
    Icons.nightlight_round, // 极简纯黑纯音直通
    Icons.graphic_eq_rounded, // 电光霓虹声波
    Icons.grid_4x4_rounded, // 赛博粒子网格
    Icons.access_time_filled_rounded, // 液态玻璃时钟
    Icons.memory_rounded, // 实时硬件遥测
  ];

  /// 毛玻璃板块卡片容器
  Widget _buildSectionContainer({
    required String title,
    Widget? headerTrailing,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF19202E),
            Color(0xFF111622),
          ],
        ),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: UIConfig.fontRegular,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: UIConfig.textActive,
                ),
              ),
              if (headerTrailing != null) headerTrailing,
            ],
          ),
          const SizedBox(height: 14.0),
          child,
        ],
      ),
    );
  }

  /// 预设卡片网格 (2列)
  Widget _buildPresetsGrid(ThemeService theme) {
    return LayoutBuilder(builder: (context, constraints) {
      final activePlatform =
          PlatformHelper.overridePlatform ?? PlatformHelper.currentPlatform;
      final compact = (activePlatform == HifiPlatformType.iphone ||
              activePlatform == HifiPlatformType.android) &&
          MediaQuery.orientationOf(context) == Orientation.landscape;
      final cols = compact ? 2 : (constraints.maxWidth < 560 ? 1 : 2);
      return GridView.builder(
        key: const ValueKey('theme-presets-grid'),
        primary: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10.0,
          crossAxisSpacing: compact ? 10.0 : 14.0,
          mainAxisExtent: 56.0,
        ),
        itemCount: ThemeService.presets.length,
        itemBuilder: (context, i) {
          final p = ThemeService.presets[i];
          final isCur = theme.currentThemeId == p.id;
          final name = Text(
            p.name,
            maxLines: compact ? 1 : null,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 13.0 : UIConfig.fontRegular,
              fontWeight: isCur ? FontWeight.w600 : FontWeight.normal,
              color: isCur
                  ? UIConfig.textActive
                  : const Color.fromRGBO(220, 230, 245, 0.9),
            ),
          );

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              theme.setTheme(p.id);
              widget.onVisualizerChanged(
                VisualizerType.values[p.defaultVisualMode
                    .clamp(0, VisualizerType.values.length - 1)],
              );
            },
            child: AnimatedContainer(
              key: ValueKey('theme-preset-${p.id}'),
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: compact ? 10.0 : 14.0),
              decoration: BoxDecoration(
                gradient: isCur
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          p.accentColor.withValues(alpha: 0.22),
                          p.accentColor.withValues(alpha: 0.08),
                          const Color(0xFF131824),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF222B3D),
                          Color(0xFF161C28),
                        ],
                      ),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: isCur
                      ? p.accentColor.withValues(alpha: 0.85)
                      : const Color.fromRGBO(255, 255, 255, 0.08),
                  width: isCur ? 1.2 : 1.0,
                ),
                boxShadow: isCur
                    ? [
                        BoxShadow(
                          color: p.accentColor.withValues(alpha: 0.28),
                          blurRadius: 14.0,
                          spreadRadius: -2.0,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 6.0,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  // 发烧微光珠宝指示圆环
                  Container(
                    width: compact ? 12.0 : 16.0,
                    height: compact ? 12.0 : 16.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.accentColor,
                      boxShadow: [
                        BoxShadow(
                          color: p.accentColor
                              .withValues(alpha: isCur ? 0.75 : 0.35),
                          blurRadius: isCur ? 8.0 : 4.0,
                        ),
                      ],
                    ),
                    child: isCur
                        ? Center(
                            child: Container(
                              width: 6.0,
                              height: 6.0,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: compact ? 8.0 : 12.0),

                  // 主题名称与声学风格
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (compact)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: name,
                          )
                        else
                          name,
                        const SizedBox(height: 2.0),
                        Text(
                          p.soundStyle,
                          maxLines: compact ? 2 : null,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 10.0 : 11.0,
                            height: compact ? 1.15 : null,
                            color: UIConfig.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3 颗微晶胶囊调色代表柱
                  if (!compact) ...[
                    _buildColorChip(p.accentColor),
                    const SizedBox(width: 4.0),
                    _buildColorChip(p.litColor),
                    const SizedBox(width: 4.0),
                    _buildColorChip(p.peakColor),
                  ],

                  if (isCur && !compact) ...[
                    const SizedBox(width: 10.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            p.accentColor.withValues(alpha: 0.35),
                            p.accentColor.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                            color: p.accentColor.withValues(alpha: 0.75),
                            width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: p.accentColor.withValues(alpha: 0.30),
                            blurRadius: 6.0,
                          ),
                        ],
                      ),
                      child: const Text(
                        '已激活',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildColorChip(Color c) {
    return Container(
      width: 7.0,
      height: 17.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3.5),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.withValues(alpha: 0.95),
            c,
            c.withValues(alpha: 0.65),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.40),
            blurRadius: 3.0,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.30),
          width: 0.5,
        ),
      ),
    );
  }

  /// 背景律动网格 (4列)
  Widget _buildVisualizerModesGrid(ThemeService theme) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth < 620 ? 3 : 4;
      return GridView.builder(
        primary: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 8.0,
          crossAxisSpacing: 10.0,
          mainAxisExtent: 34.0,
        ),
        itemCount: ThemeService.visualModeLabels.length,
        itemBuilder: (context, i) {
          final isCur = theme.backgroundVisualMode == i;
          final label = ThemeService.visualModeLabels[i];
          final accent = theme.accentColor;
          final iconData = i < _visualModeIcons.length
              ? _visualModeIcons[i]
              : Icons.graphic_eq_rounded;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              theme.setBackgroundVisualMode(i);
              widget.onVisualizerChanged(
                VisualizerType
                    .values[i.clamp(0, VisualizerType.values.length - 1)],
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isCur
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.30),
                          accent.withValues(alpha: 0.12),
                          const Color(0xFF161C28),
                        ],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF202838),
                          Color(0xFF151A26),
                        ],
                      ),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: isCur
                      ? accent.withValues(alpha: 0.85)
                      : const Color.fromRGBO(255, 255, 255, 0.08),
                  width: isCur ? 1.1 : 0.8,
                ),
                boxShadow: isCur
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.28),
                          blurRadius: 10.0,
                          spreadRadius: -2.0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconData,
                    size: 14.0,
                    color: isCur ? accent : UIConfig.textMuted,
                  ),
                  const SizedBox(width: 6.0),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isCur ? FontWeight.w600 : FontWeight.normal,
                        color:
                            isCur ? UIConfig.textActive : UIConfig.textNormal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  /// 自由调色色轮 + 滑块 + 色卡
  Widget _buildColorWheelSection(ThemeService theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 左侧：HSV 色轮 (半径 65px -> 130x130)
        SizedBox(
          width: 130.0,
          height: 130.0,
          child: _ColorWheelPicker(
            hue: theme.customHue,
            saturation: theme.customSat,
            value: theme.customVal,
            accentColor: theme.accentColor,
            onChanged: (h, s) {
              theme.setCustomHsv(h, s, theme.customVal);
            },
          ),
        ),
        const SizedBox(width: 24.0),

        // 右侧调色中枢：明度滑条 + 色彩数值代码框
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. 横向明度滑条
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '明度 / 亮度 (Brightness)',
                    style: TextStyle(
                      fontSize: UIConfig.fontSmall,
                      color: UIConfig.textMuted,
                    ),
                  ),
                  Text(
                    '${(theme.customVal * 100).round()}%',
                    style: const TextStyle(
                      fontSize: UIConfig.fontSmall,
                      fontWeight: FontWeight.bold,
                      color: UIConfig.textActive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              _BrightnessSlider(
                hue: theme.customHue,
                saturation: theme.customSat,
                value: theme.customVal,
                onChanged: (v) {
                  theme.setCustomHsv(theme.customHue, theme.customSat, v);
                },
              ),
              const SizedBox(height: 16.0),

              // 2. 颜色预览大块与三行格式编码
              Row(
                children: [
                  // 颜色预览方块
                  Container(
                    width: 42.0,
                    height: 42.0,
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: const Color.fromRGBO(255, 255, 255, 0.4),
                        width: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),

                  // HEX 格式框
                  Expanded(
                    child: _buildCodeBox(
                      'HEX',
                      '#${theme.accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    ),
                  ),
                  const SizedBox(width: 8.0),

                  // RGB 格式框
                  Expanded(
                    child: _buildCodeBox(
                      'RGB',
                      '${(theme.accentColor.r * 255).round()}, ${(theme.accentColor.g * 255).round()}, ${(theme.accentColor.b * 255).round()}',
                    ),
                  ),
                  const SizedBox(width: 8.0),

                  // HSV 格式框
                  Expanded(
                    child: _buildCodeBox(
                      'HSV',
                      '${theme.customHue.round()}°, ${(theme.customSat * 100).round()}%, ${(theme.customVal * 100).round()}%',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHexPill(Color c) {
    final hex =
        '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final cr = (c.r * 255).round();
    final cg = (c.g * 255).round();
    final cb = (c.b * 255).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(11.0),
        border: Border.all(color: c.withValues(alpha: 0.55)),
      ),
      child: Text(
        '$hex  ·  RGB($cr, $cg, $cb)',
        style: const TextStyle(
          fontSize: 11.0,
          color: UIConfig.textActive,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildCodeBox(String label, String value) {
    return Container(
      height: 42.0,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.04),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.1,
              color: UIConfig.textMuted,
            ),
          ),
          const SizedBox(height: 1.0),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: UIConfig.textActive,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// macOS 纯矢量全彩渐变色轮组件 (Hue-Saturation Color Wheel)
class _ColorWheelPicker extends StatelessWidget {
  final double hue;
  final double saturation;
  final double value;
  final Color accentColor;
  final void Function(double hue, double sat) onChanged;

  const _ColorWheelPicker({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  void _handleTouch(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final radius = size.width / 2;
    final dist = math.sqrt(dx * dx + dy * dy);
    final sat = (dist / radius).clamp(0.0, 1.0);

    // atan2 返回 [-pi, pi]
    var angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;
    final h = (angle / (2 * math.pi) * 360.0) % 360.0;

    onChanged(h, sat);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        onPanDown: (d) => _handleTouch(d.localPosition, size),
        onPanUpdate: (d) => _handleTouch(d.localPosition, size),
        child: CustomPaint(
          size: size,
          painter: _ColorWheelPainter(
            hue: hue,
            saturation: saturation,
            value: value,
            accentColor: accentColor,
          ),
        ),
      );
    });
  }
}

class _ColorWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;
  final Color accentColor;

  _ColorWheelPainter({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. 绘制色相环 (SweepGradient)
    final sweepColors = [
      const Color(0xFFFF0000),
      const Color(0xFFFFFF00),
      const Color(0xFF00FF00),
      const Color(0xFF00FFFF),
      const Color(0xFF0000FF),
      const Color(0xFFFF00FF),
      const Color(0xFFFF0000),
    ];
    final sweepPaint = Paint()
      ..shader = SweepGradient(colors: sweepColors).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, sweepPaint);

    // 2. 绘制饱和度渐变 (从中心白向边缘透明)
    final satPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: value),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, satPaint);

    // 3. 绘制明度遮罩 (黑色半透)
    if (value < 0.99) {
      final valPaint = Paint()
        ..color = Colors.black.withValues(alpha: 1.0 - value);
      canvas.drawCircle(center, radius, valPaint);
    }

    // 4. 精工外边框
    final borderPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, borderPaint);

    // 5. 准星指示器 (Crosshair Reticle)
    final angle = hue * math.pi / 180.0;
    final dist = saturation * radius;
    final retPos = Offset(
        center.dx + math.cos(angle) * dist, center.dy + math.sin(angle) * dist);

    // 准星外阴影与白环
    canvas.drawCircle(
        retPos,
        7.0,
        Paint()
          ..color = const Color.fromRGBO(0, 0, 0, 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.drawCircle(
        retPos,
        6.0,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    canvas.drawCircle(retPos, 3.2, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter old) {
    return old.hue != hue ||
        old.saturation != saturation ||
        old.value != value ||
        old.accentColor != accentColor;
  }
}

/// 横向明度渐变滑条
class _BrightnessSlider extends StatelessWidget {
  final double hue;
  final double saturation;
  final double value;
  final ValueChanged<double> onChanged;

  const _BrightnessSlider({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  void _handleTouch(Offset localPos, double width) {
    final norm = (localPos.dx / width).clamp(0.05, 1.0);
    onChanged(norm);
  }

  @override
  Widget build(BuildContext context) {
    final maxColor = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor();

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return GestureDetector(
        onPanDown: (d) => _handleTouch(d.localPosition, w),
        onPanUpdate: (d) => _handleTouch(d.localPosition, w),
        child: Container(
          height: 18.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9.0),
            gradient: LinearGradient(
              colors: [Colors.black, maxColor],
            ),
            border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.2)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: (w - 18.0) * value,
                top: -1.0,
                child: Container(
                  width: 18.0,
                  height: 18.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 3.0,
                        offset: Offset(0, 1.5),
                      ),
                    ],
                    border: Border.all(color: Colors.black26, width: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
