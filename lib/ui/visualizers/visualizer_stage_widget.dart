import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/hifi_audio_service.dart';
import '../../theme/hifi_theme.dart';
import 'visualizer_type.dart';
import 'mcintosh_meter_painter.dart';
import 'accuphase_meter_painter.dart';
import 'tape_reel_painter.dart';
import 'led_spectrum_painter.dart';
import 'neon_waveform_painter.dart';
import 'siri_orb_painter.dart';

/// 统一发烧动效舞台容器 (专为横屏设备打造，内置 60fps 物理阻尼与动画引擎)
class VisualizerStageWidget extends StatefulWidget {
  final VisualizerType initialType;
  final bool showSelector;

  const VisualizerStageWidget({
    super.key,
    this.initialType = VisualizerType.mcIntosh,
    this.showSelector = true,
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

  // 磁带轮旋转角度
  double _tapeLeftAngle = 0.0;
  double _tapeRightAngle = 0.0;

  // 峰值保持数组
  final List<double> _peakHold = List.filled(12, 0.0);

  // 动画时间
  double _animTime = 0.0;
  double _lastTimestamp = 0.0;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;

    _ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1000000.0;
      final dt = (_lastTimestamp > 0.0) ? (t - _lastTimestamp).clamp(0.001, 0.05) : 0.016;
      _lastTimestamp = t;

      _updatePhysics(dt);
      setState(() {});
    })..start();
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
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HifiAudioService.instance.state;

    CustomPainter painter;
    switch (_currentType) {
      case VisualizerType.mcIntosh:
        painter = McIntoshMeterPainter(
          leftAngle: _leftAngle,
          rightAngle: _rightAngle,
        );
        break;
      case VisualizerType.accuphase:
        painter = AccuphaseMeterPainter(
          leftAngle: _leftAngle,
          rightAngle: _rightAngle,
        );
        break;
      case VisualizerType.tapeReel:
        painter = TapeReelPainter(
          progress: state.progress,
          leftAngle: _tapeLeftAngle,
          rightAngle: _tapeRightAngle,
          isPlaying: state.isPlaying,
        );
        break;
      case VisualizerType.ledSpectrum:
        painter = LedSpectrumPainter(
          levels: state.spectrumLevels,
          peakHold: _peakHold,
        );
        break;
      case VisualizerType.neonWaveform:
        painter = NeonWaveformPainter(
          levels: state.spectrumLevels,
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

        // 右上角动效切换 Pill 胶囊控件 (支持横屏下一键快速切换 6 大发烧动效)
        if (widget.showSelector)
          Positioned(
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<VisualizerType>(
                  value: _currentType,
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
                    }
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
