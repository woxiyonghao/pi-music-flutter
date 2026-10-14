import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../theme/hifi_theme.dart';
import '../visualizers/visualizer_stage_widget.dart';
import '../shared/playback_controls_widget.dart';
import '../shared/glass_container.dart';

/// 树莓派 5 专属 7寸微雪触控屏 (1024×600) 横屏发烧台机 UI
class PiMainView extends StatelessWidget {
  const PiMainView({super.key});

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
          body: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // 左半区 (约 58% 宽度)：发烧动效舞台 (集成麦景图/金嗓子/磁带机/LED频谱/极光波形/Siri球)
                const Expanded(
                  flex: 58,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    child: VisualizerStageWidget(showSelector: true),
                  ),
                ),

                const SizedBox(width: 12),

                // 右半区 (约 42% 宽度)：曲目信息、硬件状态与大触控按键
                Expanded(
                  flex: 42,
                  child: GlassContainer(
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 顶部硬件与解码状态标牌
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.memory, color: HifiTheme.neonCyan, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'AK4191 + AK4499EX',
                                  style: TextStyle(
                                    color: HifiTheme.neonCyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: HifiTheme.mcIntoshBlue.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'I2S MASTER CLOCK',
                                style: TextStyle(
                                  color: HifiTheme.mcIntoshGlow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Divider(color: HifiTheme.cardBorder, height: 16),

                        // 曲目信息 (适合 7 寸屏阅读的大字号)
                        Text(
                          track?.title ?? 'McIntosh Reference Master',
                          style: const TextStyle(
                            color: HifiTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track != null ? '${track.artist} · ${track.album}' : 'Ready for Bit-Perfect Direct Stream',
                          style: const TextStyle(
                            color: HifiTheme.textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const Spacer(),

                        // 格式指示
                        Row(
                          children: [
                            _buildTag('DSD / FLAC', HifiTheme.accuphaseGold),
                            const SizedBox(width: 8),
                            _buildTag('192kHz / 24Bit', HifiTheme.mcIntoshGlow),
                            const SizedBox(width: 8),
                            _buildTag(state.isBitPerfect ? '0dB PURE' : 'DSP', HifiTheme.neonCyan),
                          ],
                        ),

                        const Spacer(),

                        // 触控大按键控制条
                        const PlaybackControlsWidget(compact: true),
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

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
