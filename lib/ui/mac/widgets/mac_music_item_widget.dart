import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/track.dart';
import '../../../services/theme_service.dart';
import '../../../theme/ui_config.dart';

/// 发烧黑胶唱片 CD 专辑卡片组件 (1:1 严格对齐 C++ MusicItem.cpp 与 cpp_tab_0_scan.png)
class MacMusicItemWidget extends StatefulWidget {
  final Track track;
  final String categoryTag;
  final bool isEditMode;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;

  const MacMusicItemWidget({
    super.key,
    required this.track,
    this.categoryTag = 'DSD Direct',
    this.isEditMode = false,
    this.isSelected = false,
    this.isPlaying = false,
    required this.onTap,
  });

  @override
  State<MacMusicItemWidget> createState() => _MacMusicItemWidgetState();
}

class _MacMusicItemWidgetState extends State<MacMusicItemWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MacMusicItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying || _isHovered) {
        if (!_rotationController.isAnimating) _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool hovered) {
    setState(() {
      _isHovered = hovered;
    });
    if (hovered || widget.isPlaying) {
      if (!_rotationController.isAnimating) _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ThemeService.instance.accentColor;
    const cardW = 150.0;
    const cardH = 220.0;

    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: cardW,
          height: cardH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 正方形封面区 (150x150)
              Container(
                width: cardW,
                height: cardW,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? const Color.fromRGBO(36, 44, 58, 0.95)
                      : const Color.fromRGBO(22, 26, 36, 0.95),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: widget.isEditMode && widget.isSelected
                        ? accent
                        : (_isHovered
                            ? const Color.fromRGBO(255, 255, 255, 0.25)
                            : const Color.fromRGBO(255, 255, 255, 0.08)),
                    width: (widget.isEditMode && widget.isSelected) ? 2.0 : 1.0,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 黑胶唱片矢量旋转体
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _VinylCdPainter(
                              radius: _isHovered ? 45.0 : 40.0,
                              color: (_isHovered || widget.isPlaying)
                                  ? accent
                                  : const Color.fromRGBO(215, 222, 235, 0.65),
                              rotationRad: _rotationController.value * 2 * math.pi,
                            ),
                          );
                        },
                      ),
                    ),

                    // 悬停态中心播放三角按钮 (1:1 严格同心对齐黑胶唱片中心 cd_center = (cardW / 2, 66.0))
                    if (_isHovered && !widget.isEditMode)
                      Positioned(
                        top: 66.0 - 23.5,
                        left: (cardW - 47.0) / 2,
                        width: 47.0,
                        height: 47.0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.38),
                                blurRadius: 4.0,
                                offset: const Offset(0, 2),
                              ),
                              BoxShadow(
                                color: accent.withValues(alpha: 0.40),
                                blurRadius: 8.0,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.only(left: 2.0),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28.0,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 发烧格式指示胶囊徽标 (Format Badge)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8.0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10.0, vertical: 3.0),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(12, 16, 24, 0.85),
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(
                              color: _isHovered
                                  ? const Color.fromRGBO(255, 255, 255, 0.3)
                                  : const Color.fromRGBO(255, 255, 255, 0.12),
                            ),
                          ),
                          child: Text(
                            widget.track.formatBadge,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _isHovered
                                  ? UIConfig.textActive
                                  : const Color.fromRGBO(175, 190, 210, 0.9),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 多选编辑模式：右上角选中勾选指示圈
                    if (widget.isEditMode)
                      Positioned(
                        top: 8.0,
                        right: 8.0,
                        child: Container(
                          width: 22.0,
                          height: 22.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isSelected
                                ? accent
                                : const Color.fromRGBO(18, 22, 32, 0.8),
                            border: Border.all(
                              color: widget.isSelected
                                  ? Colors.white
                                  : const Color.fromRGBO(255, 255, 255, 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: widget.isSelected
                              ? const Center(
                                  child: Icon(
                                    Icons.check,
                                    size: 14.0,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8.0),

              // 2. 文字排版区域
              // 分类小标签 (如 "DSD Direct", "Studio Master")
              Text(
                widget.categoryTag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: UIConfig.textMuted,
                ),
              ),
              const SizedBox(height: 2.0),

              // 曲目标题
              Text(
                widget.track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _isHovered ? accent : UIConfig.textActive,
                ),
              ),
              const SizedBox(height: 1.0),

              // 艺术家
              Text(
                widget.track.artist.isNotEmpty ? widget.track.artist : '未知艺术家',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.0,
                  color: UIConfig.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 纯矢量发烧黑胶唱片绘制器 (1:1 严格对齐 MusicItem::drawVinylCdIcon)
class _VinylCdPainter extends CustomPainter {
  final double radius;
  final Color color;
  final double rotationRad;

  _VinylCdPainter({
    required this.radius,
    required this.color,
    required this.rotationRad,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 66.0);
    const thickness = 2.0;
    final rIn = radius * 0.28;
    final rMid = radius * 0.65;

    final discPaint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    // 1. 外部主光盘轮廓圈 (Outer Disc Rim)
    canvas.drawCircle(center, radius, discPaint);

    // 2. 内部主轴孔圈 (Center Spindle Ring)
    canvas.drawCircle(center, rIn, discPaint);

    // 3. 动态光泽凹槽双圆弧 (Groove Sheen Arcs with Round Caps)
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 弧段 1：顶部斜弧 (-90° ~ -36°)
    final a1Start = -math.pi / 2 + rotationRad;
    const a1Sweep = 54.0 * math.pi / 180.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rMid),
      a1Start,
      a1Sweep,
      false,
      arcPaint,
    );

    // 弧段 2：底部对称斜弧 (+90° ~ +144°)
    final a2Start = math.pi / 2 + rotationRad;
    const a2Sweep = 54.0 * math.pi / 180.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rMid),
      a2Start,
      a2Sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _VinylCdPainter old) {
    return old.radius != radius ||
        old.color != color ||
        old.rotationRad != rotationRad;
  }
}
