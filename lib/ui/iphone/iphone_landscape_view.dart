import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../models/sidebar_tab.dart';
import '../../models/track.dart';
import '../../services/dac_setting_service.dart';
import '../../services/music_database_service.dart';
import '../../services/theme_service.dart';
import '../../theme/ui_config.dart';
import '../common/glass_card.dart';
import '../visualizers/visualizer_type.dart';
import '../mac/mac_background_widget.dart';
import '../mac/mac_sidebar_widget.dart';
import 'widgets/iphone_bottom_bar_widget.dart';
import '../mac/views/mac_all_music_view.dart';
import '../mac/views/mac_dac_setting_view.dart';
import '../mac/views/mac_equalizer_view.dart';
import '../mac/views/mac_theme_setting_view.dart';
import '../mac/views/mac_system_settings_view.dart';
import '../mac/views/mac_magic_tuning_view.dart';
import '../mac/views/mac_scan_music_view.dart';
import '../mac/views/mac_web_service_view.dart';

/// iPad's landscape workspace, fitted to iPhone safe areas and touch controls.
/// Orientation is selected once by IphoneMainView for the app session.
class IphoneLandscapeView extends StatefulWidget {
  const IphoneLandscapeView({
    super.key,
    this.verticalMargin = 10.0,
    this.verticalGap = 8.0,
  });

  final double verticalMargin;
  final double verticalGap;

  @override
  State<IphoneLandscapeView> createState() => _IphoneLandscapeViewState();
}

