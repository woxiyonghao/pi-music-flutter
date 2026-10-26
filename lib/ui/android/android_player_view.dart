import 'package:flutter/material.dart';

import '../../core/hifi_audio_bindings.dart';
import '../../core/hifi_audio_service.dart';
import '../../models/playback_state.dart';
import '../../models/track.dart';
import '../../services/mseb_service.dart';
import '../../services/music_database_service.dart';
import '../../services/theme_service.dart';
import '../../theme/hifi_theme.dart';
import '../iphone/iphone_landscape_view.dart';
import 'widgets/android_settings_content.dart';

enum AndroidPlayerSection {
  library('音乐库', Icons.library_music_rounded),
  scan('扫描音乐', Icons.folder_open_rounded),
  equalizer('均衡器', Icons.equalizer_rounded),
  mseb('调音魔棒', Icons.auto_fix_high_rounded),
  theme('主题动效', Icons.palette_outlined),
  output('音频输出', Icons.headphones_rounded),
  network('无线服务', Icons.wifi_rounded),
  settings('系统设置', Icons.settings_outlined);

  const AndroidPlayerSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Android keeps the same library and playback state in both launch layouts.
class AndroidPlayerView extends StatefulWidget {
  const AndroidPlayerView({super.key, required this.landscape});

  final bool landscape;

  @override
  State<AndroidPlayerView> createState() => _AndroidPlayerViewState();
}

class _AndroidPlayerViewState extends State<AndroidPlayerView> {
  AndroidPlayerSection _section = AndroidPlayerSection.library;
  final _searchController = TextEditingController();
  late final Listenable _changes;

  HifiAudioService get _audio => HifiAudioService.instance;
  MusicDatabaseService get _library => MusicDatabaseService.instance;
  Color get _accent => ThemeService.instance.accentColor;

