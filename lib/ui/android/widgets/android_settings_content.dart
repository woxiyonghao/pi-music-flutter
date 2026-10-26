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
import '../../visualizers/visualizer_stage_widget.dart';
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

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(widget.section.label,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
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

  List<Widget> _scan() => [
        _description('扫描应用音乐目录中的本地文件，更新音乐库。可先通过 WiFi 传入音乐。'),
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('音乐目录', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SelectableText(AppPaths.musicDirectory,
                  style: const TextStyle(
                      fontSize: 12, color: HifiTheme.textSecondary)),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('android-scan-library'),
                onPressed: _scanning ? null : _scanLibrary,
                icon: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
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
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: widget.onOpenNetwork,
          icon: const Icon(Icons.wifi_rounded),
          label: const Text('打开 WiFi 传歌'),
        ),
      ];

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
    return [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('启用 10 段均衡器'),
        subtitle: const Text('启用后由音频引擎进行 DSP 处理'),
        value: _audio.eqEnabled,
        onChanged: _audio.setEqEnabled,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _audio.resetEq,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('恢复平直'),
        ),
      ),
      for (var index = 0; index < frequencies.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(frequencies[index],
                      style: const TextStyle(fontSize: 12)),
                  Text('${_audio.eqBands[index].toStringAsFixed(1)} dB',
                      style: const TextStyle(
                          fontSize: 12, color: HifiTheme.textSecondary)),
                ],
              ),
              Slider(
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
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('启用调音魔棒 (MSEB)'),
        subtitle: const Text('基于海贝 MSEB 调音算法，融合 10 维专业声学参量'),
        value: mseb.isEnabled,
        onChanged: (val) {
          mseb.setEnabled(val);
          setState(() {});
        },
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            mseb.resetAll();
            setState(() {});
          },
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('全部复位'),
        ),
      ),
      for (var index = 0; index < params.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(params[index].title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    mseb.values[index].toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: mseb.values[index].abs() > 0.05
                          ? _accent
                          : HifiTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    params[index].left,
                    style: const TextStyle(
                        fontSize: 11, color: HifiTheme.textSecondary),
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
                        fontSize: 11, color: HifiTheme.textSecondary),
                  ),
                ],
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
      const Text('主题配色', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final preset in ThemeService.presets)
            ChoiceChip(
              label: Text(preset.name, style: const TextStyle(fontSize: 12)),
              avatar: CircleAvatar(backgroundColor: preset.accentColor),
              selected: theme.currentThemeId == preset.id,
              onSelected: (_) => theme.setTheme(preset.id),
              showCheckmark: false,
            ),
        ],
      ),
      const SizedBox(height: 18),
      const Text('播放动效', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      DropdownButtonFormField<VisualizerType>(
        key: ValueKey(visualizer),
        initialValue: visualizer,
        isExpanded: true,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        items: [
          for (final type in VisualizerType.values)
            DropdownMenuItem(
              value: type,
              child: Text(type.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            ),
        ],
        onChanged: (type) {
          if (type != null) theme.setBackgroundVisualMode(type.index);
        },
      ),
      const SizedBox(height: 12),
      AspectRatio(
        aspectRatio: 1.9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: RepaintBoundary(
              child: VisualizerStageWidget(activeType: visualizer)),
        ),
      ),
    ];
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
            _info('音频引擎', loaded ? '已加载' : '未加载'),
            if (capabilities['backend'] is String)
              _info('输出后端', capabilities['backend'] as String),
            _info('当前输出', deviceName.isEmpty ? '等待设备报告' : deviceName),
            _info('输出采样率',
                sampleRate > 0 ? '${sampleRate / 1000} kHz' : '等待设备报告'),
            _info('均衡器', _audio.eqEnabled ? 'DSP 已启用' : '已关闭'),
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
                Text('已接收 ${wifi.completedCount} 个文件',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
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
            Text('$title · ${running ? '运行中' : '已停止'}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _description(description),
            if (running) ...[
              const SizedBox(height: 10),
              SelectableText(address,
                  style: TextStyle(fontSize: 13, color: _accent)),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: address));
                  if (mounted) _message('地址已复制');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('复制访问地址'),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _networkBusy ? null : onToggle,
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
              _info('音乐库', '${MusicDatabaseService.instance.tracks.length} 首'),
              _info('播放队列', '${_audio.playlistQueue.length} 首'),
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

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: HifiTheme.textSecondary)),
            Text(value, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: child,
      );

  Widget _description(String text) => Text(text,
      style: const TextStyle(
          color: HifiTheme.textSecondary, fontSize: 12, height: 1.6));

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
