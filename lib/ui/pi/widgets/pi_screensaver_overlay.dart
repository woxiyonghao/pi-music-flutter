import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../theme/hifi_theme.dart';

/// 树莓派微雪 7 寸 QLED 防烧屏微光发烧屏保
/// 当长时间未操作或停止播放时，自动进入超低发热、微光呼吸的发烧时钟模式，任意触碰即刻唤醒
class PiScreensaverOverlay extends StatefulWidget {
  final VoidCallback onWake;

  const PiScreensaverOverlay({super.key, required this.onWake});

  @override
  State<PiScreensaverOverlay> createState() => _PiScreensaverOverlayState();
}

class _PiScreensaverOverlayState extends State<PiScreensaverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _pulseAnim;
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = HifiAudioService.instance;
    final track = service.currentTrack;

    final hours = _now.hour.toString().padLeft(2, '0');
    final minutes = _now.minute.toString().padLeft(2, '0');
    final seconds = _now.second.toString().padLeft(2, '0');

    return GestureDetector(
      onTap: widget.onWake,
      onPanDown: (_) => widget.onWake(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.96),
        width: double.infinity,
        height: double.infinity,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) {
            final alpha = _pulseAnim.value;

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 发烧极简时钟
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$hours:$minutes',
                        style: TextStyle(
                          color: HifiTheme.mcIntoshGlow.withValues(alpha: alpha),
                          fontSize: 64,
                          fontWeight: FontWeight.w200,
                          letterSpacing: 4.0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        seconds,
                        style: TextStyle(
                          color: HifiTheme.neonCyan.withValues(alpha: alpha * 0.8),
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 当前曲目微光提醒 (若正在播放)
                  if (track != null)
                    Text(
                      '${track.title} · ${track.artist}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: alpha * 0.7),
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // 防烧屏轻触唤醒提示
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: alpha * 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: HifiTheme.mcIntoshGlow.withValues(alpha: alpha * 0.7),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'QLED 防烧屏节能微光中 · 轻触屏幕任意位置唤醒',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: alpha * 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
