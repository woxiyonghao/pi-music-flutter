import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/hifi_audio_service.dart';
import '../../services/theme_service.dart';
import '../../theme/ui_config.dart';
import '../visualizers/visualizer_type.dart';
import '../visualizers/visualizer_stage_widget.dart';

/// macOS 全景底层背景与音乐律动动效 (1:1 严格对齐 C++ Application::renderBackground)
class MacBackgroundWidget extends StatelessWidget {
  final VisualizerType visualizerType;
  final double fullscreenProgress;

  const MacBackgroundWidget({
    super.key,
    this.visualizerType = VisualizerType.ledSpectrum,
    this.fullscreenProgress = 0.0,
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

            // 2. 背景动效层分发
            if (visualizerType == VisualizerType.ledSpectrum)
              CustomPaint(
                painter: _LedSpectrumBackgroundPainter(
                  isPlaying: isPlaying,
                  spectrumLevels: spectrum,
                  litColor: accent,
                  peakColor: currentPreset.peakColor,
                ),
              )
            else if (visualizerType != VisualizerType.pureBlack)
              Opacity(
                opacity: (0.85 + 0.15 * fullscreenProgress).clamp(0.0, 1.0),
                child: VisualizerStageWidget(
                  key: ValueKey('${visualizerType.index}_${theme.currentThemeId}_${accent.toARGB32()}'),
                  activeType: visualizerType,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 48 列全景分段 LED 点阵频谱底纹绘制器 (对齐 C++ Application::renderBackground)
class _LedSpectrumBackgroundPainter extends CustomPainter {
  final bool isPlaying;
  final List<double> spectrumLevels;
  final Color litColor;
  final Color peakColor;

  _LedSpectrumBackgroundPainter({
    required this.isPlaying,
    required this.spectrumLevels,
    required this.litColor,
    required this.peakColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const numCols = 48;
    const gapX = 4.0;
    const marginX = UIConfig.containerMarginX;
    final totalW = size.width - marginX * 2.0;
    final colW = (totalW - (numCols - 1) * gapX) / numCols;

    const segH = 6.0;
    const gapY = 2.5;
    final numRows = ((size.height - 16.0) / (segH + gapY)).floor().clamp(20, 200);
    final botY = size.height - 8.0;

    // 熄灭态微光点阵底板色
    const unlitColor = Color.fromRGBO(255, 255, 255, 0.035);
    final unlitPaint = Paint()
      ..color = unlitColor
      ..style = PaintingStyle.fill;

    final litPaint = Paint()..style = PaintingStyle.fill;

    // 绘制 48 列点阵
    for (int c = 0; c < numCols; ++c) {
      final x0 = marginX + c * (colW + gapX);
      final x1 = x0 + colW;

      int activeCount = 0;
      if (isPlaying && spectrumLevels.isNotEmpty) {
        final normX = c / (numCols - 1);
        final pos = normX * (spectrumLevels.length - 1);
        final idx0 = pos.floor();
        final idx1 = min(idx0 + 1, spectrumLevels.length - 1);
        final frac = pos - idx0;
        final smoothT = (1.0 - cos(frac * pi)) * 0.5;
        final level = spectrumLevels[idx0] * (1.0 - smoothT) +
            spectrumLevels[idx1] * smoothT;
        final dynamicLevel = (pow(level, 0.85) * 0.90).clamp(0.0, 1.0);
        activeCount = (dynamicLevel * numRows).round().clamp(0, numRows);
      }

      for (int r = 0; r < numRows; ++r) {
        final y1 = botY - r * (segH + gapY);
        final y0 = y1 - segH;
        final rect = Rect.fromLTRB(x0, y0, x1, y1);

        if (r < activeCount) {
          final isPeak = (r == activeCount - 1);
          litPaint.color = isPeak ? peakColor : litColor;
          canvas.drawRect(rect, litPaint);
        } else {
          canvas.drawRect(rect, unlitPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LedSpectrumBackgroundPainter oldDelegate) {
    return isPlaying ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.litColor != litColor ||
        oldDelegate.peakColor != peakColor;
  }
}
