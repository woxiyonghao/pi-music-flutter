import 'package:flutter/material.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// 调音魔棒 MSEB 视图 (1:1 严格对齐 C++ MagicTuningView.cpp)
class MacMagicTuningView extends StatefulWidget {
  const MacMagicTuningView({super.key});

  @override
  State<MacMagicTuningView> createState() => _MacMagicTuningViewState();
}

class _MacMagicTuningViewState extends State<MacMagicTuningView> {
  final Map<String, double> _msebParams = {
    '整体音色倾向 (冷峻 ↔ 温暖)': 0.0,
    '低频下潜深度 (轻微 ↔ 澎湃)': 0.0,
    '低频结像质感 (松散 ↔ 紧实)': 0.0,
    '人声远近定位 (靠后 ↔ 贴耳)': 0.0,
    '人声齿音消除 (通透 ↔ 顺滑)': 0.0,
    '高频通透空气感 (柔顺 ↔ 明亮)': 0.0,
    '瞬态结像冲击力 (柔和 ↔ 凌厉)': 0.0,
  };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '调音魔棒',
                    style: TextStyle(
                      fontSize: UIConfig.fontMedium,
                      fontWeight: FontWeight.bold,
                      color: UIConfig.textActive,
                    ),
                  ),
                  SizedBox(height: 4.0),
                  Text(
                    'MSEB 多维主观听感直觉调节引擎',
                    style: TextStyle(
                      fontSize: UIConfig.fontSmall,
                      color: UIConfig.textMuted,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    for (final k in _msebParams.keys) {
                      _msebParams[k] = 0.0;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 5.0),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(40, 48, 64, 0.7),
                    borderRadius: BorderRadius.circular(7.0),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.1),
                    ),
                  ),
                  child: const Text(
                    '重置平直',
                    style: TextStyle(
                      fontSize: UIConfig.fontSmall,
                      color: UIConfig.textNormal,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                for (final entry in _msebParams.entries)
                  _buildMsebSlider(entry.key, entry.value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMsebSlider(String name, double val) {
    final valStr = val > 0 ? '+${val.toStringAsFixed(1)}' : val.toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(20, 26, 36, 0.65),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: const Color.fromRGBO(255, 255, 255, 0.08),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: UIConfig.fontRegular,
                    color: UIConfig.textNormal,
                  ),
                ),
                Text(
                  valStr,
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    fontFamily: 'monospace',
                    color: val != 0.0 ? UIConfig.accent : UIConfig.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3.5,
                activeTrackColor: UIConfig.accent,
                inactiveTrackColor: const Color.fromRGBO(255, 255, 255, 0.12),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
              ),
              child: Slider(
                value: val,
                min: -10.0,
                max: 10.0,
                onChanged: (newVal) {
                  setState(() {
                    _msebParams[name] = newVal;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
