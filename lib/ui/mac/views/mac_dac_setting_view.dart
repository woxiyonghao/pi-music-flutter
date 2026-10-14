import 'package:flutter/material.dart';
import '../../../services/theme_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// DAC 解码设置视图 (1:1 严格对齐 C++ DACSettingView.cpp 与 cpp_tab_3_dac.png)
class MacDACSettingView extends StatefulWidget {
  const MacDACSettingView({super.key});

  @override
  State<MacDACSettingView> createState() => _MacDACSettingViewState();
}

class _MacDACSettingViewState extends State<MacDACSettingView> {
  int _selectedChip = 0; // 0: Apple 直通, 1: ES9038PRO, 2: AK4499EX, 3: CS43198, 4: R-2R 纯电阻, 5: ROHM 34301

  static const List<String> chips = [
    'Apple 直通',
    'ES9038PRO',
    'AK4499EX',
    'CS43198',
    'R-2R 纯电阻',
    'ROHM 34301',
  ];

  // Apple Direct 选项状态
  bool _exclusiveMode = true;
  int _appleExclusiveFlow = 0; // 0: Bit-Perfect 独占流, 1: 系统混音共享
  int _appleSampleRateTrack = 0; // 0: 原生跟随母带 (44.1k-192k), 1: 锁定 96kHz, 2: 锁定 192kHz
  int _appleImpedanceDrive = 0; // 0: 智能检测 (1.25V~3Vrms), 1: 强制高输出 (3.0Vrms), 2: 标准输出 (1.25Vrms)
  int _appleBitDepth = 0; // 0: 32-bit Float 浮点直通, 1: 24-bit 整数定点
  int _selectedDeviceIndex = 1; // 0: LS27B61x, 1: Mac mini扬声器

