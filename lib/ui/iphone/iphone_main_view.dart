import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../theme/hifi_theme.dart';
import '../shared/vu_meter_widget.dart';
import '../shared/spectrum_analyzer_widget.dart';
import '../shared/playback_controls_widget.dart';
import '../shared/glass_container.dart';

/// iPhone 移动端竖屏沉浸式 UI
class IphoneMainView extends StatelessWidget {
  const IphoneMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HifiAudioService.instance,
      builder: (context, _) {
        final service = HifiAudioService.instance;
        final state = service.state;
        final track = service.currentTrack;

        // 计算双声道 VU 摆动 (从频谱抽取低频与中频)
        final leftLevel = state.spectrumLevels.isNotEmpty ? state.spectrumLevels[1] : 0.0;
        final rightLevel = state.spectrumLevels.length > 2 ? state.spectrumLevels[2] : 0.0;

        return Scaffold(
          backgroundColor: HifiTheme.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // 1. 顶部状态栏：HiFi 标志与 Bit-Perfect 直通指示
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🎵 MyHiFi Streamer',
                          style: TextStyle(
                            color: HifiTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: state.isBitPerfect
                                ? HifiTheme.mcIntoshBlue.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: state.isBitPerfect ? HifiTheme.mcIntoshGlow : Colors.grey,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: state.isBitPerfect ? HifiTheme.neonCyan : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                state.isBitPerfect ? 'BIT-PERFECT' : 'DSP ACTIVE',
                                style: TextStyle(
                                  color: state.isBitPerfect
                                      ? HifiTheme.mcIntoshGlow
                                      : HifiTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. 经典麦景图湖蓝夜光双表头
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: VuMeterWidget(
                      leftLevel: leftLevel,
                      rightLevel: rightLevel,
                      height: 140,
                    ),
                  ),

                  // 3. 12 频段音频频谱
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: SpectrumAnalyzerWidget(
                      levels: state.spectrumLevels,
                      height: 70,
                    ),
                  ),

                  // 4. 当前正在播放曲目信息
                  Expanded(
                    child: Center(
                      child: GlassContainer(
                        width: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              track?.title ?? '暂无播放曲目',
                              style: const TextStyle(
                                color: HifiTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              track != null ? '${track.artist} - ${track.album}' : '请选择本地母带曲目或连接树莓派',
                              style: const TextStyle(
                                color: HifiTheme.textMuted,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            if (track != null)
                              Text(
                                '${track.format} | ${track.sampleRate ~/ 1000}kHz | ${track.bitDepth}Bit',
                                style: const TextStyle(
                                  color: HifiTheme.accuphaseGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 5. 底部播放控制面板
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: PlaybackControlsWidget(compact: true),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
