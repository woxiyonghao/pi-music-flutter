import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_all_music_view.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HifiAudioService.instance.stopTicker();
  });

  tearDownAll(() {
    HifiAudioService.instance.stopTicker();
    HifiAudioService.instance.dispose();
  });

  group('MacAllMusicView Queue Continuation Tests', () {
    final testTracks = [
      const Track(
        id: 101,
        title: 'FLAC Song 1',
        artist: 'Artist A',
        album: 'Album A',
        filepath: '/Music/song1.flac',
        format: AudioFormat.flac,
        sampleRate: 96000,
        bitDepth: 24,
        durationSec: 180,
      ),
      const Track(
        id: 102,
        title: 'FLAC Song 2',
        artist: 'Artist A',
        album: 'Album A',
        filepath: '/Music/song2.flac',
        format: AudioFormat.flac,
        sampleRate: 96000,
        bitDepth: 24,
        durationSec: 200,
      ),
      const Track(
        id: 201,
        title: 'WAV Song 1',
        artist: 'Artist B',
        album: 'Album B',
        filepath: '/Music/song3.wav',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitDepth: 16,
        durationSec: 240,
      ),
      const Track(
        id: 202,
        title: 'WAV Song 2',
        artist: 'Artist B',
        album: 'Album B',
        filepath: '/Music/song4.wav',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitDepth: 16,
        durationSec: 260,
      ),
    ];

    testWidgets('Clicking FLAC song 2 queues all tracks and next() proceeds to WAV song 1', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MacAllMusicView(tracks: testTracks),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap "FLAC Song 2"
      final flac2Item = find.text('FLAC Song 2');
      expect(flac2Item, findsOneWidget);
      await tester.tap(flac2Item);
      await tester.pumpAndSettle();

      final service = HifiAudioService.instance;
      // Active track is FLAC Song 2
      expect(service.currentTrack?.title, 'FLAC Song 2');
      // Queue must contain all 4 tracks, not just the 2 FLAC tracks!
      expect(service.playlistQueue.length, 4);
      expect(service.playlistQueue.map((t) => t.title).toList(), [
        'FLAC Song 1',
        'FLAC Song 2',
        'WAV Song 1',
        'WAV Song 2',
      ]);

      // Calling next() advances to WAV Song 1!
      service.next();
      await tester.pumpAndSettle();
      expect(service.currentTrack?.title, 'WAV Song 1');

      // Calling next() again advances to WAV Song 2
      service.next();
      await tester.pumpAndSettle();
      expect(service.currentTrack?.title, 'WAV Song 2');

      // Calling next() wraps around to FLAC Song 1
      service.next();
      await tester.pumpAndSettle();
      expect(service.currentTrack?.title, 'FLAC Song 1');
    });
  });
}
