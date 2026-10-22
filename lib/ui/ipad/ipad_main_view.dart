import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/hifi_audio_service.dart';
import '../../core/platform_helper.dart';
import '../../models/sidebar_tab.dart';
import '../../services/music_database_service.dart';
import '../../services/theme_service.dart';
import '../../theme/ui_config.dart';
import '../common/glass_card.dart';
import '../visualizers/visualizer_type.dart';
import '../mac/mac_background_widget.dart';
import '../mac/mac_sidebar_widget.dart';
import '../mac/mac_bottom_bar_widget.dart';
import '../mac/views/mac_all_music_view.dart';
import '../mac/views/mac_equalizer_view.dart';
import '../mac/views/mac_dac_setting_view.dart';
import '../mac/views/mac_theme_setting_view.dart';
import '../mac/views/mac_magic_tuning_view.dart';
import '../mac/views/mac_scan_music_view.dart';
import '../mac/views/mac_system_settings_view.dart';
import '../mac/views/mac_web_service_view.dart';

/// iPad / 平板端发烧纯音数播主视窗
/// 1:1 严格对齐 C++ HifiPadRenderer.cpp 架构：
/// - 纯音底层背景与实时音频律动 (麦景图/金嗓子/磁带机/LED频谱/极光波形/Siri球/玻璃时钟)
/// - 左侧侧边栏 (全部曲库、自建歌单、10段EQ、DAC设置、WiFi无线传歌、声音微调、系统设置)
/// - 右侧主功能舞台与顶部经典动效表头
/// - 底部发烧级黑胶唱片旋转播放控制底栏
/// - iPadOS 触控优化、安全区适配 (Home Indicator / 状态栏避让)
/// - 空闲时间全屏屏保沉浸动效 (0.4s 三次方缓动移出/移入)
class IpadMainView extends StatefulWidget {
  const IpadMainView({super.key});

  @override
  State<IpadMainView> createState() => _IpadMainViewState();
}

class _IpadMainViewState extends State<IpadMainView> with SingleTickerProviderStateMixin {
  SidebarTab _currentTab = SidebarTab.allMusic;
  int _selectedPlaylistId = 0;
  bool _showCreatePlaylistModal = false;
  final TextEditingController _playlistNameController = TextEditingController();

  // 空闲全屏屏保动效控制器 (0.0 正常模式 <-> 1.0 四角移出纯净全屏沉浸)
  late AnimationController _fullscreenController;
  late Animation<double> _fullscreenAnim;
  bool _isFullscreenIdle = false;
  double _idleSeconds = 0.0;
  Timer? _idleCheckTimer;

