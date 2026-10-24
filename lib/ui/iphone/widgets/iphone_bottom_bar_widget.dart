import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../models/playback_state.dart';

/// iPhone 专用 iPad/Mac 风格液态玻璃胶囊播放控制底栏 (1:1 对齐设计手稿)
class IphoneBottomBarWidget extends StatelessWidget {
  const IphoneBottomBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HifiAudioService.instance,
      builder: (context, _) {
        final service = HifiAudioService.instance;
        final state = service.state;

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
              _buildLeftControls(service, state),

              const SizedBox(width: 6.0),

              // 2. 中间时间轴与发烧进度滑块
              Expanded(
                child: _buildProgressBar(service, state),
              ),

              const SizedBox(width: 6.0),

              // 3. 右侧音量微型调节组件
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF0084FF),
              boxShadow: [
                BoxShadow(
                  color: Color(0x660084FF),
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

  Widget _buildProgressBar(HifiAudioService service, PlaybackState state) {
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
            data: const SliderThemeData(
              trackHeight: 3.0,
              activeTrackColor: Color(0xFF0084FF),
              inactiveTrackColor: Color(0x26FFFFFF),
              thumbColor: Colors.white,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: 4.5,
                elevation: 2.0,
              ),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 6.0),
              overlayColor: Color(0x400084FF),
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

  Widget _buildVolumeWidget(HifiAudioService service, PlaybackState state) {
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
            data: const SliderThemeData(
              trackHeight: 2.5,
              activeTrackColor: Color(0xFF0084FF),
              inactiveTrackColor: Color(0x26FFFFFF),
              thumbColor: Colors.white,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: 3.5,
              ),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 5.0),
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
