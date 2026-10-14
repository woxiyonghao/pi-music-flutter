import 'package:flutter/material.dart';
import '../../models/sidebar_tab.dart';
import '../../services/music_database_service.dart';
import '../../services/theme_service.dart';
import '../../theme/ui_config.dart';
import '../common/glass_card.dart';
import '../visualizers/visualizer_type.dart';
import 'mac_background_widget.dart';
import 'mac_sidebar_widget.dart';
import 'mac_bottom_bar_widget.dart';
import 'views/mac_all_music_view.dart';
import 'views/mac_equalizer_view.dart';
import 'views/mac_dac_setting_view.dart';
import 'views/mac_theme_setting_view.dart';
import 'views/mac_magic_tuning_view.dart';
import 'views/mac_scan_music_view.dart';
import 'views/mac_system_settings_view.dart';
import 'views/mac_web_service_view.dart';

/// macOS 专业桌面端发烧纯音数播主视窗 (1:1 严格对齐 C++ Application.cpp 全景架构)
class MacMainView extends StatefulWidget {
  const MacMainView({super.key});

  @override
  State<MacMainView> createState() => _MacMainViewState();
}

class _MacMainViewState extends State<MacMainView> {
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

  void _openCreatePlaylistModal() {
    _playlistNameController.clear();
    setState(() {
      _showCreatePlaylistModal = true;
    });
  }

  void _closeCreatePlaylistModal() {
    setState(() {
      _showCreatePlaylistModal = false;
    });
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
      listenable: Listenable.merge([MusicDatabaseService.instance, ThemeService.instance]),
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
              // 1. 全景底层背景与音乐律动动效 (48列全景 LED 频谱 / 名机表头)
              MacBackgroundWidget(visualizerType: activeVisualizer),

              // 2. 左侧：导航与歌单侧边栏 (230px 固定总宽度)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: UIConfig.sidebarWidth,
                child: MacSidebarWidget(
                  currentTab: _currentTab,
                  selectedPlaylistId: _selectedPlaylistId,
                  playlists: playlists,
                  dacName: 'Apple Direct',
                  isDacConnected: true,
                  onTabSelected: (tab) {
                    setState(() {
                      _currentTab = tab;
                    });
                    MusicDatabaseService.instance.setSetting('active_sidebar_tab', tab.index.toString());
                  },
                  onPlaylistSelected: (plId) {
                    setState(() {
                      _currentTab = SidebarTab.customPlaylist;
                      _selectedPlaylistId = plId;
                    });
                    MusicDatabaseService.instance.setSetting('active_sidebar_tab', SidebarTab.customPlaylist.index.toString());
                  },
                  onCreatePlaylist: _openCreatePlaylistModal,
                  onDacClicked: () {
                    setState(() {
                      _currentTab = SidebarTab.dacSettings;
                    });
                    MusicDatabaseService.instance.setSetting('active_sidebar_tab', SidebarTab.dacSettings.index.toString());
                  },
                ),
              ),

              // 3. 右上方：中央主舞台区域 (避让底部播放控制胶囊)
              Positioned(
                left: UIConfig.sidebarWidth,
                top: UIConfig.containerMarginY,
                right: UIConfig.containerMarginX,
                bottom: UIConfig.bottomBarOffset,
                child: _buildMainStage(tracks, activeVisualizer),
              ),

              // 4. 右下方：底部液态玻璃播放控制胶囊栏
              Positioned(
                left: UIConfig.sidebarWidth + UIConfig.containerMarginX,
                right: UIConfig.containerMarginX,
                bottom: UIConfig.containerMarginY,
                height: UIConfig.bottomBarHeight,
                child: const MacBottomBarWidget(),
              ),

              // 5. 顶层新建播放列表模态弹窗
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
        // 0: allMusic
        MacAllMusicView(
          tracks: tracks.cast(),
          onNavigateToScan: () {
            setState(() {
              _currentTab = SidebarTab.scanMusic;
            });
          },
        ),
        // 1: customPlaylist
        MacAllMusicView(
          tracks: tracks.cast(),
          onNavigateToScan: () {
            setState(() {
              _currentTab = SidebarTab.scanMusic;
            });
          },
        ),
        // 2: scanMusic
        MacScanMusicView(
          scannedCount: tracks.length,
          onScanComplete: () {
            MusicDatabaseService.instance.loadLibrary();
          },
        ),
        // 3: equalizer
        const MacEqualizerView(),
        // 4: msebTuning
        const MacMagicTuningView(),
        // 5: dacSettings
        const MacDACSettingView(),
        // 6: themeSettings
        MacThemeSettingView(
          currentVisualizer: activeVisualizer,
          onVisualizerChanged: (type) {
            ThemeService.instance.setBackgroundVisualMode(type.index);
          },
        ),
        // 7: systemSettings
        const MacSystemSettingsView(),
        // 8: webService
        const MacWebServiceView(isWifiTransfer: false),
        // 9: wifiTransfer
        const MacWebServiceView(isWifiTransfer: true),
        // 10: terminal
        const MacSystemSettingsView(),
      ],
    );
  }

  Widget _buildCreatePlaylistModal() {
    return Stack(
      children: [
        // 全透明点击拦截遮罩
        GestureDetector(
          onTap: _closeCreatePlaylistModal,
          behavior: HitTestBehavior.opaque,
          child: Container(color: Colors.black.withOpacity(0.45)),
        ),

        // 居中 380x200 磨砂模态对话框 (对齐 Application.cpp::renderCreatePlaylistModal)
        Center(
          child: GlassCard(
            width: 380.0,
            height: 200.0,
            borderRadius: 16.0,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '新建播放列表',
                  style: TextStyle(
                    fontSize: UIConfig.fontMedium,
                    fontWeight: FontWeight.bold,
                    color: UIConfig.textActive,
                  ),
                ),
                const SizedBox(height: 6.0),
                const Text(
                  '请输入歌单名称 (最多 8 个汉字/字符)',
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    color: UIConfig.textMuted,
                  ),
                ),
                const SizedBox(height: 16.0),

                // 输入框
                TextField(
                  controller: _playlistNameController,
                  autofocus: true,
                  maxLength: 8,
                  style: const TextStyle(
                    fontSize: UIConfig.fontRegular,
                    color: UIConfig.textActive,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color.fromRGBO(10, 14, 20, 0.85),
                    hintText: '输入新歌单名称...',
                    hintStyle: const TextStyle(color: UIConfig.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 10.0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6.0),
                      borderSide: const BorderSide(
                        color: Color.fromRGBO(255, 255, 255, 0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6.0),
                      borderSide: BorderSide(
                        color: UIConfig.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submitCreatePlaylist(),
                ),

                const Spacer(),

                // 底部取消与确定按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _closeCreatePlaylistModal,
                      style: TextButton.styleFrom(
                        foregroundColor: UIConfig.textMuted,
                      ),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 10.0),
                    ElevatedButton(
                      onPressed: _submitCreatePlaylist,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UIConfig.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                      ),
                      child: const Text('确定创建'),
                    ),
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
