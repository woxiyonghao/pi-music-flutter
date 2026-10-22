import 'dart:io';
import 'package:flutter/material.dart';
import 'core/app_paths.dart';
import 'core/hifi_audio_bindings.dart';
import 'platform/platform_audio_runtime.dart';
import 'services/music_database_service.dart';
import 'services/web_remote_service.dart';
import 'theme/hifi_theme.dart';
import 'theme/ui_config.dart';
import 'ui/mac/mac_main_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppPaths.init();
    await PlatformAudioRuntime.instance.configure();
    if (!HifiAudioBindings.instance.init()) {
      throw StateError(
          'audio_engine initialization failed: ${HifiAudioBindings.instance.loadError}');
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
            ? const MacMainView()
            : Scaffold(
                body: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('播放器启动失败', style: TextStyle(fontSize: 24)),
                          const SizedBox(height: 16),
                          const Text('请重新构建应用后再启动。错误详情：'),
                          const SizedBox(height: 12),
                          SelectableText(startupError!),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      );
}
