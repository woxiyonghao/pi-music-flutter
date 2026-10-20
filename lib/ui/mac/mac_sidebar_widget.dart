import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../core/platform_helper.dart';
import '../../models/sidebar_tab.dart';
import '../../models/track.dart';
import '../../services/theme_service.dart';
import '../../theme/ui_config.dart';
import '../common/glass_card.dart';

/// macOS / iPad / 树莓派专业发烧侧边栏 (1:1 严格对齐 C++ SidebarView.cpp / SidebarFeatureWidget.cpp / SidebarDacWidget.cpp)
class MacSidebarWidget extends StatefulWidget {
  final SidebarTab currentTab;
  final int selectedPlaylistId;
  final List<Playlist> playlists;
  final String dacName;
  final bool isDacConnected;
  final String? temperatureText;
  final ValueChanged<SidebarTab> onTabSelected;
  final ValueChanged<int> onPlaylistSelected;
  final VoidCallback onCreatePlaylist;
  final ValueChanged<int>? onDeletePlaylist;
  final VoidCallback onDacClicked;
  final HifiPlatformType? platform;

  const MacSidebarWidget({
    super.key,
    required this.currentTab,
    this.selectedPlaylistId = 0,
    required this.playlists,
    this.dacName = 'Apple Direct',
    this.isDacConnected = true,
    this.temperatureText,
    required this.onTabSelected,
    required this.onPlaylistSelected,
    required this.onCreatePlaylist,
    this.onDeletePlaylist,
    required this.onDacClicked,
    this.platform,
  });

  @override
  State<MacSidebarWidget> createState() => _MacSidebarWidgetState();
}

