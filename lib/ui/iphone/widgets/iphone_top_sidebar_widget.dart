import 'package:flutter/material.dart';
import '../../../models/sidebar_tab.dart';

/// iPhone 竖屏顶部水平滚动 Sidebar 胶囊导航栏 (1:1 对齐设计手稿)
class IphoneTopSidebarWidget extends StatelessWidget {
  final SidebarTab currentTab;
  final ValueChanged<SidebarTab> onTabSelected;
  final VoidCallback? onSwitchOrientation;

  const IphoneTopSidebarWidget({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    this.onSwitchOrientation,
  });

  static const List<_TabItemData> _items = [
    _TabItemData(SidebarTab.allMusic, '所有音乐', Icons.music_note_rounded),
    _TabItemData(SidebarTab.scanMusic, '扫描', Icons.search_rounded),
    _TabItemData(SidebarTab.equalizer, '均衡器', Icons.tune_rounded),
    _TabItemData(SidebarTab.msebTuning, '调音', Icons.auto_fix_high_rounded),
    _TabItemData(SidebarTab.dacSettings, 'DAC设置', Icons.developer_board_rounded),
    _TabItemData(SidebarTab.themeSettings, '主题', Icons.palette_outlined),
    _TabItemData(SidebarTab.systemSettings, '设置', Icons.settings_rounded),
    _TabItemData(SidebarTab.webService, 'Web服务', Icons.desktop_windows_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: const Color(0xC7161C28),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: const Color(0x1FFFFFFF),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 5.0),
      child: Row(
        children: [
          // 横向可滚动导航胶囊
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5.0),
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = (item.tab == currentTab);
                return _buildPill(item, isSelected);
              },
            ),
          ),

          // 右侧快捷切换横屏方向按钮
          if (onSwitchOrientation != null) ...[
            Container(
              width: 1.0,
              height: 20.0,
              color: const Color(0x1FFFFFFF),
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
            ),
            IconButton(
              onPressed: onSwitchOrientation,
              tooltip: '切换至横屏模式',
              icon: const Icon(
                Icons.screen_rotation_rounded,
                size: 17.0,
                color: Color(0xFF94A3B8),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPill(_TabItemData item, bool isSelected) {
    return GestureDetector(
      onTap: () => onTabSelected(item.tab),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x2E00B4D8) : Colors.transparent,
          borderRadius: BorderRadius.circular(9.0),
          border: Border.all(
            color: isSelected ? const Color(0xA600B4D8) : Colors.transparent,
            width: 1.0,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x4D00B4D8),
                    blurRadius: 10.0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 13.5,
              color: isSelected ? const Color(0xFF00B4D8) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4.5),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItemData {
  final SidebarTab tab;
  final String label;
  final IconData icon;
  const _TabItemData(this.tab, this.label, this.icon);
}
