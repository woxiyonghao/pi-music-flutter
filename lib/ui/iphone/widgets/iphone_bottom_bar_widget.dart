import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../models/playback_state.dart';
import '../../../services/theme_service.dart';

/// iPhone 专用 iPad/Mac 风格液态玻璃胶囊播放控制底栏 (1:1 对齐设计手稿)
class IphoneBottomBarWidget extends StatelessWidget {
  final VoidCallback? onSwitchOrientation;

  const IphoneBottomBarWidget({
    super.key,
    this.onSwitchOrientation,
  });

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

        return Container(
          height: 52.0,
          decoration: BoxDecoration(
            color: const Color(0xE0141A26),
            borderRadius: BorderRadius.circular(26.0),
            border: Border.all(
              color: const Color(0x26FFFFFF),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20.0,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            children: [
              // 1. 左侧核心播放控制区
              _buildLeftControls(service, state, accent),

              const SizedBox(width: 6.0),

              // 2. 中间时间轴与发烧进度滑块
              Expanded(
                child: _buildProgressBar(service, state, accent),
              ),

              const SizedBox(width: 6.0),

              // 3. 右侧音量微型调节组件
              _buildVolumeWidget(service, state, accent),

              // 4. 横/竖屏快捷旋转按钮
              if (onSwitchOrientation != null) ...[
                const SizedBox(width: 4.0),
                Container(
                  width: 1.0,
                  height: 14.0,
                  color: const Color(0x26FFFFFF),
                ),
                const SizedBox(width: 4.0),
                GestureDetector(
                  onTap: onSwitchOrientation,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                    child: Icon(
                      Icons.screen_rotation_rounded,
                      size: 15.0,
                      color: Color(0xFFC8D2E1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeftControls(HifiAudioService service, PlaybackState state, Color accent) {
    IconData modeIcon;
    switch (state.playMode) {
      case PlayMode.loopSingle:
        modeIcon = Icons.repeat_one_rounded;
        break;
      case PlayMode.shuffle:
        modeIcon = Icons.shuffle_rounded;
        break;
      case PlayMode.sequence:
        modeIcon = Icons.east_rounded;
        break;
      case PlayMode.loopList:
        modeIcon = Icons.repeat_rounded;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 循环模式
        GestureDetector(
          onTap: service.cyclePlayMode,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 6.0),
            child: Icon(modeIcon, size: 15.0, color: const Color(0xFFC8D2E1)),
          ),
        ),
        // 上一曲
        GestureDetector(
          onTap: service.previous,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 6.0),
            child: Icon(Icons.skip_previous_rounded,
                size: 19.0, color: Color(0xFFC8D2E1)),
          ),
        ),
        // 播放 / 暂停 大按键
        GestureDetector(
          onTap: service.togglePlayPause,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 30.0,
            height: 30.0,
            margin: const EdgeInsets.symmetric(horizontal: 2.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 10.0,
                ),
              ],
            ),
            child: Icon(
              state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 18.0,
              color: Colors.white,
            ),
          ),
        ),
        // 下一曲
        GestureDetector(
          onTap: service.next,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 6.0),
            child: Icon(Icons.skip_next_rounded,
                size: 19.0, color: Color(0xFFC8D2E1)),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(HifiAudioService service, PlaybackState state, Color accent) {
    final curTimeStr = state.currentTimeString;
    final durTimeStr = state.durationString;
    final progress = state.progress.clamp(0.0, 1.0);

    return Row(
      children: [
        Text(
          curTimeStr,
          style: const TextStyle(
            fontSize: 9.0,
            color: Color(0xFF828C9B),
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 2.0),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3.0,
              activeTrackColor: accent,
              inactiveTrackColor: const Color(0x26FFFFFF),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 4.5,
                elevation: 2.0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 6.0),
              overlayColor: accent.withValues(alpha: 0.25),
            ),
            child: Slider(
              value: progress,
              onChanged: (val) {
                if (state.duration > 0.0) {
                  service.seek(val * state.duration);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 2.0),
        Text(
          durTimeStr,
          style: const TextStyle(
            fontSize: 9.0,
            color: Color(0xFF828C9B),
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeWidget(HifiAudioService service, PlaybackState state, Color accent) {
    IconData volIcon;
    if (state.isMuted || state.volume <= 0.001) {
      volIcon = Icons.volume_off_rounded;
    } else if (state.volume < 0.5) {
      volIcon = Icons.volume_down_rounded;
    } else {
      volIcon = Icons.volume_up_rounded;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: service.toggleMute,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(right: 2.0),
            child: Icon(
              volIcon,
              size: 15.0,
              color: state.isMuted ? const Color(0xFFFF4D4D) : const Color(0xFFC8D2E1),
            ),
          ),
        ),
        SizedBox(
          width: 40.0,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2.5,
              activeTrackColor: accent,
              inactiveTrackColor: const Color(0x26FFFFFF),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 3.5,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 5.0),
            ),
            child: Slider(
              value: state.isMuted ? 0.0 : state.volume.clamp(0.0, 1.0),
              onChanged: (val) => service.setVolume(val),
            ),
          ),
        ),
      ],
    );
  }
}
