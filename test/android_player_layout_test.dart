import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/sidebar_tab.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/theme/hifi_theme.dart';
import 'package:hide_player_flutter/ui/android/android_player_view.dart';
import 'package:hide_player_flutter/ui/iphone/iphone_landscape_view.dart';
import 'package:hide_player_flutter/ui/iphone/widgets/iphone_bottom_bar_widget.dart';
import 'package:hide_player_flutter/ui/mac/mac_sidebar_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final audio = HifiAudioService.instance;
  final library = MusicDatabaseService.instance;
  late List<Track> originalTracks;
  const tracks = [
    Track(
      id: 90001,
      title: 'Android first song',
      artist: 'First artist',
      album: 'Fixture album',
      filepath: '/test/android-first.flac',
      sampleRate: 0,
      bitDepth: 0,
      durationSec: 120,
    ),
    Track(
      id: 90002,
      title: 'Android second song',
      artist: 'Second artist',
      album: 'Fixture album',
      filepath: '/test/android-second.flac',
      sampleRate: 96000,
      bitDepth: 24,
      durationSec: 180,
    ),
  ];

  setUp(() {
    audio.stopTicker();
    audio.stop();
    audio.clearQueue();
    originalTracks = List.of(library.tracks);
    library.tracks
      ..clear()
      ..addAll(tracks);
  });

  tearDown(() {
    audio.stop();
    audio.clearQueue();
    library.tracks
      ..clear()
      ..addAll(originalTracks);
  });

  Future<void> mount(
    WidgetTester tester, {
    required Size size,
    required bool landscape,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: HifiTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: AndroidPlayerView(landscape: landscape),
    ));
    await tester.pump();
  }

  for (final config in [
    (const Size(393, 852), false, 1.0),
    (const Size(320, 480), false, 1.0),
    (const Size(852, 393), true, 1.0),
    (const Size(667, 375), true, 1.0),
    (const Size(320, 568), false, 2.0),
    (const Size(667, 375), true, 2.0),
  ]) {
    testWidgets('all player sections fit ${config.$1}, scale ${config.$3}',
        (tester) async {
      library.setSetting('active_sidebar_tab', '${SidebarTab.allMusic.index}');
      await mount(tester,
          size: config.$1, landscape: config.$2, textScale: config.$3);
      expect(tester.takeException(), isNull);
      if (config.$2) {
        expect(find.byType(IphoneLandscapeView), findsOneWidget);
        expect(find.byType(MacSidebarWidget), findsOneWidget);
        expect(find.byType(IphoneBottomBarWidget), findsOneWidget);
        for (final label in [
          '所有音乐',
          '均衡器',
          '调音魔棒',
          'DAC',
          '扫描音乐',
          '主题',
          '设置',
          'Web服务',
        ]) {
          final nav = find.descendant(
            of: find.byType(MacSidebarWidget),
            matching: find.text(label, skipOffstage: false),
            skipOffstage: false,
          );
          await tester.ensureVisible(nav);
          await tester.tap(nav);
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull,
              reason: '$label at ${config.$1}, scale ${config.$3}');
        }
      } else {
        for (final section in AndroidPlayerSection.values) {
          final navigation = find.byKey(Key('android-nav-${section.name}'));
          await tester.ensureVisible(navigation);
          await tester.tap(navigation);
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '${section.name} at ${config.$1}, scale ${config.$3}');
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('library item defines playback queue and skip follows it',
      (tester) async {
    await mount(tester, size: const Size(393, 852), landscape: false);
    await tester.tap(find.text('Android first song').first);
    await tester.pump();
    expect(audio.playlistQueue, tracks);
    expect(audio.currentTrack, tracks[0]);
    expect(audio.state.isPlaying, isTrue);
    expect(find.textContaining('规格待检测'), findsWidgets);
    expect(find.textContaining('0kHz / 0bit'), findsNothing);
    await tester.tap(find.byTooltip('下一曲'));
    await tester.pump();
    expect(audio.currentTrack, tracks[1]);
    await tester.tap(find.byKey(const Key('android-play-pause')));
    await tester.pump();
    expect(audio.state.isPlaying, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'tap right visualizer enters fullscreen theme and exit button returns to portrait',
      (tester) async {
    await mount(tester, size: const Size(393, 852), landscape: false);

    expect(find.byKey(const Key('android-portrait-layout')), findsOneWidget);
    expect(find.byKey(const Key('android-exit-fullscreen-theme')), findsNothing);

    final enterButton = find.byKey(const Key('android-enter-fullscreen-theme'));
    expect(enterButton, findsOneWidget);
    await tester.tap(enterButton);
    await tester.pump();

    expect(find.byKey(const Key('android-portrait-layout')), findsNothing);
    final exitButton = find.byKey(const Key('android-exit-fullscreen-theme'));
    expect(exitButton, findsOneWidget);

    await tester.tap(exitButton);
    await tester.pump();

    expect(find.byKey(const Key('android-portrait-layout')), findsOneWidget);
    expect(find.byKey(const Key('android-exit-fullscreen-theme')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
