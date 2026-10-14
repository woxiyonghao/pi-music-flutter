import 'package:flutter/material.dart';
import '../../models/playback_state.dart';
import '../../core/hifi_audio_service.dart';
import '../../theme/ui_config.dart';
import '../common/glass_card.dart';

/// macOS 底部液态玻璃播放控制胶囊栏 (1:1 严格对齐 C++ BottomBarView.cpp)
class MacBottomBarWidget extends StatelessWidget {
  const MacBottomBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HifiAudioService.instance,
      builder: (context, _) {
        final service = HifiAudioService.instance;
        final state = service.state;

        return GlassCard(
          height: UIConfig.bottomBarHeight,
          borderRadius: UIConfig.bottomBarHeight * 0.5, // 24px 半圆胶囊
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Row(
            children: [
              // 1. 左区：播放模式 -> 上一曲 -> 播放/暂停 -> 下一曲
              _buildLeftControls(service, state),

              const SizedBox(width: 16.0),

              // 2. 中区：发烧音频进度条与时间轴
              Expanded(
                child: _buildProgressBar(service, state),
              ),

              const SizedBox(width: 16.0),

              // 3. 右区：音量调节组件 (小喇叭、滑块条、百分比)
              _buildVolumeWidget(service, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeftControls(HifiAudioService service, PlaybackState state) {
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
      default:
        modeIcon = Icons.repeat_rounded;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 播放模式切换
        IconButton(
          onPressed: service.cyclePlayMode,
          icon: Icon(modeIcon, size: 18.0, color: UIConfig.iconNormal),
          splashRadius: 16.0,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 8.0),

        // 上一曲
        IconButton(
          onPressed: service.previous,
          icon: const Icon(Icons.skip_previous_rounded,
              size: 20.0, color: UIConfig.iconNormal),
          splashRadius: 16.0,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 8.0),

        // 播放 / 暂停
        IconButton(
          onPressed: service.togglePlayPause,
          icon: Icon(
            state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 26.0,
            color: UIConfig.textActive,
          ),
          splashRadius: 20.0,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        const SizedBox(width: 8.0),

        // 下一曲
        IconButton(
          onPressed: service.next,
          icon: const Icon(Icons.skip_next_rounded,
              size: 20.0, color: UIConfig.iconNormal),
          splashRadius: 16.0,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildProgressBar(HifiAudioService service, PlaybackState state) {
    final curTimeStr = state.currentTimeString;
    final durTimeStr = state.durationString;
    final progress = state.progress.clamp(0.0, 1.0);

    return Row(
      children: [
        // 当前播放时间戳
        Text(
          curTimeStr,
          style: const TextStyle(
            fontSize: UIConfig.fontSmall,
            color: UIConfig.textMuted,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 10.0),

        // 交互式进度滑条
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3.5,
              activeTrackColor: UIConfig.accent,
              inactiveTrackColor: const Color.fromRGBO(255, 255, 255, 0.15),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 5.0,
                elevation: 3.0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
              overlayColor: UIConfig.accent.withOpacity(0.2),
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
        const SizedBox(width: 10.0),

        // 总时长
        Text(
          durTimeStr,
          style: const TextStyle(
            fontSize: UIConfig.fontSmall,
            color: UIConfig.textMuted,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeWidget(HifiAudioService service, PlaybackState state) {
    IconData volIcon;
    if (state.isMuted || state.volume <= 0.001) {
      volIcon = Icons.volume_off_rounded;
    } else if (state.volume < 0.5) {
      volIcon = Icons.volume_down_rounded;
    } else {
      volIcon = Icons.volume_up_rounded;
    }

    final volPercent = (state.volume * 100).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 小喇叭图标 (点击切换静音)
        IconButton(
          onPressed: service.toggleMute,
          icon: Icon(
            volIcon,
            size: 18.0,
            color: state.isMuted ? UIConfig.accent : UIConfig.iconNormal,
          ),
          splashRadius: 14.0,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
        ),

        // 90px 音量滑块
        SizedBox(
          width: 90.0,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3.5,
              activeTrackColor:
                  state.isMuted ? UIConfig.iconNormal : UIConfig.accent,
              inactiveTrackColor: const Color.fromRGBO(255, 255, 255, 0.15),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 4.5,
                elevation: 2.0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
              overlayColor: UIConfig.accent.withOpacity(0.2),
            ),
            child: Slider(
              value: state.isMuted ? 0.0 : state.volume.clamp(0.0, 1.0),
              onChanged: (val) {
                service.setVolume(val);
              },
            ),
          ),
        ),

        const SizedBox(width: 6.0),

        // 百分比数值
        SizedBox(
          width: 34.0,
          child: Text(
            state.isMuted ? '静音' : '$volPercent%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: UIConfig.fontSmall,
              color: UIConfig.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
