import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../services/pi_system_service.dart';
import '../../services/theme_service.dart';
import '../../theme/hifi_theme.dart';
import '../common/glass_card.dart';
import '../visualizers/visualizer_stage_widget.dart';
import '../visualizers/visualizer_type.dart';
import 'widgets/pi_touch_controls.dart';
import 'widgets/pi_music_library_drawer.dart';
import 'widgets/pi_tuning_drawer.dart';
import 'widgets/pi_hardware_settings_drawer.dart';
import 'widgets/pi_screensaver_overlay.dart';

enum _PiDrawerType {
  none,
  library,
  tuning,
  hardware,
}

/// 树莓派 5 专属 7寸微雪触控屏 (1024×600) 横屏发烧台机 UI
/// 100% 针对电容触控优化：触控热区 >= 48dp、手势切歌/调音、A-Z 索引大曲库与 QLED 防烧屏
class PiMainView extends StatefulWidget {
  const PiMainView({super.key});

  @override
  State<PiMainView> createState() => _PiMainViewState();
}

class _PiMainViewState extends State<PiMainView> {
  _PiDrawerType _activeDrawer = _PiDrawerType.none;

  // 手势 HUD 状态
  bool _showVolumeHud = false;
  double _currentHudVolume = 0.8;
  Timer? _volumeHudTimer;

  bool _showTrackSwitchHud = false;
  String _trackSwitchHudText = '';
  Timer? _trackSwitchHudTimer;

  // 手势滑动累计位移
  double _horizontalDragDelta = 0.0;
  double _verticalDragDelta = 0.0;

  // QLED 防烧屏微光保护状态
  bool _isScreenSaverActive = false;
  int _idleSeconds = 0;
  Timer? _idleTimer;

