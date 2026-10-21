import 'dart:io';
import 'package:flutter/material.dart';
import 'core/app_paths.dart';
import 'core/hifi_audio_bindings.dart';
import 'platform/platform_audio_runtime.dart';
import 'services/music_database_service.dart';
import 'services/web_remote_service.dart';
import 'theme/hifi_theme.dart';
import 'theme/ui_config.dart';
import 'ui/window/window_main_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();
  await PlatformAudioRuntime.instance.configure();
  if (!HifiAudioBindings.instance.init()) {
    throw StateError(
        'audio_engine initialization failed: ${HifiAudioBindings.instance.loadError}');
  }
  MusicDatabaseService.instance.loadLibrary();
  runApp(const HiFiPlayerApp());
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    WebRemoteService.instance.start(port: 8088);
  }
}

class HiFiPlayerApp extends StatelessWidget {
  const HiFiPlayerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MyHiFi Player',
        debugShowCheckedModeBanner: false,
        theme: HifiTheme.darkTheme,
        scrollBehavior: const MouseDraggableScrollBehavior(),
        home: const WindowMainView(),
      );
}
