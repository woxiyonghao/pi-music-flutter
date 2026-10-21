import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/track.dart';

const first = Track(
    id: 1,
    title: 'First',
    artist: '',
    album: '',
    filepath: '/mock/first.flac',
    durationSec: 100,
    format: AudioFormat.flac,
    sampleRate: 44100,
    bitDepth: 16);
const second = Track(
    id: 2,
    title: 'Second',
    artist: '',
    album: '',
    filepath: '/mock/second.flac',
    durationSec: 100,
    format: AudioFormat.flac,
    sampleRate: 44100,
    bitDepth: 16);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'file permission wait leaves the event loop free and respects pause and seek',
      () async {
    final permission = Completer<void>();
    final opened = <String>[];
    final audio = HifiAudioService.forTesting(
      prepareFile: (_) => permission.future,
      openFile: (path, start, end) {
        opened.add(path);
        return true;
      },
    );
    addTearDown(audio.dispose);
    final loading = audio.playTrack(first);
    expect(audio.isPreparingTrack, isTrue);
    await Future<void>.delayed(Duration.zero);
    audio.pause();
    audio.seek(12);
    expect(opened, isEmpty);
    permission.complete();
    await loading;
    expect(audio.isPreparingTrack, isFalse);
    expect(opened, [first.filepath]);
    expect(audio.state.isPaused, isTrue);
    expect(audio.state.currentTime, 12);
  });

  test('a newer track supersedes an older pending permission request',
      () async {
    final permissions = <String, Completer<void>>{};
    final opened = <String>[];
    final audio = HifiAudioService.forTesting(
      prepareFile: (path) => (permissions[path] = Completer<void>()).future,
      openFile: (path, start, end) {
        opened.add(path);
        return true;
      },
    );
    addTearDown(audio.dispose);
    final firstLoad = audio.playTrack(first);
    final secondLoad = audio.playTrack(second);
    permissions[second.filepath]!.complete();
    await secondLoad;
    permissions[first.filepath]!.complete();
    await firstLoad;
    expect(opened, [second.filepath]);
    expect(audio.currentTrack?.id, second.id);
  });

  test(
      'stop cancels pending playback without opening it after permission returns',
      () async {
    final permission = Completer<void>();
    final audio = HifiAudioService.forTesting(
      prepareFile: (_) => permission.future,
      openFile: (path, start, end) =>
          throw StateError('Cancelled playback must not open'),
    );
    addTearDown(audio.dispose);
    final loading = audio.playTrack(first);
    audio.stop();
    permission.complete();
    await loading;
    expect(audio.state.isPlaying, isFalse);
    expect(audio.isPreparingTrack, isFalse);
  });

  test('permission denial reports failure and keeps the player stopped',
      () async {
    final audio = HifiAudioService.forTesting(
      prepareFile: (_) async => throw StateError('Permission denied'),
      openFile: (path, start, end) => throw StateError('Unreadable files must not open'),
    );
    addTearDown(audio.dispose);
    await audio.playTrack(first);
    expect(audio.lastDebugLog, contains('FILE_OPEN_FAILED'));
    expect(audio.state.isPlaying, isFalse);
    expect(audio.isPreparingTrack, isFalse);
  });
}
