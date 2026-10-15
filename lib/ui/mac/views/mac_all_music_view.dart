import 'package:flutter/material.dart';
import '../../../models/track.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../services/theme_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// 所有音乐全景树状视图 (1:1 严格对齐 C++ AllMusicPlaylistView.cpp)
class MacAllMusicView extends StatefulWidget {
  final List<Track> tracks;
  final VoidCallback? onNavigateToScan;

  const MacAllMusicView({
    super.key,
    required this.tracks,
    this.onNavigateToScan,
  });

  @override
  State<MacAllMusicView> createState() => _MacAllMusicViewState();
}

class _MacAllMusicViewState extends State<MacAllMusicView> {
  int _viewMode = 0; // 0: 音频格式, 1: 艺术家/专辑, 2: 存储目录
  final Map<String, bool> _treeExpanded = {};

  bool _isGroupOpen(String key) => _treeExpanded[key] ?? true;

  void _toggleGroup(String key) {
    setState(() {
      _treeExpanded[key] = !(_treeExpanded[key] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.tracks.length;
    final totalDurationSec =
        widget.tracks.fold(0, (sum, t) => sum + t.durationSec);
    final totalMinutes = (totalDurationSec / 60).floor();

    const title = '所有音乐';
    final subtitle = totalCount > 0
        ? '发烧曲库全景树状视图 · 共 $totalCount 首 · 总时长: $totalMinutes 分钟'
        : '本地发烧曲库树列表';

    return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 卡片标头：主标题与副描述
          const Text(
            title,
            style: TextStyle(
              fontSize: UIConfig.fontMedium,
              fontWeight: FontWeight.bold,
              color: UIConfig.textActive,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: UIConfig.fontSmall,
              color: UIConfig.textMuted,
            ),
          ),
          const SizedBox(height: 16.0),

          // 2. 顶层工具栏：模式切换胶囊
          _buildToolbar(),

          const SizedBox(height: 12.0),

          // 3. 树状列表主视口
          Expanded(
            child: totalCount == 0
                ? _buildEmptyState()
                : _buildTreeScrollView(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        _buildModeButton('按音频格式', 0),
        const SizedBox(width: 8.0),
        _buildModeButton('按艺术家/专辑', 1),
        const SizedBox(width: 8.0),
        _buildModeButton('按存储目录', 2),
      ],
    );
  }

  Widget _buildModeButton(String label, int mode) {
    final isActive = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isActive
              ? UIConfig.accent.withValues(alpha: 0.28)
              : const Color.fromRGBO(28, 34, 46, 0.70),
          borderRadius: BorderRadius.circular(7.0),
          border: Border.all(
            color: isActive
                ? UIConfig.glassBorder
                : const Color.fromRGBO(255, 255, 255, 0.10),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: UIConfig.fontSmall,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? UIConfig.textActive : UIConfig.textNormal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '本地发烧曲库暂无音乐',
            style: TextStyle(
              fontSize: UIConfig.fontRegular,
              color: UIConfig.textNormal,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8.0),
          const Text(
            '请前往「扫描音乐」检索本地音乐文件，或将歌曲导入播放列表。',
            style: TextStyle(
              fontSize: UIConfig.fontSmall,
              color: UIConfig.textMuted,
            ),
          ),
          const SizedBox(height: 18.0),
          ElevatedButton(
            onPressed: widget.onNavigateToScan,
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConfig.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('前往扫描音乐', style: TextStyle(fontSize: UIConfig.fontSmall)),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeScrollView() {
    if (_viewMode == 0) {
      return _buildFormatTree();
    } else if (_viewMode == 1) {
      return _buildArtistAlbumTree();
    } else {
      return _buildDirectoryTree();
    }
  }

  Widget _buildFormatTree() {
    final dsdTracks = widget.tracks
        .where((t) =>
            t.format == AudioFormat.dsdDsf || t.format == AudioFormat.dsdDff)
        .toList();
    final flacTracks =
        widget.tracks.where((t) => t.format == AudioFormat.flac).toList();
    final wavTracks =
        widget.tracks.where((t) => t.format == AudioFormat.wav).toList();
    final alacTracks =
        widget.tracks.where((t) => t.format == AudioFormat.alac).toList();
    final mp3Tracks =
        widget.tracks.where((t) => t.format == AudioFormat.mp3).toList();
    final otherTracks = widget.tracks
        .where((t) =>
            t.format != AudioFormat.dsdDsf &&
            t.format != AudioFormat.dsdDff &&
            t.format != AudioFormat.flac &&
            t.format != AudioFormat.wav &&
            t.format != AudioFormat.alac &&
            t.format != AudioFormat.mp3)
        .toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        if (dsdTracks.isNotEmpty)
          _buildGroup(
            key: 'dsd',
            badge: 'DSD',
            title: 'DSD 原生母带 (DSF / DFF)',
            tracks: dsdTracks,
          ),
        if (flacTracks.isNotEmpty)
          _buildGroup(
            key: 'flac',
            badge: 'FLAC',
            title: 'FLAC 高解析无损母带',
            tracks: flacTracks,
          ),
        if (wavTracks.isNotEmpty)
          _buildGroup(
            key: 'wav',
            badge: 'WAV',
            title: 'WAV 广播级线性母带',
            tracks: wavTracks,
          ),
        if (alacTracks.isNotEmpty)
          _buildGroup(
            key: 'alac',
            badge: 'ALAC',
            title: 'Apple Lossless (ALAC)',
            tracks: alacTracks,
          ),
        if (mp3Tracks.isNotEmpty)
          _buildGroup(
            key: 'mp3',
            badge: 'MP3',
            title: 'MP3 经典流行音频',
            tracks: mp3Tracks,
          ),
        if (otherTracks.isNotEmpty)
          _buildGroup(
            key: 'other',
            badge: 'RAW',
            title: '其它发烧音轨',
            tracks: otherTracks,
          ),
      ],
    );
  }

  Widget _buildArtistAlbumTree() {
    final Map<String, List<Track>> artistMap = {};
    for (final t in widget.tracks) {
      final art = t.artist.isNotEmpty ? t.artist : '未知艺术家';
      artistMap.putIfAbsent(art, () => []).add(t);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        for (final entry in artistMap.entries)
          _buildGroup(
            key: 'art_${entry.key}',
            badge: '歌手',
            title: entry.key,
            tracks: entry.value,
          ),
      ],
    );
  }

  Widget _buildDirectoryTree() {
    final Map<String, List<Track>> dirMap = {};
    for (final t in widget.tracks) {
      final parts = t.filepath.split('/');
      final dir = parts.length > 1 ? parts[parts.length - 2] : '本地曲库';
      dirMap.putIfAbsent(dir, () => []).add(t);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        for (final entry in dirMap.entries)
          _buildGroup(
            key: 'dir_${entry.key}',
            badge: '目录',
            title: entry.key,
            tracks: entry.value,
          ),
      ],
    );
  }

  Widget _buildGroup({
    required String key,
    required String badge,
    required String title,
    required List<Track> tracks,
  }) {
    final isOpen = _isGroupOpen(key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 组标题栏 Header
          GestureDetector(
            onTap: () => _toggleGroup(key),
            child: Container(
              height: 32.0,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              decoration: BoxDecoration(
                color: isOpen
                    ? const Color.fromRGBO(30, 36, 52, 0.85)
                    : const Color.fromRGBO(22, 28, 40, 0.70),
                borderRadius: BorderRadius.circular(7.0),
                border: Border.all(
                  color: isOpen
                      ? UIConfig.glassBorder
                      : const Color.fromRGBO(255, 255, 255, 0.10),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  // 180° 旋转展开箭头
                  AnimatedRotation(
                    turns: isOpen ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 20.0,
                      color: UIConfig.accent,
                    ),
                  ),
                  const SizedBox(width: 4.0),

                  // 格式红框徽标
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5.0, vertical: 1.0),
                    decoration: BoxDecoration(
                      color: UIConfig.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(3.0),
                      border: Border.all(
                        color: UIConfig.accent.withValues(alpha: 0.55),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        color: UIConfig.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),

                  // 组名称
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: UIConfig.fontRegular,
                        color: UIConfig.textActive,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // 曲目统计
                  Text(
                    '${tracks.length} 首曲目',
                    style: const TextStyle(
                      fontSize: UIConfig.fontSmall,
                      color: UIConfig.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12.0),

                  // 播放全部按钮
                  GestureDetector(
                    onTap: () {
                      HifiAudioService.instance.playTracks(tracks, 0);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(45, 54, 74, 0.75),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.10),
                          width: 1.0,
                        ),
                      ),
                      child: const Text(
                        '播放全部',
                        style: TextStyle(
                          fontSize: UIConfig.fontSmall,
                          color: UIConfig.textActive,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 组内音轨列表
          if (isOpen)
            Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 4.0),
              child: Column(
                children: [
                  for (int i = 0; i < tracks.length; i++)
                    _buildTrackRow(tracks[i], i, tracks),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackRow(Track track, int index, List<Track> queueContext) {
    final service = HifiAudioService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        service.currentTrackIdNotifier,
        service.isPlayingNotifier,
        ThemeService.instance,
      ]),
      builder: (context, _) {
        final accent = ThemeService.instance.accentColor;
        final isCurrent = service.currentTrack != null &&
            service.currentTrack!.matches(track);
        final isPlaying = isCurrent && service.isPlayingNotifier.value;

        final numStr = '${(index + 1).toString().padLeft(2, '0')}.';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: InkWell(
            onTap: () {
              service.playTracks(queueContext, index);
            },
            borderRadius: BorderRadius.circular(6.0),
            child: Container(
              height: 30.0,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: isCurrent
                    ? accent.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6.0),
                border: isCurrent
                    ? Border.all(color: accent.withValues(alpha: 0.5), width: 1.0)
                    : null,
              ),
              child: Row(
                children: [
                  // 序号 / 在播动画律动指示器
                  SizedBox(
                    width: 24.0,
                    child: isPlaying
                        ? Icon(
                            Icons.equalizer_rounded,
                            size: 16.0,
                            color: accent,
                          )
                        : (isCurrent
                            ? Icon(
                                Icons.play_arrow_rounded,
                                size: 16.0,
                                color: accent,
                              )
                            : Text(
                                numStr,
                                style: const TextStyle(
                                  fontSize: UIConfig.fontSmall,
                                  color: Color.fromRGBO(140, 155, 175, 0.8),
                                  fontFamily: 'monospace',
                                ),
                              )),
                  ),
                  const SizedBox(width: 8.0),

                  // 曲目标题
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            track.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: UIConfig.fontRegular,
                              fontWeight:
                                  isCurrent ? FontWeight.w600 : FontWeight.normal,
                              color: isCurrent
                                  ? UIConfig.textActive
                                  : const Color.fromRGBO(215, 225, 238, 0.9),
                            ),
                          ),
                        ),
                        if (track.artist.isNotEmpty) ...[
                          const SizedBox(width: 8.0),
                          Text(
                            '- ${track.artist}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: UIConfig.fontSmall,
                              color: UIConfig.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 音频规格徽标 (DSD 64x / 192kHz/24bit)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6.0, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(18, 24, 34, 0.85),
                      borderRadius: BorderRadius.circular(3.0),
                      border: Border.all(
                        color: const Color.fromRGBO(50, 70, 95, 0.70),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      track.formatBadge,
                      style: const TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(65, 190, 255, 0.95),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10.0),

                  // 时长
                  SizedBox(
                    width: 44.0,
                    child: Text(
                      track.durationString,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: UIConfig.fontSmall,
                        color: Color.fromRGBO(150, 165, 185, 0.8),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),

                  const SizedBox(width: 10.0),

                  // 播放按钮
                  GestureDetector(
                    onTap: () {
                      service.playTracks(queueContext, index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(40, 48, 66, 0.75),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.10),
                          width: 1.0,
                        ),
                      ),
                      child: const Text(
                        '播放',
                        style: TextStyle(
                          fontSize: UIConfig.fontSmall,
                          color: UIConfig.textActive,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
