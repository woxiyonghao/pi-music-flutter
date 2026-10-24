import 'package:flutter/material.dart';
import '../../../services/music_database_service.dart';

/// iPhone 竖屏专享 TOPPING DX1 II DAC 解码设置视窗 (1:1 对齐设计手稿)
class IphoneDacSettingView extends StatefulWidget {
  const IphoneDacSettingView({super.key});

  @override
  State<IphoneDacSettingView> createState() => _IphoneDacSettingViewState();
}

class _IphoneDacSettingViewState extends State<IphoneDacSettingView> {
  int _selectedDevice = 1; // 0: 本机音频, 1: TOPPING DX1 II
  int _selectedFilter = 0; // 0: Minimum Phase Slow, 1: Linear Fast, 2: Minimum Fast, 3: Linear Slow

  static const List<_FilterOption> _filters = [
    _FilterOption('Minimum Phase Slow Roll-off', '发烧人声温暖纯润，无前冲振铃声'),
    _FilterOption('Linear Phase Fast Roll-off', '高频细节纤毫毕现，交响声场开阔'),
    _FilterOption('Minimum Phase Fast Roll-off', '低频紧实澎湃，瞬态响应迅猛'),
    _FilterOption('Linear Phase Slow Roll-off', '平滑音乐感，黑胶模拟温润味'),
  ];

  @override
  void initState() {
    super.initState();
    final filterStr = MusicDatabaseService.instance.getSetting('setting_dac_pcm_filter', '0');
    _selectedFilter = int.tryParse(filterStr)?.clamp(0, _filters.length - 1) ?? 0;
  }

  void _onFilterTap(int index) {
    setState(() => _selectedFilter = index);
    MusicDatabaseService.instance.setSetting('setting_dac_pcm_filter', index.toString());
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 顶部设备快速切换卡片
          Row(
            children: [
              Expanded(
                child: _buildDeviceButton(
                  title: '本机音频架构',
                  isSelected: _selectedDevice == 0,
                  onTap: () => setState(() => _selectedDevice = 0),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: _buildDeviceButton(
                  title: 'TOPPING DX1 II',
                  hasLed: true,
                  isSelected: _selectedDevice == 1,
                  onTap: () => setState(() => _selectedDevice = 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),

          // 2. DX1 II 核心硬件全景名片
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xB8161C28),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0x1FFFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Text('🎛️', style: TextStyle(fontSize: 16.0)),
                          SizedBox(width: 6.0),
                          Flexible(
                            child: Text(
                              'TOPPING DX1 II',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: const Color(0x2606D6A0),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: const Color(0x6606D6A0)),
                      ),
                      child: const Text(
                        'BIT-PERFECT DIRECT',
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF06D6A0),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3.0),
                const Text(
                  '桌面发烧级高解析平衡解码耳放一体机',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF828C9B)),
                ),
                const SizedBox(height: 10.0),

                // 2x2 参数网格
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecCell('解码核心', 'ES9039Q2M SABRE', const Color(0xFF00B4D8)),
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: _buildSpecCell('最大推流规格', '384kHz / 32-Bit', const Color(0xFFFFB703)),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecCell('DSD 原生推流', 'DSD256 Native', const Color(0xFF06D6A0)),
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: _buildSpecCell('USB 握手档位', 'UAC 2.0 (全速)', Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10.0),

          // 3. PCM 硬件滤波特性卡片
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xB8161C28),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Text('⚡', style: TextStyle(fontSize: 15.0)),
                          SizedBox(width: 6.0),
                          Flexible(
                            child: Text(
                              'PCM 滤波特性 (ES9039Q2M)',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0x1F00B4D8),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: const Text(
                        '8种硬件滤波',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF00B4D8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),

                // 滤波模式单选列表
                for (int i = 0; i < _filters.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6.0),
                  _buildFilterRow(
                    filter: _filters[i],
                    isSelected: _selectedFilter == i,
                    onTap: () => _onFilterTap(i),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10.0),

          // 4. 拓品 DX1 II 物理硬件拨片开关专属提示
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0x1AFB8500),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: const Color(0x59FB8500)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚠️', style: TextStyle(fontSize: 16.0)),
                SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '拓品 DX1 II · 硬件物理拨片提示',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFB8500),
                        ),
                      ),
                      SizedBox(height: 3.0),
                      Text(
                        'TOPPING DX1 II 的 UAC 模式是由机身背部物理硬件拨片直接控制。若需切换 UAC 1.0/2.0，请拨动机身背部开关后重新插拔 USB。',
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
  }

  Widget _buildDeviceButton({
    required String title,
    bool hasLed = false,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 36.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x2E00B4D8) : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isSelected ? const Color(0xFF00B4D8) : const Color(0x1AFFFFFF),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x4000B4D8),
                    blurRadius: 8.0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasLed) ...[
              Container(
                width: 6.0,
                height: 6.0,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF34C759),
                  boxShadow: [
                    BoxShadow(color: Color(0xFF34C759), blurRadius: 6.0),
                  ],
                ),
              ),
              const SizedBox(width: 5.0),
            ],
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecCell(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0x59000000),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: const Color(0x0FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.0, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2.0),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow({
    required _FilterOption filter,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x2400B4D8) : const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(7.0),
          border: Border.all(
            color: isSelected ? const Color(0x8000B4D8) : const Color(0x0FFFFFFF),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filter.name,
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    filter.desc,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF828C9B)),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 15.0,
              color: isSelected ? const Color(0xFF00B4D8) : const Color(0xFF475569),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterOption {
  final String name;
  final String desc;
  const _FilterOption(this.name, this.desc);
}
