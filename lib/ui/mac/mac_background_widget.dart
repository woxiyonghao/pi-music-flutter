import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../services/theme_service.dart';
import '../../theme/ui_config.dart';
import '../../core/platform_helper.dart';
import '../visualizers/visualizer_type.dart';
import '../visualizers/visualizer_stage_widget.dart';

/// macOS 全景底层背景与音乐律动动效 (1:1 严格对齐 C++ Application::renderBackground)
class MacBackgroundWidget extends StatelessWidget {
  final VisualizerType visualizerType;
  final double fullscreenProgress;
  final HifiPlatformType platform;

  const MacBackgroundWidget({
    super.key,
    this.visualizerType = VisualizerType.ledSpectrum,
    this.fullscreenProgress = 0.0,
    this.platform = HifiPlatformType.mac,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([HifiAudioService.instance, ThemeService.instance]),
      builder: (context, _) {
        final service = HifiAudioService.instance;
        final isPlaying = service.state.isPlaying;
        final spectrum = service.state.spectrumLevels;
        final theme = ThemeService.instance;
        final accent = theme.accentColor;
        final currentPreset = ThemeService.presets.firstWhere(
          (p) => p.id == theme.currentThemeId,
          orElse: () => ThemeService.presets.first,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. 基准发烧底色 (全屏通透统一深空基底)
            const ColoredBox(color: UIConfig.mainStageBg),

            // 2. 背景动效层分发 (严格使用 RepaintBoundary 建立独立 GPU 合成图层，彻底阻断对前台卡片列表的重绘波及)
            if (visualizerType == VisualizerType.ledSpectrum)
              RepaintBoundary(
                child: CustomPaint(
                  painter: _LedSpectrumBackgroundPainter(
                    isPlaying: isPlaying,
                    spectrumLevels: spectrum,
                    litColor: accent,
                    peakColor: currentPreset.peakColor,
                  ),
                ),
              ),

            if (visualizerType != VisualizerType.pureBlack &&
                visualizerType != VisualizerType.ledSpectrum)
              RepaintBoundary(
                child: VisualizerStageWidget(
                  key: ValueKey(visualizerType),
                  activeType: visualizerType,
                  platform: platform,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 48 列全景分段 LED 点阵频谱底纹绘制器 (极致性能优化：零三角函数计算、批量 Path 单次 GPU 提交)
class _LedSpectrumBackgroundPainter extends CustomPainter {
  final bool isPlaying;
  final List<double> spectrumLevels;
  final Color litColor;
  final Color peakColor;

  static const int numCols = 48;
  static const double gapX = 4.0;
  static const double segH = 6.0;
  static const double gapY = 2.5;

  // 预计算 48 列余弦平滑插值权重 (彻底消除运行时的 cos、pow、除法计算)
  static final List<_ColInterp> _colWeights = () {
    const numBands = 12;
    return List.generate(numCols, (c) {
      final normX = c / (numCols - 1);
      final pos = normX * (numBands - 1);
      final idx0 = pos.floor();
      final idx1 = min(idx0 + 1, numBands - 1);
      final frac = pos - idx0;
      final smoothT = (1.0 - cos(frac * pi)) * 0.5;
      return _ColInterp(idx0, idx1, 1.0 - smoothT, smoothT);
    });
  }();

  _LedSpectrumBackgroundPainter({
    required this.isPlaying,
    required this.spectrumLevels,
    required this.litColor,
    required this.peakColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const marginX = UIConfig.containerMarginX;
    final totalW = size.width - marginX * 2.0;
    if (totalW <= 0 || size.height <= 0) return;
    final colW = (totalW - (numCols - 1) * gapX) / numCols;
    final numRows = ((size.height - 16.0) / (segH + gapY)).floor().clamp(20, 80);
    final botY = size.height - 8.0;

    // 氛围低频辉光 (单次 drawRect)
    if (isPlaying && spectrumLevels.length >= 3) {
      final bassEnergy = (spectrumLevels[0] + spectrumLevels[1] + spectrumLevels[2]) / 3.0;
      if (bassEnergy > 0.05) {
        final glowAlpha = (bassEnergy * 0.15).clamp(0.0, 0.25);
        final glowPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              litColor.withValues(alpha: 0.0),
              litColor.withValues(alpha: glowAlpha),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);
      }
    }

    final unlitPath = Path();
    final litPath = Path();
    final peakPath = Path();

    final hasLevels = isPlaying && spectrumLevels.isNotEmpty;

    // 预计算行高度
    final rowY0 = List<double>.generate(numRows, (r) => botY - r * (segH + gapY) - segH);

    for (int c = 0; c < numCols; ++c) {
      final x0 = marginX + c * (colW + gapX);

      int activeCount = 0;
      if (hasLevels) {
        final interp = _colWeights[c];
        final val0 = interp.idx0 < spectrumLevels.length ? spectrumLevels[interp.idx0] : 0.0;
        final val1 = interp.idx1 < spectrumLevels.length ? spectrumLevels[interp.idx1] : 0.0;
        final level = val0 * interp.w0 + val1 * interp.w1;
        final dynamicLevel = (pow(level, 0.85) * 0.90).clamp(0.0, 1.0);
        activeCount = (dynamicLevel * numRows).round().clamp(0, numRows);
      }

      // 1. 点亮方块批量加入 litPath
      final litCount = (activeCount > 1) ? activeCount - 1 : 0;
      for (int r = 0; r < litCount; ++r) {
        litPath.addRect(Rect.fromLTWH(x0, rowY0[r], colW, segH));
      }

      // 2. 峰值顶端方块加入 peakPath
      if (activeCount > 0) {
        peakPath.addRect(Rect.fromLTWH(x0, rowY0[activeCount - 1], colW, segH));
      }

      // 3. 熄灭微光方块加入 unlitPath
      for (int r = activeCount; r < numRows; ++r) {
        unlitPath.addRect(Rect.fromLTWH(x0, rowY0[r], colW, segH));
      }
    }

    // 最终仅需 3 次 GPU 批量绘制调用 (从 3500 次降低到 3 次)
    final unlitPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.035)
      ..style = PaintingStyle.fill;
    canvas.drawPath(unlitPath, unlitPaint);

    final litPaint = Paint()
      ..color = litColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(litPath, litPaint);

    final peakPaint = Paint()
      ..color = peakColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(peakPath, peakPaint);
  }

  @override
  bool shouldRepaint(covariant _LedSpectrumBackgroundPainter oldDelegate) {
    return isPlaying ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.litColor != litColor ||
        oldDelegate.peakColor != peakColor;
  }
}

class _ColInterp {
  final int idx0;
  final int idx1;
  final double w0;
  final double w1;
  const _ColInterp(this.idx0, this.idx1, this.w0, this.w1);
}