  @override
  Widget build(BuildContext context) {
    final accent = ThemeService.instance.accentColor;

    return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题「DAC 设置」
          const Text(
            'DAC 设置',
            style: TextStyle(
              fontSize: UIConfig.fontMedium,
              fontWeight: FontWeight.bold,
              color: UIConfig.textActive,
            ),
          ),
          const SizedBox(height: 14.0),

          // 顶部芯片架构分段选择 Chips
          Row(
            children: [
              for (int i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 8.0),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedChip = i),
                    borderRadius: BorderRadius.circular(7.0),
                    child: Container(
                      height: 32.0,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedChip == i
                            ? accent.withValues(alpha: 0.28)
                            : const Color.fromRGBO(255, 255, 255, 0.04),
                        borderRadius: BorderRadius.circular(7.0),
                        border: Border.all(
                          color: _selectedChip == i
                              ? accent
                              : const Color.fromRGBO(255, 255, 255, 0.1),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        chips[i],
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
            ],
          ),
          const SizedBox(height: 12.0),

          // 状态横幅卡片：声卡硬件与独占模式就绪指示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(20, 26, 36, 0.7),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.7),
                            blurRadius: 4.0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    const Text(
                      '声卡硬件: Mac mini扬声器  |  独占模式就绪 (起播锁定)  |  44 kHz',
                      style: TextStyle(
                        fontSize: UIConfig.fontSmall,
                        color: UIConfig.textActive,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => setState(() => _exclusiveMode = !_exclusiveMode),
                  borderRadius: BorderRadius.circular(6.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: _exclusiveMode
                          ? accent.withValues(alpha: 0.25)
                          : const Color.fromRGBO(255, 255, 255, 0.05),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: _exclusiveMode
                            ? accent
                            : const Color.fromRGBO(255, 255, 255, 0.15),
                      ),
                    ),
                    child: Text(
                      _exclusiveMode ? '独占: 已开启' : '独占: 已旁路',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _exclusiveMode ? UIConfig.textActive : UIConfig.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),

          // 主滚动区
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // 卡片 1：Mac 硬件直通通道
                _buildSectionCard(
                  title: 'Mac 硬件直通通道 (Apple CoreAudio Bit-Perfect)',
                  children: [
                    _buildSegmentedRow(
                      label: '硬件独占流',
                      options: const ['Bit-Perfect 独占流', '系统混音共享'],
                      selectedIndex: _appleExclusiveFlow,
                      onSelected: (idx) => setState(() => _appleExclusiveFlow = idx),
                      accent: accent,
                    ),
                    const SizedBox(height: 10.0),
                    _buildSegmentedRow(
                      label: '采样率追踪',
                      options: const ['原生跟随母带 (44.1k-192k)', '锁定 96kHz', '锁定 192kHz'],
                      selectedIndex: _appleSampleRateTrack,
                      onSelected: (idx) => setState(() => _appleSampleRateTrack = idx),
                      accent: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),

                // 卡片 2：高阻抗耳机智能驱动与数据精度
                _buildSectionCard(
                  title: '高阻抗耳机智能驱动与数据精度 (Impedance & Bit Depth)',
                  children: [
                    _buildSegmentedRow(
                      label: '阻抗驱动力',
                      options: const [
                        '智能检测 (1.25V~3Vrms)',
                        '强制高输出 (3.0Vrms)',
                        '标准输出 (1.25Vrms)',
                      ],
                      selectedIndex: _appleImpedanceDrive,
                      onSelected: (idx) => setState(() => _appleImpedanceDrive = idx),
                      accent: accent,
                    ),
                    const SizedBox(height: 10.0),
                    _buildSegmentedRow(
                      label: '数据位深',
                      options: const ['32-bit Float 浮点直通', '24-bit 整数定点'],
                      selectedIndex: _appleBitDepth,
                      onSelected: (idx) => setState(() => _appleBitDepth = idx),
                      accent: accent,
                    ),
                    const SizedBox(height: 10.0),
                    const Text(
                      'Apple Direct 说明: MacBook Pro 硬件直通，Bit-Perfect 独占流绕过系统混音，原生 0 损耗输出。支持 3.5mm 智能阻抗自适应放大。',
                      style: TextStyle(
                        fontSize: 11.0,
                        color: UIConfig.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),

                // 卡片 3：CoreAudio 音频输出设备拓扑 (实时枚举)
                _buildSectionCard(
                  title: 'CoreAudio 音频输出设备拓扑 (实时枚举)',
                  children: [
                    _buildDeviceRow(
                      index: 0,
                      name: 'LS27B61x',
                      arch: '架构: AppleHDA',
                      isBuiltIn: true,
                      isCurrent: _selectedDeviceIndex == 0,
                      onTap: () => setState(() => _selectedDeviceIndex = 0),
                      accent: accent,
                    ),
                    const SizedBox(height: 6.0),
                    _buildDeviceRow(
                      index: 1,
                      name: 'Mac mini扬声器',
                      arch: '架构: AppleHDA',
                      isBuiltIn: true,
                      isCurrent: _selectedDeviceIndex == 1,
                      onTap: () => setState(() => _selectedDeviceIndex = 1),
                      accent: accent,
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
  }

  Widget _buildSectionCard({
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

  Widget _buildSegmentedRow({
    required String label,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    required Color accent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120.0,
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
                  child: InkWell(
                    onTap: () => onSelected(i),
                    borderRadius: BorderRadius.circular(6.0),
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

  Widget _buildDeviceRow({
    required int index,
    required String name,
    required String arch,
    required bool isBuiltIn,
    required bool isCurrent,
    required VoidCallback onTap,
    required Color accent,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isCurrent
              ? accent.withValues(alpha: 0.18)
              : const Color.fromRGBO(255, 255, 255, 0.03),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: isCurrent
                ? accent
                : const Color.fromRGBO(255, 255, 255, 0.08),
            width: isCurrent ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: isCurrent ? UIConfig.textActive : UIConfig.textNormal,
                  ),
                ),
                const SizedBox(width: 30.0),
                Text(
                  arch,
                  style: const TextStyle(
                    fontSize: 11.0,
                    color: UIConfig.textMuted,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (isBuiltIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, 0.08),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: const Text(
                      'Mac 内置',
                      style: TextStyle(fontSize: 10.0, color: UIConfig.textNormal),
                    ),
                  ),
                if (isCurrent) ...[
                  const SizedBox(width: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(16, 185, 129, 0.25),
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: const Text(
                      '当前输出',
                      style: TextStyle(fontSize: 10.0, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
