import 'package:flutter/material.dart';
import '../../models/sidebar_tab.dart';
import '../../services/music_database_service.dart';
import '../../theme/hifi_theme.dart';
import '../mac/views/mac_magic_tuning_view.dart';
import '../mac/views/mac_scan_music_view.dart';
import '../mac/views/mac_system_settings_view.dart';
import '../mac/views/mac_web_service_view.dart';
import 'views/iphone_all_music_view.dart';
import 'views/iphone_dac_setting_view.dart';
import 'views/iphone_equalizer_view.dart';
import 'views/iphone_theme_setting_view.dart';
import 'widgets/iphone_bottom_bar_widget.dart';
import 'widgets/iphone_now_playing_card.dart';
import 'widgets/iphone_top_sidebar_widget.dart';

/// iPhone 竖屏专享四大清晰层级纯音主视窗 (1:1 严格对齐设计手稿)
/// - 顶部 Sidebar 胶囊导航条
/// - 中间各 Sidebar 对应的滚动视窗 (DAC设置 / 10段EQ / 曲库 / 主题等)
/// - 歌曲播放信息卡片 (黑胶封面 + 采样率规格 + BIT-PERFECT + 微型动态电平)
/// - 最底部 iPad/Mac 风格播放控制胶囊栏
class IphonePortraitView extends StatefulWidget {
  final VoidCallback onSwitchToLandscape;

  const IphonePortraitView({
    super.key,
    required this.onSwitchToLandscape,
  });

  @override
  State<IphonePortraitView> createState() => _IphonePortraitViewState();
}

class _IphonePortraitViewState extends State<IphonePortraitView> {
  SidebarTab _currentTab = SidebarTab.allMusic;

  @override
  void initState() {
    super.initState();
    final savedTabIdx = int.tryParse(MusicDatabaseService.instance.getSetting('active_sidebar_tab', '0'));
    if (savedTabIdx != null && savedTabIdx >= 0 && savedTabIdx < SidebarTab.values.length) {
      _currentTab = SidebarTab.values[savedTabIdx];
    }
  }

  void _onTabSelected(SidebarTab tab) {
    setState(() => _currentTab = tab);
    MusicDatabaseService.instance.setSetting('active_sidebar_tab', tab.index.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HifiTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          child: Column(
            children: [
              // 【层级 1】顶部 Sidebar 胶囊栏
              IphoneTopSidebarWidget(
                currentTab: _currentTab,
                onTabSelected: _onTabSelected,
                onSwitchOrientation: widget.onSwitchToLandscape,
              ),
              const SizedBox(height: 8.0),

              // 【层级 2】中间各功能对应的内容滚动视窗
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xB80E121A),
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: const Color(0x14FFFFFF),
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10.0,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10.0),
                  child: _buildTabContentView(),
                ),
              ),
              const SizedBox(height: 8.0),

              // 【层级 3】当前歌曲播放信息卡片
              const IphoneNowPlayingCard(),
              const SizedBox(height: 8.0),

              // 【层级 4】最底部 iPad/Mac 风格播放条
              const IphoneBottomBarWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContentView() {
    switch (_currentTab) {
      case SidebarTab.dacSettings:
        return const IphoneDacSettingView();
      case SidebarTab.equalizer:
        return const IphoneEqualizerView();
      case SidebarTab.allMusic:
      case SidebarTab.customPlaylist:
        return const IphoneAllMusicView();
      case SidebarTab.themeSettings:
        return const IphoneThemeSettingView();
      case SidebarTab.scanMusic:
        return MacScanMusicView(
          scannedCount: MusicDatabaseService.instance.tracks.length,
          onScanComplete: () => MusicDatabaseService.instance.loadLibrary(),
        );
      case SidebarTab.msebTuning:
        return const MacMagicTuningView();
      case SidebarTab.systemSettings:
      case SidebarTab.terminal:
        return const MacSystemSettingsView();
      case SidebarTab.webService:
        return const MacWebServiceView(isWifiTransfer: false);
      case SidebarTab.wifiTransfer:
        return const MacWebServiceView(isWifiTransfer: true);
    }
  }
}