  // 动效选择模式弹窗
  bool _showVisualizerPicker = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _startIdleTimer();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _volumeHudTimer?.cancel();
    _trackSwitchHudTimer?.cancel();
    super.dispose();
  }

  void _startIdleTimer() {
    _idleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final timeoutMins = PiSystemService.instance.screenSaverTimeoutMinutes;
      if (timeoutMins <= 0) return;

      _idleSeconds++;
      if (_idleSeconds >= timeoutMins * 60 && !_isScreenSaverActive && _activeDrawer == _PiDrawerType.none) {
        setState(() {
          _isScreenSaverActive = true;
        });
      }
    });
  }

  void _onUserActivity() {
    _idleSeconds = 0;
    if (_isScreenSaverActive) {
      setState(() {
        _isScreenSaverActive = false;
      });
    }
  }

  void _triggerVolumeHud(double newVol) {
    _volumeHudTimer?.cancel();
    setState(() {
      _showVolumeHud = true;
      _currentHudVolume = newVol;
    });
    _volumeHudTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _showVolumeHud = false;
        });
      }
    });
  }

  void _triggerTrackSwitchHud(String text) {
    _trackSwitchHudTimer?.cancel();
    setState(() {
      _showTrackSwitchHud = true;
      _trackSwitchHudText = text;
    });
    _trackSwitchHudTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _showTrackSwitchHud = false;
        });
      }
    });
  }

  void _cycleVisualizer() {
    _onUserActivity();
    final themeService = ThemeService.instance;
    final currentMode = themeService.backgroundVisualMode;
    final nextMode = (currentMode + 1) % VisualizerType.values.length;
    themeService.setBackgroundVisualMode(nextMode);
    _triggerTrackSwitchHud('视觉模式: ${VisualizerType.values[nextMode].displayName}');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        HifiAudioService.instance,
        PiSystemService.instance,
        ThemeService.instance,
      ]),
      builder: (context, _) {
        final audioService = HifiAudioService.instance;
        final piSys = PiSystemService.instance;
        final themeService = ThemeService.instance;
        final state = audioService.state;
        final track = audioService.currentTrack;

        final visualType = (themeService.backgroundVisualMode >= 0 &&
                themeService.backgroundVisualMode < VisualizerType.values.length)
            ? VisualizerType.values[themeService.backgroundVisualMode]
            : VisualizerType.mcIntosh;

        return Listener(
          onPointerDown: (_) => _onUserActivity(),
          child: Scaffold(
            backgroundColor: HifiTheme.background,
            body: Stack(
              children: [
                // 1. 主视觉区 (1024×600 黄金分割布局)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    child: Column(
                      children: [
                        // 顶部极窄硬件与网络状态栏 (高度约 32dp)
                        _buildTopStatusBar(piSys, state, track),

                        const SizedBox(height: 6),

                        // 主工作台 (左右双栏分栏：左 58% 发烧舞台，右 42% 触控操作台)
                        Expanded(
                          child: Row(
                            children: [
                              // 左半区 (约 58% 宽度)：发烧动效舞台 (集成电容屏手势增强)
                              Expanded(
                                flex: 58,
                                child: _buildVisualizerStageSection(visualType, audioService),
                              ),

                              const SizedBox(width: 10),

                              // 右半区 (约 42% 宽度)：曲目信息、微型频谱与触控控制卡片
                              Expanded(
                                flex: 42,
                                child: _buildControlSection(track, state, audioService),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. 音量手势调节 HUD 悬浮层
                if (_showVolumeHud)
                  Positioned.fill(
                    child: Center(
                      child: _buildVolumeHudWidget(),
                    ),
                  ),

                // 3. 切歌与动效切换 HUD 悬浮层
                if (_showTrackSwitchHud)
                  Positioned.fill(
                    child: Center(
                      child: _buildTrackSwitchHudWidget(),
                    ),
                  ),

                // 4. 动效模式快速选择器弹窗
                if (_showVisualizerPicker)
                  Positioned.fill(
                    child: _buildVisualizerPickerModal(themeService),
                  ),

                // 5. 模态抽屉层 (曲库、调音、硬件设置)
                if (_activeDrawer == _PiDrawerType.library)
                  Positioned.fill(
                    child: PiMusicLibraryDrawer(
                      onClose: () => setState(() => _activeDrawer = _PiDrawerType.none),
                    ),
                  ),

                if (_activeDrawer == _PiDrawerType.tuning)
                  Positioned.fill(
                    child: PiTuningDrawer(
                      onClose: () => setState(() => _activeDrawer = _PiDrawerType.none),
                    ),
                  ),

                if (_activeDrawer == _PiDrawerType.hardware)
                  Positioned.fill(
                    child: PiHardwareSettingsDrawer(
                      onClose: () => setState(() => _activeDrawer = _PiDrawerType.none),
                    ),
                  ),

                // 6. QLED 屏幕防烧屏微光发烧屏保
                if (_isScreenSaverActive)
                  Positioned.fill(
                    child: PiScreensaverOverlay(
                      onWake: _onUserActivity,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 顶部极窄状态栏 (32dp)
  Widget _buildTopStatusBar(PiSystemService piSys, dynamic state, dynamic track) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          // DAC 芯片标牌
          GestureDetector(
            onTap: () => setState(() => _activeDrawer = _PiDrawerType.hardware),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: HifiTheme.neonCyan.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.memory, color: HifiTheme.neonCyan, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    piSys.dacDeviceName,
                    style: const TextStyle(
                      color: HifiTheme.neonCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 硬件时钟 / ALSA 直通指示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: HifiTheme.mcIntoshBlue.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.5)),
            ),
            child: const Text(
              'I2S MASTER CLOCK',
              style: TextStyle(
                color: HifiTheme.mcIntoshGlow,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const Spacer(),

          // 局域网 Web 遥控端口与 IP 指示
          GestureDetector(
            onTap: () => setState(() => _activeDrawer = _PiDrawerType.hardware),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: HifiTheme.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_rounded, color: HifiTheme.accuphaseGold, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Web: ${piSys.localIp}:${piSys.webRemotePort}',
                    style: const TextStyle(
                      color: HifiTheme.textPrimary,
                      fontSize: 11,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // SoC 温度指示
          GestureDetector(
            onTap: () => setState(() => _activeDrawer = _PiDrawerType.hardware),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: piSys.tempColorHex == 'red'
                      ? Colors.redAccent
                      : (piSys.tempColorHex == 'amber' ? Colors.orangeAccent : HifiTheme.neonCyan),
                  width: 0.9,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.thermostat_rounded,
                    color: piSys.tempColorHex == 'red'
                        ? Colors.redAccent
                        : (piSys.tempColorHex == 'amber' ? Colors.orangeAccent : HifiTheme.neonCyan),
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${piSys.socTemperature.toStringAsFixed(1)}°C',
                    style: const TextStyle(
                      color: HifiTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 左侧发烧动效舞台 (集成电容触控滑动切歌、垂直滑动手势调音量)
  Widget _buildVisualizerStageSection(VisualizerType visualType, HifiAudioService audioService) {
    return GestureDetector(
      onDoubleTap: () => _cycleVisualizer(),
      onHorizontalDragStart: (_) {
        _horizontalDragDelta = 0.0;
      },
      onHorizontalDragUpdate: (details) {
        _horizontalDragDelta += details.primaryDelta ?? 0.0;
      },
      onHorizontalDragEnd: (details) {
        if (_horizontalDragDelta > 45.0) {
          // 向右划：上一曲
          audioService.previous();
          _triggerTrackSwitchHud('⏮ 上一曲: ${audioService.currentTrack?.title ?? ""}');
        } else if (_horizontalDragDelta < -45.0) {
          // 向左划：下一曲
          audioService.next();
          _triggerTrackSwitchHud('⏭ 下一曲: ${audioService.currentTrack?.title ?? ""}');
        }
        _horizontalDragDelta = 0.0;
      },
      onVerticalDragStart: (_) {
        _verticalDragDelta = 0.0;
      },
      onVerticalDragUpdate: (details) {
        _verticalDragDelta -= details.primaryDelta ?? 0.0;
        final step = _verticalDragDelta / 240.0;
        if (step.abs() > 0.02) {
          final newVol = (audioService.state.volume + step).clamp(0.0, 1.0);
          audioService.setVolume(newVol);
          _triggerVolumeHud(newVol);
          _verticalDragDelta = 0.0;
        }
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: VisualizerStageWidget(
              activeType: visualType,
              showSelector: false,
            ),
          ),

          // 舞台左下角：动效模式快速切换胶囊标牌
          Positioned(
            left: 12,
            bottom: 12,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showVisualizerPicker = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.6), width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: HifiTheme.mcIntoshGlow, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      visualType.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded, color: HifiTheme.mcIntoshGlow, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 右侧曲目信息、微型频谱与触控控制台
  Widget _buildControlSection(dynamic track, dynamic state, HifiAudioService audioService) {
    return GlassCard(
      height: double.infinity,
      borderRadius: 16.0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 曲目信息 (适合 7 寸屏阅读的大字号 19sp, 防眩光 Bold)
          Text(
            track?.title ?? 'McIntosh Reference Master',
            style: const TextStyle(
              color: HifiTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            track != null
                ? '${track.artist.isNotEmpty ? track.artist : "未知艺术家"} · ${track.album.isNotEmpty ? track.album : "未知专辑"}'
                : 'Ready for Bit-Perfect Direct Stream',
            style: const TextStyle(
              color: HifiTheme.textMuted,
              fontSize: 12.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // 2. 音质规格与 Bit-Perfect 标牌
          Row(
            children: [
              _buildTag(
                track?.formatBadge.contains('DSD') == true ? 'DSD MASTER' : 'FLAC / WAV',
                HifiTheme.accuphaseGold,
              ),
              const SizedBox(width: 6),
              _buildTag(
                track != null ? track.formatBadge : '192kHz / 24Bit',
                HifiTheme.mcIntoshGlow,
              ),
              const SizedBox(width: 6),
              _buildTag(state.isBitPerfect ? '0dB PURE' : 'DSP', HifiTheme.neonCyan),
              if (track?.isCueTrack == true) ...[
                const SizedBox(width: 6),
                _buildTag('CUE 分轨', Colors.purpleAccent),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // 3. 12频段微型实时频谱律动 (细密高保真律动条)
          SizedBox(
            height: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) {
                final levels = state.spectrumLevels as List<double>;
                final rawLevel = i < levels.length ? levels[i] : 0.0;
                final level = rawLevel.clamp(0.05, 1.0);

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: 24 * level,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          HifiTheme.mcIntoshBlue,
                          level > 0.8 ? HifiTheme.neonCyan : HifiTheme.mcIntoshGlow,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                );
              }),
            ),
          ),

          const Spacer(),

          // 4. 触控大按键控制条 (Touch Target >= 48dp)
          PiTouchControls(
            onVolumeTap: () {
              final newVol = (state.volume > 0.05) ? 0.0 : 0.8;
              audioService.setVolume(newVol);
              _triggerVolumeHud(newVol);
            },
          ),

          const Spacer(),

          // 5. 底部大号功能切换卡片 (一触即达：曲库/歌单、音色调音、硬件设置)
          Row(
            children: [
              Expanded(
                child: _buildBottomTouchButton(
                  icon: Icons.library_music_rounded,
                  label: '本地曲库',
                  color: HifiTheme.mcIntoshGlow,
                  onTap: () {
                    setState(() {
                      _activeDrawer = _PiDrawerType.library;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBottomTouchButton(
                  icon: Icons.tune_rounded,
                  label: '音色调音',
                  color: HifiTheme.neonCyan,
                  onTap: () {
                    setState(() {
                      _activeDrawer = _PiDrawerType.tuning;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBottomTouchButton(
                  icon: Icons.settings_input_component_rounded,
                  label: '硬件设置',
                  color: HifiTheme.accuphaseGold,
                  onTap: () {
                    setState(() {
                      _activeDrawer = _PiDrawerType.hardware;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBottomTouchButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: color.withValues(alpha: 0.3),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: HifiTheme.cardBorder, width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: HifiTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 音量 HUD 弹窗
  Widget _buildVolumeHudWidget() {
    final pct = (_currentHudVolume * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.35),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _currentHudVolume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: HifiTheme.mcIntoshGlow,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            '音量 $pct%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _currentHudVolume,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(HifiTheme.mcIntoshGlow),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 切歌/模式切换 HUD 弹窗
  Widget _buildTrackSwitchHudWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HifiTheme.neonCyan.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: HifiTheme.neonCyan.withValues(alpha: 0.3),
            blurRadius: 18,
          ),
        ],
      ),
      child: Text(
        _trackSwitchHudText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 动效模式快速选择器模态
  Widget _buildVisualizerPickerModal(ThemeService themeService) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showVisualizerPicker = false;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Container(
            width: 520,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HifiTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.6)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '选择发烧视觉动效舞台',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () {
                        setState(() {
                          _showVisualizerPicker = false;
                        });
                      },
                    ),
                  ],
                ),
                const Divider(color: HifiTheme.cardBorder),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(VisualizerType.values.length, (idx) {
                    final type = VisualizerType.values[idx];
                    final isSel = themeService.backgroundVisualMode == idx;

                    return GestureDetector(
                      onTap: () {
                        themeService.setBackgroundVisualMode(idx);
                        setState(() {
                          _showVisualizerPicker = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? HifiTheme.mcIntoshBlue : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? HifiTheme.mcIntoshGlow : HifiTheme.cardBorder,
                          ),
                        ),
                        child: Text(
                          type.displayName,
                          style: TextStyle(
                            color: isSel ? Colors.white : HifiTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
