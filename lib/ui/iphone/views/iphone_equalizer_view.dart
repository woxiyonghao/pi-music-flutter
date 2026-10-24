import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';

/// iPhone 竖屏 10 段发烧图形均衡器视窗 (1:1 对齐设计手稿)
class IphoneEqualizerView extends StatefulWidget {
  const IphoneEqualizerView({super.key});

  @override
  State<IphoneEqualizerView> createState() => _IphoneEqualizerViewState();
}

class _IphoneEqualizerViewState extends State<IphoneEqualizerView> {
  int _selectedPreset = 0; // 0: 发烧人声, 1: 纯净直通, 2: 动感重低音, 3: 古典交响

  static const List<String> _presets = [
    '发烧人声',
    '纯净直通',
    '动感重低音',
    '古典交响',
  ];

  static const List<List<double>> _presetBands = [
    [1.5, 1.0, 0.5, -1.0, 0.5, 2.0, 3.5, 2.5, 1.0, 0.0], // 发烧人声
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],   // 纯净直通
    [4.5, 3.8, 2.5, 1.0, 0.0, 0.0, 0.5, 1.5, 2.0, 1.5],   // 动感重低音
    [2.0, 1.5, 0.5, 0.0, 0.0, 1.0, 1.5, 2.5, 3.0, 2.5],   // 古典交响
  ];

  static const List<String> _freqLabels = [
    '31', '62', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'
  ];

  void _applyPreset(int index) {
    setState(() => _selectedPreset = index);
    final service = HifiAudioService.instance;
    final bands = _presetBands[index];
    service.setEqAndBands(index != 1, bands, selectedPreset: index);
  }

  void _updateBand(int index, double gain) {
    final service = HifiAudioService.instance;
    service.setEqBand(index, gain);
    if (!service.eqEnabled) {
      service.setEqEnabled(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HifiAudioService.instance,
      builder: (context, _) {
        final service = HifiAudioService.instance;
        final eqBands = service.eqBands;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 顶部预设胶囊横向滑动条
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (int i = 0; i < _presets.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6.0),
                      _buildPresetPill(
                        label: _presets[i],
                        isSelected: _selectedPreset == i,
                        onTap: () => _applyPreset(i),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10.0),

              // 2. EQ 响应平滑曲线卡片
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: const Color(0xB8161C28),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'EQ 响应平滑曲线',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0x2606D6A0),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: const Text(
                            '+3.0 dB @ 2.5kHz',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF06D6A0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    SizedBox(
                      height: 48.0,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _EqCurvePainter(eqBands),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10.0),

              // 3. 10 段高精垂直滑块面板
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: const Color(0xB8161C28),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Column(
                  children: [
                    // 标头与 Preamp 增益
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '前级增益 (Preamp): -2.5 dB',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF828C9B),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.0),
                          Text(
                            '10-BAND EQ',
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00B4D8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // 10 个纵向滑块排列
                    SizedBox(
                      height: 160.0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (int i = 0; i < 10; i++)
                            _buildVerticalBand(
                              index: i,
                              freq: _freqLabels[i],
                              gain: eqBands.length > i ? eqBands[i] : 0.0,
                              onChanged: (val) => _updateBand(i, val),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x3300B4D8) : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: isSelected ? const Color(0xFF00B4D8) : const Color(0x1AFFFFFF),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalBand({
    required int index,
    required String freq,
    required double gain,
    required ValueChanged<double> onChanged,
  }) {
    // gain 范围 -12.0 到 +12.0，映射到 0.0 到 1.0
    final normalized = ((gain + 12.0) / 24.0).clamp(0.0, 1.0);
    final gainText = gain > 0 ? '+${gain.toStringAsFixed(1)}' : gain.toStringAsFixed(1);

    return SizedBox(
      width: 28.0,
      child: Column(
        children: [
          // 顶部 dB 数值
          Text(
            gainText,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00B4D8),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4.0),

          // 滑块轨槽
          Expanded(
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                // 拖拽手势交互
                final delta = -details.primaryDelta! / 110.0 * 24.0;
                onChanged((gain + delta).clamp(-12.0, 12.0));
              },
              child: Container(
                width: 28.0,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 背景槽
                    Container(
                      width: 5.0,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    // 填充高度
                    FractionallySizedBox(
                      heightFactor: normalized,
                      child: Container(
                        width: 5.0,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00B4D8), Color(0xFF06D6A0)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    // 滑块旋钮
                    Positioned(
                      bottom: (115.0 * normalized).clamp(0.0, 115.0),
                      child: Container(
                        width: 14.0,
                        height: 7.0,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x8000B4D8),
                              blurRadius: 6.0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4.0),

          // 底部频率标牌
          Text(
            freq,
            style: const TextStyle(
              fontSize: 9.0,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 绘制贝塞尔 EQ 曲线
class _EqCurvePainter extends CustomPainter {
  final List<double> bands;
  _EqCurvePainter(this.bands);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0x26FFFFFF)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    // 0dB 参考基线
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), linePaint);

    if (bands.isEmpty) return;

    final curvePaint = Paint()
      ..color = const Color(0xFF00B4D8)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = <Offset>[];
    for (int i = 0; i < bands.length; i++) {
      final x = (size.width / (bands.length - 1)) * i;
      // gain -12 ~ +12 映射到高度
      final y = centerY - (bands[i] / 12.0) * (size.height * 0.42);
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter oldDelegate) => true;
}
