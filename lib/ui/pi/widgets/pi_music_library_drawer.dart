import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../models/track.dart';
import '../../../services/music_database_service.dart';
import '../../../services/web_remote_service.dart';
import '../../../theme/hifi_theme.dart';
import '../../common/glass_card.dart';

/// 树莓派 1024x600 专属大触控曲库抽屉
/// 特点：粗手指大触控行高 (>=60dp)、A-Z 拼音字母快速跳跃、即点即播与高亮
class PiMusicLibraryDrawer extends StatefulWidget {
  final VoidCallback onClose;

  const PiMusicLibraryDrawer({super.key, required this.onClose});

  @override
  State<PiMusicLibraryDrawer> createState() => _PiMusicLibraryDrawerState();
}

class _PiMusicLibraryDrawerState extends State<PiMusicLibraryDrawer> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _filterQuery = '';
  String _activeTag = 'ALL'; // ALL, DSD, HIRES, CUE

  bool _isScanning = false;
  String? _scanMessage;

  final List<String> _alphabet = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scanMusic() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _scanMessage = '正在检索全盘与移动存储音频...';
    });
    try {
      final count = await MusicDatabaseService.instance.scanLibrary();
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanMessage = '扫描完成！已入库 $count 首曲目';
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _scanMessage = null;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanMessage = '扫描异常: $e';
        });
      }
    }
  }

  List<Track> _getFilteredTracks(List<Track> allTracks) {
    return allTracks.where((t) {
      if (_activeTag == 'DSD') {
        if (t.format != AudioFormat.dsdDsf && t.format != AudioFormat.dsdDff) return false;
      } else if (_activeTag == 'HIRES') {
        if (t.sampleRate < 96000 && t.bitDepth < 24) return false;
      } else if (_activeTag == 'CUE') {
        if (!t.isCueTrack) return false;
      }

      if (_filterQuery.trim().isEmpty) return true;
      final q = _filterQuery.toLowerCase();
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          t.album.toLowerCase().contains(q);
    }).toList();
  }

  void _scrollToLetter(String letter, List<Track> tracks) {
    int targetIndex = -1;
    for (int i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      final firstChar = t.title.trim().isNotEmpty ? t.title.trim()[0].toUpperCase() : '#';
      if (letter == '#' && !RegExp(r'[A-Za-z]').hasMatch(firstChar)) {
        targetIndex = i;
        break;
      } else if (firstChar == letter) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex != -1 && _scrollController.hasClients) {
      final offset = (targetIndex * 64.0).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTracks = MusicDatabaseService.instance.tracks;
    final filteredTracks = _getFilteredTracks(allTracks);
    final audioService = HifiAudioService.instance;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: GlassCard(
            borderRadius: 16.0,
            backgroundColor: HifiTheme.cardBackground.withValues(alpha: 0.92),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. 顶部控制栏：关闭大按钮、标题、分类过滤器与搜索框
                Row(
                  children: [
                    // 关闭大热区按钮 (48x48dp)
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        onTap: widget.onClose,
                        borderRadius: BorderRadius.circular(24),
                        splashColor: HifiTheme.mcIntoshGlow.withValues(alpha: 0.3),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                            border: Border.all(color: HifiTheme.cardBorder),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // 标题与曲目总数
                    Row(
                      children: [
                        const Text(
                          '发烧本地曲库',
                          style: TextStyle(
                            color: HifiTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: HifiTheme.mcIntoshBlue.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            '${filteredTracks.length} 首',
                            style: const TextStyle(
                              color: HifiTheme.mcIntoshGlow,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 14),

                    // 中间操作区：快速过滤器 + 扫描按键 (横向自适应)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFilterPill('ALL', '全部'),
                            const SizedBox(width: 6),
                            _buildFilterPill('DSD', 'DSD 母带'),
                            const SizedBox(width: 6),
                            _buildFilterPill('HIRES', 'Hi-Res 192k'),
                            const SizedBox(width: 6),
                            _buildFilterPill('CUE', 'CUE 分轨'),
                            const SizedBox(width: 10),

                            // 扫描全盘 / U 盘大按键
                            GestureDetector(
                              onTap: _isScanning ? null : _scanMusic,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isScanning
                                      ? HifiTheme.mcIntoshBlue.withValues(alpha: 0.3)
                                      : HifiTheme.mcIntoshBlue.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: HifiTheme.mcIntoshGlow),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isScanning)
                                      const SizedBox(
                                        width: 13,
                                        height: 13,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    else
                                      const Icon(Icons.sync_rounded, color: Colors.white, size: 15),
                                    const SizedBox(width: 5),
                                    Text(
                                      _isScanning ? '正在扫描...' : '扫描曲库/U盘',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 搜索框
                    SizedBox(
                      width: 180,
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (val) {
                          setState(() {
                            _filterQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: '搜索曲目/艺术家...',
                          hintStyle: const TextStyle(color: HifiTheme.textMuted, fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, color: HifiTheme.textMuted, size: 18),
                          suffixIcon: _filterQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      _filterQuery = '';
                                    });
                                  },
                                  child: const Icon(Icons.close_rounded, color: HifiTheme.textMuted, size: 18),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.3),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: HifiTheme.cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: HifiTheme.cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: HifiTheme.mcIntoshGlow),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_scanMessage != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: HifiTheme.mcIntoshBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: HifiTheme.mcIntoshGlow, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _scanMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                const Divider(color: HifiTheme.cardBorder, height: 18),

                // 2. 主列表区域与右侧字母索引条
                Expanded(
                  child: Row(
                    children: [
                      // 左侧大字号曲目滚动列表
                      Expanded(
                        child: filteredTracks.isEmpty
                            ? _buildEmptyState(allTracks.isEmpty)
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: filteredTracks.length,
                                itemExtent: 64.0, // 固定 64dp 高度，保障手指轻松点按
                                itemBuilder: (context, index) {
                                  final track = filteredTracks[index];
                                  final isCurrent = audioService.currentTrack?.matches(track) == true;
                                  final isPlaying = isCurrent && audioService.state.isPlaying;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Material(
                                      color: isCurrent
                                          ? HifiTheme.mcIntoshBlue.withValues(alpha: 0.22)
                                          : Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        onTap: () {
                                          audioService.playTrack(track, filteredTracks, index);
                                          widget.onClose();
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        splashColor: HifiTheme.mcIntoshGlow.withValues(alpha: 0.3),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isCurrent
                                                  ? HifiTheme.mcIntoshGlow.withValues(alpha: 0.8)
                                                  : Colors.transparent,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // 播放状态图标或序号
                                              SizedBox(
                                                width: 32,
                                                child: isPlaying
                                                    ? const Icon(Icons.graphic_eq_rounded, color: HifiTheme.neonCyan, size: 22)
                                                    : (isCurrent
                                                        ? const Icon(Icons.pause_rounded, color: HifiTheme.mcIntoshGlow, size: 22)
                                                        : Text(
                                                            '${index + 1}',
                                                            style: const TextStyle(
                                                              color: HifiTheme.textMuted,
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          )),
                                              ),
                                              const SizedBox(width: 8),

                                              // 曲目名与艺术家
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      track.title,
                                                      style: TextStyle(
                                                        color: isCurrent ? HifiTheme.neonCyan : HifiTheme.textPrimary,
                                                        fontSize: 15,
                                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${track.artist.isNotEmpty ? track.artist : '未知艺术家'} · ${track.album.isNotEmpty ? track.album : '未知专辑'}',
                                                      style: TextStyle(
                                                        color: isCurrent ? Colors.white70 : HifiTheme.textMuted,
                                                        fontSize: 12,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // 格式与规格标牌
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: track.formatBadge.contains('DSD')
                                                      ? HifiTheme.accuphaseGold.withValues(alpha: 0.15)
                                                      : HifiTheme.mcIntoshBlue.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: track.formatBadge.contains('DSD')
                                                        ? HifiTheme.accuphaseGold.withValues(alpha: 0.5)
                                                        : HifiTheme.mcIntoshGlow.withValues(alpha: 0.5),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  track.formatBadge,
                                                  style: TextStyle(
                                                    color: track.formatBadge.contains('DSD')
                                                        ? HifiTheme.accuphaseGold
                                                        : HifiTheme.mcIntoshGlow,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),

                                              // 时长
                                              Text(
                                                track.durationString,
                                                style: const TextStyle(
                                                  color: HifiTheme.textMuted,
                                                  fontSize: 12,
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // 右侧大尺寸字母快速跳跃索引条
                      const SizedBox(width: 8),
                      Container(
                        width: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _alphabet.map((letter) {
                            return GestureDetector(
                              onTap: () => _scrollToLetter(letter, filteredTracks),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 1),
                                child: Text(
                                  letter,
                                  style: const TextStyle(
                                    color: HifiTheme.mcIntoshGlow,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(String tag, String label) {
    final isSelected = _activeTag == tag;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTag = tag;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? HifiTheme.mcIntoshBlue : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? HifiTheme.mcIntoshGlow : HifiTheme.cardBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : HifiTheme.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isCompletelyEmpty) {
    if (!isCompletelyEmpty) {
      return Center(
        child: Text(
          '未找到与 "$_filterQuery" 匹配的曲目',
          style: const TextStyle(color: HifiTheme.textMuted, fontSize: 15),
        ),
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HifiTheme.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.album_rounded, size: 50, color: HifiTheme.mcIntoshGlow),
            const SizedBox(height: 10),
            const Text(
              '树莓派曲库暂无音乐',
              style: TextStyle(
                color: HifiTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '支持将存有音乐的 U 盘插入树莓派 USB 接口，\n或在同一局域网用电脑浏览器访问 http://${WebRemoteService.instance.localIp}:8080 无线传歌',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: HifiTheme.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _scanMusic,
              icon: _isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.travel_explore_rounded, size: 18),
              label: Text(_isScanning ? '正在扫描...' : '立即扫描本地与 U 盘音乐'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HifiTheme.mcIntoshBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
