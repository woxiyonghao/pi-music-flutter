import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_paths.dart';
import 'core/hifi_audio_bindings.dart';
import 'platform/platform_audio_runtime.dart';
import 'services/music_database_service.dart';
import 'services/web_remote_service.dart';
import 'theme/hifi_theme.dart';
import 'theme/ui_config.dart';
import 'ui/ipad/ipad_main_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppPaths.init();
    await PlatformAudioRuntime.instance.configure();
    if (!HifiAudioBindings.instance.init()) {
      throw StateError(
          'audio_engine initialization failed: ${HifiAudioBindings.instance.loadError}');
    }
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    MusicDatabaseService.instance.loadLibrary();
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'HiFi Player startup',
    ));
    runApp(HiFiPlayerApp(startupError: error.toString()));
    return;
  }
  runApp(const HiFiPlayerApp());
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    WebRemoteService.instance.start(port: 8088);
  }
}

class HiFiPlayerApp extends StatelessWidget {
  const HiFiPlayerApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MyHiFi Player',
        debugShowCheckedModeBanner: false,
        theme: HifiTheme.darkTheme,
        scrollBehavior: const MouseDraggableScrollBehavior(),
        home: startupError == null
            ? const IpadMainView()
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
