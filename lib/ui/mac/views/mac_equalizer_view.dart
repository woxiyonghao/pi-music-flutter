import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../services/music_database_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/web_remote_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// 图形均衡器视图 (1:1 严格对齐 C++ EQConfigView.cpp 与 cpp_tab_1_eq.png)
class MacEqualizerView extends StatefulWidget {
  const MacEqualizerView({super.key});

  @override
  State<MacEqualizerView> createState() => _MacEqualizerViewState();
}

class _MacEqualizerViewState extends State<MacEqualizerView> {
  static const List<String> bandLabels = [
    '31Hz', '62Hz', '125Hz', '250Hz', '500Hz',
    '1kHz', '2kHz', '4kHz', '8kHz', '16kHz',
  ];

  static const List<Map<String, dynamic>> presets = [
    {'name': '原音直通', 'gains': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]},
    {'name': '流行音乐', 'gains': [2.5, 1.5, 0.0, -1.0, -1.5, 1.0, 2.5, 3.5, 2.5, 1.5]},
    {'name': '摇滚现场', 'gains': [4.5, 3.5, 2.0, 0.0, -1.0, 1.5, 3.5, 4.0, 4.5, 4.0]},
    {'name': '经典人声', 'gains': [-2.0, -1.0, 0.0, 2.0, 3.5, 4.0, 3.0, 1.5, 0.0, -1.0]},
    {'name': '古典交响', 'gains': [3.5, 3.0, 2.0, 1.0, -1.0, 0.0, 1.5, 2.5, 3.5, 3.5]},
    {'name': '震撼低音', 'gains': [6.0, 5.0, 3.5, 2.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]},
    {'name': '通透高音', 'gains': [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.5, 4.5, 6.0, 6.0]},
    {'name': '自定义',   'gains': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]},
  ];

  int _selectedPreset = 0; // 0: 原音直通 (初始纯净直通，无人工染色)
  late List<double> _bandGains = List.filled(10, 0.0);
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    HifiAudioService.instance.addListener(_onAudioServiceChanged);
  }

  @override
  void dispose() {
    HifiAudioService.instance.removeListener(_onAudioServiceChanged);
    super.dispose();
  }

  void _onAudioServiceChanged() {
    if (!mounted) return;
    final audio = HifiAudioService.instance;
    if (_isEnabled != audio.eqEnabled || !listEquals(_bandGains, audio.eqBands)) {
      setState(() {
        _isEnabled = audio.eqEnabled;
        _bandGains = List<double>.from(audio.eqBands);
        _matchOrUpdatePreset();
      });
    }
  }

  void _matchOrUpdatePreset() {
    for (int i = 0; i < presets.length - 1; i++) {
      final pGains = (presets[i]['gains'] as List).map((e) => (e as num).toDouble()).toList();
      bool match = true;
      for (int b = 0; b < 10; b++) {
        if ((_bandGains[b] - pGains[b]).abs() > 0.05) {
          match = false;
          break;
        }
      }
      if (match) {
        _selectedPreset = i;
        return;
      }
    }
    _selectedPreset = presets.length - 1; // 自定义
  }

  void _loadSettings() {
    final audio = HifiAudioService.instance;
    _isEnabled = audio.eqEnabled;
    _bandGains = List<double>.from(audio.eqBands);

    final db = MusicDatabaseService.instance;
    final savedPreset = int.tryParse(db.getSetting('eq_selected_preset', '-1'));
    if (savedPreset != null && savedPreset >= 0 && savedPreset < presets.length) {
      _selectedPreset = savedPreset;
    } else {
      _matchOrUpdatePreset();
    }
  }

  void _saveSettings() {
    HifiAudioService.instance.setEqAndBands(_isEnabled, _bandGains, selectedPreset: _selectedPreset);
    WebRemoteService.instance.broadcastState();
  }

  void _applyPreset(int index) {
    setState(() {
      _selectedPreset = index;
      _bandGains = List<double>.from((presets[index]['gains'] as List).map((e) => (e as num).toDouble()));
      _isEnabled = index != 0;
      _saveSettings();
    });
  }

  void _resetToFlat() {
    setState(() {
      _selectedPreset = 0;
      _bandGains = List.filled(10, 0.0);
      _isEnabled = false;
      HifiAudioService.instance.resetEq();
      WebRemoteService.instance.broadcastState();
    });
  }

  void _updateBand(int index, double gain) {
    setState(() {
      _bandGains[index] = gain.clamp(-12.0, 12.0);
      _selectedPreset = presets.length - 1; // 标记为自定义
      if (!_isEnabled) _isEnabled = true;
      _saveSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final accent = ThemeService.instance.accentColor;

        return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 顶部 Header 栏：标题 + 副标题 + 复原按钮 + EQ 激活胶囊按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '图形均衡器',
                    style: TextStyle(
                      fontSize: UIConfig.fontMedium,
                      fontWeight: FontWeight.bold,
                      color: UIConfig.textActive,
                    ),
                  ),
                  SizedBox(height: 3.0),
                  Text(
                    '10 段专业频段精调 · 纯净硬件直通',
                    style: TextStyle(
                      fontSize: UIConfig.fontSmall,
                      color: UIConfig.textMuted,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // 复原按钮
                  InkWell(
                    onTap: _resetToFlat,
                    borderRadius: BorderRadius.circular(6.0),
                    child: Container(
                      height: 28.0,
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(40, 48, 64, 0.7),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.12),
                        ),
                      ),
                      child: const Text(
                        '复原',
                        style: TextStyle(
                          fontSize: UIConfig.fontSmall,
                          color: UIConfig.textNormal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10.0),

                  // EQ 激活/旁路胶囊按钮
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isEnabled = !_isEnabled;
                        _saveSettings();
                      });
                    },
                    borderRadius: BorderRadius.circular(14.0),
                    child: Container(
                      height: 28.0,
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isEnabled
                            ? accent.withValues(alpha: 0.25)
                            : const Color.fromRGBO(255, 255, 255, 0.05),
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(
                          color: _isEnabled
                              ? accent
                              : const Color.fromRGBO(255, 255, 255, 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6.0,
                            height: 6.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isEnabled ? const Color(0xFF34C759) : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            _isEnabled ? 'EQ 已激活' : 'EQ 已旁路',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _isEnabled ? UIConfig.textActive : UIConfig.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // 2. 预设方案水平胶囊栏 (8款发烧经典预设)
          Row(
            children: [
              for (int i = 0; i < presets.length; i++) ...[
                if (i > 0) const SizedBox(width: 8.0),
                Expanded(
                  child: InkWell(
                    onTap: () => _applyPreset(i),
                    borderRadius: BorderRadius.circular(13.0),
                    child: Container(
                      height: 26.0,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedPreset == i
                            ? accent.withValues(alpha: 0.28)
                            : const Color.fromRGBO(255, 255, 255, 0.04),
                        borderRadius: BorderRadius.circular(13.0),
                        border: Border.all(
                          color: _selectedPreset == i
                              ? accent
                              : const Color.fromRGBO(255, 255, 255, 0.1),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        presets[i]['name'] as String,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: _selectedPreset == i
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedPreset == i
                              ? UIConfig.textActive
                              : UIConfig.textNormal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12.0),

          // 3. 动态频响 Catmull-Rom 贝塞尔三次样条响应曲线视窗 (Curve Canvas)
          SizedBox(
            height: 140.0,
            child: _SplineCurveCanvas(
              bandGains: _bandGains,
              isEnabled: _isEnabled,
              accentColor: accent,
            ),
          ),
          const SizedBox(height: 12.0),

          // 4. 10 段发烧级图形推子控制区 (Mixer Faders)
          Expanded(
            child: Row(
              children: [
                for (int i = 0; i < 10; i++) ...[
                  if (i > 0) const SizedBox(width: 8.0),
                  Expanded(
                    child: _MixerFaderColumn(
                      key: ValueKey('eq_${i}_${accent.toARGB32()}'),
                      index: i,
                      label: bandLabels[i],
                      gain: _bandGains[i],
                      isEnabled: _isEnabled,
                      accentColor: accent,
                      onGainChanged: (val) => _updateBand(i, val),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

/// Catmull-Rom 三次样条频响曲线视窗 (1:1 严格对齐 EQConfigView.cpp::renderCurveCanvas)
class _SplineCurveCanvas extends StatelessWidget {
  final List<double> bandGains;
  final bool isEnabled;
  final Color accentColor;

  const _SplineCurveCanvas({
    required this.bandGains,
    required this.isEnabled,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(12, 16, 24, 0.85),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.08),
        ),
      ),
      child: Stack(
        children: [
          // 左侧刻度文本: +12, 0dB, -12
          Positioned(
            left: 10.0,
            top: 10.0,
            child: Text('+12', style: TextStyle(fontSize: 10.0, color: UIConfig.textMuted.withValues(alpha: 0.7))),
          ),
          Positioned(
            left: 10.0,
            top: 60.0,
            child: Text('0dB', style: TextStyle(fontSize: 10.0, color: UIConfig.textMuted.withValues(alpha: 0.9), fontWeight: FontWeight.bold)),
          ),
          Positioned(
            left: 10.0,
            bottom: 10.0,
            child: Text('-12', style: TextStyle(fontSize: 10.0, color: UIConfig.textMuted.withValues(alpha: 0.7))),
          ),

          // 样条曲线与渐变区域
          Positioned.fill(
            left: 36.0,
            right: 16.0,
            top: 10.0,
            bottom: 10.0,
            child: CustomPaint(
              painter: _CurvePainter(
                bandGains: bandGains,
                isEnabled: isEnabled,
                accentColor: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  final List<double> bandGains;
  final bool isEnabled;
  final Color accentColor;

  _CurvePainter({
    required this.bandGains,
    required this.isEnabled,
    required this.accentColor,
  });

  Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    final x = 0.5 * ((2.0 * p1.dx) + (-p0.dx + p2.dx) * t + (2.0 * p0.dx - 5.0 * p1.dx + 4.0 * p2.dx - p3.dx) * t2 + (-p0.dx + 3.0 * p1.dx - 3.0 * p2.dx + p3.dx) * t3);
    final y = 0.5 * ((2.0 * p1.dy) + (-p0.dy + p2.dy) * t + (2.0 * p0.dy - 5.0 * p1.dy + 4.0 * p2.dy - p3.dy) * t2 + (-p0.dy + 3.0 * p1.dy - 3.0 * p2.dy + p3.dy) * t3);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final yMid = size.height / 2;
    final maxDev = size.height * 0.45;
    final numBands = bandGains.length;
    final colW = size.width / numBands;

    // 1. 基准参考线 (+12dB, 0dB, -12dB)
    final gridPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.08)
      ..strokeWidth = 1.0;
    final zeroLinePaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.18)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, yMid - maxDev), Offset(size.width, yMid - maxDev), gridPaint);
    canvas.drawLine(Offset(0, yMid), Offset(size.width, yMid), zeroLinePaint);
    canvas.drawLine(Offset(0, yMid + maxDev), Offset(size.width, yMid + maxDev), gridPaint);

    // 2. 计算 10 个频段的中心采样点
    final pts = <Offset>[];
    for (int i = 0; i < numBands; i++) {
      final cx = (i + 0.5) * colW;
      final cy = yMid - (bandGains[i] / 12.0) * maxDev;
      pts.add(Offset(cx, cy));
    }

    // 3. Catmull-Rom 三次样条插值生成密集平滑点
    const subdiv = 8;
    final curvePts = <Offset>[];
    for (int i = 0; i < numBands - 1; i++) {
      final p0 = (i == 0) ? pts[0] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = (i + 2 < numBands) ? pts[i + 2] : p2;

      for (int step = 0; step < subdiv; step++) {
        final t = step / subdiv;
        final pt = _catmullRom(p0, p1, p2, p3, t);
        curvePts.add(Offset(pt.dx, pt.dy.clamp(0.0, size.height)));
      }
    }
    curvePts.add(pts.last);

    // 4. 曲线下方发光半透渐变填充 (Gradient Fill under curve)
    if (isEnabled && curvePts.isNotEmpty) {
      final fillPath = Path();
      fillPath.moveTo(curvePts.first.dx, yMid);
      for (final pt in curvePts) {
        fillPath.lineTo(pt.dx, pt.dy);
      }
      fillPath.lineTo(curvePts.last.dx, yMid);
      fillPath.close();

      final fillPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    // 5. 曲线主体矢量高光描边 (带高斯微光光晕)
    if (curvePts.isNotEmpty) {
      final strokePath = Path();
      strokePath.moveTo(curvePts.first.dx, curvePts.first.dy);
      for (int i = 1; i < curvePts.length; i++) {
        strokePath.lineTo(curvePts[i].dx, curvePts[i].dy);
      }

      if (isEnabled) {
        // 外发光层
        canvas.drawPath(
          strokePath,
          Paint()
            ..color = accentColor.withValues(alpha: 0.3)
            ..strokeWidth = 4.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }

      // 主线条
      canvas.drawPath(
        strokePath,
        Paint()
          ..color = isEnabled ? accentColor : const Color.fromRGBO(160, 175, 195, 0.5)
          ..strokeWidth = isEnabled ? 2.5 : 1.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // 6. 10 个频段频点发光圆环节点
    for (int i = 0; i < numBands; i++) {
      if (isEnabled) {
        canvas.drawCircle(pts[i], 4.5, Paint()..color = accentColor.withValues(alpha: 0.35));
        canvas.drawCircle(pts[i], 3.0, Paint()..color = accentColor);
        canvas.drawCircle(pts[i], 1.5, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(pts[i], 2.5, Paint()..color = const Color.fromRGBO(160, 175, 195, 0.6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) {
    return old.isEnabled != isEnabled || old.accentColor != accentColor || old.bandGains != bandGains;
  }
}

/// 10 段专业调音推子单列 (1:1 严格对齐 EQConfigView.cpp::renderSliders)
class _MixerFaderColumn extends StatelessWidget {
  final int index;
  final String label;
  final double gain;
  final bool isEnabled;
  final Color accentColor;
  final ValueChanged<double> onGainChanged;

  const _MixerFaderColumn({
    super.key,
    required this.index,
    required this.label,
    required this.gain,
    required this.isEnabled,
    required this.accentColor,
    required this.onGainChanged,
  });

  void _handleTouch(Offset localPos, double railH) {
    const pad = 10.0;
    final usableH = railH - pad * 2;
    if (usableH <= 0) return;
    final clampedY = (localPos.dy - pad).clamp(0.0, usableH);
    final norm = 1.0 - (clampedY / (usableH / 2));
    var newGain = (norm * 12.0 * 10).round() / 10.0;
    if (newGain.abs() < 0.2) newGain = 0.0;
    onGainChanged(newGain);
  }

  @override
  Widget build(BuildContext context) {
    final gainStr = gain > 0.05
        ? '+${gain.toStringAsFixed(1)}'
        : (gain < -0.05 ? gain.toStringAsFixed(1) : '0.0');

    return Column(
      children: [
        // 顶部实时 dB 数值
        Text(
          gainStr,
          style: TextStyle(
            fontSize: 11.0,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: isEnabled && gain.abs() > 0.05 ? UIConfig.textActive : UIConfig.textMuted,
          ),
        ),
        const SizedBox(height: 6.0),

        // 垂直推子轨道交互区
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final h = constraints.maxHeight;
            final w = constraints.maxWidth;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _handleTouch(d.localPosition, h),
              onPanDown: (d) => _handleTouch(d.localPosition, h),
              onPanUpdate: (d) => _handleTouch(d.localPosition, h),
              onTapDown: (d) => _handleTouch(d.localPosition, h),
              onDoubleTap: () => onGainChanged(0.0),
              child: SizedBox(
                width: math.max(w, 36.0),
                height: h,
                child: CustomPaint(
                  painter: _FaderPainter(
                    gain: gain,
                    isEnabled: isEnabled,
                    accentColor: accentColor,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6.0),

        // 底部频段标签 (31Hz, 1kHz 等)
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.0,
            color: UIConfig.textNormal,
          ),
        ),
      ],
    );
  }
}

class _FaderPainter extends CustomPainter {
  final double gain;
  final bool isEnabled;
  final Color accentColor;

  _FaderPainter({
    required this.gain,
    required this.isEnabled,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const railTop = 10.0;
    final railBot = size.height - 10.0;
    final railH = railBot - railTop;
    final railMid = (railTop + railBot) / 2;

    // 1. 垂直暗槽轨道 (4px 宽)
    const trackW = 4.0;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - trackW / 2, railTop, cx + trackW / 2, railBot),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(trackRect, Paint()..color = const Color.fromRGBO(255, 255, 255, 0.12));

    // 2. 0 dB 中心基准参考线横向短刻度
    final notchPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.3)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx - 7.0, railMid), Offset(cx + 7.0, railMid), notchPaint);

    // 3. 计算滑块物理 Y 坐标
    final thumbNorm = (gain / 12.0).clamp(-1.0, 1.0);
    final thumbY = railMid - thumbNorm * (railH / 2);

    // 4. 动态发光填充柱 (从 0dB 向上/向下激发)
    if (isEnabled && gain.abs() > 0.05) {
      final yFill0 = math.min(railMid, thumbY);
      final yFill1 = math.max(railMid, thumbY);

      // 填充柱光晕
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - 3.5, yFill0, cx + 3.5, yFill1),
          const Radius.circular(2.0),
        ),
        Paint()..color = accentColor.withValues(alpha: 0.25),
      );

      // 主题色填充柱实色
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - 1.8, yFill0, cx + 1.8, yFill1),
          const Radius.circular(1.5),
        ),
        Paint()..color = accentColor,
      );
    }

    // 5. 调音台推子物理手柄 (Tactile Slider Thumb)
    const thumbW = 28.0;
    const thumbH = 13.0;
    final thumbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, thumbY), width: thumbW, height: thumbH),
      const Radius.circular(4.0),
    );

    // 阴影
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, thumbY + 1.5), width: thumbW, height: thumbH),
        const Radius.circular(4.0),
      ),
      Paint()..color = Colors.black45,
    );

    // 手柄本体金属底
    canvas.drawRRect(thumbRect, Paint()..color = const Color.fromRGBO(35, 42, 56, 1.0));

    // 手柄边框
    canvas.drawRRect(
      thumbRect,
      Paint()
        ..color = isEnabled && gain.abs() > 0.05 ? accentColor : const Color.fromRGBO(255, 255, 255, 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 手柄中央凹槽横线 (Notch highlight)
    canvas.drawLine(
      Offset(cx - 8.0, thumbY),
      Offset(cx + 8.0, thumbY),
      Paint()..color = const Color.fromRGBO(255, 255, 255, 0.6)..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _FaderPainter old) {
    return old.gain != gain || old.isEnabled != isEnabled || old.accentColor != accentColor;
  }
}
