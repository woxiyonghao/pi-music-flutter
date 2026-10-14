import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../theme/hifi_theme.dart';
import '../visualizers/visualizer_type.dart';
import '../visualizers/visualizer_stage_widget.dart';
import '../shared/playback_controls_widget.dart';

/// macOS 桌面专业端发烧播放器 UI (CoreAudio / Hog Mode)
class MacMainView extends StatefulWidget {
  const MacMainView({super.key});

  @override
  State<MacMainView> createState() => _MacMainViewState();
}

class _MacMainViewState extends State<MacMainView> {
  VisualizerType _activeVisualizer = VisualizerType.mcIntosh;

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
          body: Row(
            children: [
              // 1. macOS 专业侧边栏 (220px 紧凑发烧布局，防溢出)
              Container(
                width: 220,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1117),
                  border: Border(right: BorderSide(color: HifiTheme.cardBorder)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // macOS 顶部交通灯安全留白
                    const SizedBox(height: 44),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18.0),
                      child: Text(
                        'MY HIFI MASTER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: HifiTheme.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildMacMenuItem(Icons.library_music_rounded, '音乐曲库', true),
                    _buildMacMenuItem(Icons.playlist_play_rounded, '精选歌单', false),
                    _buildMacMenuItem(Icons.album_rounded, '专辑唱片', false),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18.0),
                      child: Text(
                        'HARDWARE & DAC',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: HifiTheme.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildMacMenuItem(Icons.developer_board_rounded, 'AK4499EX 前级', false),
                    _buildMacMenuItem(Icons.tune_rounded, '10段专业均衡器', false),
                    _buildMacMenuItem(Icons.speaker_rounded, 'CoreAudio 独占', false),
                    const Spacer(),

                    // 底部声卡指示 (自适应防溢出)
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: HifiTheme.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: HifiTheme.cardBorder),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lock_rounded, size: 12, color: HifiTheme.neonCyan),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'HOG MODE (EXCLUSIVE)',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: HifiTheme.neonCyan,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Bit-Perfect Direct Audio',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: HifiTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. macOS 主舞台展示区
              Expanded(
                child: Column(
                  children: [
                    // 顶部窗口标头 (集成发烧动效切换与引擎状态)
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: const BoxDecoration(
                        color: Color(0xFF090D14),
                        border: Border(bottom: BorderSide(color: HifiTheme.cardBorder)),
                      ),
                      child: Row(
                        children: [
                          // 左侧标头与状态绿灯
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: HifiTheme.neonCyan,
                                  boxShadow: [
                                    BoxShadow(color: HifiTheme.neonCyan, blurRadius: 6),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'HiFi Master Audio Console',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: HifiTheme.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),

                          // 右侧发烧动效快捷切换 + 引擎指标 (自适应防溢出)
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 动效切换器
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141923),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: HifiTheme.cardBorder),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<VisualizerType>(
                                        value: _activeVisualizer,
                                        dropdownColor: const Color(0xFF161B24),
                                        isDense: true,
                                        icon: const Icon(Icons.style_rounded, size: 14, color: HifiTheme.mcIntoshGlow),
                                        style: const TextStyle(fontSize: 11, color: HifiTheme.textPrimary, fontWeight: FontWeight.bold),
                                        items: VisualizerType.values.map((type) {
                                          return DropdownMenuItem<VisualizerType>(
                                            value: type,
                                            child: Text(type.displayName),
                                          );
                                        }).toList(),
                                        onChanged: (newType) {
                                          if (newType != null) {
                                            setState(() {
                                              _activeVisualizer = newType;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // 384kHz 引擎指标
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: HifiTheme.mcIntoshBlue.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.4)),
                                    ),
                                    child: const Text(
                                      '384kHz / 32Bit Float Engine',
                                      style: TextStyle(color: HifiTheme.mcIntoshGlow, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 中部发烧动效舞台核心 (无遮挡纯净画布)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(14)),
                          child: VisualizerStageWidget(
                            activeType: _activeVisualizer,
                            showSelector: false,
                          ),
                        ),
                      ),
                    ),

                    // 底部常驻播放控制栏 (自适应弹性布局，彻底杜绝 overflow 报警)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: const BoxDecoration(
                        color: HifiTheme.cardBackground,
                        border: Border(top: BorderSide(color: HifiTheme.cardBorder)),
                      ),
                      child: Row(
                        children: [
                          // 曲目信息 (弹性收缩防溢出)
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  track?.title ?? 'McIntosh Reference Track',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  track?.artist ?? 'Apple CoreAudio Direct',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: HifiTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                          // 播放控制
                          const Expanded(
                            flex: 5,
                            child: PlaybackControlsWidget(compact: true),
                          ),

                          // 音量控制 (弹性收缩 Slider，永不溢出)
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Icon(Icons.volume_up_rounded, size: 18, color: HifiTheme.textMuted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                      activeTrackColor: HifiTheme.mcIntoshGlow,
                                      inactiveTrackColor: HifiTheme.cardBorder,
                                    ),
                                    child: Slider(
                                      value: state.volume,
                                      onChanged: (val) => service.setVolume(val),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacMenuItem(IconData icon, String title, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active ? HifiTheme.mcIntoshBlue.withOpacity(0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: active ? HifiTheme.mcIntoshGlow : HifiTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? HifiTheme.textPrimary : HifiTheme.textMuted,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
