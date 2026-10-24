import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../models/track.dart';
import '../../../services/music_database_service.dart';

/// iPhone 竖屏所有音乐曲库视窗 (1:1 对齐设计手稿)
class IphoneAllMusicView extends StatefulWidget {
  const IphoneAllMusicView({super.key});

  @override
  State<IphoneAllMusicView> createState() => _IphoneAllMusicViewState();
}

class _IphoneAllMusicViewState extends State<IphoneAllMusicView> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilter = 0; // 0: 全部, 1: DSD母带, 2: 192kHz, 3: 收藏歌单

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MusicDatabaseService.instance,
        HifiAudioService.instance,
      ]),
      builder: (context, _) {
        final db = MusicDatabaseService.instance;
        final service = HifiAudioService.instance;
        final allTracks = db.tracks;
        final currentTrack = service.currentTrack;

        // 根据搜索与筛选分类
        final query = _searchController.text.trim().toLowerCase();
        final filtered = allTracks.where((t) {
          if (query.isNotEmpty) {
            final match = t.title.toLowerCase().contains(query) ||
                t.artist.toLowerCase().contains(query) ||
                t.album.toLowerCase().contains(query);
            if (!match) return false;
          }
          if (_selectedFilter == 1) {
            return t.format == AudioFormat.dsdDsf || t.format == AudioFormat.dsdDff;
          }
          if (_selectedFilter == 2) {
            return t.sampleRate >= 192000;
          }
          return true;
        }).toList();

        return Column(
          children: [
            // 1. 搜索框
            Container(
              height: 36.0,
              decoration: BoxDecoration(
                color: const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(9.0),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 12.0, color: Colors.white),
                decoration: InputDecoration(
                  hintText: '🔍 搜索曲目、发烧母带、歌手...',
                  hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  border: InputBorder.none,
                  suffixIcon: query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          child: const Icon(Icons.clear, size: 14.0, color: Color(0xFF828C9B)),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8.0),

            // 2. 分类标签胶囊
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildTagPill('全部 (${allTracks.length})', 0),
                  const SizedBox(width: 6.0),
                  _buildTagPill('DSD母带', 1),
                  const SizedBox(width: 6.0),
                  _buildTagPill('192kHz', 2),
                  const SizedBox(width: 6.0),
                  _buildTagPill('收藏歌单', 3),
                ],
              ),
            ),
            const SizedBox(height: 10.0),

            // 3. 歌曲列表
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.music_off_rounded, size: 36.0, color: Color(0xFF475569)),
                          const SizedBox(height: 8.0),
                          Text(
                            allTracks.isEmpty ? '曲库为空，请先在「扫描」中扫描本地音乐' : '未找到匹配曲目',
                            style: const TextStyle(fontSize: 12.0, color: Color(0xFF828C9B)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6.0),
                      itemBuilder: (context, index) {
                        final track = filtered[index];
                        final isPlaying = currentTrack?.id == track.id;
                        return _buildTrackCard(track, isPlaying, index + 1, service);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTagPill(String label, int index) {
    final isSelected = (_selectedFilter == index);
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x3300B4D8) : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected ? const Color(0xFF00B4D8) : const Color(0x1AFFFFFF),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackCard(Track track, bool isPlaying, int num, HifiAudioService service) {
    final formatBadge = track.format.name.toUpperCase();
    final rateStr = (track.sampleRate / 1000).toStringAsFixed(0);
    final isDsd = track.format == AudioFormat.dsdDsf || track.format == AudioFormat.dsdDff;

    final badgeBg = isDsd ? const Color(0x2606D6A0) : const Color(0x2EFFB703);
    final badgeColor = isDsd ? const Color(0xFF06D6A0) : const Color(0xFFFFB703);

    return GestureDetector(
      onTap: () => service.playTrack(track),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isPlaying ? const Color(0x2400B4D8) : const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(9.0),
          border: Border.all(
            color: isPlaying ? const Color(0x8000B4D8) : const Color(0x0FFFFFFF),
          ),
        ),
        child: Row(
          children: [
            // 播放图标或序号
            Container(
              width: 18.0,
              alignment: Alignment.center,
              child: isPlaying
                  ? const Icon(Icons.play_arrow_rounded, color: Color(0xFF00B4D8), size: 16.0)
                  : Text(
                      '$num',
                      style: const TextStyle(fontSize: 11.0, color: Color(0xFF64748B)),
                    ),
            ),
            const SizedBox(width: 8.0),

            // 歌曲标题与歌手
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                      color: isPlaying ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    '${track.artist.isEmpty ? "未知艺术家" : track.artist} · ${track.album.isEmpty ? "单曲" : track.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF828C9B)),
                  ),
                ],
              ),
            ),

            // 格式徽标与时长
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.0),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                  child: Text(
                    '$formatBadge ${rateStr}k',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  track.durationString,
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontFamily: 'monospace'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
