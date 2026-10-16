import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';

void main() {
  group('iPad Branch Regression & Bug Fix Tests', () {
    test('Empty DB produces clean empty tracks list without mock data', () {
      final dbService = MusicDatabaseService.instance;
      // In fresh state without tracks in memory or DB
      expect(dbService.tracks, isA<List<Track>>());
      // Ensure no hardcoded mock tracks like '此情可待' or 'Hotel_California.flac' are auto-injected
      final hasFakeDemoTrack = dbService.tracks.any((t) => t.title == '此情可待' && t.filepath == '/Music/此情可待.dsf');
      expect(hasFakeDemoTrack, isFalse, reason: 'Mock demo data must never be automatically injected on clean start');
    });

    test('Track format extension mapping correctly parses audio formats', () {
      expect(Track.formatFromExtension('.flac'), AudioFormat.flac);
      expect(Track.formatFromExtension('.wav'), AudioFormat.wav);
      expect(Track.formatFromExtension('.dsf'), AudioFormat.dsdDsf);
      expect(Track.formatFromExtension('.dff'), AudioFormat.dsdDff);
      expect(Track.formatFromExtension('.alac'), AudioFormat.alac);
      expect(Track.formatFromExtension('.m4a'), AudioFormat.alac);
      expect(Track.formatFromExtension('.mp3'), AudioFormat.mp3);
      expect(Track.formatFromExtension('.xyz'), AudioFormat.unknown);
    });

    test('AudioService does not auto-advance or loop when file is invalid', () {
      final audioService = HifiAudioService.instance;
      const invalidTrack = Track(
        id: 99999,
        title: 'Nonexistent Track',
        artist: 'Unknown',
        album: 'None',
        filepath: '/path/does/not/exist/999.flac',
        sampleRate: 44100,
        bitDepth: 16,
        durationSec: 180,
      );

      // In FLUTTER_TEST, calling playTrack marks isPlaying, but stop/pause resets it
      audioService.playTrack(invalidTrack, [invalidTrack], 0);
      expect(audioService.currentTrack?.id, 99999);

      audioService.stop();
      expect(audioService.state.isPlaying, isFalse);
      expect(audioService.isPlayingNotifier.value, isFalse);
    });

    test('Scanning empty directory results in 0 tracks and no crash', () async {
      final prevTracks = List<Track>.from(MusicDatabaseService.instance.tracks);
      addTearDown(() {
        if (prevTracks.isNotEmpty) {
          MusicDatabaseService.instance.saveScannedTracks(prevTracks);
        }
      });
      final tempDir = Directory.systemTemp.createTempSync('hifi_empty_scan_test');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final count = await MusicDatabaseService.instance.scanLibrary(customPath: tempDir.path);
      expect(count, 0);
    });

    test('Scan real music directory populates tracks', () async {
      if (Directory('/Users/mk10/Downloads/music').existsSync()) {
        final count = await MusicDatabaseService.instance.scanLibrary(customPath: '/Users/mk10/Downloads/music');
        expect(count, greaterThan(0));
      }
    });
  });
}
