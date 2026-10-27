import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_paths.dart';
import '../../../core/hifi_audio_bindings.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../services/mseb_service.dart';
import '../../../services/music_database_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/web_remote_service.dart';
import '../../../services/wifi_transfer_service.dart';
import '../../../theme/hifi_theme.dart';
import '../../visualizers/visualizer_type.dart';
import '../android_player_view.dart' show AndroidPlayerSection;

/// Touch-friendly settings backed by the services available on Android.
class AndroidSettingsContent extends StatefulWidget {
  const AndroidSettingsContent({
    super.key,
    required this.section,
    required this.onOpenNetwork,
  });

  final AndroidPlayerSection section;
  final VoidCallback onOpenNetwork;

  @override
  State<AndroidSettingsContent> createState() => _AndroidSettingsContentState();
}

class _AndroidSettingsContentState extends State<AndroidSettingsContent> {
  bool _scanning = false;
  bool _networkBusy = false;
  String? _scanMessage;

  Color get _accent => ThemeService.instance.accentColor;
  HifiAudioService get _audio => HifiAudioService.instance;

  static const List<Map<String, dynamic>> _eqPresets = [
    {
      'name': '原音直通',
      'gains': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    },
    {
      'name': '流行音乐',
      'gains': [2.5, 1.5, 0.0, -1.0, -1.5, 1.0, 2.5, 3.5, 2.5, 1.5],
    },
    {
      'name': '摇滚现场',
      'gains': [4.5, 3.5, 2.0, 0.0, -1.0, 1.5, 3.5, 4.0, 4.5, 4.0],
    },
    {
      'name': '经典人声',
      'gains': [-2.0, -1.0, 0.0, 2.0, 3.5, 4.0, 3.0, 1.5, 0.0, -1.0],
    },
    {
      'name': '古典交响',
      'gains': [3.5, 3.0, 2.0, 1.0, -1.0, 0.0, 1.5, 2.5, 3.5, 3.5],
    },
    {
      'name': '震撼低音',
      'gains': [6.0, 5.0, 3.5, 2.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    },
    {
      'name': '通透高音',
      'gains': [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.5, 4.5, 6.0, 6.0],
    },
    {
      'name': '自定义',
      'gains': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    },
  ];

  int _currentEqPresetIndex() {
    final currentBands = _audio.eqBands;
    for (int i = 0; i < _eqPresets.length - 1; i++) {
      final presetGains = _eqPresets[i]['gains'] as List<double>;
      bool matches = true;
      for (int b = 0; b < 10; b++) {
        if ((currentBands[b] - presetGains[b]).abs() > 0.15) {
          matches = false;
          break;
        }
      }
      if (matches) return i;
    }
    return _eqPresets.length - 1; // 自定义
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        children: [
          Text(widget.section.label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...switch (widget.section) {
            AndroidPlayerSection.scan => _scan(),
            AndroidPlayerSection.equalizer => _equalizer(),
            AndroidPlayerSection.mseb => _mseb(),
            AndroidPlayerSection.theme => _theme(),
            AndroidPlayerSection.output => _output(),
            AndroidPlayerSection.network => [_network()],
            AndroidPlayerSection.settings => _settings(),
            AndroidPlayerSection.library => <Widget>[],
          },
        ],
      );

  List<Widget> _scan() {
    final wifiDir = WifiTransferService.instance.targetDir.isNotEmpty
        ? WifiTransferService.instance.targetDir
        : AppPaths.musicDirectory;
    const publicDir = '/storage/emulated/0/Music';
    return [
      _description('扫描 WiFi 传歌目录和公共 Music 目录，包含子目录与 CUE 分轨文件。'),
      const SizedBox(height: 12),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('扫描目录 (共 2 处)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wifi_rounded, size: 16, color: _accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. WiFi 传歌写入目录',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      SelectableText(
                        wifiDir,
                        style: const TextStyle(
                            fontSize: 11, color: HifiTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.folder_special_rounded, size: 16, color: _accent),
                const SizedBox(width: 6),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('2. 公共音乐目录',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      SelectableText(
                        publicDir,
                        style: TextStyle(
                            fontSize: 11, color: HifiTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('android-scan-library'),
              onPressed: _scanning ? null : _scanLibrary,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _accent.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              ),
              icon: _scanning
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          _accent.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(_scanning ? '正在扫描…' : '扫描音乐目录'),
            ),
            if (_scanMessage != null) ...[
              const SizedBox(height: 8),
              _description(_scanMessage!),
            ],
          ],
        ),
      ),
    ];
  }

  Future<void> _scanLibrary() async {
    setState(() {
      _scanning = true;
      _scanMessage = null;
    });
    try {
      await MusicDatabaseService.instance.scanLibrary();
      if (mounted) {
        setState(() => _scanMessage =
            '扫描完成，音乐库共有 ${MusicDatabaseService.instance.tracks.length} 首歌曲。');
      }
    } on MusicLibraryScanException catch (error) {
      if (mounted) {
        setState(() => _scanMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _scanMessage = '扫描失败，请检查音乐目录和文件访问权限。');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  List<Widget> _equalizer() {
    const frequencies = [
      '31 Hz',
      '63 Hz',
      '125 Hz',
      '250 Hz',
      '500 Hz',
      '1 kHz',
      '2 kHz',
      '4 kHz',
      '8 kHz',
      '16 kHz',
    ];
    final activePreset = _currentEqPresetIndex();

    return [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: _audio.eqEnabled,
                  activeThumbColor: _accent,
                  activeTrackColor: _accent.withValues(alpha: 0.45),
                  onChanged: _audio.setEqEnabled,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _audio.eqEnabled ? '10段均衡器' : '10段均衡器(关)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _audio.eqEnabled ? _accent : HifiTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: _audio.resetEq,
            style: TextButton.styleFrom(
              foregroundColor: _accent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.restart_alt_rounded, size: 15),
            label: const Text('恢复平直', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _eqPresets.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    _eqPresets[i]['name'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          activePreset == i ? _accent : HifiTheme.textPrimary,
                      fontWeight: activePreset == i
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  selected: activePreset == i,
                  selectedColor: _accent.withValues(alpha: 0.18),
                  side: BorderSide(
                    color: activePreset == i
                        ? _accent
                        : Colors.white.withValues(alpha: 0.08),
                    width: activePreset == i ? 1.3 : 1.0,
                  ),
                  visualDensity:
                      const VisualDensity(horizontal: -2, vertical: -3),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  onSelected: (_) {
                    final gains = List<double>.from(
                        _eqPresets[i]['gains'] as List<double>);
                    _audio.setEqBands(gains);
                    setState(() {});
                  },
                  showCheckmark: false,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3.0,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
        ),
        child: Column(
          children: [
            for (var index = 0; index < frequencies.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7.5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          frequencies[index],
                          style: const TextStyle(
                            fontSize: 11,
                            color: HifiTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        key: Key('android-eq-band-$index'),
                        min: -12,
                        max: 12,
                        divisions: 48,
                        activeColor: _accent,
                        value: _audio.eqBands[index].clamp(-12, 12),
                        label: '${_audio.eqBands[index].toStringAsFixed(1)} dB',
                        onChanged: _audio.eqEnabled
                            ? (gain) => _audio.setEqBand(index, gain)
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 46,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_audio.eqBands[index] > 0 ? '+' : ''}${_audio.eqBands[index].toStringAsFixed(1)} dB',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: _audio.eqBands[index].abs() > 0.05
                                ? _accent
                                : HifiTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _mseb() {
    final mseb = MsebService.instance;
    const params = [
      (title: '声音冷暖', left: '偏冷通透', right: '偏暖醇厚'),
      (title: '低音下潜', left: '紧致轻盈', right: '深沉澎湃'),
      (title: '低音质感', left: '速度迅捷', right: '蓬松弹性'),
      (title: '音符厚度', left: '纤细轻盈', right: '扎实饱满'),
      (title: '人声位置', left: '舞台后缩', right: '贴耳靠前'),
      (title: '女声甜度', left: '自然平直', right: '润泽甜美'),
      (title: '齿音消除', left: '柔化去刺', right: '原生锋芒'),
      (title: '瞬态存在感', left: '柔和松弛', right: '硬朗凌厉'),
      (title: '空气感', left: '凝聚内敛', right: '空灵弥漫'),
      (title: '声场明亮度', left: '紧凑聚焦', right: '宏大宽广'),
    ];

    return [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: mseb.isEnabled,
                  activeThumbColor: _accent,
                  activeTrackColor: _accent.withValues(alpha: 0.45),
                  onChanged: (val) {
                    mseb.setEnabled(val);
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  mseb.isEnabled ? '调音魔棒' : '调音魔棒(关)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mseb.isEnabled ? _accent : HifiTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () {
              mseb.resetAll();
              setState(() {});
            },
            style: TextButton.styleFrom(
              foregroundColor: _accent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.restart_alt_rounded, size: 15),
            label: const Text('全部复位', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
      const SizedBox(height: 6),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
        ),
        child: Column(
          children: [
            for (var index = 0; index < params.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            params[index].title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${mseb.values[index] > 0 ? '+' : ''}${mseb.values[index].toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: mseb.values[index].abs() > 0.05
                                ? _accent
                                : HifiTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          params[index].left,
                          style: const TextStyle(
                              fontSize: 9.5, color: HifiTheme.textSecondary),
                        ),
                        Expanded(
                          child: Slider(
                            key: Key('android-mseb-param-$index'),
                            min: -10,
                            max: 10,
                            divisions: 40,
                            activeColor: _accent,
                            value: mseb.values[index].clamp(-10, 10),
                            label: mseb.values[index].toStringAsFixed(1),
                            onChanged: (val) {
                              mseb.setParam(index, val);
                              setState(() {});
                            },
                          ),
                        ),
                        Text(
                          params[index].right,
                          style: const TextStyle(
                              fontSize: 9.5, color: HifiTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _theme() {
    final theme = ThemeService.instance;
    final visualizer = VisualizerType.values[
        theme.backgroundVisualMode.clamp(0, VisualizerType.values.length - 1)];
    return [
      const Text('主题配色',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final preset in ThemeService.presets)
            ChoiceChip(
              label: Text(
                preset.name,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.currentThemeId == preset.id
                      ? preset.accentColor
                      : HifiTheme.textPrimary,
                  fontWeight: theme.currentThemeId == preset.id
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              avatar: CircleAvatar(
                radius: 5,
                backgroundColor: preset.accentColor,
              ),
              selected: theme.currentThemeId == preset.id,
              selectedColor: preset.accentColor.withValues(alpha: 0.18),
              side: BorderSide(
                color: theme.currentThemeId == preset.id
                    ? preset.accentColor
                    : Colors.white.withValues(alpha: 0.08),
                width: theme.currentThemeId == preset.id ? 1.3 : 1.0,
              ),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              onSelected: (_) => theme.setTheme(preset.id),
              showCheckmark: false,
            ),
        ],
      ),
      const SizedBox(height: 14),
      const Text('播放动效',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final type in VisualizerType.values)
            ChoiceChip(
              key: Key('android-visualizer-${type.name}'),
              label: Text(
                type.displayName,
                style: TextStyle(
                  fontSize: 11,
                  color: visualizer == type ? _accent : HifiTheme.textPrimary,
                  fontWeight: visualizer == type
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              avatar: Icon(
                _visualizerIcon(type),
                size: 14,
                color: visualizer == type ? _accent : HifiTheme.textSecondary,
              ),
              selected: visualizer == type,
              selectedColor: _accent.withValues(alpha: 0.18),
              side: BorderSide(
                color: visualizer == type
                    ? _accent
                    : Colors.white.withValues(alpha: 0.08),
                width: visualizer == type ? 1.3 : 1.0,
              ),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              onSelected: (_) => theme.setBackgroundVisualMode(type.index),
              showCheckmark: false,
            ),
        ],
      ),
    ];
  }

  IconData _visualizerIcon(VisualizerType type) {
    switch (type) {
      case VisualizerType.ledSpectrum:
        return Icons.equalizer_rounded;
      case VisualizerType.mcIntosh:
        return Icons.speed_rounded;
      case VisualizerType.accuphase:
        return Icons.av_timer_rounded;
      case VisualizerType.tapeReel:
        return Icons.album_rounded;
      case VisualizerType.siriWave:
        return Icons.waves_rounded;
      case VisualizerType.siriOrb:
        return Icons.blur_on_rounded;
      case VisualizerType.bubbles:
        return Icons.bubble_chart_rounded;
      case VisualizerType.pureBlack:
        return Icons.dark_mode_rounded;
      case VisualizerType.neonWave:
        return Icons.graphic_eq_rounded;
      case VisualizerType.cyberGrid:
        return Icons.grid_4x4_rounded;
      case VisualizerType.glassClock:
        return Icons.access_time_rounded;
      case VisualizerType.ipadTelemetryDashboard:
        return Icons.developer_board_rounded;
    }
  }

  List<Widget> _output() {
    final bindings = HifiAudioBindings.instance;
    final loaded = bindings.isLoaded;
    final deviceName = loaded ? bindings.getDeviceName() : '';
    final sampleRate = loaded ? bindings.getSampleRate() : 0;
    Map<String, dynamic> capabilities = {};
    if (loaded) {
      try {
        capabilities = bindings.capabilities;
      } catch (_) {
        // Older engine binaries can still play without a capability report.
      }
    }
    return [
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _info('音频引擎', loaded ? '已加载' : '未加载', isHighlight: loaded),
            if (capabilities['backend'] is String)
              _info('输出后端', capabilities['backend'] as String),
            _info('当前输出', deviceName.isEmpty ? '等待设备报告' : deviceName,
                isHighlight: deviceName.isNotEmpty),
            _info('输出采样率',
                sampleRate > 0 ? '${sampleRate / 1000} kHz' : '等待设备报告',
                isHighlight: sampleRate > 0),
            _info('均衡器', _audio.eqEnabled ? 'DSP 已启用' : '已关闭',
                isHighlight: _audio.eqEnabled),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _description('耳机、蓝牙和 USB 音频路由由 Android 系统管理。连接或切换设备后，以引擎实际报告的输出为准。'),
      const SizedBox(height: 8),
      _description('歌曲标注的采样率是文件规格；实际输出采样率见上方设备信息。'),
    ];
  }

  Widget _network() => ListenableBuilder(
        listenable: Listenable.merge([
          WebRemoteService.instance,
          WifiTransferService.instance,
        ]),
        builder: (context, _) {
          final web = WebRemoteService.instance;
          final wifi = WifiTransferService.instance;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _description('开启后，在同一局域网的浏览器中访问对应地址。'),
              const SizedBox(height: 12),
              _serverCard(
                title: 'WiFi 传歌',
                description: '把本地音乐上传到应用音乐目录，完成后更新曲库。',
                running: wifi.isRunning,
                address: 'http://${wifi.localIp}:${wifi.port}',
                onToggle: () => _toggleNetwork(
                  () async {
                    if (wifi.isRunning) {
                      await wifi.stop();
                      return true;
                    }
                    return wifi.start(targetDir: AppPaths.musicDirectory);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _serverCard(
                title: 'Web 遥控',
                description: '通过浏览器控制当前播放、音量和播放队列。',
                running: web.isRunning,
                address: 'http://${web.localIp}:${web.port}',
                onToggle: () => _toggleNetwork(
                  () async {
                    if (web.isRunning) {
                      await web.stop();
                      return true;
                    }
                    return web.start();
                  },
                ),
              ),
              if (wifi.uploadedFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '已接收 ${wifi.completedCount} 个文件',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 8),
                for (final file in wifi.uploadedFiles.reversed.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${file.name} · ${file.formattedSize}',
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ],
          );
        },
      );

  Widget _serverCard({
    required String title,
    required String description,
    required bool running,
    required String address,
    required VoidCallback onToggle,
  }) =>
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: running
                        ? _accent.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: running
                          ? _accent.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    running ? '运行中' : '已停止',
                    style: TextStyle(
                      fontSize: 11,
                      color: running ? _accent : HifiTheme.textSecondary,
                      fontWeight:
                          running ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _description(description),
            if (running) ...[
              const SizedBox(height: 10),
              SelectableText(address,
                  style: TextStyle(
                      fontSize: 13,
                      color: _accent,
                      fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: address));
                  if (mounted) _message('地址已复制');
                },
                style: TextButton.styleFrom(foregroundColor: _accent),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('复制访问地址'),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _networkBusy ? null : onToggle,
              style: FilledButton.styleFrom(
                backgroundColor: _accent.withValues(alpha: 0.18),
                foregroundColor: _accent,
              ),
              child: Text(running ? '停止$title' : '开启$title'),
            ),
          ],
        ),
      );

  Future<void> _toggleNetwork(Future<bool> Function() action) async {
    setState(() => _networkBusy = true);
    try {
      final success = await action();
      if (mounted && !success) _message('服务启动失败，请检查网络和端口。');
    } catch (_) {
      if (mounted) _message('无法更改服务状态，请检查网络。');
    } finally {
      if (mounted) setState(() => _networkBusy = false);
    }
  }

  List<Widget> _settings() => [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Android HiFi Player',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _description('启动时选择横屏或竖屏，两种布局共用音乐库、播放队列和音效设置。'),
              const SizedBox(height: 10),
              _info('音乐库', '${MusicDatabaseService.instance.tracks.length} 首',
                  isHighlight: true),
              _info('播放队列', '${_audio.playlistQueue.length} 首',
                  isHighlight: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text('应用音乐目录', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SelectableText(AppPaths.musicDirectory,
            style:
                const TextStyle(fontSize: 12, color: HifiTheme.textSecondary)),
      ];

  Widget _info(String label, String value, {bool isHighlight = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Wrap(
          spacing: 10,
          runSpacing: 2,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11.5, color: HifiTheme.textSecondary)),
            Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
                color: isHighlight ? _accent : null,
              ),
            ),
          ],
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _accent.withValues(alpha: 0.12)),
        ),
        child: child,
      );

  Widget _description(String text) => Text(text,
      style: const TextStyle(
          color: HifiTheme.textSecondary, fontSize: 11.5, height: 1.45));

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
