import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/theme_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';
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
    final theme = ThemeService.instance;
    final accent = theme.accentColor;

    return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              InkWell(
                onTap: () {
                  theme.resetToDefault();
                  widget.onVisualizerChanged(VisualizerType.ledSpectrum);
                },
                borderRadius: BorderRadius.circular(7.0),
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

          // 2. 独立滚动区域
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
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
          ),
        ],
      ),
    );
  }

  /// 毛玻璃板块卡片容器
  Widget _buildSectionContainer({
    required String title,
    Widget? headerTrailing,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(20, 26, 36, 0.7),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.11),
        ),
      ),
      padding: const EdgeInsets.all(16.0),
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
                  color: UIConfig.textActive,
                ),
              ),
              if (headerTrailing != null) headerTrailing,
            ],
          ),
          const SizedBox(height: 12.0),
          child,
        ],
      ),
    );
  }

  /// 预设卡片网格 (2列)
  Widget _buildPresetsGrid(ThemeService theme) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth < 560 ? 1 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 8.0,
          crossAxisSpacing: 12.0,
          mainAxisExtent: 52.0,
        ),
        itemCount: ThemeService.presets.length,
        itemBuilder: (context, i) {
          final p = ThemeService.presets[i];
          final isCur = theme.currentThemeId == p.id;

          return InkWell(
            onTap: () {
              theme.setTheme(p.id);
              widget.onVisualizerChanged(
                VisualizerType.values[p.defaultVisualMode.clamp(0, VisualizerType.values.length - 1)],
              );
            },
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              decoration: BoxDecoration(
                color: isCur
                    ? p.accentColor.withValues(alpha: 0.15)
                    : const Color.fromRGBO(255, 255, 255, 0.04),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: isCur
                      ? p.accentColor
                      : const Color.fromRGBO(255, 255, 255, 0.1),
                  width: isCur ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  // 双圆环主题标点
                  Container(
                    width: 14.0,
                    height: 14.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.accentColor,
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
                  const SizedBox(width: 12.0),

                  // 主题名称与声学风格
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: UIConfig.fontRegular,
                            fontWeight: isCur ? FontWeight.w600 : FontWeight.normal,
                            color: isCur
                                ? UIConfig.textActive
                                : const Color.fromRGBO(220, 230, 245, 0.9),
                          ),
                        ),
                        Text(
                          p.soundStyle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.0,
                            color: UIConfig.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3 颗调色代表色条
                  _buildColorChip(p.accentColor),
                  const SizedBox(width: 4.0),
                  _buildColorChip(p.litColor),
                  const SizedBox(width: 4.0),
                  _buildColorChip(p.peakColor),

                  if (isCur) ...[
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: p.accentColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: p.accentColor, width: 1.0),
                      ),
                      child: const Text(
                        '已激活',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
      width: 12.0,
      height: 18.0,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(3.0),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.2)),
      ),
    );
  }

  /// 背景律动网格 (4列)
  Widget _buildVisualizerModesGrid(ThemeService theme) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth < 600 ? 3 : 4;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 8.0,
          crossAxisSpacing: 10.0,
          mainAxisExtent: 30.0,
        ),
        itemCount: ThemeService.visualModeLabels.length,
        itemBuilder: (context, i) {
          final isCur = theme.backgroundVisualMode == i;
          final label = ThemeService.visualModeLabels[i];
          final accent = theme.accentColor;

          return InkWell(
            onTap: () {
              theme.setBackgroundVisualMode(i);
              widget.onVisualizerChanged(
                VisualizerType.values[i.clamp(0, VisualizerType.values.length - 1)],
              );
            },
            borderRadius: BorderRadius.circular(7.0),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCur
                    ? accent.withValues(alpha: 0.28)
                    : const Color.fromRGBO(255, 255, 255, 0.04),
                borderRadius: BorderRadius.circular(7.0),
                border: Border.all(
                  color: isCur
                      ? accent
                      : const Color.fromRGBO(255, 255, 255, 0.1),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isCur ? FontWeight.w600 : FontWeight.normal,
                  color: isCur ? UIConfig.textActive : UIConfig.textNormal,
                ),
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
                    width: 36.0,
                    height: 36.0,
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
                      '#${theme.accentColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    ),
                  ),
                  const SizedBox(width: 8.0),

                  // RGB 格式框
                  Expanded(
                    child: _buildCodeBox(
                      'RGB',
                      '${theme.accentColor.red}, ${theme.accentColor.green}, ${theme.accentColor.blue}',
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
    final hex = '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(11.0),
        border: Border.all(color: c.withValues(alpha: 0.55)),
      ),
      child: Text(
        '$hex  ·  RGB(${c.red}, ${c.green}, ${c.blue})',
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
      height: 36.0,
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
              color: UIConfig.textMuted,
            ),
          ),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.0,
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
      final valPaint = Paint()..color = Colors.black.withValues(alpha: 1.0 - value);
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
    final retPos = Offset(center.dx + math.cos(angle) * dist, center.dy + math.sin(angle) * dist);

    // 准星外阴影与白环
    canvas.drawCircle(retPos, 7.0, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.85)..style = PaintingStyle.stroke..strokeWidth = 2.5);
    canvas.drawCircle(retPos, 6.0, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.6);
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
