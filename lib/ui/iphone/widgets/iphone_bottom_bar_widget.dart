import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../models/playback_state.dart';
import '../../../services/theme_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';
import '../../common/hifi_slider.dart';

/// The iPad transport, with narrower spacing for the iPhone landscape stage.
class IphoneBottomBarWidget extends StatelessWidget {
  final VoidCallback? onToggleFullscreen;

  const IphoneBottomBarWidget({super.key, this.onToggleFullscreen});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        HifiAudioService.instance,
        ThemeService.instance,
      ]),
      builder: (context, _) {
        final service = HifiAudioService.instance;
        final state = service.state;
        final accent = ThemeService.instance.accentColor;
        final modeIcon = switch (state.playMode) {
          PlayMode.loopSingle => Icons.repeat_one_rounded,
          PlayMode.shuffle => Icons.shuffle_rounded,
          PlayMode.sequence => Icons.east_rounded,
          PlayMode.loopList => Icons.repeat_rounded,
        };
        return GlassCard(
          height: UIConfig.bottomBarHeight,
          borderRadius: UIConfig.bottomBarHeight / 2,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _button('播放模式', modeIcon, service.cyclePlayMode),
              _button('上一曲', Icons.skip_previous_rounded, service.previous),
              _button(
                state.isPlaying ? '暂停' : '播放',
                state.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                service.togglePlayPause,
                color: Colors.white,
                size: 25,
              ),
              _button('下一曲', Icons.skip_next_rounded, service.next),
              const SizedBox(width: 4),
              Expanded(
                child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                          children: [
                            if (constraints.maxWidth >= 105)
                              _time(state.currentTimeString),
                            Expanded(
                              child: _slider(
                                accent: accent,
                                value: state.progress.clamp(0.0, 1.0),
                                semanticLabel: '播放进度',
                                onChanged: state.duration > 0
                                    ? (value) =>
                                        service.seek(value * state.duration)
                                    : null,
                              ),
                            ),
                            if (constraints.maxWidth >= 170)
                              _time(state.durationString),
                          ],
                        )),
              ),
              const SizedBox(width: 4),
              _button(
                state.isMuted ? '取消静音' : '静音',
                state.isMuted || state.volume <= 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                service.toggleMute,
                color: state.isMuted ? accent : UIConfig.iconNormal,
              ),
              SizedBox(
                width: 52,
                child: _slider(
                  accent: accent,
                  value: state.isMuted ? 0 : state.volume.clamp(0.0, 1.0),
                  semanticLabel: '音量',
                  onChanged: service.setVolume,
                ),
              ),
              if (onToggleFullscreen != null)
                _button(
                    '全屏沉浸表头', Icons.fullscreen_rounded, onToggleFullscreen!),
            ],
          ),
        );
      },
    );
  }

  Widget _time(String value) => Text(
        value,
        style: const TextStyle(
          fontSize: 10,
          color: UIConfig.textMuted,
          fontFamily: 'monospace',
        ),
      );

  Widget _button(String label, IconData icon, VoidCallback onPressed,
          {Color color = UIConfig.iconNormal, double size = 19}) =>
      SizedBox(
          width: 32,
          height: 40,
          child: IconButton(
            tooltip: label,
            onPressed: onPressed,
            icon: Icon(icon, size: size, color: color),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 40),
            visualDensity: VisualDensity.compact,
          ));

  Widget _slider({
    required Color accent,
    required double value,
    required String semanticLabel,
    required ValueChanged<double>? onChanged,
  }) =>
      Semantics(
        label: semanticLabel,
        child: SliderTheme(
          data: SliderThemeData(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            trackHeight: 3,
            activeTrackColor: accent,
            inactiveTrackColor: const Color(0x26FFFFFF),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
          ),
          child: HifiSlider(value: value, onChanged: onChanged),
        ),
      );
}
