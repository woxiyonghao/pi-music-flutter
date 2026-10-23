import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_paths.dart';
import 'core/hifi_audio_bindings.dart';
import 'platform/platform_audio_runtime.dart';
import 'services/music_database_service.dart';
import 'services/dac_setting_service.dart';
import 'services/web_remote_service.dart';
import 'theme/hifi_theme.dart';
import 'theme/ui_config.dart';
import 'ui/ipad/ipad_main_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HiFiPlayerStartup(
    initialize: initializePlayer,
    onReady: startPlayerServices,
  ));
}

Future<void> initializePlayer() async {
  await AppPaths.init().timeout(const Duration(seconds: 15));
  await PlatformAudioRuntime.instance
      .configure()
      .timeout(const Duration(seconds: 20));
  if (!HifiAudioBindings.instance.init()) {
    throw StateError(
        'audio_engine initialization failed: ${HifiAudioBindings.instance.loadError}');
  }
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }
  DacSettingService.instance;
  MusicDatabaseService.instance.loadLibrary();
}

void startPlayerServices() {
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    unawaited(() async {
      try {
        if (Platform.isIOS) {
          await PlatformAudioRuntime.instance
              .refreshOutput()
              .timeout(const Duration(seconds: 5));
        }
      } catch (error) {
        debugPrint('[Startup] 音频设备查询失败，将在播放时重试: $error');
      }
    }());
    unawaited(() async {
      try {
        await WebRemoteService.instance.start(port: 8088);
        await MusicDatabaseService.instance.initializeLibrary();
      } catch (error, stack) {
        FlutterError.reportError(FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'HiFi Player background startup'));
      }
    }());
  }
}

/// Paint a real Flutter frame before waiting for plugins or scanning storage.
class HiFiPlayerStartup extends StatefulWidget {
  const HiFiPlayerStartup({super.key, required this.initialize, this.onReady});
  final Future<void> Function() initialize;
  final VoidCallback? onReady;

  @override
  State<HiFiPlayerStartup> createState() => _HiFiPlayerStartupState();
}

class _HiFiPlayerStartupState extends State<HiFiPlayerStartup> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      await widget.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint('[Startup] 主界面首帧已完成');
          widget.onReady?.call();
        }
      });
    } catch (error, stack) {
      debugPrint('[Startup] $error\n$stack');
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) =>
      HiFiPlayerApp(isStarting: !_ready, startupError: _error);
}

class HiFiPlayerApp extends StatelessWidget {
  const HiFiPlayerApp({super.key, this.startupError, this.isStarting = false});

  final String? startupError;
  final bool isStarting;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MyHiFi Player',
        debugShowCheckedModeBanner: false,
        theme: HifiTheme.darkTheme,
        scrollBehavior: const MouseDraggableScrollBehavior(),
        home: startupError == null
            ? (isStarting
                ? const Scaffold(
                    body: Center(
                        child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('正在启动播放器',
                          style: TextStyle(color: Colors.white, fontSize: 18))
                    ],
                  )))
                : const IpadMainView())
            : Scaffold(
                body: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '播放器启动失败',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '请重新构建或检查原生音频库后再启动。错误详情：',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            startupError!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      );
}
