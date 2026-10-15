import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/services/web_remote_service.dart';
import 'package:hide_player_flutter/services/wifi_transfer_service.dart';

void main() {
  group('WebRemoteService Live Network Tests', () {
    const testPort = 18088;
    final web = WebRemoteService.instance;

    setUp(() async {
      await web.stop();
    });

    tearDown(() async {
      await web.stop();
    });

    test('starts and binds successfully on test port', () async {
      final ok = await web.start(port: testPort);
      expect(ok, isTrue);
      expect(web.isRunning, isTrue);
      expect(web.port, testPort);
      expect(web.localIp, isNotEmpty);
    });

    test('serves Web Remote SPA HTML on GET /', () async {
      await web.start(port: testPort);
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/'));
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.ok);
      expect(resp.headers.contentType?.mimeType, 'text/html');

      final body = await resp.transform(utf8.decoder).join();
      expect(body, contains('<!DOCTYPE html>'));
      expect(body, contains('PiHiFi 发烧纯音远程中枢'));
      expect(body, contains('id="trackTitle"'));
      expect(body, contains('id="vinylDisc"'));
      client.close();
    });

    test('returns status JSON on GET /api/status', () async {
      await web.start(port: testPort);
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/api/status'));
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.ok);
      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      expect(json['type'], 'state');
      expect(json.containsKey('is_playing'), isTrue);
      expect(json.containsKey('current_time'), isTrue);
      expect(json.containsKey('spectrum'), isTrue);
      client.close();
    });

    test('establishes WebSocket connection and handles commands', () async {
      await web.start(port: testPort);
      final ws = await WebSocket.connect('ws://127.0.0.1:$testPort/ws');
      expect(ws.readyState, WebSocket.open);

      final receivedPackets = <Map<String, dynamic>>[];
      final sub = ws.listen((data) {
        if (data is String) {
          try {
            receivedPackets.add(jsonDecode(data) as Map<String, dynamic>);
          } catch (_) {}
        }
      });

      // Wait a moment to receive initial burst
      await Future.delayed(const Duration(milliseconds: 150));
      expect(receivedPackets.any((p) => p['type'] == 'state'), isTrue);
      expect(receivedPackets.any((p) => p['type'] == 'library'), isTrue);
      expect(web.clientCount, greaterThanOrEqualTo(1));

      // Send a command through WebSocket
      ws.add(jsonEncode({'action': 'pause'}));
      await Future.delayed(const Duration(milliseconds: 50));

      await sub.cancel();
      await ws.close();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(web.clientCount, 0);
    });
  });

  group('WifiTransferService Live Network Tests', () {
    const testPort = 18080;
    final wifi = WifiTransferService.instance;
    late Directory tempMusicDir;

    setUp(() async {
      await wifi.stop();
      tempMusicDir = Directory.systemTemp.createTempSync('hifi_wifi_test_');
    });

    tearDown(() async {
      await wifi.stop();
      if (tempMusicDir.existsSync()) {
        try {
          tempMusicDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('starts and binds successfully on test port', () async {
      final ok = await wifi.start(port: testPort, targetDir: tempMusicDir.path);
      expect(ok, isTrue);
      expect(wifi.isRunning, isTrue);
      expect(wifi.port, testPort);
      expect(wifi.targetDir, tempMusicDir.path);
    });

    test('serves drag-and-drop HTML on GET /', () async {
      await wifi.start(port: testPort, targetDir: tempMusicDir.path);
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$testPort/'));
      final resp = await req.close();

      expect(resp.statusCode, HttpStatus.ok);
      expect(resp.headers.contentType?.mimeType, 'text/html');

      final body = await resp.transform(utf8.decoder).join();
      expect(body, contains('PiHiFi 无线传歌中枢'));
      expect(body, contains('dropZone'));
      client.close();
    });

    test('handles file upload via POST /upload?filename=...', () async {
      await wifi.start(port: testPort, targetDir: tempMusicDir.path);
      final client = HttpClient();

      const testFilename = 'test_song.flac';
      final dummyAudioBytes = utf8.encode('fLaC_dummy_audio_binary_data_stream_for_testing_123456');

      final req = await client.postUrl(
        Uri.parse('http://127.0.0.1:$testPort/upload?filename=$testFilename'),
      );
      req.headers.contentType = ContentType.binary;
      req.headers.contentLength = dummyAudioBytes.length;
      req.add(dummyAudioBytes);

      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.ok);

      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['status'], 'ok');
      expect(json['filename'], testFilename);
      expect(json['bytes'], dummyAudioBytes.length);

      // Verify file was written to disk in target music directory
      final savedFile = File('${tempMusicDir.path}/$testFilename');
      expect(savedFile.existsSync(), isTrue);
      expect(savedFile.lengthSync(), dummyAudioBytes.length);

      // Verify transfer history recorded
      expect(wifi.completedCount, 1);
      expect(wifi.uploadedFiles.first.name, testFilename);
      expect(wifi.uploadedFiles.first.sizeBytes, dummyAudioBytes.length);

      client.close();
    });
  });
}
