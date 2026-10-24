import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';

/// iPhone 竖屏歌曲播放信息卡片 (1:1 对齐设计手稿)
/// 位于中间各功能滚动视窗与底部播放胶囊栏之间
class IphoneNowPlayingCard extends StatelessWidget {
  const IphoneNowPlayingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HifiAudioService.instance,
      builder: (context, _) {
        final service = HifiAudioService.instance;
        final track = service.currentTrack;
        final state = service.state;

        // 计算微型双声道电平
        final leftLevel = state.spectrumLevels.isNotEmpty
            ? state.spectrumLevels[1].clamp(0.05, 1.0)
            : (state.isPlaying ? 0.72 : 0.0);
        final rightLevel = state.spectrumLevels.length > 2
            ? state.spectrumLevels[2].clamp(0.05, 1.0)
            : (state.isPlaying ? 0.65 : 0.0);

        final title = track?.title ?? '加州旅馆 Hotel California';
        final artistAlbum = track != null
            ? '${track.artist} · ${track.album}'
            : 'Eagles · Hell Freezes Over (Master)';

        final specText = track != null
            ? '${track.format.name.toUpperCase()} ${(track.sampleRate / 1000).toStringAsFixed(0)}k/${track.bitDepth}b'
            : 'FLAC 192k/24b';

        return Container(
          height: 70.0,
          decoration: BoxDecoration(
            color: const Color(0xD1121823),
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(
              color: const Color(0x24FFFFFF),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 18.0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
          child: Row(
            children: [
              // 1. 左侧黑胶唱片与封面微缩图
              SizedBox(
                width: 48.0,
                height: 48.0,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // 黑胶盘体
                    Positioned(
                      right: 0,
                      child: Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF101318),
                          border: Border.all(
                            color: const Color(0x26FFFFFF),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                    // 封面卡片
                    Container(
                      width: 42.0,
                      height: 42.0,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A1B0A), Color(0xFF1A2E3B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(7.0),
                        border: Border.all(
                          color: const Color(0x33FFFFFF),
                          width: 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 6.0,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '🎸',
                        style: TextStyle(fontSize: 18.0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),

              // 2. 中间曲目元数据与发烧直通标牌
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      artistAlbum,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          // 母带格式徽标
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0),
                            decoration: BoxDecoration(
                              color: const Color(0x2EFFB703),
                              borderRadius: BorderRadius.circular(3.5),
                              border: Border.all(
                                color: const Color(0x66FFB703),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              specText,
                              style: const TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFB703),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5.0),

                          // BIT-PERFECT 直通徽标
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0),
                            decoration: BoxDecoration(
                              color: const Color(0x2606D6A0),
                              borderRadius: BorderRadius.circular(3.5),
                              border: Border.all(
                                color: const Color(0x6606D6A0),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4.0,
                                  height: 4.0,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF06D6A0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF06D6A0),
                                        blurRadius: 4.0,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 3.5),
                                const Text(
                                  'BIT-PERFECT',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF06D6A0),
                                    letterSpacing: 0.2,
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

              // 3. 右侧微型双声道实时动圈动态电平条
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildVuMeterBar(leftLevel, 'L'),
                    const SizedBox(height: 3.5),
                    _buildVuMeterBar(rightLevel, 'R'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVuMeterBar(double level, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 7.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 3.0),
        Container(
          width: 36.0,
          height: 3.5,
          decoration: BoxDecoration(
            color: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(2.0),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: level.clamp(0.05, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2.0),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF00B4D8),
                    Color(0xFF06D6A0),
                    Color(0xFFFFB703),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
