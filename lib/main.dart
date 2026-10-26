import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'core/app_paths.dart';
import 'core/hifi_audio_bindings.dart';
import 'core/hifi_audio_service.dart';
import 'platform/platform_audio_runtime.dart';
import 'services/mseb_service.dart';
import 'services/music_database_service.dart';
import 'services/web_remote_service.dart';
import 'theme/hifi_theme.dart';
import 'theme/ui_config.dart';
import 'ui/android/android_main_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Show the orientation choice before disk, plugin or engine initialization.
  runApp(const HiFiPlayerApp(
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
  MusicDatabaseService.instance.loadLibrary();
  MsebService.instance.reloadFromDatabase();
  HifiAudioService.instance.reloadEqSettings();
}

void startPlayerServices() {
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    unawaited(WebRemoteService.instance.start(port: 8088));
  }
}

class HiFiPlayerApp extends StatelessWidget {
  const HiFiPlayerApp({super.key, this.initialize, this.onReady});

  final Future<void> Function()? initialize;
  final VoidCallback? onReady;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MyHiFi Player',
        debugShowCheckedModeBanner: false,
        theme: HifiTheme.darkTheme,
        scrollBehavior: const MouseDraggableScrollBehavior(),
        home: AndroidMainView(initialize: initialize, onReady: onReady),
      );
}
