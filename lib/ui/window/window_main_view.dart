import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../theme/hifi_theme.dart';
import '../shared/vu_meter_widget.dart';
import '../shared/spectrum_analyzer_widget.dart';
import '../shared/playback_controls_widget.dart';

/// Windows 桌面端发烧纯音播放器 UI
class WindowMainView extends StatelessWidget {
  const WindowMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HifiAudioService.instance,
      builder: (context, _) {
        final service = HifiAudioService.instance;
        final state = service.state;
        final track = service.currentTrack;

        final leftLevel = state.spectrumLevels.isNotEmpty ? state.spectrumLevels[1] : 0.0;
        final rightLevel = state.spectrumLevels.length > 2 ? state.spectrumLevels[2] : 0.0;

        return Scaffold(
          backgroundColor: HifiTheme.background,
          appBar: AppBar(
            backgroundColor: const Color(0xFF161B22),
            title: const Text('Windows HiFi Player (WASAPI Exclusive)'),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: HifiTheme.neonCyan),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('WASAPI 0dB DIRECT', style: TextStyle(color: HifiTheme.neonCyan, fontSize: 11)),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Expanded(
                  flex: 6,
                  child: VuMeterWidget(
                    leftLevel: leftLevel,
                    rightLevel: rightLevel,
                    height: double.infinity,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  flex: 4,
                  child: SpectrumAnalyzerWidget(
                    levels: state.spectrumLevels,
                    height: double.infinity,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HifiTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HifiTheme.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Text(
                        track?.title ?? 'McIntosh High-End Audio Session',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const PlaybackControlsWidget(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
