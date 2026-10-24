import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/mseb_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/web_remote_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

class MSEBParamDef {
  final String title;
  final String enTitle;
  final String desc;
  final String leftLabel;
  final String rightLabel;

  const MSEBParamDef({
    required this.title,
    required this.enTitle,
    required this.desc,
    required this.leftLabel,
    required this.rightLabel,
  });
}

/// 调音魔棒 MSEB 视图 (1:1 严格对齐 C++ MagicTuningView.cpp 与 cpp_tab_2_mseb.png)
class MacMagicTuningView extends StatefulWidget {
  const MacMagicTuningView({super.key});

  @override
  State<MacMagicTuningView> createState() => _MacMagicTuningViewState();
}

class _MacMagicTuningViewState extends State<MacMagicTuningView> {
  static const List<MSEBParamDef> params = [
    MSEBParamDef(
      title: '声音冷暖',
      enTitle: 'Sound Temperature',
      desc: '冷暖音色倾斜',
      leftLabel: '偏冷通透',
      rightLabel: '偏暖醇厚',
    ),
    MSEBParamDef(
      title: '低音下潜',
      enTitle: 'Bass Extension',
      desc: '极低频下潜深度',
      leftLabel: '紧致轻盈',
      rightLabel: '深沉澎湃',
    ),
    MSEBParamDef(
      title: '低音质感',
      enTitle: 'Bass Texture',
      desc: '62–250Hz 低频厚薄',
      leftLabel: '速度迅捷',
      rightLabel: '蓬松弹性',
    ),
    MSEBParamDef(
      title: '音符厚度',
      enTitle: 'Note Thickness',
      desc: '基频饱满厚实度',
      leftLabel: '纤细轻盈',
      rightLabel: '扎实饱满',
    ),
    MSEBParamDef(
      title: '人声位置',
      enTitle: 'Vocal Distance',
      desc: '人声结像远近感',
      leftLabel: '舞台后缩',
      rightLabel: '贴耳靠前',
    ),
    MSEBParamDef(
      title: '女声甜度',
      enTitle: 'Female Overtones',
      desc: '高频泛音润泽度',
      leftLabel: '自然平直',
      rightLabel: '润泽甜美',
    ),
    MSEBParamDef(
      title: '齿音消除',
      enTitle: 'Sibilance Control',
      desc: '柔化唇齿毛刺音',
      leftLabel: '柔化去刺',
      rightLabel: '原生锋芒',
    ),
    MSEBParamDef(
      title: '瞬态存在感',
      enTitle: 'Attack Presence',
      desc: '2–4kHz 打击感调节',
      leftLabel: '柔和松弛',
      rightLabel: '硬朗凌厉',
    ),
    MSEBParamDef(
      title: '空气感',
      enTitle: 'Air & Treble',
      desc: '极高频空间泛音',
      leftLabel: '凝聚内敛',
      rightLabel: '空灵弥漫',
    ),
    MSEBParamDef(
      title: '声场明亮度',
      enTitle: 'Stage Brightness',
      desc: '低中频与高频平衡',
      leftLabel: '紧凑聚焦',
      rightLabel: '宏大宽广',
    ),
  ];

  late bool _isEnabled = false;
  late final List<double> _values = List.filled(10, 0.0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    MsebService.instance.addListener(_onMsebChanged);
  }

  @override
  void dispose() {
    MsebService.instance.removeListener(_onMsebChanged);
    super.dispose();
  }

  void _onMsebChanged() {
    if (!mounted) return;
    final mseb = MsebService.instance;
    if (_isEnabled != mseb.isEnabled || !listEquals(_values, mseb.values)) {
      setState(() {
        _isEnabled = mseb.isEnabled;
        for (int i = 0; i < 10; i++) {
          _values[i] = mseb.values[i];
        }
      });
    }
  }

  void _loadSettings() {
    final mseb = MsebService.instance;
    _isEnabled = mseb.isEnabled;
    for (int i = 0; i < 10; i++) {
      _values[i] = mseb.values[i];
    }
  }