  @override
  void initState() {
    super.initState();
    _changes = Listenable.merge([
      _audio,
      _library,
      ThemeService.instance,
      MsebService.instance,
    ]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectSection(AndroidPlayerSection section) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.landscape) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final mediaQuery = MediaQuery.of(context);
          const canvasScale = 1.25;
          const fontScale = 0.88;
          final baseWidth =
              constraints.maxWidth < 500 ? 844.0 : constraints.maxWidth;
          final baseHeight =
              constraints.maxHeight < 260 ? 390.0 : constraints.maxHeight;
          final virtualSize = Size(
            baseWidth * canvasScale,
            baseHeight * canvasScale,
          );
          final horizontalPadding = EdgeInsets.only(
            left: mediaQuery.padding.left * canvasScale,
            right: mediaQuery.padding.right * canvasScale,
          );
          final horizontalViewPadding = EdgeInsets.only(
            left: mediaQuery.viewPadding.left * canvasScale,
            right: mediaQuery.viewPadding.right * canvasScale,
          );
          return FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: virtualSize.width,
              height: virtualSize.height,
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  size: virtualSize,
                  padding: horizontalPadding,
                  viewPadding: horizontalViewPadding,
                  viewInsets: mediaQuery.viewInsets * canvasScale,
                  textScaler: const TextScaler.linear(fontScale),
                ),
                child: const IphoneLandscapeView(
                  key: Key('android-landscape-layout'),
                  verticalMargin: 4.0,
                  verticalGap: 5.0,
                ),
              ),
            ),
          );
        },
      );
    }
    return ListenableBuilder(
      listenable: _changes,
      builder: (context, _) => Scaffold(
        backgroundColor: HifiTheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, constraints) => _portrait(constraints),
            ),
          ),
        ),
      ),
    );
  }

  Widget _portrait(BoxConstraints constraints) {
    // Keep every action reachable when the keyboard, split screen or large text
    // leaves too little height for a fixed player beneath the library.
    final scrollPage = constraints.maxHeight < 530 ||
        MediaQuery.textScalerOf(context).scale(14) > 21;
    final children = <Widget>[
      _header(),
      const SizedBox(height: 8),
      _topNavigation(),
      const SizedBox(height: 8),
      if (scrollPage)
        SizedBox(height: 280, child: _content())
      else
        Expanded(child: _content()),
      const SizedBox(height: 8),
      _nowPlaying(),
      const SizedBox(height: 8),
      _controls(),
    ];
    return KeyedSubtree(
      key: const Key('android-portrait-layout'),
      child: scrollPage
          ? SingleChildScrollView(child: Column(children: children))
          : Column(children: children),
    );
  }

  Widget _header() => Row(
        children: [
          Icon(Icons.graphic_eq_rounded, color: _accent, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'HiFi Player',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            widget.landscape ? '横屏' : '竖屏',
            style:
                const TextStyle(color: HifiTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '音量',
            visualDensity: VisualDensity.compact,
            onPressed: _showVolume,
            icon: Icon(_audio.state.isMuted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded),
          ),
        ],
      );

  Widget _topNavigation() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final section in AndroidPlayerSection.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  key: Key('android-nav-${section.name}'),
                  label: Text(section.label),
                  avatar: Icon(section.icon, size: 17),
                  selected: _section == section,
                  onSelected: (_) => _selectSection(section),
                  selectedColor: _accent.withValues(alpha: 0.22),
                  showCheckmark: false,
                ),
              ),
          ],
        ),
      );

  Widget _content() => _panel(
        child: _section == AndroidPlayerSection.library
            ? _libraryContent()
            : AndroidSettingsContent(
                key: ValueKey(_section),
                section: _section,
                onOpenNetwork: () =>
                    _selectSection(AndroidPlayerSection.network),
              ),
      );

  Widget _libraryContent() {
    final query = _searchController.text.trim().toLowerCase();
    final tracks = _library.tracks.where((track) {
      return query.isEmpty ||
          '${track.title} ${track.artist} ${track.album}'
              .toLowerCase()
              .contains(query);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('音乐库 · ${tracks.length} 首',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              IconButton(
                tooltip: '播放全部',
                onPressed: tracks.isEmpty ? null : () => _play(tracks, 0),
                icon: Icon(Icons.play_circle_outline_rounded, color: _accent),
              ),
              IconButton(
                tooltip: '扫描音乐',
                onPressed: () => _selectSection(AndroidPlayerSection.scan),
                icon: const Icon(Icons.create_new_folder_outlined, size: 22),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            key: const Key('android-library-search'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索歌曲、歌手、专辑',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.035),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.library_music_outlined,
                          size: 42, color: _accent),
                      const SizedBox(height: 12),
                      Text(query.isEmpty ? '把喜欢的音乐放进来' : '没有找到匹配的歌曲'),
                      const SizedBox(height: 8),
                      Text(
                        query.isEmpty
                            ? '通过 WiFi 传歌导入文件，再扫描本地音乐。'
                            : '试试其他歌名、歌手或专辑。',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: HifiTheme.textSecondary),
                      ),
                      if (query.isEmpty)
                        TextButton.icon(
                          onPressed: () =>
                              _selectSection(AndroidPlayerSection.network),
                          icon: const Icon(Icons.wifi_rounded),
                          label: const Text('WiFi 传歌'),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  key: const PageStorageKey('android-library'),
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) =>
                      _trackTile(tracks[index], () => _play(tracks, index)),
                ),
        ),
      ],
    );
  }

  Widget _trackTile(Track track, VoidCallback onTap) {
    final selected = track.matches(_audio.currentTrack);
    return ListTile(
      key: ValueKey('android-track-${track.filepath}-${track.trackNumber}'),
      dense: true,
      selected: selected,
      selectedTileColor: _accent.withValues(alpha: 0.1),
      contentPadding: const EdgeInsets.only(left: 12, right: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: selected ? 0.24 : 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          selected && _audio.state.isPlaying
              ? Icons.graphic_eq_rounded
              : Icons.music_note_rounded,
          color: _accent,
          size: 22,
        ),
      ),
      title: Text(track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${track.artist.isEmpty ? '未知歌手' : track.artist} · ${_trackSpecification(track)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: HifiTheme.textSecondary),
      ),
      trailing: IconButton(
        tooltip: '加入播放队列',
        onPressed: () {
          _audio.addToQueue(track);
          _message('已加入播放队列');
        },
        icon: const Icon(Icons.playlist_add_rounded, size: 20),
      ),
      onTap: onTap,
    );
  }

  Future<void> _play(List<Track> tracks, int index) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _audio.playTrack(tracks[index], tracks, index);
    if (mounted && !_audio.state.isPlaying && !_audio.state.isPaused) {
      _message('无法播放此文件，请检查文件是否存在及音频引擎状态。');
    }
  }

  Widget _nowPlaying({bool framed = true}) {
    final track = _audio.currentTrack;
    final state = _audio.state;
    final nativeReady = HifiAudioBindings.instance.isLoaded;
    final status = _audio.isPreparingTrack
        ? '正在打开文件…'
        : state.isPlaying
            ? '正在播放'
            : state.isPaused
                ? '已暂停'
                : '等待播放';
    final child = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_accent.withValues(alpha: 0.55), HifiTheme.background],
              ),
              border: Border.all(color: _accent.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.album_rounded, size: 28, color: _accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(track?.title ?? '尚未选择歌曲',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  track == null
                      ? '从音乐库开始聆听'
                      : '${track.artist.isEmpty ? '未知歌手' : track.artist} · ${_trackSpecification(track)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: HifiTheme.textSecondary),
                ),
                const SizedBox(height: 3),
                Text(
                  nativeReady && state.isPlaying && state.isBitPerfect
                      ? '$status · BIT-PERFECT'
                      : status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: _accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return framed ? _panel(child: child) : child;
  }

  Widget _controls() {
    final state = _audio.state;
    final hasQueue = _audio.playlistQueue.isNotEmpty;
    final canPlay = hasQueue || _audio.currentTrack != null;
    final mode = switch (_audio.playMode) {
      PlayMode.loopList => ('列表循环', Icons.repeat_rounded),
      PlayMode.loopSingle => ('单曲循环', Icons.repeat_one_rounded),
      PlayMode.shuffle => ('随机播放', Icons.shuffle_rounded),
      PlayMode.sequence => ('顺序播放', Icons.format_list_numbered_rounded),
    };
    return _panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(state.currentTimeString,
                    style: const TextStyle(
                        fontSize: 10, color: HifiTheme.textSecondary)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      key: const Key('android-playback-progress'),
                      value: state.progress.clamp(0, 1),
                      activeColor: _accent,
                      onChanged: state.duration <= 0
                          ? null
                          : (value) => _audio.seek(value * state.duration),
                    ),
                  ),
                ),
                Text(state.durationString,
                    style: const TextStyle(
                        fontSize: 10, color: HifiTheme.textSecondary)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: mode.$1,
                  icon: Icon(mode.$2, size: 21),
                  onPressed: _audio.cyclePlayMode,
                ),
                IconButton(
                  tooltip: '上一曲',
                  onPressed: hasQueue ? _audio.previous : null,
                  icon: const Icon(Icons.skip_previous_rounded, size: 30),
                ),
                IconButton.filled(
                  key: const Key('android-play-pause'),
                  tooltip: state.isPlaying ? '暂停' : '播放',
                  style: IconButton.styleFrom(
                      backgroundColor: _accent, foregroundColor: Colors.white),
                  onPressed: canPlay ? _audio.togglePlayPause : null,
                  icon: Icon(
                      state.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 30),
                ),
                IconButton(
                  tooltip: '下一曲',
                  onPressed: hasQueue ? () => _audio.next() : null,
                  icon: const Icon(Icons.skip_next_rounded, size: 30),
                ),
                IconButton(
                  tooltip: '播放队列',
                  onPressed: _showQueue,
                  icon: const Icon(Icons.queue_music_rounded, size: 23),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVolume() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => ListenableBuilder(
        listenable: _audio,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('音量 · ${(_audio.state.volume * 100).round()}%'),
              Row(
                children: [
                  IconButton(
                    tooltip: _audio.state.isMuted ? '取消静音' : '静音',
                    onPressed: _audio.toggleMute,
                    icon: Icon(_audio.state.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded),
                  ),
                  Expanded(
                    child: Slider(
                      value: _audio.state.volume.clamp(0, 1),
                      onChanged: _audio.setVolume,
                      activeColor: _accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueue() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: ListenableBuilder(
          listenable: _audio,
          builder: (context, _) {
            final queue = List<Track>.of(_audio.playlistQueue);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('播放队列 · ${queue.length} 首',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: queue.isEmpty
                      ? const Center(child: Text('队列为空，从音乐库选择歌曲'))
                      : ListView.builder(
                          itemCount: queue.length,
                          itemBuilder: (context, index) => ListTile(
                            selected: index == _audio.currentIndex,
                            leading: Text('${index + 1}'),
                            title: Text(queue[index].title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(queue[index].artist,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Text(queue[index].durationSec > 0
                                ? queue[index].durationString
                                : '--:--'),
                            onTap: () => _play(queue, index),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _trackSpecification(Track track) {
    if (track.sampleRate > 0 && track.bitDepth > 0) return track.formatBadge;
    return track.format == AudioFormat.unknown
        ? '规格待检测'
        : '${track.format.name.toUpperCase()} · 规格待检测';
  }

  Widget _panel({required Widget child}) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: HifiTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      );
}
