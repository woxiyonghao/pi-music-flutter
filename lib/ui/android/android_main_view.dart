import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../theme/hifi_theme.dart';
import '../shared/vu_meter_widget.dart';
import '../shared/spectrum_analyzer_widget.dart';
import '../shared/playback_controls_widget.dart';
import '../shared/glass_container.dart';

/// Android 移动端 Material 3 风格 HiFi UI
class AndroidMainView extends StatelessWidget {
  const AndroidMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HifiAudioService.instance,
      builder: (context, _) {
        final service = HifiAudioService.instance;
        final state = service.state;
        final track = service.currentTrack;

        final leftLevel = state.spectrumLevels.isNotEmpty ? state.spectrumLevels[0] : 0.0;
        final rightLevel = state.spectrumLevels.length > 1 ? state.spectrumLevels[1] : 0.0;

        return Scaffold(
          backgroundColor: HifiTheme.background,
          appBar: AppBar(
            title: const Text('Android HiFi Player (AAudio)'),
            actions: [
              IconButton(
                icon: Icon(
                  state.isMuted ? Icons.volume_off : Icons.volume_up,
                  color: HifiTheme.textPrimary,
                ),
                onPressed: () => service.toggleMute(),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                VuMeterWidget(
                  leftLevel: leftLevel,
                  rightLevel: rightLevel,
                  height: 150,
                ),
                const SizedBox(height: 12),
                SpectrumAnalyzerWidget(
                  levels: state.spectrumLevels,
                  height: 80,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GlassContainer(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.album_rounded, size: 64, color: HifiTheme.mcIntoshGlow),
                        const SizedBox(height: 12),
                        Text(
                          track?.title ?? '暂无播放歌曲',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          track?.artist ?? '本地音频解码引擎就绪',
                          style: const TextStyle(color: HifiTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const PlaybackControlsWidget(),
              ],
            ),
          ),
        );
      },
    );
  }
}
