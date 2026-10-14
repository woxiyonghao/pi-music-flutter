import 'package:flutter/material.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// DAC 解码设置视图 (1:1 严格对齐 C++ DACSettingView.cpp)
class MacDACSettingView extends StatefulWidget {
  const MacDACSettingView({super.key});

  @override
  State<MacDACSettingView> createState() => _MacDACSettingViewState();
}

class _MacDACSettingViewState extends State<MacDACSettingView> {
  int _selectedChip = 0; // 0: Apple, 1: ES9038PRO, 2: AK4499EX, 3: CS43198, 4: R-2R, 5: ROHM

  static const List<Map<String, String>> chipTabs = [
    {'name': 'Apple 直通', 'sub': 'Mac 原生硬件直通'},
    {'name': 'ES9038PRO', 'sub': 'ESS Sabre 旗舰并联'},
    {'name': 'AK4499EX', 'sub': 'AKM 旭化成 Velvet'},
    {'name': 'CS43198', 'sub': 'Cirrus Logic Master'},
    {'name': 'R-2R 纯电阻', 'sub': '分立电阻 NOS/OS'},
    {'name': 'ROHM 34301', 'sub': 'MUS-IC BD34301'},
  ];

  bool _exclusiveMode = true;
  int _filterIndex = 0;
  int _dsdBypass = 0;
  int _dpllBand = 1;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          const Text(
            'DAC 设置',
            style: TextStyle(
              fontSize: UIConfig.fontMedium,
              fontWeight: FontWeight.bold,
              color: UIConfig.textActive,
            ),
          ),
          const SizedBox(height: 16.0),

          // 顶部芯片架构分段选择器
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < chipTabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedChip = i;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: _selectedChip == i
                              ? UIConfig.accent.withOpacity(0.3)
                              : const Color.fromRGBO(255, 255, 255, 0.05),
                          borderRadius: BorderRadius.circular(7.0),
                          border: Border.all(
                            color: _selectedChip == i
                                ? UIConfig.accent
                                : const Color.fromRGBO(255, 255, 255, 0.1),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          chipTabs[i]['name']!,
                          style: TextStyle(
                            fontSize: UIConfig.fontSmall,
                            fontWeight: _selectedChip == i
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _selectedChip == i
                                ? UIConfig.textActive
                                : UIConfig.textNormal,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20.0),

          // 芯片硬件参数面板
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildSectionCard(
                  title: '核心传输通道 (Bit-Perfect Hog Mode)',
                  children: [
                    _buildSwitchTile(
                      'CoreAudio 硬件独占访问 (Hog Mode)',
                      '屏蔽系统音频混音器与重采样，锁定比特完美直通。',
                      _exclusiveMode,
                      (val) => setState(() => _exclusiveMode = val),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                _buildSectionCard(
                  title: '数字滤波器 (Digital FIR Filter)',
                  children: [
                    _buildOptionGroup(
                      '滤波器滚降特性',
                      ['线性相位快速', '线性相位慢速', '最小相位快速', '最小相位慢速', '低色散超缓'],
                      _filterIndex,
                      (idx) => setState(() => _filterIndex = idx),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                _buildSectionCard(
                  title: 'DSD 原生硬解通道 (Direct DSD Path)',
                  children: [
                    _buildOptionGroup(
                      'DSD 解码模式',
                      ['原生硬解直通 (Direct DSD)', 'Delta-Sigma 调制', 'DSD over PCM (DoP)'],
                      _dsdBypass,
                      (idx) => setState(() => _dsdBypass = idx),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                _buildSectionCard(
                  title: '时钟防抖锁相环 (DPLL Jitter Eliminator)',
                  children: [
                    _buildOptionGroup(
                      'DPLL 带宽',
                      ['最低抖动 (Lowest Jitter)', '标准带宽 (Standard)', '高容错带宽 (High Tolerance)'],
                      _dpllBand,
                      (idx) => setState(() => _dpllBand = idx),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
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
          width: 1.0,
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

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
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
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: UIConfig.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildOptionGroup(
    String label,
    List<String> options,
    int selectedIndex,
    ValueChanged<int> onSelect,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: UIConfig.fontSmall,
            color: UIConfig.textMuted,
          ),
        ),
        const SizedBox(height: 6.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 6.0,
          children: [
            for (int i = 0; i < options.length; i++)
              GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? UIConfig.accent.withOpacity(0.25)
                        : const Color.fromRGBO(255, 255, 255, 0.04),
                    borderRadius: BorderRadius.circular(5.0),
                    border: Border.all(
                      color: selectedIndex == i
                          ? UIConfig.accent
                          : const Color.fromRGBO(255, 255, 255, 0.1),
                    ),
                  ),
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 11.0,
                      color: selectedIndex == i
                          ? UIConfig.textActive
                          : UIConfig.textNormal,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
