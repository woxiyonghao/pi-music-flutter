import 'package:flutter/material.dart';
import '../../common/hifi_slider.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../models/playback_state.dart';
import '../../../theme/hifi_theme.dart';

/// 树莓派 7 寸电容触控屏专属发烧大热区控制条 (Touch Target >= 48dp)
class PiTouchControls extends StatelessWidget {
  final VoidCallback? onVolumeTap;

  const PiTouchControls({super.key, this.onVolumeTap});

  @override
  Widget build(BuildContext context) {
    final service = HifiAudioService.instance;
    final state = service.state;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. 发烧级触控进度滑块 (加高触控碰撞高度与加粗轨道，防触控误触)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              Text(
                state.currentTimeString,
                style: const TextStyle(
                  color: HifiTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5.0,
                    activeTrackColor: HifiTheme.mcIntoshGlow,
                    inactiveTrackColor: HifiTheme.cardBorder,
                    thumbColor: HifiTheme.mcIntoshGlow,
                    overlayColor: HifiTheme.mcIntoshGlow.withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9.0,
                      elevation: 4.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                  ),
                  child: HifiSlider(
                    value: state.progress.clamp(0.0, 1.0),
                    onChanged: (val) {
                      if (state.duration > 0) {
                        service.seek(val * state.duration);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state.durationString,
                style: const TextStyle(
                  color: HifiTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 2. 发烧大尺寸触控按键组 (全部采用触控瞬态高亮与扩大碰撞盒)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 播放模式切换按键
            _buildTouchButton(
              size: 48,
              icon: _getPlayModeIcon(state.playMode),
              iconColor: state.playMode == PlayMode.loopSingle
                  ? HifiTheme.accuphaseGold
                  : HifiTheme.textPrimary,
              tooltip: _getPlayModeTooltip(state.playMode),
              onTap: () => service.cyclePlayMode(),
            ),

            // 上一曲 (54x54 dp)
            _buildTouchButton(
              size: 54,
              icon: Icons.skip_previous_rounded,
              iconSize: 32,
              iconColor: HifiTheme.textPrimary,
              tooltip: '上一曲',
              onTap: () => service.previous(),
            ),

            // 播放/暂停发烧中心大按钮 (68x68 dp 麦景图湖蓝夜光双光晕)
            GestureDetector(
              onTap: () => service.togglePlayPause(),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(0.0, -0.2),
                    radius: 0.85,
                    colors: [
                      HifiTheme.mcIntoshGlow,
                      HifiTheme.mcIntoshBlue,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HifiTheme.mcIntoshGlow.withValues(alpha: state.isPlaying ? 0.6 : 0.25),
                      blurRadius: state.isPlaying ? 20 : 10,
                      spreadRadius: state.isPlaying ? 2 : 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),

            // 下一曲 (54x54 dp)
            _buildTouchButton(
              size: 54,
              icon: Icons.skip_next_rounded,
              iconSize: 32,
              iconColor: HifiTheme.textPrimary,
              tooltip: '下一曲',
              onTap: () => service.next(),
            ),

            // 音量与静音切换按键 (48x48 dp)
            _buildTouchButton(
              size: 48,
              icon: state.isMuted
                  ? Icons.volume_off_rounded
                  : (state.volume > 0.5
                      ? Icons.volume_up_rounded
                      : (state.volume > 0 ? Icons.volume_down_rounded : Icons.volume_mute_rounded)),
              iconColor: state.isMuted ? Colors.redAccent : HifiTheme.textPrimary,
              tooltip: '音量控制',
              onTap: onVolumeTap ?? () => service.toggleMute(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTouchButton({
    required double size,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    double iconSize = 24,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        splashColor: HifiTheme.mcIntoshGlow.withValues(alpha: 0.3),
        highlightColor: HifiTheme.mcIntoshBlue.withValues(alpha: 0.2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HifiTheme.cardBackground.withValues(alpha: 0.7),
            border: Border.all(color: HifiTheme.cardBorder, width: 1.2),
          ),
          child: Center(
            child: Icon(
              icon,
              color: iconColor,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.loopList:
        return Icons.repeat_rounded;
      case PlayMode.loopSingle:
        return Icons.repeat_one_rounded;
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
      case PlayMode.sequence:
        return Icons.format_list_numbered_rounded;
    }
  }

  String _getPlayModeTooltip(PlayMode mode) {
    switch (mode) {
      case PlayMode.loopList:
        return '列表循环';
      case PlayMode.loopSingle:
        return '单曲循环';
      case PlayMode.shuffle:
        return '随机播放';
      case PlayMode.sequence:
        return '顺序播放';
    }
  }
}
