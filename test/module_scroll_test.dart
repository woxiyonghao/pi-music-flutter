import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/core/platform_helper.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/platform/platform_audio_runtime.dart';
import 'package:hide_player_flutter/services/dac_setting_service.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/common/module_scroll_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_dac_setting_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_equalizer_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_magic_tuning_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_scan_music_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_system_settings_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_theme_setting_view.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_web_service_view.dart';
import 'package:hide_player_flutter/ui/visualizers/visualizer_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/module-scroll-route');
  late PlatformAudioRuntime runtime;
  late DacSettingService dac;

  setUp(() async {
    HifiAudioService.instance.stopTicker();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getOutputFormat') {
        return {
          'id': 'usb-dx1',
          'name': 'TOPPING DX1 II',
          'transport': 'USB',
          'sampleRate': 48000,
        };
      }
      return null;
    });
    runtime =
        PlatformAudioRuntime.forTesting(channel: channel, reportOutput: (_) {});
    await runtime.refreshOutput();
    dac = DacSettingService.forTesting(
      runtime: runtime,
      readDevices: () => '[]',
      selectOutput: (_) => false,
      followsSystemOutput: true,
    );
    final db = MusicDatabaseService.instance;
    db.tracks.clear();
    for (var index = 0; index < 6; index++) {
      db.tracks.add(Track(
        id: index + 1,
        title: 'Track $index',
        artist: 'Artist',
        album: 'Album',
        filepath: '/test/track-$index',
        format: AudioFormat.values[index + 1],
        sampleRate: 48000,
        bitDepth: 24,
        durationSec: 60,
      ));
    }
  });

  tearDown(() {
    dac.dispose();
    runtime.dispose();
    MusicDatabaseService.instance.tracks.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final platform in [HifiPlatformType.mac, HifiPlatformType.pi]) {
    testWidgets('$platform retains its fixed module heading', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: SizedBox(
            width: 800,
            height: 300,
            child: ModuleScrollView(
              storageId: 'legacy-platform-module',
              platform: platform,
              header: const [Text('Fixed heading')],
              children: [
                for (var i = 0; i < 30; i++)
                  SizedBox(height: 60, child: Text('Control $i'))
              ],
            )),
      )));
      final headingTop = tester.getTopLeft(find.text('Fixed heading')).dy;
      final control = find.text('Control 0', skipOffstage: false);
      final controlTop = tester.getTopLeft(control).dy;
      await tester.timedDrag(
          control, const Offset(0, -90), const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getTopLeft(find.text('Fixed heading')).dy, headingTop);
      expect(tester.getTopLeft(control).dy, lessThan(controlTop - 40));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final size in [
    const Size(667, 375),
    const Size(844, 390),
    const Size(932, 430)
  ]) {
    for (final module in [
      'dac',
      'eq',
      'mseb',
      'scan',
      'settings',
      'web',
      'wifi',
      'theme'
    ]) {
      testWidgets('$module title and actions scroll together at $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Widget page;
        late String title;
        Finder? action;
        switch (module) {
          case 'dac':
            page = MacDACSettingView(
                platform: HifiPlatformType.iphone, service: dac);
            title = '发烧 DAC 物理硬件与解码设置';
            action = find.byTooltip('重新探测已连接的音频设备', skipOffstage: false);
          case 'eq':
            page = const MacEqualizerView();
            title = '图形均衡器';
            action = find.text('复原', skipOffstage: false);
          case 'mseb':
            page = const MacMagicTuningView();
            title = '调音魔棒';
            action = find.text('一键全复位', skipOffstage: false);
          case 'scan':
            page = const MacScanMusicView();
            title = '选择';
            action = find.text('重新扫描', skipOffstage: false);
          case 'settings':
            page =
                const MacSystemSettingsView(platform: HifiPlatformType.iphone);
            title = '系统设置';
          case 'web':
          case 'wifi':
            page = MacWebServiceView(
                platform: HifiPlatformType.iphone,
                isWifiTransfer: module == 'wifi');
            title = 'Web 服务';
            action = find.text('WiFi 局域网传歌', skipOffstage: false);
          case 'theme':
            page = MacThemeSettingView(
                currentVisualizer: VisualizerType.ledSpectrum,
                onVisualizerChanged: (_) {});
            title = '主题';
            action = find.text('恢复名机预设', skipOffstage: false);
        }
        // Match the workspace's remaining area after its sidebar, safe area and player.
        await tester.pumpWidget(MaterialApp(
          theme: HifiTheme.darkTheme,
          home: Scaffold(
              body: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
                width: size.width - 240,
                height: size.height - 120,
                child: page),
          )),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: '$module initial layout');
        final heading = find.text(title, skipOffstage: false).first;
        final headingTop = tester.getTopLeft(heading).dy;
        final actionTop = action == null ? null : tester.getTopLeft(action).dy;
        final device = module == 'dac'
            ? find.text('TOPPING DX1 II', skipOffstage: false).first
            : null;
        final deviceTop = device == null ? null : tester.getTopLeft(device).dy;

        await tester.timedDrag(
            heading, const Offset(0, -90), const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 50));
        final movement = tester.getTopLeft(heading).dy - headingTop;
        expect(movement, lessThan(-40),
            reason: '$module header must leave its original position');
        if (action != null) {
          expect(
              tester.getTopLeft(action).dy - actionTop!, closeTo(movement, 1),
              reason: '$module actions must share the header scroll position');
        }
        if (device != null) {
          expect(
              tester.getTopLeft(device).dy - deviceTop!, closeTo(movement, 1),
              reason: 'DAC device tabs must move with the whole module');
        }
        expect(tester.takeException(), isNull,
            reason: '$module after dragging');
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