class _MacSidebarWidgetState extends State<MacSidebarWidget> {
  late final ScrollController _scrollController;
  HifiPlatformType get _currentPlatform => widget.platform ?? PlatformHelper.currentPlatform;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _confirmDeletePlaylist(BuildContext context, int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E232A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(
            color: ThemeService.instance.accentColor.withValues(alpha: 0.35),
            width: 1.0,
          ),
        ),
        title: const Text(
          '删除播放列表',
          style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '确定要从曲库中移除播放列表「$name」吗？',
          style: const TextStyle(color: UIConfig.textNormal, fontSize: 13.0),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: UIConfig.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDeletePlaylist?.call(id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: UIConfig.sidebarWidth,
      padding: const EdgeInsets.only(
        left: UIConfig.containerMarginX,
        right: UIConfig.containerMarginX,
        top: UIConfig.containerMarginY,
        bottom: UIConfig.containerMarginY,
      ),
      child: Column(
        children: [
          // 1. 上半部分：功能项与歌单列表容器 (Xcode 风格液态玻璃卡片 + 全指针平滑拖拽滚动)
          Expanded(
            child: GlassCard(
              borderRadius: UIConfig.containerRounding,
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.invertedStylus,
                  },
                ),
                child: RawScrollbar(
                  controller: _scrollController,
                  thumbVisibility: false,
                  thickness: 3.0,
                  radius: const Radius.circular(2.0),
                  thumbColor: ThemeService.instance.accentColor.withValues(alpha: 0.45),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // [板块一：功能项]
                        _buildSectionHeader('功能'),
                        _buildNavItem(
                          tab: SidebarTab.scanMusic,
                          label: '扫描音乐',
                          iconData: Icons.search_rounded,
                          isSelected: widget.currentTab == SidebarTab.scanMusic,
                          onTap: () => widget.onTabSelected(SidebarTab.scanMusic),
                        ),
                        _buildNavItem(
                          tab: SidebarTab.equalizer,
                          label: '均衡器',
                          iconData: Icons.tune_rounded,
                          isSelected: widget.currentTab == SidebarTab.equalizer,
                          onTap: () => widget.onTabSelected(SidebarTab.equalizer),
                        ),
                        _buildNavItem(
                          tab: SidebarTab.msebTuning,
                          label: '调音魔棒',
                          iconData: Icons.auto_fix_high_rounded,
                          isSelected: widget.currentTab == SidebarTab.msebTuning,
                          onTap: () => widget.onTabSelected(SidebarTab.msebTuning),
                        ),
                        _buildNavItem(
                          tab: SidebarTab.dacSettings,
                          label: 'DAC',
                          iconData: Icons.developer_board_rounded,
                          isSelected: widget.currentTab == SidebarTab.dacSettings,
                          onTap: () => widget.onTabSelected(SidebarTab.dacSettings),
                        ),
                        _buildNavItem(
                          tab: SidebarTab.themeSettings,
                          label: '主题',
                          iconData: Icons.palette_outlined,
                          isSelected: widget.currentTab == SidebarTab.themeSettings,
                          onTap: () => widget.onTabSelected(SidebarTab.themeSettings),
                        ),
                        _buildNavItem(
                          tab: SidebarTab.systemSettings,
                          label: '设置',
                          iconData: Icons.settings_rounded,
                          isSelected: widget.currentTab == SidebarTab.systemSettings,
                          onTap: () => widget.onTabSelected(SidebarTab.systemSettings),
                        ),
                        _buildNavItem(
                          tab: SidebarTab.webService,
                          label: 'Web服务',
                          iconData: Icons.desktop_windows_rounded,
                          isSelected: widget.currentTab == SidebarTab.webService,
                          onTap: () => widget.onTabSelected(SidebarTab.webService),
                        ),
                        _buildNavItem(
                          tab: SidebarTab.wifiTransfer,
                          label: 'WiFi传歌',
                          iconData: Icons.wifi_tethering_rounded,
                          isSelected: widget.currentTab == SidebarTab.wifiTransfer,
                          onTap: () => widget.onTabSelected(SidebarTab.wifiTransfer),
                        ),

                        const SizedBox(height: 8.0),

                        // [板块二：播放列表]
                        _buildSectionHeader('播放列表'),
                        _buildNavItem(
                          tab: SidebarTab.allMusic,
                          label: '所有音乐',
                          iconData: Icons.music_note_rounded,
                          isSelected: widget.currentTab == SidebarTab.allMusic,
                          onTap: () => widget.onTabSelected(SidebarTab.allMusic),
                        ),

                        // 用户自定义歌单列表
                        for (final pl in widget.playlists)
                          _buildNavItem(
                            tab: SidebarTab.customPlaylist,
                            label: pl.name,
                            iconData: Icons.queue_music_rounded,
                            isSelected: widget.currentTab == SidebarTab.customPlaylist &&
                                widget.selectedPlaylistId == pl.id,
                            onTap: () => widget.onPlaylistSelected(pl.id),
                            trailing: widget.onDeletePlaylist != null
                                ? GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _confirmDeletePlaylist(context, pl.id, pl.name),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 13.0,
                                        color: UIConfig.textMuted,
                                      ),
                                    ),
                                  )
                                : null,
                          ),

                        // 添加播放列表按钮 (树莓派屏幕无软键盘故在端侧隐藏，保留在 Web 遥控中枢通过手机/电脑创建)
                        if (_currentPlatform != HifiPlatformType.pi)
                          _buildNavItem(
                            tab: null,
                            label: '添加播放列表',
                            iconData: Icons.add_rounded,
                            isSelected: false,
                            onTap: widget.onCreatePlaylist,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: UIConfig.containerGap),

          // 2. 下半部分：固定 DAC 状态指示卡片 (点击直达 DAC 设置)
          GlassCard(
            height: UIConfig.dacCardHeight,
            borderRadius: UIConfig.containerRounding,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            onTap: widget.onDacClicked,
            child: Row(
              children: [
                // 状态指示灯 (绿灯：已连接，灰灯：未连接)
                Container(
                  width: 6.0,
                  height: 6.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isDacConnected
                        ? UIConfig.dacConnected
                        : UIConfig.dacDisconnected,
                    boxShadow: widget.isDacConnected
                        ? [
                            BoxShadow(
                              color: UIConfig.dacConnected.withValues(alpha: 0.55),
                              blurRadius: 5.5,
                              spreadRadius: 2.0,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: HifiAudioService.instance.outputDeviceNameNotifier,
                    builder: (context, name, _) => Text(
                      widget.isDacConnected
                          ? (name.isNotEmpty && _currentPlatform != HifiPlatformType.pi ? name : widget.dacName)
                          : 'DAC: 未连接',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: UIConfig.fontRegular,
                        color: widget.isDacConnected
                            ? UIConfig.textNormal
                            : UIConfig.textMuted,
                        fontWeight:
                            widget.isDacConnected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                if (widget.temperatureText != null) ...[
                  const SizedBox(width: 4.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, 0.08),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      widget.temperatureText!,
                      style: const TextStyle(
                        fontSize: 10.0,
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, top: 6.0, bottom: 4.0),
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
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: _SidebarNavButton(
        label: label,
        iconData: iconData,
        isSelected: isSelected,
        onTap: onTap,
        trailing: trailing,
      ),
    );
  }
}

class _SidebarNavButton extends StatefulWidget {
  final String label;
  final IconData iconData;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SidebarNavButton({
    required this.label,
    required this.iconData,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  @override
  State<_SidebarNavButton> createState() => _SidebarNavButtonState();
}

class _SidebarNavButtonState extends State<_SidebarNavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = ThemeService.instance.accentColor;
    final isSelected = widget.isSelected;

    Color bg;
    if (isSelected) {
      bg = accent.withValues(alpha: 0.16);
    } else if (_isHovered) {
      bg = Colors.white.withValues(alpha: 0.08);
    } else {
      bg = Colors.transparent;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (!_isHovered) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isHovered) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36.0,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(UIConfig.navItemRounding),
            color: bg,
            border: isSelected
                ? Border.all(
                    color: accent.withValues(alpha: 0.65),
                    width: 1.0,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 8.0,
                      spreadRadius: 1.0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.iconData,
                size: 16.0,
                color: isSelected
                    ? accent
                    : (_isHovered ? UIConfig.textActive : UIConfig.iconNormal),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: UIConfig.fontRegular,
                    color: isSelected
                        ? UIConfig.textActive
                        : (_isHovered ? UIConfig.textActive : UIConfig.textNormal),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
