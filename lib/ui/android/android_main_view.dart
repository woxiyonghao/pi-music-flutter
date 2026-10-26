import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'android_player_view.dart';
import 'widgets/android_orientation_dialog.dart';

/// Display mode belongs to this process: resuming keeps the choice, while a
/// fresh launch asks again. Never write the direction into persistent settings.
class AndroidMainView extends StatefulWidget {
  const AndroidMainView({super.key, this.initialize, this.onReady});

  final Future<void> Function()? initialize;
  final VoidCallback? onReady;

  @override
  State<AndroidMainView> createState() => _AndroidMainViewState();
}

class _AndroidMainViewState extends State<AndroidMainView> {
  bool? _landscape;
  late bool _ready;
  bool _initializing = false;
  bool _locking = false;
  Object? _startupError;
  Object? _orientationError;

  @override
  void initState() {
    super.initState();
    _ready = widget.initialize == null;
    unawaited(_prepareChooser());
    if (!_ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_initialize());
      });
    }
  }

  Future<void> _prepareChooser() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    } catch (error) {
      // The choice still works in multi-window and on hosts without rotation.
      debugPrint('[Android] Cannot rotate the startup screen: $error');
    }
  }

  Future<void> _initialize() async {
    if (_initializing) return;
    setState(() {
      _initializing = true;
      _startupError = null;
    });
    try {
      await widget.initialize!();
      if (!mounted) return;
      setState(() => _ready = true);
      widget.onReady?.call();
    } catch (error) {
      if (mounted) setState(() => _startupError = error);
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _confirmOrientation(bool landscape) async {
    if (_landscape != null || _locking) return;
    setState(() {
      _locking = true;
      _orientationError = null;
    });
    try {
      await SystemChrome.setPreferredOrientations(landscape
          ? const [DeviceOrientation.landscapeLeft]
          : const [DeviceOrientation.portraitUp]);
      try {
        await SystemChrome.setEnabledSystemUIMode(
          landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
        );
      } catch (_) {}
      if (mounted) setState(() => _landscape = landscape);
    } catch (error) {
      if (mounted) setState(() => _orientationError = error);
    } finally {
      if (mounted) setState(() => _locking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_landscape == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF080C12),
        body: SafeArea(
          child: AndroidOrientationDialog(
            initialIsLandscape: true,
            confirming: _locking,
            error: _orientationError == null ? null : '屏幕方向设置失败，请重试',
            onConfirmed: _confirmOrientation,
          ),
        ),
      );
    }
    if (!_ready) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_startupError == null) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('正在启动播放器'),
                  ] else ...[
                    const Text('播放器启动失败'),
                    const SizedBox(height: 12),
                    Text('$_startupError', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _initializing ? null : _initialize,
                      child: const Text('重试'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    // Android may ignore rotation locks on tablets and in multi-window. Render
    // the selected mode responsively instead of waiting forever for a resize.
    return AndroidPlayerView(landscape: _landscape!);
  }
}
