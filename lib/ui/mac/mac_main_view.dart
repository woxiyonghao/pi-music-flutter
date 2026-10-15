import 'dart:async';
import 'dart:math';
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
/// 具备：空闲时间全屏屏保检测 (15s/30s/1m/5m/永不)、四角板块平滑滑出动效 (0.4s 缓动插值)、
/// 双击或点击胶囊栏无缝切换沉浸表头模式与鼠标活动自适应唤醒
class MacMainView extends StatefulWidget {
  const MacMainView({super.key});

  @override
  State<MacMainView> createState() => _MacMainViewState();
}

class _MacMainViewState extends State<MacMainView> with SingleTickerProviderStateMixin {
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

    // 启动 1 秒级空闲检测定时器 (对齐 C++ Application.cpp:583-597)
    _idleCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkIdleFullscreen();
    });
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
      listenable: Listenable.merge([MusicDatabaseService.instance, ThemeService.instance]),
      builder: (context, _) {
        final theme = ThemeService.instance;
        final activeVisualizer = VisualizerType.values[theme.backgroundVisualMode.clamp(0, VisualizerType.values.length - 1)];
        final db = MusicDatabaseService.instance;
        final tracks = db.tracks;
        final playlists = db.playlists;

        return Scaffold(
          backgroundColor: UIConfig.mainStageBg,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final screenW = constraints.maxWidth;
              final screenH = constraints.maxHeight;

              return MouseRegion(
                onHover: (_) => _onUserActivity(),
                child: Listener(
                  onPointerDown: (_) => _onUserActivity(),
                  onPointerMove: (_) => _onUserActivity(),
                  onPointerSignal: (_) => _onUserActivity(),
                  child: AnimatedBuilder(
                    animation: _fullscreenAnim,
                    builder: (context, _) {
                        final progress = _fullscreenAnim.value;

                        // C++ Application.cpp:802-803 ease_t 三次方极速缓动因子
                        final easeT = progress < 0.5
                            ? 4.0 * progress * progress * progress
                            : 1.0 - pow(-2.0 * progress + 2.0, 3.0) * 0.5;

                        // 四角移出偏移计算 (保证完全移出大屏视口)
                        // 1. 左上角：sidebar 功能与歌单区 -> 向左上方 (-260, -150)
                        final topNavDx = -260.0 * easeT;
                        final topNavDy = -150.0 * easeT;

                        // 2. 右上角：mainstateview 主舞台区域 -> 向右上方 (screenW, -150)
                        final mainDx = (screenW - 180.0) * easeT;
                        final mainDy = -150.0 * easeT;

                        // 3. 右下角：bottombar 底部播放控制胶囊栏 -> 向右下方 (screenW, +150)
                        final bottomDx = (screenW - 180.0) * easeT;
                        final bottomDy = (screenH * 0.25 + 40.0) * easeT;

                        final opacity = (1.0 - easeT).clamp(0.0, 1.0);
                        final isFullyFullscreen = progress >= 0.999;

                        final screensaverThemeIdx = int.tryParse(db.getSetting('setting_idle_screensaver_theme', '0')) ?? 0;
                        final VisualizerType effectiveVisualizer;
                        if (progress > 0.6 && screensaverThemeIdx > 0) {
                          switch (screensaverThemeIdx) {
                            case 1: effectiveVisualizer = VisualizerType.mcIntosh; break;
                            case 2: effectiveVisualizer = VisualizerType.accuphase; break;
                            case 3: effectiveVisualizer = VisualizerType.tapeReel; break;
                            case 4: effectiveVisualizer = VisualizerType.siriWave; break;
                            case 5: effectiveVisualizer = VisualizerType.bubbles; break;
                            case 6: effectiveVisualizer = VisualizerType.glassClock; break;
                            default: effectiveVisualizer = activeVisualizer; break;
                          }
                        } else {
                          effectiveVisualizer = activeVisualizer;
                        }

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. 全景底层背景与音乐律动动效 (独立 GPU 图层隔离)
                            RepaintBoundary(
                              child: MacBackgroundWidget(
                                visualizerType: effectiveVisualizer,
                                fullscreenProgress: progress,
                              ),
                            ),

                            // 2. 左侧：导航与歌单侧边栏 (230px 固定总宽度，向左上方移出，独立 GPU 图层隔离)
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
                                      child: IgnorePointer(
                                        ignoring: progress > 0.4,
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
                                    ),
                                  ),
                                ),
                              ),

                            // 3. 右上方：中央主舞台区域 (向右上方移出，独立 GPU 图层隔离)
                            if (!isFullyFullscreen)
                              Positioned(
                                left: UIConfig.sidebarWidth,
                                top: UIConfig.containerMarginY,
                                right: UIConfig.containerMarginX,
                                bottom: UIConfig.bottomBarOffset,
                                child: RepaintBoundary(
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
                              ),

                            // 4. 右下方：底部液态玻璃播放控制胶囊栏 (向右下方移出，独立 GPU 图层隔离)
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

                             // 5. 全屏沉浸模式悬浮工具条 (动效切换 + 退出全屏)
                            if (progress > 0.05)
                              Positioned(
                                top: 16.0,
                                right: 16.0,
                                child: Opacity(
                                  opacity: progress.clamp(0.0, 1.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
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
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        DropdownButtonHideUnderline(
                                          child: DropdownButton<VisualizerType>(
                                            value: effectiveVisualizer,
                                            dropdownColor: const Color(0xFF161B24),
                                            icon: Icon(Icons.style_rounded, size: 16, color: theme.accentColor),
                                            style: const TextStyle(fontSize: 11, color: UIConfig.textActive, fontWeight: FontWeight.bold),
                                            items: VisualizerType.values.map((type) {
                                              return DropdownMenuItem<VisualizerType>(
                                                value: type,
                                                child: Text(type.displayName),
                                              );
                                            }).toList(),
                                            onChanged: (newType) {
                                              if (newType != null) {
                                                ThemeService.instance.setBackgroundVisualMode(newType.index);
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        IconButton(
                                          icon: const Icon(Icons.fullscreen_exit_rounded, size: 18, color: UIConfig.iconNormal),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                          tooltip: '退出全屏',
                                          onPressed: _exitFullscreenIdle,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // 6. 顶层新建播放列表模态弹窗
                            if (_showCreatePlaylistModal) _buildCreatePlaylistModal(),
                          ],
                        );
                      },
                    ),
                  ),
                );
            },
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
        MacEqualizerView(),
        // 4: msebTuning
        MacMagicTuningView(),
        // 5: dacSettings
        MacDACSettingView(),
        // 6: themeSettings
        MacThemeSettingView(
          currentVisualizer: activeVisualizer,
          onVisualizerChanged: (type) {
            ThemeService.instance.setBackgroundVisualMode(type.index);
          },
        ),
        // 7: systemSettings
        MacSystemSettingsView(),
        // 8: webService
        const MacWebServiceView(isWifiTransfer: false),
        // 9: wifiTransfer
        const MacWebServiceView(isWifiTransfer: true),
        // 10: terminal
        MacSystemSettingsView(),
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
