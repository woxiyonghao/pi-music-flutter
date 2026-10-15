import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/ui/mac/views/mac_all_music_view.dart';

void main() {
  group('CUE Track and Split WAV Matching Tests', () {
    test('CUE split tracks sharing the same WAV filepath do NOT match each other', () {
      const cueTrack1 = Track(
        id: 1,
        title: '此情可待',
        artist: '阿强',
        album: '此情可待',
        filepath: '/Music/阿强 此情可待[WAV+CUE]/CDImage.wav',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitDepth: 16,
        durationSec: 241,
        isCueTrack: true,
        trackNumber: 1,
        startTimeSec: 0.0,
        endTimeSec: 241.0,
      );

      const cueTrack2 = Track(
        id: 2,
        title: '草帽歌',
        artist: '阿强',
        album: '此情可待',
        filepath: '/Music/阿强 此情可待[WAV+CUE]/CDImage.wav',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitDepth: 16,
        durationSec: 274,
        isCueTrack: true,
        trackNumber: 2,
        startTimeSec: 241.0,
        endTimeSec: 515.0,
      );

      const cueTrack3 = Track(
        id: 3,
        title: '女人花',
        artist: '阿强',
        album: '此情可待',
        filepath: '/Music/阿强 此情可待[WAV+CUE]/CDImage.wav',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitDepth: 16,
        durationSec: 239,
        isCueTrack: true,
        trackNumber: 3,
        startTimeSec: 515.0,
        endTimeSec: 754.0,
      );

      // 1. Even though filepath is identical, different CUE tracks must NOT match
      expect(cueTrack1.matches(cueTrack2), isFalse);
      expect(cueTrack1.matches(cueTrack3), isFalse);
      expect(cueTrack2.matches(cueTrack3), isFalse);

      // 2. operator == must be false for different tracks
      expect(cueTrack1 == cueTrack2, isFalse);
      expect(cueTrack2 == cueTrack3, isFalse);

      // 3. Track matches itself
      expect(cueTrack1.matches(cueTrack1), isTrue);
      expect(cueTrack1 == cueTrack1, isTrue);

      // 4. Same CUE track created independently with matching metadata matches
      const cueTrack1Duplicate = Track(
        id: 1,
        title: '此情可待',
        artist: '阿强',
        album: '此情可待',
        filepath: '/Music/阿强 此情可待[WAV+CUE]/CDImage.wav',
        format: AudioFormat.wav,
        sampleRate: 44100,
        bitDepth: 16,
        durationSec: 241,
        isCueTrack: true,
        trackNumber: 1,
        startTimeSec: 0.0,
        endTimeSec: 241.0,
      );
      expect(cueTrack1.matches(cueTrack1Duplicate), isTrue);
      expect(cueTrack1 == cueTrack1Duplicate, isTrue);
    });

    testWidgets('MacAllMusicView only marks the currently playing CUE track as active',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        HifiAudioService.instance.stopTicker();
        tester.view.resetPhysicalSize();
      });

      const cueTracks = [
        Track(
          id: 1,
          title: '此情可待',
          artist: '阿强',
          album: '此情可待',
          filepath: '/Music/阿强 此情可待[WAV+CUE]/CDImage.wav',
          format: AudioFormat.wav,
          sampleRate: 44100,
          bitDepth: 16,
          durationSec: 241,
          isCueTrack: true,
          trackNumber: 1,
          startTimeSec: 0.0,
          endTimeSec: 241.0,
        ),
        Track(
          id: 2,
          title: '草帽歌',
          artist: '阿强',
          album: '此情可待',
          filepath: '/Music/阿强 此情可待[WAV+CUE]/CDImage.wav',
          format: AudioFormat.wav,
          sampleRate: 44100,
          bitDepth: 16,
          durationSec: 274,
          isCueTrack: true,
          trackNumber: 2,
          startTimeSec: 241.0,
          endTimeSec: 515.0,
        ),
        Track(
          id: 3,
          title: '女人花',
          artist: '阿强',
          album: '此情可待',
          filepath: '/Music/阿强 此情可待[WAV+CUE]/CDImage.wav',
          format: AudioFormat.wav,
          sampleRate: 44100,
          bitDepth: 16,
          durationSec: 239,
          isCueTrack: true,
          trackNumber: 3,
          startTimeSec: 515.0,
          endTimeSec: 754.0,
        ),
      ];

      // Simulate playing track 1
      HifiAudioService.instance.playTrack(cueTracks[0], cueTracks, 0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MacAllMusicView(
              tracks: cueTracks,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only ONE equalizer icon must exist (for track 1)
      expect(find.byIcon(Icons.equalizer_rounded), findsOneWidget);

      // Track 2 and 3 must display their track index numbers ("02." and "03.")
      expect(find.text('02.'), findsOneWidget);
      expect(find.text('03.'), findsOneWidget);

      // Now switch to playing track 2
      HifiAudioService.instance.playTrack(cueTracks[1], cueTracks, 1);
      await tester.pumpAndSettle();

      // Still exactly ONE equalizer icon, now for track 2
      expect(find.byIcon(Icons.equalizer_rounded), findsOneWidget);
      expect(find.text('01.'), findsOneWidget);
      expect(find.text('03.'), findsOneWidget);

      HifiAudioService.instance.stopTicker();
      HifiAudioService.instance.dispose();
    });
  });
}
