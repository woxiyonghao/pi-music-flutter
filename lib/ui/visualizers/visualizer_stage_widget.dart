import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/hifi_audio_service.dart';
import '../../services/theme_service.dart';
import '../../theme/hifi_theme.dart';
import 'visualizer_type.dart';
import 'mcintosh_meter_painter.dart';
import 'accuphase_meter_painter.dart';
import 'tape_reel_painter.dart';
import 'led_spectrum_painter.dart';
import 'neon_waveform_painter.dart';
import 'siri_orb_painter.dart';
import 'siri_wave_painter.dart';
import 'audio_bubbles_painter.dart';
import 'cyber_grid_painter.dart';
import 'glass_clock_painter.dart';

/// 统一发烧动效舞台容器 (专为横屏设备打造，内置 60fps 物理阻尼与动画引擎)
class VisualizerStageWidget extends StatefulWidget {
  final VisualizerType? activeType;
  final VisualizerType initialType;
  final ValueChanged<VisualizerType>? onTypeChanged;
  final bool showSelector;

  const VisualizerStageWidget({
    super.key,
    this.activeType,
    this.initialType = VisualizerType.mcIntosh,
    this.onTypeChanged,
    this.showSelector = false,
  });

  @override
  State<VisualizerStageWidget> createState() => _VisualizerStageWidgetState();
}

class _VisualizerStageWidgetState extends State<VisualizerStageWidget> with SingleTickerProviderStateMixin {
  late VisualizerType _currentType;
  late Ticker _ticker;

  // 物理阻尼角度 (针运动)
  double _leftAngle = McIntoshMeterPainter.minAngle;
  double _rightAngle = McIntoshMeterPainter.minAngle;
  double _accuphaseValL = 0.0;
  double _accuphaseValR = 0.0;

  // 磁带轮旋转角度
  double _tapeLeftAngle = 0.0;
  double _tapeRightAngle = 0.0;

  // 峰值保持数组
  final List<double> _peakHold = List.filled(12, 0.0);

  // 动画时间
  double _animTime = 0.0;
  double _lastTimestamp = 0.0;

  void _onPlayStateChanged() {
    if (mounted) {
      if (!_ticker.isTicking) {
        _lastTimestamp = 0.0;
        _ticker.start();
      }
      setState(() {});
    }
  }

  // 音乐微光气泡粒子物理模型 (38 颗分阶气泡)
  final List<AudioBubble> _bubbles = [];
  bool _bubblesInitialized = false;

  void _initBubbles(Size size) {
    _bubbles.clear();
    final rand = Random();
    final w = size.width > 10 ? size.width : 1400.0;
    final h = size.height > 10 ? size.height : 900.0;
    for (int i = 0; i < 38; i++) {
      final rClass = i % 10;
      double baseR;
      int freqBand;
      double vy;
      double alpha;
      if (rClass < 6) {
        baseR = 12.0 + rand.nextInt(16);
        freqBand = 2 + (i % 2);
        vy = 28.0 + rand.nextInt(22);
        alpha = 0.45 + rand.nextInt(30) * 0.01;
      } else if (rClass < 9) {
        baseR = 28.0 + rand.nextInt(18);
        freqBand = 1;
        vy = 18.0 + rand.nextInt(16);
        alpha = 0.35 + rand.nextInt(25) * 0.01;
      } else {
        baseR = 52.0 + rand.nextInt(22);
        freqBand = 0;
        vy = 12.0 + rand.nextInt(10);
        alpha = 0.22 + rand.nextInt(18) * 0.01;
      }
      _bubbles.add(AudioBubble(
        x: rand.nextDouble() * w,
        y: rand.nextDouble() * h,
        vy: vy,
        vxPhase: rand.nextDouble() * 6.28,
        vxSpeed: 0.6 + rand.nextInt(12) * 0.1,
        vxAmp: 10.0 + rand.nextInt(20),
        baseRadius: baseR,
        currentRadius: baseR,
        alpha: alpha,
        freqBand: freqBand,
      ));
    }
    _bubblesInitialized = true;
  }

