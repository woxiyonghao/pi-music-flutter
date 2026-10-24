import 'package:flutter/material.dart';
import '../../../services/theme_service.dart';
import '../../visualizers/visualizer_type.dart';

/// iPhone 竖屏专享发烧名机主题与背景律动视窗 (1:1 对齐设计手稿)
class IphoneThemeSettingView extends StatelessWidget {
  const IphoneThemeSettingView({super.key});

  static const List<_PresetTheme> _presets = [
    _PresetTheme('麦景图湖蓝', 'McIntosh Blue', Color(0xFF00B4D8), VisualizerType.mcIntosh),
    _PresetTheme('金嗓子香槟金', 'Accuphase Amber', Color(0xFFFFB703), VisualizerType.accuphase),
    _PresetTheme('复古开盘机', 'Tape Reel', Color(0xFFE2E8F0), VisualizerType.tapeReel),
    _PresetTheme('极光LED频谱', 'LED Spectrum', Color(0xFF06D6A0), VisualizerType.ledSpectrum),
    _PresetTheme('纯音极黑', 'Pure Dark', Color(0xFF828C9B), VisualizerType.glassClock),
  ];

  static const List<_VisualModeItem> _modes = [
    _VisualModeItem('经典动圈大表头', Icons.speed_rounded, VisualizerType.mcIntosh),
    _VisualModeItem('金嗓子旗舰大表头', Icons.speed_outlined, VisualizerType.accuphase),
    _VisualModeItem('复古磁带旋转', Icons.album_rounded, VisualizerType.tapeReel),
    _VisualModeItem('48列全景LED频谱', Icons.equalizer_rounded, VisualizerType.ledSpectrum),
    _VisualModeItem('极光声波流动', Icons.waves_rounded, VisualizerType.neonWave),
    _VisualModeItem('液态玻璃时钟', Icons.access_time_rounded, VisualizerType.glassClock),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final theme = ThemeService.instance;
        final currentMode = VisualizerType.values[theme.backgroundVisualMode.clamp(0, VisualizerType.values.length - 1)];

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 名机经典预设横排
              const Text(
                '名机经典视觉预设',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8.0),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (final p in _presets) ...[
                      _buildPresetCard(p, currentMode, theme),
                      const SizedBox(width: 8.0),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14.0),

              // 2. 背景动效律动模式选择网格
              const Text(
                '背景动效律动',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8.0),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 2.8,
                ),
                itemCount: _modes.length,
                itemBuilder: (context, index) {
                  final item = _modes[index];
                  final isSelected = (item.type == currentMode);
                  return _buildModeCard(item, isSelected, theme);
                },
              ),
              const SizedBox(height: 14.0),

              // 3. iPhone 专享规则标牌卡片 (明确无全屏屏保/常驻控制)
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: const Color(0x1A00B4D8),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: const Color(0x4D00B4D8)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📱', style: TextStyle(fontSize: 16.0)),
                    SizedBox(width: 8.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'iPhone 竖屏专享规范',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00B4D8),
                            ),
                          ),
                          SizedBox(height: 3.0),
                          Text(
                            '依要求：iPhone 竖屏模式不开启任何全屏屏保或熄屏移出，顶部 Sidebar 导航、功能视窗、歌曲信息卡片与播放底栏始终常驻，确保随时单手触达。',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFFCBD5E1),
                              height: 1.4,
                            ),
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

  Widget _buildPresetCard(_PresetTheme p, VisualizerType currentMode, ThemeService theme) {
    final isSelected = (p.type == currentMode);
    return GestureDetector(
      onTap: () {
        theme.setBackgroundVisualMode(p.type.index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 105.0,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? p.color.withValues(alpha: 0.22) : const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(9.0),
          border: Border.all(
            color: isSelected ? p.color : const Color(0x1FFFFFFF),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: p.color.withValues(alpha: 0.35),
                    blurRadius: 10.0,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              p.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.0,
                color: isSelected ? p.color : const Color(0xFF828C9B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(_VisualModeItem item, bool isSelected, ThemeService theme) {
    return GestureDetector(
      onTap: () {
        theme.setBackgroundVisualMode(item.type.index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x2600B4D8) : const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isSelected ? const Color(0xFF00B4D8) : const Color(0x14FFFFFF),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 16.0,
              color: isSelected ? const Color(0xFF00B4D8) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6.0),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTheme {
  final String title;
  final String subtitle;
  final Color color;
  final VisualizerType type;
  const _PresetTheme(this.title, this.subtitle, this.color, this.type);
}

class _VisualModeItem {
  final String title;
  final IconData icon;
  final VisualizerType type;
  const _VisualModeItem(this.title, this.icon, this.type);
}