  void _saveVal(int i, double v) {
    setState(() {
      _values[i] = v;
      MsebService.instance.setParam(i, v);
      _isEnabled = MsebService.instance.isEnabled;
      WebRemoteService.instance.broadcastMseb();
      WebRemoteService.instance.broadcastState();
    });
  }

  void _resetAll() {
    setState(() {
      MsebService.instance.resetAll();
      for (int i = 0; i < _values.length; i++) {
        _values[i] = 0.0;
      }
      WebRemoteService.instance.broadcastMseb();
      WebRemoteService.instance.broadcastState();
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
              const Text('10 段 DSP 音色映射 · 与图形均衡器叠加',
                  style: TextStyle(fontSize: 11, color: UIConfig.textMuted)),
              const SizedBox(height: 8),
              // 顶部 Header 栏：左侧标题，右侧按钮组
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '调音魔棒',
                    style: TextStyle(
                      fontSize: UIConfig.fontMedium,
                      fontWeight: FontWeight.bold,
                      color: UIConfig.textActive,
                    ),
                  ),
                  Row(
                    children: [
                      // 开关胶囊按钮
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isEnabled = !_isEnabled;
                            MsebService.instance.setEnabled(_isEnabled);
                            WebRemoteService.instance.broadcastMseb();
                            WebRemoteService.instance.broadcastState();
                          });
                        },
                        borderRadius: BorderRadius.circular(6.0),
                        child: Container(
                          height: 28.0,
                          padding: const EdgeInsets.symmetric(horizontal: 14.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isEnabled
                                ? accent.withValues(alpha: 0.28)
                                : const Color.fromRGBO(255, 255, 255, 0.05),
                            borderRadius: BorderRadius.circular(6.0),
                            border: Border.all(
                              color: _isEnabled
                                  ? accent
                                  : const Color.fromRGBO(255, 255, 255, 0.15),
                            ),
                          ),
                          child: Text(
                            _isEnabled ? '魔棒调音 · 已开启' : '魔棒调音 · 已旁路',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _isEnabled
                                  ? UIConfig.textActive
                                  : UIConfig.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),

                      // 一键全复位按钮
                      InkWell(
                        onTap: _resetAll,
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
                            '一键全复位',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: UIConfig.textNormal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14.0),

              // 核心列表区
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: params.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 8.0),
                  itemBuilder: (context, i) {
                    return _buildParamCard(i, params[i], _values[i], accent);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParamCard(
      int index, MSEBParamDef def, double val, Color accent) {
    final hasVal = val.abs() > 0.05;
    final valStr =
        val > 0 ? '+${val.toStringAsFixed(1)}' : val.toStringAsFixed(1);
    final activeDesc =
        val > 0 ? def.rightLabel : (val < 0 ? def.leftLabel : '原音直通');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(20, 26, 36, 0.7),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.08),
        ),
      ),
      child: Column(
        children: [
          // 第一行：中文标题 + 英文标题 + 解释说明 + 右侧胶囊状态徽标
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      def.title,
                      style: const TextStyle(
                        fontSize: UIConfig.fontRegular,
                        fontWeight: FontWeight.w600,
                        color: UIConfig.textActive,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      def.enTitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: accent,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Flexible(
                      child: Text(
                        def.desc,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.0,
                          color: UIConfig.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),

              // 右侧胶囊状态徽标
              if (hasVal)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: accent, width: 1.0),
                  ),
                  child: Text(
                    '$valStr $activeDesc',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8.0),

          // 第二行：左说明 ↔ 双向中心原点滑轨 ↔ 右说明+实时数值
          Row(
            children: [
              // 左说明
              SizedBox(
                width: 68.0,
                child: Text(
                  def.leftLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: val < -0.05 ? accent : UIConfig.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),

              // 双向中心滑轨
              Expanded(
                child: _MSEBBipolarSlider(
                  key: ValueKey('mseb_${index}_${accent.toARGB32()}'),
                  value: val,
                  accentColor: accent,
                  onChanged: (newVal) {
                    setState(() {
                      _values[index] = newVal;
                      _saveVal(index, newVal);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8.0),

              // 右说明 + 数值
              SizedBox(
                width: 106.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        def.rightLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: val > 0.05 ? accent : UIConfig.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      valStr,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        color: hasVal ? accent : UIConfig.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 双向中心原点发烧滑轨 (-10.0 ~ +10.0，从中心 0.0 向两侧展开激活线)
class _MSEBBipolarSlider extends StatelessWidget {
  final double value;
  final Color accentColor;
  final ValueChanged<double> onChanged;

  const _MSEBBipolarSlider({
    super.key,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  void _handleTouch(Offset localPos, double width) {
    // 0.0 在中心 (width / 2)
    final norm = (localPos.dx / width).clamp(0.0, 1.0);
    var v = -10.0 + norm * 20.0;
    v = (v * 10).round() / 10.0; // 0.1 精度
    if (v.abs() < 0.25) v = 0.0; // 原点吸附
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      const h = 32.0;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _handleTouch(d.localPosition, w),
        onPanDown: (d) => _handleTouch(d.localPosition, w),
        onPanUpdate: (d) => _handleTouch(d.localPosition, w),
        onTapDown: (d) => _handleTouch(d.localPosition, w),
        onDoubleTap: () => onChanged(0.0),
        child: Container(
          width: w,
          height: h,
          alignment: Alignment.center,
          child: SizedBox(
            width: w,
            height: 26.0,
            child: CustomPaint(
              painter: _MSEBSliderPainter(
                value: value,
                accentColor: accentColor,
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _MSEBSliderPainter extends CustomPainter {
  final double value;
  final Color accentColor;

  _MSEBSliderPainter({
    required this.value,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final cx = size.width / 2;
    final w = size.width;

    // 1. 底层暗色轨道线
    final trackPaint = Paint()
      ..color = const Color.fromRGBO(38, 45, 60, 0.85)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, cy), Offset(w, cy), trackPaint);

    // 2. 中心 0.0 原点刻度微标记
    final centerTickPaint = Paint()
      ..color = const Color.fromRGBO(110, 125, 150, 0.7)
      ..strokeWidth = 1.5;
    canvas.drawLine(
        Offset(cx, cy - 5.0), Offset(cx, cy + 5.0), centerTickPaint);

    // 3. 计算滑块位置
    final norm = ((value + 10.0) / 20.0).clamp(0.0, 1.0);
    final thumbX = norm * w;

    // 4. 动态发光填充轨 (由中心向滑块延伸)
    if (value.abs() > 0.05) {
      final xStart = cx;
      final xEnd = thumbX;

      // 发光外晕
      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.25)
        ..strokeWidth = 7.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(xStart, cy), Offset(xEnd, cy), glowPaint);

      // 主题色实线
      final activePaint = Paint()
        ..color = accentColor
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(xStart, cy), Offset(xEnd, cy), activePaint);
    }

    // 5. 椭圆胶囊药丸滑块旋钮 (Pill Thumb with Notch)
    const thumbW = 26.0;
    const thumbH = 14.0;
    final thumbRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(thumbX, cy), width: thumbW, height: thumbH),
      const Radius.circular(7.0),
    );

    // 外光晕
    if (value.abs() > 0.05) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(thumbX, cy),
              width: thumbW + 3.0,
              height: thumbH + 3.0),
          const Radius.circular(8.5),
        ),
        Paint()
          ..color = accentColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // 滑块主体
    final thumbBgPaint = Paint()..color = const Color.fromRGBO(36, 45, 62, 1.0);
    canvas.drawRRect(thumbRect, thumbBgPaint);

    // 滑块边框
    final thumbBorderPaint = Paint()
      ..color = value.abs() > 0.05
          ? accentColor
          : const Color.fromRGBO(85, 100, 125, 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(thumbRect, thumbBorderPaint);

    // 中心微型刻痕 (Notch)
    final notchPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.7)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(thumbX, cy - 3.5), Offset(thumbX, cy + 3.5), notchPaint);
  }

  @override
  bool shouldRepaint(covariant _MSEBSliderPainter old) {
    return old.value != value || old.accentColor != accentColor;
  }
}
