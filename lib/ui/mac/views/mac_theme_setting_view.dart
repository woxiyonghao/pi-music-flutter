import 'package:flutter/material.dart';
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
  int _selectedPresetIndex = 0;

  static const List<Map<String, dynamic>> themePresets = [
    {'name': '现代玫瑰红', 'desc': '标准 Apple Music 发烧玫红', 'color': Color(0xFFFA2D48)},
    {'name': '麦景图经典湖蓝', 'desc': 'McIntosh 标志性幽蓝夜光', 'color': Color(0xFF0077B6)},
    {'name': '金嗓子香槟金', 'desc': 'Accuphase 顶级香槟琥珀', 'color': Color(0xFFFFB703)},
    {'name': '赛博霓虹翠绿', 'desc': 'Cyberpunk 纯澈电光翠绿', 'color': Color(0xFF06D6A0)},
    {'name': '英伦深绿', 'desc': 'British Racing 优雅古董', 'color': Color(0xFF1B4332)},
    {'name': '钛金冷灰', 'desc': 'Titanium 精工高阻尼灰度', 'color': Color(0xFF8D99AE)},
    {'name': '纯净暖琥珀', 'desc': '真空电子管温润琥珀', 'color': Color(0xFFFB8500)},
    {'name': '奢华玫瑰金', 'desc': 'Rose Gold 贵族金属温润', 'color': Color(0xFFE07A5F)},
  ];

  static const List<Map<String, dynamic>> visualizerModes = [
    {'type': VisualizerType.ledSpectrum, 'name': '48列全景 LED 频谱'},
    {'type': VisualizerType.mcIntosh, 'name': '名机动圈大表头'},
    {'type': VisualizerType.accuphase, 'name': '金嗓子旗舰大表头'},
    {'type': VisualizerType.tapeReel, 'name': '复古开盘磁带机'},
    {'type': VisualizerType.siriWave, 'name': 'Siri 流光声波'},
    {'type': VisualizerType.siriOrb, 'name': 'Siri 悬浮微光球'},
    {'type': VisualizerType.bubbles, 'name': '音乐微光气泡'},
    {'type': VisualizerType.pureBlack, 'name': '极简纯黑纯音直通'},
    {'type': VisualizerType.neonWave, 'name': '电光霓虹声波'},
    {'type': VisualizerType.cyberGrid, 'name': '赛博粒子网格'},
    {'type': VisualizerType.glassClock, 'name': '液态玻璃时钟'},
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题与「恢复名机预设」按钮
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
                onTap: () {
                  setState(() {
                    _selectedPresetIndex = 0;
                  });
                  widget.onVisualizerChanged(VisualizerType.ledSpectrum);
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
          const SizedBox(height: 16.0),

          // 主滚动区
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // 板块一：名机预设
                _buildSectionHeader('预设'),
                const SizedBox(height: 8.0),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 12.0,
                    mainAxisExtent: 48.0,
                  ),
                  itemCount: themePresets.length,
                  itemBuilder: (context, i) {
                    final item = themePresets[i];
                    final isCur = _selectedPresetIndex == i;
                    final color = item['color'] as Color;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPresetIndex = i;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          color: isCur
                              ? color.withOpacity(0.18)
                              : const Color.fromRGBO(255, 255, 255, 0.04),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: isCur
                                ? color
                                : const Color.fromRGBO(255, 255, 255, 0.1),
                            width: isCur ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12.0,
                              height: 12.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                boxShadow: [
                                  BoxShadow(
                                      color: color.withOpacity(0.6),
                                      blurRadius: 4.0),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: UIConfig.fontRegular,
                                      fontWeight: isCur
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isCur
                                          ? UIConfig.textActive
                                          : UIConfig.textNormal,
                                    ),
                                  ),
                                  Text(
                                    item['desc'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.0,
                                      color: UIConfig.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCur)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4.0),
                                  border: Border.all(color: color, width: 1.0),
                                ),
                                child: const Text(
                                  '已激活',
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20.0),

                // 板块二：背景律动动效
                _buildSectionHeader('背景律动'),
                const SizedBox(height: 8.0),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 10.0,
                    mainAxisExtent: 32.0,
                  ),
                  itemCount: visualizerModes.length,
                  itemBuilder: (context, i) {
                    final item = visualizerModes[i];
                    final isCur = widget.currentVisualizer == item['type'];

                    return GestureDetector(
                      onTap: () {
                        widget.onVisualizerChanged(item['type'] as VisualizerType);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCur
                              ? UIConfig.accent.withOpacity(0.25)
                              : const Color.fromRGBO(255, 255, 255, 0.04),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(
                            color: isCur
                                ? UIConfig.accent
                                : const Color.fromRGBO(255, 255, 255, 0.1),
                          ),
                        ),
                        child: Text(
                          item['name'] as String,
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: isCur ? FontWeight.w600 : FontWeight.normal,
                            color: isCur
                                ? UIConfig.textActive
                                : UIConfig.textNormal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: UIConfig.fontRegular,
        fontWeight: FontWeight.w600,
        color: UIConfig.textActive,
      ),
    );
  }
}
