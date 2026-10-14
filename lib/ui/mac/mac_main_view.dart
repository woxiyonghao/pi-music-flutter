import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../theme/hifi_theme.dart';
import '../visualizers/visualizer_stage_widget.dart';
import '../shared/playback_controls_widget.dart';

/// macOS 桌面专业端发烧播放器 UI (CoreAudio / Hog Mode)
class MacMainView extends StatelessWidget {
  const MacMainView({super.key});

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
          body: Row(
            children: [
              // macOS 侧边栏
              Container(
                width: 240,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1117),
                  border: Border(right: BorderSide(color: HifiTheme.cardBorder)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // macOS 顶部红黄绿交通灯间距
                    const SizedBox(height: 48),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        'MY HIFI MASTER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: HifiTheme.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMacMenuItem(Icons.library_music_rounded, '音乐曲库', true),
                    _buildMacMenuItem(Icons.playlist_play_rounded, '精选歌单', false),
                    _buildMacMenuItem(Icons.album_rounded, '专辑唱片', false),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        'HARDWARE & DAC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: HifiTheme.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMacMenuItem(Icons.developer_board_rounded, 'AK4499EX 解码前级', false),
                    _buildMacMenuItem(Icons.tune_rounded, 'DSP / 10段均衡器', false),
                    _buildMacMenuItem(Icons.speaker_rounded, 'CoreAudio 独占直通', false),
                    const Spacer(),
                    // 底部声卡指示
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: HifiTheme.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: HifiTheme.cardBorder),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lock_rounded, size: 12, color: HifiTheme.neonCyan),
                              SizedBox(width: 4),
                              Text('HOG MODE (EXCLUSIVE)',
                                  style: TextStyle(fontSize: 10, color: HifiTheme.neonCyan, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text('Bit-Perfect CoreAudio', style: TextStyle(fontSize: 11, color: HifiTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // macOS 主展示区
              Expanded(
                child: Column(
                  children: [
                    // 顶部窗口标头
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: HifiTheme.cardBorder)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Mac Pro HiFi Audio Console',
                              style: TextStyle(fontWeight: FontWeight.bold, color: HifiTheme.textPrimary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: HifiTheme.mcIntoshBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: HifiTheme.mcIntoshGlow.withOpacity(0.5)),
                            ),
                            child: const Text('384kHz / 32Bit Float Engine',
                                style: TextStyle(color: HifiTheme.mcIntoshGlow, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),

                    // 中部发烧动效舞台核心 (支持6大动效即时切换)
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          child: VisualizerStageWidget(showSelector: true),
                        ),
                      ),
                    ),

                    // 底部常驻播放控制栏
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: const BoxDecoration(
                        color: HifiTheme.cardBackground,
                        border: Border(top: BorderSide(color: HifiTheme.cardBorder)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(track?.title ?? 'McIntosh Reference Track',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(track?.artist ?? 'Apple CoreAudio Direct',
                                    style: const TextStyle(color: HifiTheme.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Expanded(
                            flex: 5,
                            child: PlaybackControlsWidget(compact: true),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Icon(Icons.volume_up_rounded, size: 20, color: HifiTheme.textMuted),
                                SizedBox(
                                  width: 100,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                    ),
                                    child: Slider(
                                      value: state.volume,
                                      onChanged: (val) => service.setVolume(val),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacMenuItem(IconData icon, String title, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? HifiTheme.mcIntoshBlue.withOpacity(0.3) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: active ? HifiTheme.mcIntoshGlow : HifiTheme.textMuted),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                color: active ? HifiTheme.textPrimary : HifiTheme.textMuted,
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
    );
  }
}