class _IphoneLandscapeViewState extends State<IphoneLandscapeView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  SidebarTab _currentTab = SidebarTab.allMusic;
  int _selectedPlaylistId = 0;
  bool _showCreatePlaylistModal = false;
  final _playlistNameController = TextEditingController();
  late final AnimationController _fullscreenController;
  late final Animation<double> _fullscreenAnim;
  Timer? _idleCheckTimer;
  int _idleSeconds = 0;
  bool _isFullscreen = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final db = MusicDatabaseService.instance;
    final savedTab = int.tryParse(db.getSetting('active_sidebar_tab', '0'));
    if (savedTab != null &&
        savedTab >= 0 &&
        savedTab < SidebarTab.values.length) {
      _currentTab = SidebarTab.values[savedTab];
    }
    _selectedPlaylistId =
        int.tryParse(db.getSetting('active_playlist_id', '0')) ?? 0;
    if (_currentTab == SidebarTab.customPlaylist &&
        !db.playlists.any((p) => p.id == _selectedPlaylistId)) {
      _currentTab = SidebarTab.allMusic;
    }
    _fullscreenController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fullscreenAnim = CurvedAnimation(
        parent: _fullscreenController, curve: Curves.easeInOutCubic);
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _idleCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_isActive || _showCreatePlaylistModal || _isFullscreen) return;
        final mode =
            int.tryParse(db.getSetting('setting_idle_fullscreen', '4')) ?? 4;
        final timeout =
            switch (mode) { 0 => 15, 1 => 30, 2 => 60, 3 => 300, _ => 0 };
        if (timeout == 0) {
          _idleSeconds = 0;
          return;
        }
        if (++_idleSeconds >= timeout) _setFullscreen(true);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isActive = state == AppLifecycleState.resumed;
    _idleSeconds = 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleCheckTimer?.cancel();
    _fullscreenController.dispose();
    _playlistNameController.dispose();
    super.dispose();
  }

  void _setFullscreen(bool value) {
    if (_isFullscreen == value) return;
    setState(() => _isFullscreen = value);
    _idleSeconds = 0;
    if (value) {
      _fullscreenController.forward();
    } else {
      _fullscreenController.reverse();
    }
  }

  void _onUserActivity() {
    _idleSeconds = 0;
    if (_isFullscreen) _setFullscreen(false);
  }

  void _onTabSelected(SidebarTab tab) {
    setState(() {
      _currentTab = tab;
      _selectedPlaylistId = 0;
    });
    MusicDatabaseService.instance
        .setSetting('active_sidebar_tab', tab.index.toString());
  }

  void _selectPlaylist(int id) {
    setState(() {
      _currentTab = SidebarTab.customPlaylist;
      _selectedPlaylistId = id;
    });
    final db = MusicDatabaseService.instance;
    db.setSetting(
        'active_sidebar_tab', SidebarTab.customPlaylist.index.toString());
    db.setSetting('active_playlist_id', id.toString());
  }

  void _openCreatePlaylistModal() {
    _playlistNameController.clear();
    setState(() => _showCreatePlaylistModal = true);
  }

  void _closeCreatePlaylistModal() =>
      setState(() => _showCreatePlaylistModal = false);

  void _submitCreatePlaylist() {
    final name = _playlistNameController.text.trim();
    if (name.isEmpty) return;
    final db = MusicDatabaseService.instance;
    db.createPlaylist(name);
    _closeCreatePlaylistModal();
    if (db.playlists.isNotEmpty) _selectPlaylist(db.playlists.last.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MusicDatabaseService.instance,
        HifiAudioService.instance,
        ThemeService.instance,
        DacSettingService.instance,
      ]),
      builder: (context, _) {
        final theme = ThemeService.instance;
        final visualizer = VisualizerType.values[theme.backgroundVisualMode
            .clamp(0, VisualizerType.values.length - 1)];
        final dac = DacSettingService.instance;
        final systemInsets = MediaQuery.paddingOf(context);
        // landscapeRight puts the camera cutout on the right. Keep that inset
        // and the Home Indicator clear, reclaiming the symmetric empty left edge.
        final contentInsets = systemInsets.copyWith(
          left: systemInsets.left.clamp(0.0, 16.0),
        );
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: UIConfig.mainStageBg,
          body: AnimatedBuilder(
            animation: _fullscreenAnim,
            builder: (context, _) {
              final progress = _fullscreenAnim.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                      child: MacBackgroundWidget(
                          visualizerType: visualizer,
                          fullscreenProgress: progress)),
                  Padding(
                    padding: contentInsets,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeLeft: true,
                      removeTop: true,
                      removeRight: true,
                      removeBottom: true,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (_) => _onUserActivity(),
                        onPointerMove: (_) => _onUserActivity(),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final sidebarWidth =
                              constraints.maxWidth < 700 ? 160.0 : 180.0;
                          final margin = widget.verticalMargin;
                          const leftMargin = 8.0;
                          const rightMargin = 0.0;
                          final gap = widget.verticalGap;
                          final mainLeft = sidebarWidth + leftMargin + gap;
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              if (progress < 0.999) ...[
                                Positioned(
                                  left: leftMargin,
                                  top: margin,
                                  bottom: margin,
                                  width: sidebarWidth,
                                  child: _panel(
                                      progress,
                                      Offset(-sidebarWidth - margin, -150),
                                      MacSidebarWidget(
                                        width: sidebarWidth,
                                        padding: EdgeInsets.zero,
                                        gap: gap,
                                        currentTab: _currentTab,
                                        selectedPlaylistId: _selectedPlaylistId,
                                        playlists: MusicDatabaseService
                                            .instance.playlists,
                                        dacName: dac.dacName,
                                        isDacConnected:
                                            dac.currentDevice != null,
                                        onTabSelected: _onTabSelected,
                                        onPlaylistSelected: _selectPlaylist,
                                        onCreatePlaylist:
                                            _openCreatePlaylistModal,
                                        onDacClicked: () => _onTabSelected(
                                            SidebarTab.dacSettings),
                                      )),
                                ),
                                Positioned(
                                  left: mainLeft,
                                  right: rightMargin,
                                  top: margin,
                                  bottom:
                                      margin + UIConfig.bottomBarHeight + gap,
                                  child: _panel(
                                      progress,
                                      Offset(constraints.maxWidth, -150),
                                      _buildMainStage(visualizer)),
                                ),
                                Positioned(
                                  left: mainLeft,
                                  right: rightMargin,
                                  bottom: margin,
                                  height: UIConfig.bottomBarHeight,
                                  child: _panel(
                                      progress,
                                      Offset(constraints.maxWidth,
                                          constraints.maxHeight / 3),
                                      IphoneBottomBarWidget(
                                          onToggleFullscreen: () =>
                                              _setFullscreen(true))),
                                ),
                              ],
                              if (progress > 0.05)
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: Opacity(
                                    opacity: progress.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color.fromRGBO(
                                            14, 18, 26, 0.82),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color.fromRGBO(
                                              255, 255, 255, 0.12),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.4),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        tooltip: '退出全屏',
                                        onPressed: () => _setFullscreen(false),
                                        icon: const Icon(
                                            Icons.fullscreen_exit_rounded,
                                            size: 20,
                                            color: UIConfig.iconNormal),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 8),
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_showCreatePlaylistModal)
                                _buildCreatePlaylistModal(),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _panel(double progress, Offset offset, Widget child) => IgnorePointer(
        ignoring: progress > 0.4,
        child: Transform.translate(
          offset: offset * progress,
          child: Opacity(opacity: (1 - progress).clamp(0, 1), child: child),
        ),
      );

  Widget _buildMainStage(VisualizerType visualizer) {
    final db = MusicDatabaseService.instance;
    switch (_currentTab) {
      case SidebarTab.allMusic:
        return MacAllMusicView(
            tracks: db.tracks,
            onNavigateToScan: () => _onTabSelected(SidebarTab.scanMusic));
      case SidebarTab.customPlaylist:
        final playlist =
            db.playlists.where((p) => p.id == _selectedPlaylistId).firstOrNull;
        return MacAllMusicView(
            key: ValueKey(_selectedPlaylistId),
            title: playlist?.name ?? '播放列表',
            isPlaylist: true,
            playlistId: playlist?.id,
            tracks: playlist?.tracks ?? const <Track>[],
            onNavigateToScan: () => _onTabSelected(SidebarTab.scanMusic));
      case SidebarTab.scanMusic:
        return MacScanMusicView(
            scannedCount: db.tracks.length, onScanComplete: db.loadLibrary);
      case SidebarTab.equalizer:
        return const MacEqualizerView();
      case SidebarTab.msebTuning:
        return const MacMagicTuningView();
      case SidebarTab.dacSettings:
        return const MacDACSettingView();
      case SidebarTab.themeSettings:
        return MacThemeSettingView(
            currentVisualizer: visualizer,
            onVisualizerChanged: (type) =>
                ThemeService.instance.setBackgroundVisualMode(type.index));
      case SidebarTab.systemSettings:
      case SidebarTab.terminal:
        return const MacSystemSettingsView();
      case SidebarTab.webService:
        return const MacWebServiceView(isWifiTransfer: false);
      case SidebarTab.wifiTransfer:
        return const MacWebServiceView(isWifiTransfer: true);
    }
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
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                    style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
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
                      hintStyle: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 12.0),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 8.0),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.0)),
                    ),
                    onSubmitted: (_) => _submitCreatePlaylist(),
                  ),
                  const SizedBox(height: 12.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: _closeCreatePlaylistModal,
                          child: const Text('取消')),
                      const SizedBox(width: 8.0),
                      ElevatedButton(
                          onPressed: _submitCreatePlaylist,
                          child: const Text('创建')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
