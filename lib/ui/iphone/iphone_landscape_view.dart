import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../models/sidebar_tab.dart';
import '../../services/music_database_service.dart';
import '../../services/theme_service.dart';
import '../../theme/ui_config.dart';
import '../common/glass_card.dart';
import '../visualizers/visualizer_type.dart';
import '../mac/mac_background_widget.dart';
import '../mac/mac_sidebar_widget.dart';
import 'widgets/iphone_bottom_bar_widget.dart';
import 'views/iphone_all_music_view.dart';
import 'views/iphone_dac_setting_view.dart';
import 'views/iphone_equalizer_view.dart';
import 'views/iphone_theme_setting_view.dart';
import 'views/iphone_system_settings_view.dart';
import '../mac/views/mac_magic_tuning_view.dart';
import '../mac/views/mac_scan_music_view.dart';
import '../mac/views/mac_web_service_view.dart';

/// iPhone 横屏发烧纯音工作台 (1:1 严格对齐 Mac 经典固定 4 块架构)
/// 依要求：
/// 1. 块 1 左上：功能与歌单卡片（保留“主题”、“DAC”、“均衡器”、“所有音乐”等）
/// 2. 块 2 左下：固定 DAC 状态指示卡片 (TOPPING DX1 II 🟢)
/// 3. 块 3 右上：完整中央主舞台视图
/// 4. 块 4 右下：底部液态玻璃播放胶囊栏
/// 5. 底层：发烧律动背景透视
/// 6. 彻底移除全屏屏保与息屏包含/息屏时间设置，所有卡片常驻
class IphoneLandscapeView extends StatefulWidget {
  final VoidCallback onSwitchToPortrait;

  const IphoneLandscapeView({
    super.key,
    required this.onSwitchToPortrait,
  });

  @override
  State<IphoneLandscapeView> createState() => _IphoneLandscapeViewState();
}

class _IphoneLandscapeViewState extends State<IphoneLandscapeView> {
  SidebarTab _currentTab = SidebarTab.allMusic;
  int _selectedPlaylistId = 0;
  bool _showCreatePlaylistModal = false;
  final TextEditingController _playlistNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final savedTabIdx = int.tryParse(MusicDatabaseService.instance.getSetting('active_sidebar_tab', '0'));
    if (savedTabIdx != null && savedTabIdx >= 0 && savedTabIdx < SidebarTab.values.length) {
      _currentTab = SidebarTab.values[savedTabIdx];
    }
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }

  void _onTabSelected(SidebarTab tab) {
    setState(() => _currentTab = tab);
    MusicDatabaseService.instance.setSetting('active_sidebar_tab', tab.index.toString());
  }

  void _openCreatePlaylistModal() {
    _playlistNameController.clear();
    setState(() => _showCreatePlaylistModal = true);
  }

  void _closeCreatePlaylistModal() {
    setState(() => _showCreatePlaylistModal = false);
  }

  void _submitCreatePlaylist() {
    final name = _playlistNameController.text.trim();
    if (name.isNotEmpty) {
      MusicDatabaseService.instance.createPlaylist(name);
    }
    _closeCreatePlaylistModal();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MusicDatabaseService.instance,
        HifiAudioService.instance,
        ThemeService.instance,
      ]),
      builder: (context, _) {
        final theme = ThemeService.instance;
        final activeVisualizer = VisualizerType.values[theme.backgroundVisualMode.clamp(0, VisualizerType.values.length - 1)];
        final db = MusicDatabaseService.instance;
        final tracks = db.tracks;
        final playlists = db.playlists;

        return Scaffold(
          backgroundColor: UIConfig.mainStageBg,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. 全景底层发烧律动背景 (透视呈现)
              RepaintBoundary(
                child: MacBackgroundWidget(
                  visualizerType: activeVisualizer,
                  fullscreenProgress: 0.0,
                ),
              ),

              // 2. 统一纯音横屏边距 (不依赖 SafeArea 造成的大幅不对称切角，保持紧凑发烧间距)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: Row(
                  children: [
                    // 左侧列 (包含块 1 与块 2，严格填满高并与右侧顶底对齐)
                    SizedBox(
                      width: 170.0,
                      child: MacSidebarWidget(
                        width: 170.0,
                        padding: EdgeInsets.zero,
                        gap: 6.0,
                        currentTab: _currentTab,
                        selectedPlaylistId: _selectedPlaylistId,
                        playlists: playlists,
                        dacName: 'TOPPING DX1 II',
                        isDacConnected: true,
                        onTabSelected: _onTabSelected,
                        onPlaylistSelected: (plId) {
                          setState(() {
                            _currentTab = SidebarTab.customPlaylist;
                            _selectedPlaylistId = plId;
                          });
                        },
                        onCreatePlaylist: _openCreatePlaylistModal,
                        onDacClicked: () => _onTabSelected(SidebarTab.dacSettings),
                      ),
                    ),
                    const SizedBox(width: 8.0),

                    // 右侧列 (包含块 3 主舞台与块 4 底部播放胶囊条)
                    Expanded(
                      child: Column(
                        children: [
                          // 块 3: 中央主舞台视图
                          Expanded(
                            child: _buildMainStage(tracks, activeVisualizer),
                          ),
                          const SizedBox(height: 6.0),

                          // 块 4: 底部液态玻璃播放胶囊栏 (内置横竖屏旋转按键，彻底避免右上方浮动图标遮挡卡片)
                          IphoneBottomBarWidget(
                            onSwitchOrientation: widget.onSwitchToPortrait,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. 新建播放列表模态框
              if (_showCreatePlaylistModal) _buildCreatePlaylistModal(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainStage(List<dynamic> tracks, VisualizerType activeVisualizer) {
    final idx = _currentTab.index.clamp(0, SidebarTab.values.length - 1);
    return IndexedStack(
      index: idx,
      children: [
        const IphoneAllMusicView(),
        const IphoneAllMusicView(),
        MacScanMusicView(
          scannedCount: tracks.length,
          onScanComplete: () => MusicDatabaseService.instance.loadLibrary(),
        ),
        const IphoneEqualizerView(),
        const MacMagicTuningView(),
        const IphoneDacSettingView(),
        const IphoneThemeSettingView(),
        IphoneSystemSettingsView(onSwitchOrientation: widget.onSwitchToPortrait),
        const MacWebServiceView(isWifiTransfer: false),
        const MacWebServiceView(isWifiTransfer: true),
        IphoneSystemSettingsView(onSwitchOrientation: widget.onSwitchToPortrait),
      ],
    );
  }

  Widget _buildCreatePlaylistModal() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _closeCreatePlaylistModal,
          behavior: HitTestBehavior.opaque,
          child: Container(color: Colors.black.withValues(alpha: 0.5)),
        ),
        Center(
          child: GlassCard(
            width: 320.0,
            borderRadius: 14.0,
            padding: const EdgeInsets.all(18.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '新建播放列表',
                  style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10.0),
                TextField(
                  controller: _playlistNameController,
                  autofocus: true,
                  maxLength: 8,
                  style: const TextStyle(fontSize: 13.0, color: Colors.white),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xD90A0E14),
                    hintText: '输入新歌单名称...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.0),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0)),
                  ),
                  onSubmitted: (_) => _submitCreatePlaylist(),
                ),
                const SizedBox(height: 12.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _closeCreatePlaylistModal, child: const Text('取消')),
                    const SizedBox(width: 8.0),
                    ElevatedButton(onPressed: _submitCreatePlaylist, child: const Text('创建')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
