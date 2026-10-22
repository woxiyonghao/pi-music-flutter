import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../models/track.dart';
import '../../../services/music_database_service.dart';
import '../../../services/theme_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';
import '../widgets/mac_music_item_widget.dart';

enum ScanUIState {
  idle,
  scanning,
  completed,
}

/// 扫描音乐视图 (1:1 严格对齐 C++ ScanMusicWidget.cpp 与 cpp_tab_0_scan.png)
class MacScanMusicView extends StatefulWidget {
  final int scannedCount;
  final VoidCallback? onScanComplete;

  const MacScanMusicView({
    super.key,
    this.scannedCount = 0,
    this.onScanComplete,
  });

  @override
  State<MacScanMusicView> createState() => _MacScanMusicViewState();
}

class _MacScanMusicViewState extends State<MacScanMusicView>
    with TickerProviderStateMixin {
  ScanUIState _state = ScanUIState.completed;
  bool _isEditMode = false;
  final Set<int> _selectedTrackIds = {};
  late final AnimationController _animController;

  static const List<AudioFormat> formatOrder = [
    AudioFormat.dsdDsf,
    AudioFormat.dsdDff,
    AudioFormat.alac,
    AudioFormat.flac,
    AudioFormat.wav,
    AudioFormat.mp3,
  ];

  static const Map<AudioFormat, Map<String, String>> formatMeta = {
    AudioFormat.dsdDsf: {
      'title': 'DSD-DSF',
      'subtitle': 'SACD-1-bit',
      'tag': 'DSD Direct',
    },
    AudioFormat.dsdDff: {
      'title': 'DSD-DFF',
      'subtitle': 'SACD',
      'tag': '1-bit Stream',
    },
    AudioFormat.alac: {
      'title': 'Apple-ALAC',
      'subtitle': 'Apple-Lossless-Audio-Codec',
      'tag': 'Apple 无损',
    },
    AudioFormat.flac: {
      'title': 'FLAC',
      'subtitle': 'Free-Lossless-24bit/192kHz',
      'tag': 'Studio Master',
    },
    AudioFormat.wav: {
      'title': 'WAV',
      'subtitle': 'Uncompressed-PCM',
      'tag': 'Uncompressed',
    },
    AudioFormat.mp3: {
      'title': 'MP3',
      'subtitle': 'MPEG-Audio',
      'tag': '流行热播',
    },
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    final tracks = MusicDatabaseService.instance.tracks;
    if (tracks.isEmpty) {
      _state = ScanUIState.idle;
    } else {
      _state = ScanUIState.completed;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _triggerScan() async {
    setState(() {
      _state = ScanUIState.scanning;
      _isEditMode = false;
      _selectedTrackIds.clear();
    });

    // 真正异步扫描音乐文件与 CUE 分轨表
    try {
      await MusicDatabaseService.instance.scanLibrary();
    } catch (e) {
      debugPrint('[MacScanView] 扫描异常: $e');
    }

    if (mounted) {
      widget.onScanComplete?.call();
      setState(() {
        _state = ScanUIState.completed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.instance,
        HifiAudioService.instance.currentTrackNotifier,
        HifiAudioService.instance.isPlayingNotifier,
      ]),
      builder: (context, _) {

        final theme = ThemeService.instance;
        final accent = theme.accentColor;

        return GlassCard(
          borderRadius: UIConfig.containerRounding,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 状态机分发渲染
              if (_state == ScanUIState.idle) _buildIdleState(accent),
              if (_state == ScanUIState.scanning) _buildScanningState(accent),
              if (_state == ScanUIState.completed) _buildCompletedState(accent),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. 待机态：巡游放大镜 +「全盘检索」胶囊按钮 (对齐 ScanMusicWidget::renderIdleState)
  // ===========================================================================
  Widget _buildIdleState(Color accent) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final t = _animController.value * 2 * math.pi;
        final offsetX = math.cos(t * 1.5) * 12.0;
        final offsetY = math.sin(t * 2.2) * 9.0;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(offsetX, offsetY - 20.0),
                child: CustomPaint(
                  size: const Size(110.0, 110.0),
                  painter: _SearchIconPainter(accentColor: accent),
                ),
              ),
              const SizedBox(height: 36.0),

              // 全盘检索发烧胶囊按钮
              InkWell(
                onTap: _triggerScan,
                borderRadius: BorderRadius.circular(21.0),
                child: Container(
                  width: 190.0,
                  height: 42.0,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(21.0),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.4),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25),
                        blurRadius: 12.0,
                      ),
                    ],
                  ),
                  child: const Text(
                    '全盘检索',
                    style: TextStyle(
                      fontSize: UIConfig.fontRegular,
                      fontWeight: FontWeight.bold,
                      color: UIConfig.textActive,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 2. 扫描态：纯净沉浸式太阳日冕与曲速星芒 (严格受限于卡片边界，绝不溢出)
  // ===========================================================================
  Widget _buildScanningState(Color accent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(UIConfig.containerRounding),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _CosmicWarpPainter(
              timer: _animController.value * 10.0,
              accentColor: accent,
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 3. 已完成展示态：格式分组卡片网格 (对齐 ScanMusicWidget::renderCompletedState)
  // ===========================================================================
  Widget _buildCompletedState(Color accent) {
    final allTracks = MusicDatabaseService.instance.tracks;
    final currentPlayingTrack = HifiAudioService.instance.currentTrack;
    final isEnginePlaying = HifiAudioService.instance.isPlayingNotifier.value;

    // 按格式分流曲目
    final Map<AudioFormat, List<Track>> formatBuckets = {};
    for (final t in allTracks) {
      formatBuckets.putIfAbsent(t.format, () => []).add(t);
    }

    return Column(
      children: [
        // 顶部操作栏：「选择」多选模式切换 +「重新扫描」
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _isEditMode = !_isEditMode),
              child: Container(
                height: 28.0,
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isEditMode
                      ? accent.withValues(alpha: 0.28)
                      : const Color.fromRGBO(40, 48, 64, 0.7),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: _isEditMode
                        ? accent
                        : const Color.fromRGBO(255, 255, 255, 0.12),
                  ),
                ),
                child: Text(
                  _isEditMode ? '完成选择' : '选择',
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    color: _isEditMode ? UIConfig.textActive : UIConfig.textNormal,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _triggerScan,
              child: Container(
                height: 28.0,
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(40, 48, 64, 0.7),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.12),
                  ),
                ),
                child: const Text(
                  '重新扫描',
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    color: UIConfig.textNormal,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),

        // 纵向滚动列表 (每个格式一行横向卡片)
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              for (final fmt in formatOrder)
                if (formatBuckets.containsKey(fmt) && formatBuckets[fmt]!.isNotEmpty)
                  _buildFormatSection(
                    fmt: fmt,
                    tracks: formatBuckets[fmt]!,
                    currentPlaying: currentPlayingTrack,
                    isEnginePlaying: isEnginePlaying,
                    accent: accent,
                  ),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormatSection({
    required AudioFormat fmt,
    required List<Track> tracks,
    required Track? currentPlaying,
    required bool isEnginePlaying,
    required Color accent,
  }) {
    final meta = formatMeta[fmt] ?? {
      'title': '未知格式',
      'subtitle': '',
      'tag': '本地音频',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 板块大标题与副标题
          Text(
            meta['title']!,
            style: const TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: UIConfig.textActive,
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            '${meta['subtitle']!} · 共 ${tracks.length} 首',
            style: const TextStyle(
              fontSize: UIConfig.fontSmall,
              color: UIConfig.textMuted,
            ),
          ),
          const SizedBox(height: 12.0),

          // 卡片横向滚动行 (支持鼠标全指针拖拽与状态保持)
          SizedBox(
            height: 220.0,
            child: ScrollConfiguration(
              behavior: const MouseDraggableScrollBehavior(),
              child: ListView.separated(
                key: PageStorageKey('mac_scan_format_${fmt.name}'),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: tracks.length,
                separatorBuilder: (context, _) => const SizedBox(width: 16.0),

              itemBuilder: (context, index) {
                final track = tracks[index];
                final isPlaying = currentPlaying != null &&
                    currentPlaying.matches(track) &&
                    isEnginePlaying;
                final isSelected = _selectedTrackIds.contains(track.id);

                return MacMusicItemWidget(
                  track: track,
                  categoryTag: meta['tag']!,
                  isEditMode: _isEditMode,
                  isSelected: isSelected,
                  isPlaying: isPlaying,

                  onTap: () {
                    if (_isEditMode) {
                      setState(() {
                        if (isSelected) {
                          _selectedTrackIds.remove(track.id);
                        } else {
                          _selectedTrackIds.add(track.id);
                        }
                      });
                    } else {
                      HifiAudioService.instance.playTrack(track, tracks, index);
                    }
                  },
                );
              },
            ),
          ),
        ),

        ],
      ),
    );
  }
}

/// 纯矢量发烧级放大镜绘制器
class _SearchIconPainter extends CustomPainter {
  final Color accentColor;

  _SearchIconPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.42, size.height * 0.42);
    const lensR = 30.0;

    // 1. 镜片半透明微光底板
    canvas.drawCircle(c, lensR - 2.0, Paint()..color = const Color.fromRGBO(255, 255, 255, 0.08));

    // 2. 外部主镜框 (主题色外发光)
    canvas.drawCircle(c, lensR + 2.5, Paint()..color = accentColor.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawCircle(c, lensR, Paint()..color = accentColor..style = PaintingStyle.stroke..strokeWidth = 3.5);

    // 3. 镜片弧光反射 (左上圆弧高光)
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: lensR - 5.0),
      -2.4,
      1.5,
      false,
      Paint()..color = const Color.fromRGBO(255, 255, 255, 0.65)..style = PaintingStyle.stroke..strokeWidth = 2.0..strokeCap = StrokeCap.round,
    );

    // 4. 镜内探索引导小圆
    canvas.drawCircle(c, lensR * 0.38, Paint()..color = accentColor.withValues(alpha: 0.15));
    canvas.drawCircle(c, lensR * 0.38, Paint()..color = accentColor..style = PaintingStyle.stroke..strokeWidth = 2.0);

    // 5. 45度斜向手柄
    final hStart = Offset(c.dx + lensR * 0.7071, c.dy + lensR * 0.7071);
    final hEnd = Offset(hStart.dx + 26.0, hStart.dy + 26.0);
    canvas.drawLine(hStart, hEnd, Paint()..color = accentColor..strokeWidth = 5.5..strokeCap = StrokeCap.round);
    canvas.drawLine(
      Offset(hStart.dx + 1.2, hStart.dy + 1.2),
      Offset(hEnd.dx - 2.5, hEnd.dy - 2.5),
      Paint()..color = const Color.fromRGBO(255, 255, 255, 0.45)..strokeWidth = 1.8..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SearchIconPainter old) => old.accentColor != accentColor;
}

/// 扫描态纯净宇宙太阳光球与星芒激光流绘制器 (1:1 严格对齐 C++ ScanMusicWidget::drawLaserWarpAnimation)
class _CosmicWarpPainter extends CustomPainter {
  final double timer;
  final Color accentColor;

  _CosmicWarpPainter({
    required this.timer,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 严格限制在卡片内部裁剪，绝对不溢出到窗口外边框或侧边栏 (对齐 C++ dl->PushClipRect)
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10.0),
    ));

    final center = Offset(size.width / 2, size.height / 2);
    final maxDist = math.sqrt(center.dx * center.dx + center.dy * center.dy) + 40.0;

    final r = (accentColor.r * 255).round();
    final g = (accentColor.g * 255).round();
    final b = (accentColor.b * 255).round();

    final rLight = (r + (255 - r) * 0.75).round().clamp(0, 255);
    final gLight = (g + (255 - g) * 0.75).round().clamp(0, 255);
    final bLight = (b + (255 - b) * 0.75).round().clamp(0, 255);

    // =========================================================================
    // 1. 密集发丝级径向星芒激光流 (360 束，严格对齐 C++ NUM_RAYS = 360)
    // =========================================================================
    const numRays = 360;
    for (int i = 0; i < numRays; i++) {
      // 黄金分割角 (137.5° / 2.3999632 rad) 均匀环形铺展
      final angle = i * 2.3999632;

      // 确定性随机相位与多频流动速度
      final phase = ((i * 17 + 31) * 0.0137) % 1.0;
      final speed = 0.18 + ((i * 7) * 0.019) % 0.12;
      final progress = (timer * speed + phase) % 1.0;

      // 连续长光束延伸
      final rStart = 18.0 + progress * 50.0;
      final rEnd = math.min(maxDist, rStart + 80.0 + (progress * progress) * (maxDist - 80.0));

      final x1 = center.dx + math.cos(angle) * rStart;
      final y1 = center.dy + math.sin(angle) * (rStart * 0.90);
      final x2 = center.dx + math.cos(angle) * rEnd;
      final y2 = center.dy + math.sin(angle) * (rEnd * 0.90);

      // 多层通透微光：大部分为细腻幽光 (Alpha 25~120)，少数高亮主光束 (Alpha 180~220)
      var alpha = (25.0 + progress * 95.0).round();
      if (i % 8 == 0) {
        alpha = math.min(225, alpha + 90);
      }

      // 1.0px 发丝级细腻线条
      final rayPaint = Paint()
        ..color = Color.fromARGB(alpha.clamp(0, 255), r, g, b)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), rayPaint);

      // 高亮主光束核心叠加入射白炽微光
      if (alpha > 150) {
        final midX = x1 + (x2 - x1) * 0.5;
        final midY = y1 + (y2 - y1) * 0.5;
        final corePaint = Paint()
          ..color = Color.fromARGB((alpha * 0.65).round().clamp(0, 255), rLight, gLight, bLight)
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(midX, midY), Offset(x2, y2), corePaint);
      }
    }

    // =========================================================================
    // 2. 漫天星尘与闪烁十字星芒粒子系统 (240 颗，严格对齐 C++ NUM_PARTICLES = 240)
    // =========================================================================
    const numParticles = 240;
    for (int j = 0; j < numParticles; j++) {
      final pAngle = (j * 2.3999632) + ((j * 13) * 0.021) % 0.25;
      final pPhase = ((j * 29 + 11) * 0.0173) % 1.0;
      final pSpeed = 0.16 + ((j * 11) * 0.013) % 0.10;
      final pProg = (timer * pSpeed + pPhase) % 1.0;

      final pCurve = pProg * pProg; // 二次加速，呈现远小近大的空间透视
      final pR = 16.0 + pCurve * (maxDist - 16.0);

      final px = center.dx + math.cos(pAngle) * pR;
      final py = center.dy + math.sin(pAngle) * (pR * 0.90);

      // 渐入渐出透明度包络
      final fade = (pProg < 0.12) ? (pProg / 0.12) : (1.0 - pCurve * 0.65);
      final pAlpha = (fade * 255.0).clamp(0.0, 255.0).round();
      final pSize = 0.8 + pCurve * 2.2;

      final pType = j % 12;
      if (pType < 7) {
        // (1) 普通深空微光星尘：细微点缀
        canvas.drawCircle(
          Offset(px, py),
          pSize,
          Paint()..color = Color.fromARGB(pAlpha, rLight, gLight, bLight),
        );
      } else if (pType < 10) {
        // (2) 带有主题色柔和光晕的恒星粒子：双层微发光
        final haloR = pSize * 2.6;
        canvas.drawCircle(
          Offset(px, py),
          haloR,
          Paint()..color = Color.fromARGB((pAlpha * 0.35).round().clamp(0, 255), r, g, b),
        );
        canvas.drawCircle(
          Offset(px, py),
          pSize,
          Paint()..color = Color.fromARGB(pAlpha, 255, 255, 255),
        );
      } else {
        // (3) 星球大战原版同款 4 芒十字衍射星芒 (Cross Star Flares)
        final flareLen = 4.0 + pCurve * 10.0;
        canvas.drawCircle(
          Offset(px, py),
          pSize * 2.0,
          Paint()..color = Color.fromARGB((pAlpha * 0.45).round().clamp(0, 255), r, g, b),
        );
        final flarePaint = Paint()
          ..color = Color.fromARGB((pAlpha * 0.85).round().clamp(0, 255), rLight, gLight, bLight)
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(px - flareLen, py), Offset(px + flareLen, py), flarePaint);
        canvas.drawLine(Offset(px, py - flareLen), Offset(px, py + flareLen), flarePaint);
        canvas.drawCircle(
          Offset(px, py),
          1.5,
          Paint()..color = const Color.fromARGB(255, 255, 255, 255),
        );
      }
    }

    // =========================================================================
    // 3. 核心太阳光球 (1:1 严格对齐 C++ drawSmoothSolarSphere)
    // =========================================================================
    final pulse = 1.0 + 0.03 * math.sin(timer * 2.5);

    // 1. 广域深空外日冕柔和微光辉晕 (由 36px 向外平滑渐隐入深空背景)
    canvas.drawCircle(center, 36.0 * pulse, Paint()..color = Color.fromARGB(20, r, g, b));
    canvas.drawCircle(center, 28.0 * pulse, Paint()..color = Color.fromARGB(45, r, g, b));
    canvas.drawCircle(center, 21.0 * pulse, Paint()..color = Color.fromARGB(85, r, g, b));
    canvas.drawCircle(center, 15.0 * pulse, Paint()..color = Color.fromARGB(140, r, g, b));

    // 2. 高温过渡色球层 (由主题色经由白炽过渡)
    final r1 = (r + (255 - r) * 0.40).round().clamp(0, 255);
    final g1 = (g + (255 - g) * 0.40).round().clamp(0, 255);
    final b1 = (b + (255 - b) * 0.40).round().clamp(0, 255);

    final r2 = (r + (255 - r) * 0.70).round().clamp(0, 255);
    final g2 = (g + (255 - g) * 0.70).round().clamp(0, 255);
    final b2 = (b + (255 - b) * 0.70).round().clamp(0, 255);

    final r3 = (r + (255 - r) * 0.90).round().clamp(0, 255);
    final g3 = (g + (255 - g) * 0.90).round().clamp(0, 255);
    final b3 = (b + (255 - b) * 0.90).round().clamp(0, 255);

    canvas.drawCircle(center, 11.0 * pulse, Paint()..color = Color.fromARGB(190, r1, g1, b1));
    canvas.drawCircle(center, 7.5 * pulse, Paint()..color = Color.fromARGB(230, r2, g2, b2));
    canvas.drawCircle(center, 5.0 * pulse, Paint()..color = Color.fromARGB(250, r3, g3, b3));

    // 3. 极热白炽恒星核 (100% 纯净白炽圆球)
    canvas.drawCircle(center, 3.2 * pulse, Paint()..color = const Color.fromARGB(255, 255, 255, 255));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CosmicWarpPainter old) => true;
}
