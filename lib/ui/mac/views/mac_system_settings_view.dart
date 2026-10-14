import 'package:flutter/material.dart';
import '../../../services/music_database_service.dart';
import '../../../services/theme_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// 系统设置视图 (1:1 严格对齐 C++ SystemSettingsView.cpp，纯平铺按钮组，无任何 popup/dropdown，完整 SQLite 持久化)
class MacSystemSettingsView extends StatefulWidget {
  const MacSystemSettingsView({super.key});

  @override
  State<MacSystemSettingsView> createState() => _MacSystemSettingsViewState();
}

class _MacSystemSettingsViewState extends State<MacSystemSettingsView> {
  // 板块一：音频重放与时钟引擎
  int _sampleRateMode = 0;       // 0: Bit-Perfect 源码直出, 1: 超采样 192k/24b, 2: 极频 384k/32b
  int _dsdMode = 0;             // 0: DoP (DSD over PCM), 1: Native 原生直通, 2: DSD 软解 PCM
  int _bufferSizeMode = 1;      // 0: 64帧, 1: 256帧 (标准发烧), 2: 512帧
  int _fadeDurationMode = 2;    // 0: 关闭, 1: 0.3s, 2: 0.5s (发烧标准), 3: 1.0s

  // 板块二：硬件性能与显示控制
  int _cpuGovernor = 0;         // 0: Performance (纯音锁频最高), 1: Schedutil
  double _screenBrightness = 0.85; // 85%
  int _screenTimeoutMode = 0;   // 0: 从不, 1: 5分钟, 2: 15分钟, 3: 30分钟
  int _idleFullscreenMode = 4;  // 0: 15秒, 1: 30秒, 2: 1分钟, 3: 5分钟, 4: 永不

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final db = MusicDatabaseService.instance;
    _sampleRateMode = int.tryParse(db.getSetting('setting_sample_rate', '0'))?.clamp(0, 2) ?? 0;
    _dsdMode = int.tryParse(db.getSetting('setting_dsd_mode', '0'))?.clamp(0, 2) ?? 0;
    _bufferSizeMode = int.tryParse(db.getSetting('setting_buffer_size', '1'))?.clamp(0, 2) ?? 1;
    _fadeDurationMode = int.tryParse(db.getSetting('setting_fade_duration_mode', '2'))?.clamp(0, 3) ?? 2;
    _cpuGovernor = int.tryParse(db.getSetting('setting_cpu_governor', '0'))?.clamp(0, 1) ?? 0;
    _screenBrightness = double.tryParse(db.getSetting('setting_brightness', '0.85'))?.clamp(0.1, 1.0) ?? 0.85;
    _screenTimeoutMode = int.tryParse(db.getSetting('setting_screen_timeout', '0'))?.clamp(0, 3) ?? 0;
    _idleFullscreenMode = int.tryParse(db.getSetting('setting_idle_fullscreen', '4'))?.clamp(0, 4) ?? 4;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题「系统设置」 (无 subtitle，无右上角杂项)
          const Text(
            '系统设置',
            style: TextStyle(
              fontSize: UIConfig.fontMedium,
              fontWeight: FontWeight.bold,
              color: UIConfig.textActive,
            ),
          ),
          const SizedBox(height: 16.0),