  @override
  void initState() {
    super.initState();
    // 强制锁定 iPad 为横屏模式 (只允许 LandscapeLeft / LandscapeRight)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final savedTabIdx = int.tryParse(MusicDatabaseService.instance.getSetting('active_sidebar_tab', '0'));
    if (savedTabIdx != null && savedTabIdx >= 0 && savedTabIdx < SidebarTab.values.length) {
      _currentTab = SidebarTab.values[savedTabIdx];
    }

    _fullscreenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fullscreenAnim = CurvedAnimation(
      parent: _fullscreenController,
      curve: Curves.easeInOutCubic,
    );

    // 启动 1 秒级空闲检测定时器 (对齐 HifiPadRenderer.cpp 空闲屏保逻辑)
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _idleCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _checkIdleFullscreen();
      });
    }
  }

  @override
  void dispose() {
    _idleCheckTimer?.cancel();
    _fullscreenController.dispose();
    _playlistNameController.dispose();
    super.dispose();
  }

  double _getIdleTimeoutSeconds() {
    final modeStr = MusicDatabaseService.instance.getSetting('setting_idle_fullscreen', '4');
    final mode = int.tryParse(modeStr) ?? 4;
    switch (mode) {
      case 0:
        return 15.0; // 15 秒
      case 1:
        return 30.0; // 30 秒
      case 2:
        return 60.0; // 1 分钟
      case 3:
        return 300.0; // 5 分钟
      case 4:
      default:
        return 0.0; // 永不
    }
  }

  void _checkIdleFullscreen() {
    final timeout = _getIdleTimeoutSeconds();
    if (timeout > 0.0 && !_showCreatePlaylistModal) {
      _idleSeconds += 1.0;
      if (_idleSeconds >= timeout && !_isFullscreenIdle) {
        _enterFullscreenIdle();
      }
    } else {
      if (!_isFullscreenIdle) {
        _idleSeconds = 0.0;
      }
    }
  }

  void _onUserActivity() {
    _idleSeconds = 0.0;
    if (_isFullscreenIdle) {
      _exitFullscreenIdle();
    }
  }

  void _enterFullscreenIdle() {
    if (!_isFullscreenIdle) {
      setState(() {
        _isFullscreenIdle = true;
      });
      _fullscreenController.forward();
    }
  }

  void _exitFullscreenIdle() {
    if (_isFullscreenIdle) {
      setState(() {
        _isFullscreenIdle = false;
      });
      _fullscreenController.reverse();
    }
  }

  void _toggleFullscreen() {
    if (_isFullscreenIdle) {
      _exitFullscreenIdle();
    } else {
      _enterFullscreenIdle();
    }
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
      listenable: Listenable.merge([
        MusicDatabaseService.instance,
        ThemeService.instance,
        HifiAudioService.instance,
      ]),
      builder: (context, _) {
        final theme = ThemeService.instance;
        final activeVisualizer = VisualizerType.values[theme.backgroundVisualMode.clamp(0, VisualizerType.values.length - 1)];
        final db = MusicDatabaseService.instance;
        final tracks = db.tracks;
        final playlists = db.playlists;

        return Scaffold(
          backgroundColor: UIConfig.mainStageBg,
          body: SafeArea(
            bottom: false, // 底部由 BottomBar 自适应避让 Home Indicator
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenW = constraints.maxWidth;
                final screenH = constraints.maxHeight;

                return Listener(
                  onPointerDown: (_) => _onUserActivity(),
                  onPointerMove: (_) => _onUserActivity(),
                  child: AnimatedBuilder(
                    animation: _fullscreenAnim,
                    builder: (context, _) {
                      final progress = _fullscreenAnim.value;

                      // C++ HifiPadRenderer.cpp ease_t 三次方极速缓动因子
                      final easeT = progress < 0.5
                          ? 4.0 * progress * progress * progress
                          : 1.0 - pow(-2.0 * progress + 2.0, 3.0) * 0.5;

                      // 四角移出偏移计算
                      final topNavDx = -260.0 * easeT;
                      final topNavDy = -150.0 * easeT;

                      final mainDx = (screenW - 180.0) * easeT;
                      final mainDy = -150.0 * easeT;

                      final bottomDx = (screenW - 180.0) * easeT;
                      final bottomDy = (screenH * 0.25 + 40.0) * easeT;

                      final opacity = (1.0 - easeT).clamp(0.0, 1.0);
                      final isFullyFullscreen = progress >= 0.999;

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. 全景底层背景与音乐律动动效 (严格跟随侧边栏主题选择)
                          RepaintBoundary(
                            child: MacBackgroundWidget(
                              visualizerType: activeVisualizer,
                              fullscreenProgress: progress,
                            ),
                          ),

                          // 2. 左侧：导航与歌单侧边栏
                          if (!isFullyFullscreen)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: UIConfig.sidebarWidth,
                              child: RepaintBoundary(
                                child: Transform.translate(
                                  offset: Offset(topNavDx, topNavDy),
                                  child: Opacity(
                                    opacity: opacity,
                                    child: MacSidebarWidget(
                                      currentTab: _currentTab,
                                      selectedPlaylistId: _selectedPlaylistId,
                                      playlists: playlists,
                                      dacName: HifiAudioService.instance.state.activeDeviceName,
                                      isDacConnected: true,
                                      onTabSelected: (tab) {
                                        setState(() {
                                          _currentTab = tab;
                                          _selectedPlaylistId = 0;
                                        });
                                        db.setSetting('active_sidebar_tab', tab.index.toString());
                                      },
                                      onPlaylistSelected: (playlistId) {
                                        setState(() {
                                          _currentTab = SidebarTab.customPlaylist;
                                          _selectedPlaylistId = playlistId;
                                        });
                                      },
                                      onCreatePlaylist: _openCreatePlaylistModal,
                                      onDacClicked: () {
                                        setState(() {
                                          _currentTab = SidebarTab.dacSettings;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // 3. 右侧：主业务舞台内容区
                          if (!isFullyFullscreen)
                            Positioned(
                              left: UIConfig.sidebarWidth + UIConfig.containerMarginX,
                              right: UIConfig.containerMarginX,
                              top: UIConfig.containerMarginY,
                              bottom: UIConfig.bottomBarHeight + UIConfig.containerMarginY * 2,
                              child: Transform.translate(
                                offset: Offset(mainDx, mainDy),
                                child: Opacity(
                                  opacity: opacity,
                                  child: IgnorePointer(
                                    ignoring: progress > 0.4,
                                    child: _buildMainStage(tracks, activeVisualizer),
                                  ),
                                ),
                              ),
                            ),

                          // 4. 底部：黑胶唱片与全功能控制栏
                          if (!isFullyFullscreen)
                            Positioned(
                              left: UIConfig.sidebarWidth + UIConfig.containerMarginX,
                              right: UIConfig.containerMarginX,
                              bottom: UIConfig.containerMarginY,
                              height: UIConfig.bottomBarHeight,
                              child: RepaintBoundary(
                                child: Transform.translate(
                                  offset: Offset(bottomDx, bottomDy),
                                  child: Opacity(
                                    opacity: opacity,
                                    child: IgnorePointer(
                                      ignoring: progress > 0.4,
                                      child: MacBottomBarWidget(
                                        onToggleFullscreen: _toggleFullscreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // 5. 沉浸全屏模式快捷退出按钮
                          if (progress > 0.05)
                            Positioned(
                              top: 16.0,
                              right: 16.0,
                              child: Opacity(
                                opacity: progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(14, 18, 26, 0.82),
                                    borderRadius: BorderRadius.circular(20.0),
                                    border: Border.all(
                                      color: const Color.fromRGBO(255, 255, 255, 0.12),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 10.0,
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.fullscreen_exit_rounded, size: 20, color: UIConfig.iconNormal),
                                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    tooltip: '退出全屏',
                                    onPressed: _exitFullscreenIdle,
                                  ),
                                ),
                              ),
                            ),

                          // 6. 新建歌单弹窗
                          if (_showCreatePlaylistModal)
                            _buildCreatePlaylistModal(),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
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
        const MacDACSettingView(platform: HifiPlatformType.ipad),
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
          child: Container(color: Colors.black.withValues(alpha: 0.45)),
        ),

        // 居中磨砂模态对话框
        Center(
          child: GlassCard(
            width: 380.0,
            borderRadius: 16.0,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 14.0),

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
                      borderSide: const BorderSide(color: Color(0xFF2680EB)),
                    ),
                  ),
                  onSubmitted: (_) => _submitCreatePlaylist(),
                ),

                const SizedBox(height: 16.0),

                // 底部操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _closeCreatePlaylistModal,
                      style: TextButton.styleFrom(
                        foregroundColor: UIConfig.textMuted,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                      ),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8.0),
                    ElevatedButton(
                      onPressed: _submitCreatePlaylist,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2680EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18.0, vertical: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                      ),
                      child: const Text('创建'),
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