  @override
  void initState() {
    super.initState();
    _currentType = widget.activeType ?? widget.initialType;
    HifiAudioService.instance.isPlayingNotifier.addListener(_onPlayStateChanged);

    final state = HifiAudioService.instance.state;
    final isMeterMode = _currentType == VisualizerType.mcIntosh ||
        _currentType == VisualizerType.accuphase ||
        _currentType == VisualizerType.tapeReel ||
        _currentType == VisualizerType.ledSpectrum ||
        _currentType == VisualizerType.pureBlack;

    _ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1000000.0;
      final dt = (_lastTimestamp > 0.0) ? (t - _lastTimestamp).clamp(0.001, 0.05) : 0.016;
      _lastTimestamp = t;

      _updatePhysics(dt);

      if (!HifiAudioService.instance.state.isPlaying && isMeterMode) {
        final atRest = (_leftAngle - McIntoshMeterPainter.minAngle).abs() < 0.002 &&
            (_rightAngle - McIntoshMeterPainter.minAngle).abs() < 0.002 &&
            _accuphaseValL < 0.002 &&
            _accuphaseValR < 0.002;
        if (atRest) {
          _leftAngle = McIntoshMeterPainter.minAngle;
          _rightAngle = McIntoshMeterPainter.minAngle;
          _accuphaseValL = 0.0;
          _accuphaseValR = 0.0;
          _ticker.stop(); // 彻底停止 Ticker，释放 OS VSync，CPU 直降至 0.0%
        }
      }

      setState(() {});
    });

    if (state.isPlaying || !isMeterMode) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant VisualizerStageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeType != oldWidget.activeType && widget.activeType != null) {
      _currentType = widget.activeType!;
      if (!_ticker.isTicking) {
        _lastTimestamp = 0.0;
        _ticker.start();
      }
      setState(() {});
    }
  }

  void _updatePhysics(double dt) {
    final state = HifiAudioService.instance.state;
    final levels = state.spectrumLevels;

    // 1. 双声道目标声压电平
    final rawL = levels.isNotEmpty ? levels[1] : 0.0;
    final rawR = levels.length > 2 ? levels[2] : 0.0;

    // 2. 指针物理惯性阻尼计算 (Attack 快速瞬态击打 0.32, Decay 慢速柔和释放 0.06)
    final normL = pow(rawL.clamp(0.0, 1.0), 0.9).toDouble();
    final normR = pow(rawR.clamp(0.0, 1.0), 0.9).toDouble();

    final targetAngleL = McIntoshMeterPainter.minAngle + normL * McIntoshMeterPainter.sweepAngle;
    final targetAngleR = McIntoshMeterPainter.minAngle + normR * McIntoshMeterPainter.sweepAngle;

    if (targetAngleL > _leftAngle) {
      _leftAngle += (targetAngleL - _leftAngle) * 0.32;
    } else {
      _leftAngle += (targetAngleL - _leftAngle) * 0.06;
    }

    if (targetAngleR > _rightAngle) {
      _rightAngle += (targetAngleR - _rightAngle) * 0.32;
    } else {
      _rightAngle += (targetAngleR - _rightAngle) * 0.06;
    }

    // Accuphase 物理非线性映射与惯性阻尼 (Attack 0.35, Decay 0.07, pow 0.82)
    final accNormL = pow(rawL.clamp(0.0, 1.0), 0.82).toDouble();
    final accNormR = pow(rawR.clamp(0.0, 1.0), 0.82).toDouble();
    if (accNormL > _accuphaseValL) {
      _accuphaseValL += (accNormL - _accuphaseValL) * 0.35;
    } else {
      _accuphaseValL += (accNormL - _accuphaseValL) * 0.07;
    }
    if (accNormR > _accuphaseValR) {
      _accuphaseValR += (accNormR - _accuphaseValR) * 0.35;
    } else {
      _accuphaseValR += (accNormR - _accuphaseValR) * 0.07;
    }

    // 3. 磁带轮旋转物理模型 (线速度恒定，角速度与当前带卷半径成反比)
    if (state.isPlaying) {
      _tapeLeftAngle += (1.5 + (1.0 - state.progress) * 1.5) * dt;
      _tapeRightAngle += (1.5 + state.progress * 1.5) * dt;
    }

    // 4. LED 频谱峰值保持与重力回落
    for (int i = 0; i < 12; i++) {
      final lvl = (i < levels.length) ? levels[i] : 0.0;
      if (lvl >= _peakHold[i]) {
        _peakHold[i] = lvl;
      } else {
        _peakHold[i] = (_peakHold[i] - 0.55 * dt).clamp(0.0, 1.0);
      }
    }

    // 5. 波形与能量球演进时间
    final avgEnergy = levels.isNotEmpty ? levels.reduce((a, b) => a + b) / levels.length : 0.0;
    _animTime += (1.5 + avgEnergy * 3.5) * dt;

    // 6. 音乐微光气泡物理更新
    if (_bubblesInitialized) {
      double bass = 0.0;
      double mid = 0.0;
      double treble = 0.0;
      if (state.isPlaying && levels.isNotEmpty) {
        final len = levels.length;
        bass = (levels[0] + (len > 1 ? levels[1] : 0.0) + (len > 2 ? levels[2] : 0.0)) / 3.0;
        if (len > 6) mid = (levels[3] + levels[4] + levels[5] + levels[6]) / 4.0;
        if (len > 10) treble = (levels[7] + levels[8] + levels[9] + levels[10]) / 4.0;
      }
      final totalEnergy = bass * 0.5 + mid * 0.3 + treble * 0.2;
      final speedFactor = state.isPlaying ? (1.0 + totalEnergy * 2.2) : 1.0;

      for (final b in _bubbles) {
        b.y -= b.vy * speedFactor * dt;
        b.vxPhase += b.vxSpeed * dt;
        if (b.y < -b.currentRadius * 1.5) {
          b.y = 900.0 + b.currentRadius + (Random().nextInt(40));
          b.x = Random().nextDouble() * 1400.0;
        }
        double targetR = b.baseRadius;
        if (state.isPlaying) {
          if (b.freqBand == 0) {
            targetR = b.baseRadius * (1.0 + bass * 0.45);
          } else if (b.freqBand == 1) {
            targetR = b.baseRadius * (1.0 + bass * 0.30 + mid * 0.15);
          } else if (b.freqBand == 2) {
            targetR = b.baseRadius * (1.0 + mid * 0.35);
          } else {
            targetR = b.baseRadius * (1.0 + treble * 0.30);
          }
        }
        b.currentRadius += (targetR - b.currentRadius) * (12.0 * dt);
      }
    }
  }

  @override
  void dispose() {
    HifiAudioService.instance.isPlayingNotifier.removeListener(_onPlayStateChanged);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HifiAudioService.instance.state;

    final effectiveType = widget.activeType ?? _currentType;

    CustomPainter painter;
    switch (effectiveType) {
      case VisualizerType.mcIntosh:
        painter = McIntoshMeterPainter(
          leftAngle: _leftAngle,
          rightAngle: _rightAngle,
          themeId: ThemeService.instance.currentThemeId,
          accentColor: ThemeService.instance.accentColor,
        );
        break;
      case VisualizerType.accuphase:
        painter = AccuphaseMeterPainter(
          leftAngle: _leftAngle,
          rightAngle: _rightAngle,
          leftValue: _accuphaseValL,
          rightValue: _accuphaseValR,
          animTime: _animTime,
          volumePercent: (state.volume * 100).round(),
          themeId: ThemeService.instance.currentThemeId,
          accentColor: ThemeService.instance.accentColor,
        );
        break;
      case VisualizerType.tapeReel:
        painter = TapeReelPainter(
          progress: state.progress,
          leftAngle: _tapeLeftAngle,
          rightAngle: _tapeRightAngle,
          isPlaying: state.isPlaying,
          elapsedSec: state.currentTime,
          accentColor: ThemeService.instance.accentColor,
        );
        break;
      case VisualizerType.ledSpectrum:
        painter = LedSpectrumPainter(
          levels: state.spectrumLevels,
          peakHold: _peakHold,
          accentColor: ThemeService.instance.accentColor,
        );
        break;
      case VisualizerType.siriWave:
        painter = SiriWavePainter(
          spectrumLevels: state.spectrumLevels,
          animTime: _animTime,
          accentColor: ThemeService.instance.accentColor,
          isPlaying: state.isPlaying,
        );
        break;
      case VisualizerType.neonWave:
        painter = NeonWaveformPainter(
          levels: state.spectrumLevels,
          animTime: _animTime,
          accentColor: ThemeService.instance.accentColor,
          isPlaying: state.isPlaying,
        );
        break;
      case VisualizerType.cyberGrid:
        painter = CyberGridPainter(
          spectrumLevels: state.spectrumLevels,
          animTime: _animTime,
          accentColor: ThemeService.instance.accentColor,
          isPlaying: state.isPlaying,
        );
        break;
      case VisualizerType.glassClock:
        final avgEnergy = state.spectrumLevels.isNotEmpty
            ? state.spectrumLevels.reduce((a, b) => a + b) / state.spectrumLevels.length
            : 0.0;
        painter = GlassClockPainter(
          animTime: _animTime,
          accentColor: ThemeService.instance.accentColor,
          isPlaying: state.isPlaying,
          energy: avgEnergy,
        );
        break;
      case VisualizerType.bubbles:
        if (!_bubblesInitialized) {
          _initBubbles(const Size(1400, 900));
        }
        painter = AudioBubblesPainter(
          bubbles: _bubbles,
          accentColor: ThemeService.instance.accentColor,
          isPlaying: state.isPlaying,
          spectrumLevels: state.spectrumLevels,
          animTime: _animTime,
        );
        break;
      case VisualizerType.siriOrb:
        final avgEnergy = state.spectrumLevels.isNotEmpty
            ? state.spectrumLevels.reduce((a, b) => a + b) / state.spectrumLevels.length
            : 0.0;
        painter = SiriOrbPainter(
          energy: avgEnergy,
          animTime: _animTime,
          accentColor: ThemeService.instance.accentColor,
          isPlaying: state.isPlaying,
        );
        break;
      case VisualizerType.pureBlack:
        painter = LedSpectrumPainter(
          levels: state.spectrumLevels,
          peakHold: _peakHold,
          accentColor: ThemeService.instance.accentColor,
        );
        break;
    }

    return Stack(
      children: [
        // 核心渲染画布
        Positioned.fill(
          child: CustomPaint(
            painter: painter,
          ),
        ),

        // 右上角动效切换 Pill 胶囊控件 (可选)
        if (widget.showSelector)
          Positioned(
            right: 16,
            top: 16,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<VisualizerType>(
                    value: effectiveType,
                    dropdownColor: const Color(0xFF161B24),
                    icon: const Icon(Icons.style_rounded, size: 16, color: HifiTheme.mcIntoshGlow),
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
                          _currentType = newType;
                        });
                        widget.onTypeChanged?.call(newType);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
