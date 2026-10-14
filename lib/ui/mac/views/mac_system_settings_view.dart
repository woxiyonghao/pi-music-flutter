import 'package:flutter/material.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// 系统设置视图 (1:1 严格对齐 C++ SystemSettingsView.cpp)
class MacSystemSettingsView extends StatefulWidget {
  const MacSystemSettingsView({super.key});

  @override
  State<MacSystemSettingsView> createState() => _MacSystemSettingsViewState();
}

class _MacSystemSettingsViewState extends State<MacSystemSettingsView> {
  int _bufferSizeIndex = 2; // 256 samples
  int _idleScreensaverIndex = 2; // 3分钟
  bool _exclusiveHogMode = true;

  static const List<String> bufferSizes = [
    '64 采样 (极低延迟 1.4ms)',
    '128 采样 (发烧低延迟 2.9ms)',
    '256 采样 (标准发烧推荐 5.8ms)',
    '512 采样 (高稳定性 11.6ms)',
    '1024 采样 (低功耗容错 23.2ms)',
  ];

  static const List<String> idleTimes = [
    '30 秒', '1 分钟', '3 分钟', '5 分钟', '永不进入屏保',
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '设置',
            style: TextStyle(
              fontSize: UIConfig.fontMedium,
              fontWeight: FontWeight.bold,
              color: UIConfig.textActive,
            ),
          ),
          const SizedBox(height: 16.0),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildCardSection(
                  title: '音频底层驱动与缓冲区 (CoreAudio Architecture)',
                  children: [
                    _buildDropdownRow(
                      '硬件 DMA 环形缓冲区尺寸',
                      '缓冲区越小延迟越低；如遇 CPU 重负载偶发断音可适度上调。',
                      bufferSizes,
                      _bufferSizeIndex,
                      (idx) => setState(() => _bufferSizeIndex = idx),
                    ),
                    const Divider(color: Color.fromRGBO(255, 255, 255, 0.08)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CoreAudio 独占直通 (Bit-Perfect Hog Mode)',
                              style: TextStyle(
                                fontSize: UIConfig.fontSmall,
                                color: UIConfig.textNormal,
                              ),
                            ),
                            SizedBox(height: 2.0),
                            Text(
                              '锁定声卡专属驱动访问，杜绝系统混音降质。',
                              style: TextStyle(
                                fontSize: 11.0,
                                color: UIConfig.textMuted,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _exclusiveHogMode,
                          activeColor: UIConfig.accent,
                          onChanged: (val) =>
                              setState(() => _exclusiveHogMode = val),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14.0),

                _buildCardSection(
                  title: '全景屏保与空闲沉浸 (Idle Screensaver)',
                  children: [
                    _buildDropdownRow(
                      '无操作自动全屏动效超时',
                      '超时后四角控制面板平滑淡出，进入名机表头大画面沉浸。',
                      idleTimes,
                      _idleScreensaverIndex,
                      (idx) => setState(() => _idleScreensaverIndex = idx),
                    ),
                  ],
                ),

                const SizedBox(height: 14.0),

                _buildCardSection(
                  title: '系统规格与版本信息 (System Information)',
                  children: [
                    _buildInfoRow('应用程序', 'PiHifiPlayer for macOS (Modern C++20 + Flutter 3)'),
                    _buildInfoRow('音频渲染引擎', 'Apple CoreAudio Zero-Copy SPSC RingBuffer'),
                    _buildInfoRow('解码母带格式', 'DSD (DSF/DFF), FLAC, WAV, ALAC, MP3, CUE'),
                    _buildInfoRow('目标物理刷新率', '60 FPS 垂直同步防撕裂'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(20, 26, 36, 0.7),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.1),
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
          const SizedBox(height: 10.0),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdownRow(
    String title,
    String subtitle,
    List<String> items,
    int selectedIndex,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: UIConfig.fontSmall,
            color: UIConfig.textNormal,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.0,
            color: UIConfig.textMuted,
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(10, 14, 20, 0.8),
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.1),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedIndex,
              dropdownColor: const Color(0xFF141923),
              isDense: true,
              style: const TextStyle(
                fontSize: UIConfig.fontSmall,
                color: UIConfig.textActive,
              ),
              items: [
                for (int i = 0; i < items.length; i++)
                  DropdownMenuItem(value: i, child: Text(items[i])),
              ],
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: UIConfig.fontSmall,
              color: UIConfig.textMuted,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: UIConfig.fontSmall,
              color: UIConfig.textNormal,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
