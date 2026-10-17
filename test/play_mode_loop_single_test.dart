import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/hifi_audio_service.dart';
import 'package:hide_player_flutter/models/track.dart';
import 'package:hide_player_flutter/models/playback_state.dart';
import 'package:hide_player_flutter/services/web_remote_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final track1 = Track(
    id: 1,
    title: '海阔天空',
    artist: 'Beyond',
    album: 'Words & Music',
    filepath: '/mock/music/beyond.flac',
    durationSec: 324,
    format: AudioFormat.flac,
    sampleRate: 44100,
    bitDepth: 16,
  );

  final track2 = Track(
    id: 2,
    title: '光辉岁月',
    artist: 'Beyond',
    album: 'Words & Music',
    filepath: '/mock/music/glory.flac',
    durationSec: 300,
    format: AudioFormat.flac,
    sampleRate: 44100,
    bitDepth: 16,
  );

  group('PlayMode.loopSingle Tests', () {
    test('setPlayMode and cyclePlayMode properly switch modes', () {
      final service = HifiAudioService.instance;
      
      service.setPlayMode(PlayMode.loopList);
      expect(service.playMode, PlayMode.loopList);
      expect(service.state.playMode, PlayMode.loopList);

      service.setPlayMode(PlayMode.loopSingle);
      expect(service.playMode, PlayMode.loopSingle);
      expect(service.state.playMode, PlayMode.loopSingle);

      service.cyclePlayMode();
      expect(service.playMode, PlayMode.shuffle);

      service.cyclePlayMode();
      expect(service.playMode, PlayMode.sequence);

      service.cyclePlayMode();
      expect(service.playMode, PlayMode.loopList);

      service.cyclePlayMode();
      expect(service.playMode, PlayMode.loopSingle);
    });

    test('next(isAutomatic: true) replays current track when in loopSingle mode', () {
      final service = HifiAudioService.instance;
      service.playTracks([track1, track2], 0);

      expect(service.currentTrack?.id, 1);
      expect(service.currentIndex, 0);

      service.setPlayMode(PlayMode.loopSingle);

      // 模拟曲目播放自然完毕 (isAutomatic: true)
      service.next(isAutomatic: true);

      // 验证单曲循环模式下依然播放 track1，不会跳到 track2 也不会停播
      expect(service.currentTrack?.id, 1);
      expect(service.currentIndex, 0);
      expect(service.state.isPlaying, true);
    });

    test('next(isAutomatic: false) advances to next track even in loopSingle mode', () {
      final service = HifiAudioService.instance;
      service.playTracks([track1, track2], 0);
      service.setPlayMode(PlayMode.loopSingle);

      // 用户手动点击下一曲
      service.next(isAutomatic: false);

      // 手动下一曲应允许切歌到 track2
      expect(service.currentTrack?.id, 2);
      expect(service.currentIndex, 1);
      expect(service.state.isPlaying, true);

      // track2 自然播完后应继续单曲循环 track2
      service.next(isAutomatic: true);
      expect(service.currentTrack?.id, 2);
      expect(service.currentIndex, 1);
    });

    test('WebRemoteService HTTP API /api/mode switches and reports mode properly', () async {
      const port = 19088;
      final web = WebRemoteService.instance;
      await web.stop();
      final ok = await web.start(port: port);
      expect(ok, isTrue);

      final client = HttpClient();
      try {
        // 1. 设置单曲循环模式
        final req1 = await client.getUrl(Uri.parse('http://127.0.0.1:$port/api/mode?mode=single'));
        final resp1 = await req1.close();
        expect(resp1.statusCode, HttpStatus.ok);

        final reqStatus1 = await client.getUrl(Uri.parse('http://127.0.0.1:$port/api/status'));
        final respStatus1 = await reqStatus1.close();
        final body1 = await respStatus1.transform(utf8.decoder).join();
        final json1 = jsonDecode(body1) as Map<String, dynamic>;
        expect(json1['mode'], 'single');
        expect(HifiAudioService.instance.playMode, PlayMode.loopSingle);

        // 2. 切换到列表循环模式
        final req2 = await client.getUrl(Uri.parse('http://127.0.0.1:$port/api/mode?mode=list'));
        final resp2 = await req2.close();
        expect(resp2.statusCode, HttpStatus.ok);

        final reqStatus2 = await client.getUrl(Uri.parse('http://127.0.0.1:$port/api/status'));
        final respStatus2 = await reqStatus2.close();
        final body2 = await respStatus2.transform(utf8.decoder).join();
        final json2 = jsonDecode(body2) as Map<String, dynamic>;
        expect(json2['mode'], 'list');
        expect(HifiAudioService.instance.playMode, PlayMode.loopList);
      } finally {
        client.close();
        await web.stop();
      }
    });
  });
}
