import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/services/theme_service.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_scan_music_view.dart';
import 'package:hide_player_flutter/ui/mac/widgets/mac_music_item_widget.dart';

void main() {
  const testTrack1 = Track(
    id: 101,
    title: '从开始到现在',
    artist: '阿强',
    album: '此情可待',
    filepath: '/Music/从开始到现在.wav',
    format: AudioFormat.wav,
    sampleRate: 44100,
    bitDepth: 16,
    durationSec: 275,
  );

  const testTrack2 = Track(
    id: 102,
    title: '爱上你等于爱上寂寞',
    artist: '阿强',
    album: '此情可待',
    filepath: '/Music/爱上你等于爱上寂寞.wav',
    format: AudioFormat.wav,
    sampleRate: 44100,
    bitDepth: 16,
    durationSec: 290,
  );

  setUp(() {
    MusicDatabaseService.instance.loadFallbackDemoTracksForTesting();
  });

  tearDown(() {
    HifiAudioService.instance.pause();
  });

  testWidgets('MacMusicItemWidget automatically spins when current track plays without hover',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              MacMusicItemWidget(
                track: testTrack1,
                onTap: () {},
              ),
              MacMusicItemWidget(
                track: testTrack2,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. Initial state: No track playing
    // Text color should not be accent color
    final accent = ThemeService.instance.accentColor;
    final track1TextFinder = find.text('从开始到现在');
    final Text initialText = tester.widget(track1TextFinder);
    expect(initialText.style?.color, isNot(accent));

    // 2. Play testTrack1 via HifiAudioService
    HifiAudioService.instance.playTrack(testTrack1, [testTrack1, testTrack2], 0);
    await tester.pump(const Duration(milliseconds: 50));

    // Title should now immediately turn into accent color
    final Text playingText = tester.widget(track1TextFinder);
    expect(playingText.style?.color, accent,
        reason: 'Current playing track title must turn accent color without hover');

    // testTrack2 should not be accent color
    final Text track2Text = tester.widget(find.text('爱上你等于爱上寂寞'));
    expect(track2Text.style?.color, isNot(accent));

    // 3. Switch to testTrack2 via audio service (simulating auto next or remote control)
    HifiAudioService.instance.playTrack(testTrack2, [testTrack1, testTrack2], 1);
    await tester.pump(const Duration(milliseconds: 50));

    final Text track1Updated = tester.widget(track1TextFinder);
    expect(track1Updated.style?.color, isNot(accent),
        reason: 'Old track must reset styling when song changes');

    final Text track2Updated = tester.widget(find.text('爱上你等于爱上寂寞'));
    expect(track2Updated.style?.color, accent,
        reason: 'New track must turn accent color when played');

    // 4. Pause playback
    HifiAudioService.instance.pause();
    await tester.pump(const Duration(milliseconds: 50));

    final Text track2Paused = tester.widget(find.text('爱上你等于爱上寂寞'));
    expect(track2Paused.style?.color, isNot(accent),
        reason: 'Paused track should reset active play styling');
  });

  testWidgets('MacScanMusicView inside IndexedStack immediately responds to playback without tab switch',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IndexedStack(
            index: 0,
            children: [
              MacScanMusicView(),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Find the first track in MacScanMusicView
    final firstTrackFinder = find.text('decaud-goldberg-var5-dsd128');
    expect(firstTrackFinder, findsOneWidget);

    final accent = ThemeService.instance.accentColor;
    final Text initialText = tester.widget(firstTrackFinder);
    expect(initialText.style?.color, isNot(accent));

    // Click to play this track
    await tester.tap(firstTrackFinder);
    await tester.pump(const Duration(milliseconds: 100));

    // Must be playing and highlighted in accent color immediately, WITHOUT tab switch!
    final Text playingText = tester.widget(firstTrackFinder);
    expect(playingText.style?.color, accent,
        reason: 'Track must immediately highlight in accent color upon play without tab switch');
  });
}

