import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'iphone_landscape_view.dart';
import 'iphone_portrait_view.dart';
import 'widgets/iphone_orientation_dialog.dart';

/// Orientation belongs to this app session. Backgrounding keeps the choice;
/// terminating the process discards it and requires a new choice on next launch.
class IphoneMainView extends StatefulWidget {
  const IphoneMainView({super.key, this.initialize, this.onReady});

  final Future<void> Function()? initialize;
  final VoidCallback? onReady;

  @override
  State<IphoneMainView> createState() => _IphoneMainViewState();
}

class _IphoneMainViewState extends State<IphoneMainView> {
  bool? _landscape;
  late bool _ready;
  bool _locking = false;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    _ready = widget.initialize == null;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!_ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
    }
  }

  Future<void> _initialize() async {
    setState(() => _startupError = null);
    try {
      await widget.initialize!();
      if (!mounted) return;
      setState(() => _ready = true);
      widget.onReady?.call();
    } catch (error) {
      if (mounted) setState(() => _startupError = error);
    }
  }

  Future<void> _confirmOrientation(bool landscape) async {
    if (_landscape != null || _locking) return;
    _locking = true;
    try {
      await SystemChrome.setPreferredOrientations(landscape
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight
            ]
          : const [DeviceOrientation.portraitUp]);
      if (mounted) setState(() => _landscape = landscape);
    } finally {
      _locking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_landscape == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF080C12),
        body: SafeArea(
          child: IphoneOrientationDialog(
            initialIsLandscape: true,
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
                        onPressed: _initialize, child: const Text('重试')),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return _landscape!
        ? const IphoneLandscapeView()
        : const IphonePortraitView();
  }
}
