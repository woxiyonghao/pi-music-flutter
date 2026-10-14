import 'package:flutter/material.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// 图形均衡器视图 (1:1 严格对齐 C++ EQConfigView.cpp)
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

  int _selectedPreset = 0;
  List<double> _bandGains = List.filled(10, 0.0);
  bool _isEnabled = true;

  void _applyPreset(int index) {
    setState(() {
      _selectedPreset = index;
      _bandGains = List<double>.from(presets[index]['gains'] as List);
      _isEnabled = index != 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题与副标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  SizedBox(height: 4.0),
                  Text(
                    '10 段专业频段精调 · 纯净硬件直通',
                    style: TextStyle(
                      fontSize: UIConfig.fontSmall,
                      color: UIConfig.textMuted,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _isEnabled,
                activeColor: UIConfig.accent,
                onChanged: (val) {
                  setState(() {
                    _isEnabled = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // 预设选择胶囊栏
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < presets.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => _applyPreset(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 5.0),
                        decoration: BoxDecoration(
                          color: _selectedPreset == i
                              ? UIConfig.accent.withOpacity(0.3)
                              : const Color.fromRGBO(28, 34, 46, 0.7),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(
                            color: _selectedPreset == i
                                ? UIConfig.glassBorder
                                : const Color.fromRGBO(255, 255, 255, 0.1),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          presets[i]['name'] as String,
                          style: TextStyle(
                            fontSize: UIConfig.fontSmall,
                            color: _selectedPreset == i
                                ? UIConfig.textActive
                                : UIConfig.textNormal,
                            fontWeight: _selectedPreset == i
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20.0),

          // 10 段垂直推子
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 0; i < 10; i++)
                  _buildSliderColumn(i, bandLabels[i]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderColumn(int index, String label) {
    final gain = _bandGains[index];
    final gainStr = gain > 0 ? '+${gain.toStringAsFixed(1)}' : gain.toStringAsFixed(1);

    return Column(
      children: [
        Text(
          '${gainStr}dB',
          style: TextStyle(
            fontSize: 10.0,
            fontFamily: 'monospace',
            color: gain != 0.0 && _isEnabled
                ? UIConfig.accent
                : UIConfig.textMuted,
          ),
        ),
        const SizedBox(height: 6.0),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3.5,
                activeTrackColor:
                    _isEnabled ? UIConfig.accent : UIConfig.iconNormal,
                inactiveTrackColor: const Color.fromRGBO(255, 255, 255, 0.12),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 5.5,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
              ),
              child: Slider(
                value: gain.clamp(-12.0, 12.0),
                min: -12.0,
                max: 12.0,
                onChanged: _isEnabled
                    ? (val) {
                        setState(() {
                          _bandGains[index] = val;
                          _selectedPreset = presets.length - 1; // 自定义
                        });
                      }
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6.0),
        Text(
          label,
          style: const TextStyle(
            fontSize: UIConfig.fontSmall,
            color: UIConfig.textNormal,
          ),
        ),
      ],
    );
  }
}
