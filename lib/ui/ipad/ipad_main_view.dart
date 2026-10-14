import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../theme/hifi_theme.dart';
import '../visualizers/visualizer_stage_widget.dart';
import '../shared/playback_controls_widget.dart';
import '../shared/glass_container.dart';

/// iPad / 平板端大屏双栏 Master-Detail UI
class IpadMainView extends StatelessWidget {
  const IpadMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HifiAudioService.instance,
      builder: (context, _) {
        final service = HifiAudioService.instance;
        final state = service.state;
        final track = service.currentTrack;

        return Scaffold(
          backgroundColor: HifiTheme.background,
          body: SafeArea(
            child: Row(
              children: [
                // 1. 左侧功能导航与曲库列表 (宽 320pt)
                Container(
                  width: 300,
                  decoration: const BoxDecoration(
                    color: HifiTheme.cardBackground,
                    border: Border(right: BorderSide(color: HifiTheme.cardBorder)),
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Icon(Icons.graphic_eq_rounded, color: HifiTheme.mcIntoshGlow, size: 28),
                            SizedBox(width: 10),
                            Text(
                              'HiFi Master Pad',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: HifiTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            _buildNavItem(Icons.library_music, '全部曲库 (Library)', true),
                            _buildNavItem(Icons.queue_music, '我的歌单 (Playlists)', false),
                            _buildNavItem(Icons.tune, '10段图形EQ (Equalizer)', false),
                            _buildNavItem(Icons.settings_input_component, 'AK4499EX DAC 设置', false),
                            _buildNavItem(Icons.wifi, '无线传歌与服务 (WiFi)', false),
                            _buildNavItem(Icons.settings, '系统设置 (System)', false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. 右侧沉浸式麦景图双表头与发烧控制中心
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // 经典发烧动效舞台 (集成麦景图/金嗓子/磁带机/LED频谱/极光波形/Siri球)
                        const Expanded(
                          flex: 7,
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            child: VisualizerStageWidget(showSelector: true),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 当前播放卡片与控制条
                        GlassContainer(
                          width: double.infinity,
                          child: Column(
                            children: [
                              Text(
                                track?.title ?? 'McIntosh Reference Audiophile Track',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                track != null ? '${track.artist} - ${track.album}' : 'Ready for playback',
                                style: const TextStyle(color: HifiTheme.textMuted),
                              ),
                              const SizedBox(height: 16),
                              const PlaybackControlsWidget(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, String title, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: active ? HifiTheme.mcIntoshBlue.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: active ? Border.all(color: HifiTheme.mcIntoshGlow.withOpacity(0.4)) : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: active ? HifiTheme.mcIntoshGlow : HifiTheme.textMuted),
        title: Text(
          title,
          style: TextStyle(
            color: active ? HifiTheme.textPrimary : HifiTheme.textMuted,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () {},
      ),
    );
  }
}
