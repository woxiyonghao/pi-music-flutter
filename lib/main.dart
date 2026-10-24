import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'core/app_paths.dart';
import 'core/hifi_audio_bindings.dart';
import 'platform/platform_audio_runtime.dart';
import 'services/dac_setting_service.dart';
import 'services/music_database_service.dart';
import 'services/web_remote_service.dart';
import 'theme/hifi_theme.dart';
import 'theme/ui_config.dart';
import 'ui/iphone/iphone_main_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The orientation choice is the first Flutter frame, before plugin or disk IO.
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
  DacSettingService.instance;
  MusicDatabaseService.instance.loadLibrary();
}

void startPlayerServices() {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  unawaited(() async {
    try {
      await PlatformAudioRuntime.instance.prepareBackgroundStorage();
    } catch (error) {
      debugPrint('[Startup] 后台文件保护设置失败: $error');
    }
  }());
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
        library: 'HiFi Player background startup',
      ));
    }
  }());
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
        home: IphoneMainView(initialize: initialize, onReady: onReady),
      );
}
