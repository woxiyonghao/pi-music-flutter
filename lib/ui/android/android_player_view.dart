import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/hifi_audio_bindings.dart';
import '../../core/hifi_audio_service.dart';
import '../../models/playback_state.dart';
import '../../models/track.dart';
import '../../services/mseb_service.dart';
import '../../services/music_database_service.dart';
import '../../services/theme_service.dart';
import '../../theme/hifi_theme.dart';
import '../iphone/iphone_landscape_view.dart';
import '../mac/mac_background_widget.dart';
import '../visualizers/visualizer_stage_widget.dart';
import '../visualizers/visualizer_type.dart';
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
  late final Listenable _changes;
  final _navScrollController = ScrollController();
  bool _isFullscreenTheme = false;

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
    _navScrollController.dispose();
    super.dispose();
  }

  void _ensureChipVisible(BuildContext chipContext) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!chipContext.mounted || !_navScrollController.hasClients) return;
      final ro = chipContext.findRenderObject();
      if (ro is RenderBox) {
        final viewport = RenderAbstractViewport.of(ro);
        if (viewport != null) {
          final offsetToReveal = viewport.getOffsetToReveal(ro, 0.5);
          final current = _navScrollController.offset;
          if ((offsetToReveal.offset - current).abs() > 4.0) {
            _navScrollController.animateTo(
              offsetToReveal.offset.clamp(
                _navScrollController.position.minScrollExtent,
                _navScrollController.position.maxScrollExtent,
              ),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
            );
          }
        }
      }
    });
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
    final theme = ThemeService.instance;
    final visualizer = VisualizerType.values[
        theme.backgroundVisualMode.clamp(0, VisualizerType.values.length - 1)];

    return ListenableBuilder(
      listenable: _changes,
      builder: (context, _) => Scaffold(
        backgroundColor: HifiTheme.background,
        body: _isFullscreenTheme
            ? _buildFullscreenTheme(visualizer)
            : SafeArea(
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
      const SizedBox(height: 6),
      _topNavigation(),
      const SizedBox(height: 6),
      if (scrollPage)
        SizedBox(height: 280, child: _content())
      else
        Expanded(child: _content()),
      const SizedBox(height: 6),
      _nowPlaying(),
      const SizedBox(height: 6),
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
          _HeaderAnimatedEqIcon(
            isPlaying: _audio.state.isPlaying,
            color: _accent,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'HiFi Player',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            widget.landscape ? '横屏' : '竖屏',
            style:
                const TextStyle(color: HifiTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '音量',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _showVolume,
            icon: Icon(
              _audio.state.isMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              size: 20,
            ),
          ),
        ],
      );

  Widget _topNavigation() => SingleChildScrollView(
        controller: _navScrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final section in AndroidPlayerSection.values)
              Builder(
                builder: (chipContext) => Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: ChoiceChip(
                    key: Key('android-nav-${section.name}'),
                    label: Text(
                      section.label,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            _section == section ? _accent : HifiTheme.textPrimary,
                        fontWeight: _section == section
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    avatar: Icon(
                      section.icon,
                      size: 15,
                      color: _section == section
                          ? _accent
                          : HifiTheme.textSecondary,
                    ),
                    selected: _section == section,
                    onSelected: (_) {
                      _selectSection(section);
                      _ensureChipVisible(chipContext);
                    },
                    selectedColor: _accent.withValues(alpha: 0.18),
                    side: BorderSide(
                      color: _section == section
                          ? _accent.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.08),
                      width: _section == section ? 1.3 : 1.0,
                    ),
                    visualDensity:
                        const VisualDensity(horizontal: -2, vertical: -3),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    showCheckmark: false,
                  ),
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
    final tracks = _library.tracks;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('音乐库 · ${tracks.length} 首',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              IconButton(
                tooltip: '播放全部',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: tracks.isEmpty ? null : () => _play(tracks, 0),
                icon: Icon(Icons.play_circle_outline_rounded,
                    color: _accent, size: 20),
              ),
              IconButton(
                tooltip: '扫描音乐',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _selectSection(AndroidPlayerSection.scan),
                icon: Icon(Icons.create_new_folder_outlined,
                    size: 19, color: _accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.library_music_outlined,
                          size: 38, color: _accent),
                      const SizedBox(height: 10),
                      const Text('把喜欢的音乐放进来',
                          style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 6),
                      const Text(
                        '通过 WiFi 传歌导入文件，再扫描本地音乐。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11.5, color: HifiTheme.textSecondary),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _selectSection(AndroidPlayerSection.network),
                        style: TextButton.styleFrom(
                          foregroundColor: _accent,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.wifi_rounded, size: 16),
                        label: const Text('WiFi 传歌',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  key: const PageStorageKey('android-library'),
                  padding: const EdgeInsets.only(bottom: 6),
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
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      minLeadingWidth: 32,
      selected: selected,
      selectedTileColor: _accent.withValues(alpha: 0.1),
      contentPadding: const EdgeInsets.only(left: 10, right: 2),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: selected ? 0.24 : 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: selected && _audio.state.isPlaying
              ? _HeaderAnimatedEqIcon(
                  isPlaying: true,
                  color: _accent,
                )
              : Icon(
                  selected
                      ? Icons.play_arrow_rounded
                      : Icons.music_note_rounded,
                  color: _accent,
                  size: 18,
                ),
        ),
      ),
      title: Text(track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? _accent : null,
          )),
      subtitle: Text(
        '${track.artist.isEmpty ? '未知歌手' : track.artist} · ${_trackSpecification(track)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10.5, color: HifiTheme.textSecondary),
      ),
      trailing: IconButton(
        tooltip: '加入播放队列',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        onPressed: () {
          _audio.addToQueue(track);
          _message('已加入播放队列');
        },
        icon: const Icon(Icons.playlist_add_rounded, size: 18),
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
    final theme = ThemeService.instance;
    final visualizer = VisualizerType.values[
        theme.backgroundVisualMode.clamp(0, VisualizerType.values.length - 1)];

    final status = _audio.isPreparingTrack
        ? '正在打开文件…'
        : state.isPlaying
            ? '正在播放'
            : state.isPaused
                ? '已暂停'
                : '等待播放';

    final child = LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final leftWidth = (maxW * 0.52).clamp(150.0, 185.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              // 左侧固定区域：文字超长自动以省略号 ... 截断
              SizedBox(
                width: leftWidth,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _accent.withValues(alpha: 0.55),
                            HifiTheme.background,
                          ],
                        ),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: state.isPlaying
                            ? _HeaderAnimatedEqIcon(
                                isPlaying: true,
                                color: _accent,
                              )
                            : Icon(Icons.album_rounded,
                                size: 20, color: _accent),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track?.title ?? '尚未选择歌曲',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 1.5),
                          Text(
                            track == null
                                ? '从音乐库开始聆听'
                                : '${track.artist.isEmpty ? '未知歌手' : track.artist} · ${_trackSpecification(track)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: HifiTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 1.5),
                          Text(
                            nativeReady && state.isPlaying && state.isBitPerfect
                                ? '$status · BIT-PERFECT'
                                : status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: _accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              // 右侧动效大表头：等比例缩放放入，点击进入全屏主题
              Expanded(
                child: Tooltip(
                  message: '全屏主题',
                  child: InkWell(
                    key: const Key('android-enter-fullscreen-theme'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _isFullscreenTheme = true),
                    child: Container(
                      height: 50,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFF07090E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.08),
                            blurRadius: 6,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 360,
                                height: 180,
                                child: RepaintBoundary(
                                  child: VisualizerStageWidget(
                                    activeType: visualizer,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.fullscreen_rounded,
                                size: 12,
                                color: _accent.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  Text(state.currentTimeString,
                      style: const TextStyle(
                          fontSize: 9.5, color: HifiTheme.textSecondary)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.0,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14.0),
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
                          fontSize: 9.5, color: HifiTheme.textSecondary)),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: mode.$1,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                  icon: Icon(mode.$2, size: 19),
                  onPressed: _audio.cyclePlayMode,
                ),
                IconButton(
                  tooltip: '上一曲',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: hasQueue ? _audio.previous : null,
                  icon: const Icon(Icons.skip_previous_rounded, size: 24),
                ),
                IconButton.filled(
                  key: const Key('android-play-pause'),
                  tooltip: state.isPlaying ? '暂停' : '播放',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints:
                      const BoxConstraints(minWidth: 42, minHeight: 42),
                  style: IconButton.styleFrom(
                      backgroundColor: _accent, foregroundColor: Colors.white),
                  onPressed: canPlay ? _audio.togglePlayPause : null,
                  icon: Icon(
                      state.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 24),
                ),
                IconButton(
                  tooltip: '下一曲',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: hasQueue ? () => _audio.next() : null,
                  icon: const Icon(Icons.skip_next_rounded, size: 24),
                ),
                IconButton(
                  tooltip: '播放队列',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                  onPressed: _showQueue,
                  icon: const Icon(Icons.queue_music_rounded, size: 20),
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
              Text(
                '音量 · ${(_audio.state.volume * 100).round()}%',
                style: TextStyle(fontWeight: FontWeight.w600, color: _accent),
              ),
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
                            selectedTileColor: _accent.withValues(alpha: 0.12),
                            leading: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: index == _audio.currentIndex
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: index == _audio.currentIndex
                                    ? _accent
                                    : HifiTheme.textSecondary,
                              ),
                            ),
                            title: Text(
                              queue[index].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: index == _audio.currentIndex
                                    ? _accent
                                    : null,
                                fontWeight: index == _audio.currentIndex
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(queue[index].artist,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Text(
                              queue[index].durationSec > 0
                                  ? queue[index].durationString
                                  : '--:--',
                              style: TextStyle(
                                color: index == _audio.currentIndex
                                    ? _accent
                                    : HifiTheme.textSecondary,
                              ),
                            ),
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
          border: Border.all(color: _accent.withValues(alpha: 0.15)),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      );

  Widget _buildFullscreenTheme(VisualizerType visualizer) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _isFullscreenTheme = false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07090E),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                // 横屏全屏主题动效充满屏幕
                RotatedBox(
                  quarterTurns: 1, // 将全屏主题旋转为横向全景展示，充满屏幕
                  child: SizedBox(
                    width: h,
                    height: w,
                    child: RepaintBoundary(
                      child: MacBackgroundWidget(
                        visualizerType: visualizer,
                        fullscreenProgress: 1.0,
                      ),
                    ),
                  ),
                ),
                // 右上角缩小按钮 (位于屏幕右上角，点击变回竖屏)
                Positioned(
                  top: 16,
                  right: 16,
                  child: SafeArea(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(14, 18, 26, 0.82),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: IconButton(
                        key: const Key('android-exit-fullscreen-theme'),
                        tooltip: '退出全屏',
                        onPressed: () =>
                            setState(() => _isFullscreenTheme = false),
                        icon: const Icon(
                          Icons.fullscreen_exit_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                      ),
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
}

class _HeaderAnimatedEqIcon extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const _HeaderAnimatedEqIcon({
    required this.isPlaying,
    required this.color,
  });

  @override
  State<_HeaderAnimatedEqIcon> createState() => _HeaderAnimatedEqIconState();
}

class _HeaderAnimatedEqIconState extends State<_HeaderAnimatedEqIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _HeaderAnimatedEqIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) {
      return Icon(
        Icons.graphic_eq_rounded,
        color: widget.color.withValues(alpha: 0.8),
        size: 20,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * pi;
        // 4 根跳动的频段动效柱
        final h1 = 4.0 + 8.0 * ((sin(t * 1.5) + 1.0) * 0.5);
        final h2 = 4.0 + 13.0 * ((sin(t * 2.0 + 1.0) + 1.0) * 0.5);
        final h3 = 5.0 + 11.0 * ((sin(t * 1.8 + 2.2) + 1.0) * 0.5);
        final h4 = 3.5 + 8.5 * ((sin(t * 2.4 + 3.1) + 1.0) * 0.5);

        return SizedBox(
          width: 20,
          height: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _bar(h1),
              _bar(h2),
              _bar(h3),
              _bar(h4),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(double height) => Container(
        width: 3.0,
        height: height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1.5),
        ),
      );
}
