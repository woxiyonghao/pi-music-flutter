import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../theme/hifi_theme.dart';

class PlaybackControlsWidget extends StatelessWidget {
  final bool compact;

  const PlaybackControlsWidget({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final service = HifiAudioService.instance;
    final state = service.state;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度滑块
        Row(
          children: [
            Text(
              state.currentTimeString,
              style: const TextStyle(color: HifiTheme.textMuted, fontSize: 12),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  activeTrackColor: HifiTheme.mcIntoshGlow,
                  inactiveTrackColor: HifiTheme.cardBorder,
                  thumbColor: HifiTheme.textPrimary,
                ),
                child: Slider(
                  value: state.progress.clamp(0.0, 1.0),
                  onChanged: (val) {
                    if (state.duration > 0) {
                      service.seek(val * state.duration);
                    }
                  },
                ),
              ),
            ),
            Text(
              state.durationString,
              style: const TextStyle(color: HifiTheme.textMuted, fontSize: 12),
            ),
          ],
        ),

        // 控制按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, size: 32),
              color: HifiTheme.textPrimary,
              onPressed: () {},
            ),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [HifiTheme.mcIntoshGlow, HifiTheme.mcIntoshBlue],
                ),
                boxShadow: [
                  BoxShadow(
                    color: HifiTheme.mcIntoshBlue.withOpacity(0.5),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: IconButton(
                iconSize: compact ? 36 : 44,
                icon: Icon(
                  state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                onPressed: () => service.togglePlayPause(),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, size: 32),
              color: HifiTheme.textPrimary,
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }
}