          // 滚动内容区
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // 板块一：音频重放与时钟引擎
                _buildCardContainer(
                  title: '音频重放与时钟引擎',
                  children: [
                    _buildButtonGroupRow(
                      label: '输出采样率',
                      options: const [
                        'Bit-Perfect 源码直出',
                        '超采样 192kHz/24Bit',
                        '极频 384kHz/32Bit',
                      ],
                      selectedIndex: _sampleRateMode,
                      onSelected: (idx) {
                        setState(() => _sampleRateMode = idx);
                        MusicDatabaseService.instance.setSetting('setting_sample_rate', idx.toString());
                      },
                    ),
                    const SizedBox(height: 10.0),
                    _buildButtonGroupRow(
                      label: 'DSD 播放模式',
                      options: const [
                        'DoP (DSD over PCM)',
                        'Native 原生直通',
                        'DSD 软解 PCM',
                      ],
                      selectedIndex: _dsdMode,
                      onSelected: (idx) {
                        setState(() => _dsdMode = idx);
                        MusicDatabaseService.instance.setSetting('setting_dsd_mode', idx.toString());
                      },
                    ),
                    const SizedBox(height: 10.0),
                    _buildButtonGroupRow(
                      label: '硬件缓冲深度',
                      options: const [
                        '64 帧 (极低延迟)',
                        '256 帧 (标准发烧)',
                        '512 帧 (防爆音深缓冲)',
                      ],
                      selectedIndex: _bufferSizeMode,
                      onSelected: (idx) {
                        setState(() => _bufferSizeMode = idx);
                        MusicDatabaseService.instance.setSetting('setting_buffer_size', idx.toString());
                      },
                    ),
                    const SizedBox(height: 10.0),
                    _buildButtonGroupRow(
                      label: '切歌过渡效果',
                      options: const [
                        '关闭 (直接切歌)',
                        '0.3 秒 (极速)',
                        '0.5 秒 (发烧标准)',
                        '1.0 秒 (悠扬慢淡)',
                      ],
                      selectedIndex: _fadeDurationMode,
                      onSelected: (idx) {
                        setState(() => _fadeDurationMode = idx);
                        MusicDatabaseService.instance.setSetting('setting_fade_duration_mode', idx.toString());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14.0),

                // 板块二：硬件性能与显示控制
                _buildCardContainer(
                  title: '硬件性能与显示控制',
                  children: [
                    _buildButtonGroupRow(
                      label: 'CPU 调频策略',
                      options: const [
                        'Performance (纯音锁频最高)',
                        'Schedutil (动态温控平衡)',
                      ],
                      selectedIndex: _cpuGovernor,
                      onSelected: (idx) {
                        setState(() => _cpuGovernor = idx);
                        MusicDatabaseService.instance.setSetting('setting_cpu_governor', idx.toString());
                      },
                    ),
                    const SizedBox(height: 10.0),
                    _buildSliderRow(
                      label: '屏幕背光亮度',
                      value: _screenBrightness,
                      onChanged: (val) {
                        setState(() => _screenBrightness = val);
                        MusicDatabaseService.instance.setSetting('setting_brightness', val.toStringAsFixed(2));
                      },
                    ),
                    const SizedBox(height: 10.0),
                    _buildButtonGroupRow(
                      label: '自动息屏待机',
                      options: const [
                        '从不',
                        '5 分钟',
                        '15 分钟',
                        '30 分钟',
                      ],
                      selectedIndex: _screenTimeoutMode,
                      onSelected: (idx) {
                        setState(() => _screenTimeoutMode = idx);
                        MusicDatabaseService.instance.setSetting('setting_screen_timeout', idx.toString());
                      },
                    ),
                    const SizedBox(height: 10.0),
                    _buildButtonGroupRow(
                      label: '空余时间显示全屏',
                      options: const [
                        '15 秒',
                        '30 秒',
                        '1 分钟',
                        '5 分钟',
                        '永不',
                      ],
                      selectedIndex: _idleFullscreenMode,
                      onSelected: (idx) {
                        setState(() => _idleFullscreenMode = idx);
                        MusicDatabaseService.instance.setSetting('setting_idle_fullscreen', idx.toString());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  /// 封装毛玻璃底板卡片
  Widget _buildCardContainer({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(20, 26, 36, 0.7),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: UIConfig.fontRegular,
              fontWeight: FontWeight.w600,
              color: UIConfig.textActive,
            ),
          ),
          const SizedBox(height: 14.0),
          ...children,
        ],
      ),
    );
  }

  /// 纯平铺段选按钮行 (1:1 对齐 renderButtonGroup)
  Widget _buildButtonGroupRow({
    required String label,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
  }) {
    final accent = ThemeService.instance.accentColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 130.0,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: UIConfig.fontSmall,
              color: UIConfig.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              for (int i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 8.0),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(i),
                    child: Container(
                      height: 28.0,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedIndex == i
                            ? accent.withValues(alpha: 0.28)
                            : const Color.fromRGBO(255, 255, 255, 0.04),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(
                          color: selectedIndex == i
                              ? accent
                              : const Color.fromRGBO(255, 255, 255, 0.1),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        options[i],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: selectedIndex == i
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selectedIndex == i
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
        ),
      ],
    );
  }

  /// 屏幕亮度平滑滑块行
  Widget _buildSliderRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final accent = ThemeService.instance.accentColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 130.0,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: UIConfig.fontSmall,
              color: UIConfig.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3.5,
                    activeTrackColor: accent,
                    inactiveTrackColor: const Color.fromRGBO(255, 255, 255, 0.12),
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6.0,
                      elevation: 2.0,
                    ),
                    overlayColor: accent.withValues(alpha: 0.2),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                  ),
                  child: Slider(
                    value: value,
                    min: 0.1,
                    max: 1.0,
                    onChanged: onChanged,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              SizedBox(
                width: 40.0,
                child: Text(
                  '${(value * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: UIConfig.fontSmall,
                    color: UIConfig.textActive,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
