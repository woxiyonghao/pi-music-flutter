import 'package:flutter/material.dart';
import '../../models/sidebar_tab.dart';
import '../../models/track.dart';
import '../../services/theme_service.dart';
import '../../theme/ui_config.dart';
import '../common/glass_card.dart';

/// macOS 专业侧边栏 (1:1 严格对齐 C++ SidebarView.cpp / SidebarFeatureWidget.cpp / SidebarDacWidget.cpp)
class MacSidebarWidget extends StatelessWidget {
  final SidebarTab currentTab;
  final int selectedPlaylistId;
  final List<Playlist> playlists;
  final String dacName;
  final bool isDacConnected;
  final ValueChanged<SidebarTab> onTabSelected;
  final ValueChanged<int> onPlaylistSelected;
  final VoidCallback onCreatePlaylist;
  final VoidCallback onDacClicked;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? gap;
  final bool? showWebService;

  const MacSidebarWidget({
    super.key,
    required this.currentTab,
    this.selectedPlaylistId = 0,
    required this.playlists,
    this.dacName = 'Android AAudio',
    this.isDacConnected = true,
    required this.onTabSelected,
    required this.onPlaylistSelected,
    required this.onCreatePlaylist,
    required this.onDacClicked,
    this.padding,
    this.width,
    this.gap,
    this.showWebService,
  });

  @override
  Widget build(BuildContext context) {
    final actualPadding = padding ??
        const EdgeInsets.only(
          left: UIConfig.containerMarginX,
          right: UIConfig.containerMarginX,
          top: UIConfig.containerMarginY,
          bottom: UIConfig.containerMarginY,
        );
    final actualWidth = width ?? UIConfig.sidebarWidth;
    final actualGap = gap ?? UIConfig.containerGap;
    final shouldShowWeb = showWebService ?? true;

    return Container(
      width: actualWidth,
      padding: actualPadding,
      child: Column(
        children: [
          // 1. 上半部分：功能项与歌单列表容器 (Xcode 风格液态玻璃卡片)
          Expanded(
            child: GlassCard(
              borderRadius: UIConfig.containerRounding,
              padding:
                  const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // [板块一：功能项]
                    _buildSectionHeader('功能'),
                    _buildNavItem(
                      tab: SidebarTab.scanMusic,
                      label: '扫描音乐',
                      iconData: Icons.search_rounded,
                      isSelected: currentTab == SidebarTab.scanMusic,
                      onTap: () => onTabSelected(SidebarTab.scanMusic),
                    ),
                    _buildNavItem(
                      tab: SidebarTab.equalizer,
                      label: '均衡器',
                      iconData: Icons.tune_rounded,
                      isSelected: currentTab == SidebarTab.equalizer,
                      onTap: () => onTabSelected(SidebarTab.equalizer),
                    ),
                    _buildNavItem(
                      tab: SidebarTab.msebTuning,
                      label: '调音魔棒',
                      iconData: Icons.auto_fix_high_rounded,
                      isSelected: currentTab == SidebarTab.msebTuning,
                      onTap: () => onTabSelected(SidebarTab.msebTuning),
                    ),
                    _buildNavItem(
                      tab: SidebarTab.dacSettings,
                      label: 'DAC',
                      iconData: Icons.developer_board_rounded,
                      isSelected: currentTab == SidebarTab.dacSettings,
                      onTap: () => onTabSelected(SidebarTab.dacSettings),
                    ),
                    _buildNavItem(
                      tab: SidebarTab.themeSettings,
                      label: '主题',
                      iconData: Icons.palette_outlined,
                      isSelected: currentTab == SidebarTab.themeSettings,
                      onTap: () => onTabSelected(SidebarTab.themeSettings),
                    ),
                    _buildNavItem(
                      tab: SidebarTab.systemSettings,
                      label: '设置',
                      iconData: Icons.settings_rounded,
                      isSelected: currentTab == SidebarTab.systemSettings,
                      onTap: () => onTabSelected(SidebarTab.systemSettings),
                    ),
                    if (shouldShowWeb)
                      _buildNavItem(
                        tab: SidebarTab.webService,
                        label: 'Web服务',
                        iconData: Icons.desktop_windows_rounded,
                        isSelected: currentTab == SidebarTab.webService,
                        onTap: () => onTabSelected(SidebarTab.webService),
                      ),

                    const SizedBox(height: 6.0),

                    // [板块二：播放列表]
                    _buildSectionHeader('播放列表'),
                    _buildNavItem(
                      tab: SidebarTab.allMusic,
                      label: '所有音乐',
                      iconData: Icons.music_note_rounded,
                      isSelected: currentTab == SidebarTab.allMusic,
                      onTap: () => onTabSelected(SidebarTab.allMusic),
                    ),

                    // 用户自定义歌单列表
                    for (final pl in playlists)
                      _buildNavItem(
                        tab: SidebarTab.customPlaylist,
                        label: pl.name,
                        iconData: Icons.queue_music_rounded,
                        isSelected: currentTab == SidebarTab.customPlaylist &&
                            selectedPlaylistId == pl.id,
                        onTap: () => onPlaylistSelected(pl.id),
                      ),

                    // 添加播放列表按钮
                    _buildNavItem(
                      tab: null,
                      label: '添加播放列表',
                      iconData: Icons.add_rounded,
                      isSelected: false,
                      onTap: onCreatePlaylist,
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: actualGap),

          // 2. 下半部分：固定 DAC 状态指示卡片 (点击直达 DAC 设置)
          GlassCard(
            height: UIConfig.dacCardHeight,
            borderRadius: UIConfig.containerRounding,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            onTap: onDacClicked,
            child: Row(
              children: [
                // 状态指示灯 (绿灯：已连接，灰灯：未连接)
                Container(
                  width: 6.0,
                  height: 6.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDacConnected
                        ? UIConfig.dacConnected
                        : UIConfig.dacDisconnected,
                    boxShadow: isDacConnected
                        ? [
                            BoxShadow(
                              color:
                                  UIConfig.dacConnected.withValues(alpha: 0.55),
                              blurRadius: 5.5,
                              spreadRadius: 2.0,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    isDacConnected ? dacName : 'DAC: 未连接',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: UIConfig.fontRegular,
                      color: isDacConnected
                          ? UIConfig.textNormal
                          : UIConfig.textMuted,
                      fontWeight:
                          isDacConnected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, top: 3.0, bottom: 2.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: UIConfig.fontSmall,
          color: UIConfig.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required SidebarTab? tab,
    required String label,
    required IconData iconData,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(UIConfig.navItemRounding),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 30.0,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(UIConfig.navItemRounding),
              color: isSelected
                  ? ThemeService.instance.accentColor.withValues(alpha: 0.16)
                  : Colors.transparent,
              border: isSelected
                  ? Border.all(
                      color: ThemeService.instance.accentColor
                          .withValues(alpha: 0.65),
                      width: 1.0,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: ThemeService.instance.accentColor
                            .withValues(alpha: 0.28),
                        blurRadius: 8.0,
                        spreadRadius: 1.0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  iconData,
                  size: 16.0,
                  color: isSelected
                      ? ThemeService.instance.accentColor
                      : UIConfig.iconNormal,
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: UIConfig.fontRegular,
                      color: isSelected
                          ? UIConfig.textActive
                          : UIConfig.textNormal,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
