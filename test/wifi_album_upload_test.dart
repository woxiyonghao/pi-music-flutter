import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:hide_player_flutter/services/wifi_transfer_service.dart';

void main() {
  final wifi = WifiTransferService.instance;
  late Directory temp;
  late HttpClient client;

  setUp(() async {
    await wifi.stop();
    wifi.clearTransferHistory();
    temp = Directory.systemTemp.createTempSync('hifi_wifi_album_');
    MusicDatabaseService.instance.customDatabasePathForTesting =
        '${temp.path}/private/library.db';
    client = HttpClient();
    expect(await wifi.start(port: 0, targetDir: temp.path), isTrue);
  });
  tearDown(() async {
    client.close(force: true);
    await wifi.stop();
    MusicDatabaseService.instance.customDatabasePathForTesting = null;
    temp.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> upload(String filename, List<int> data) async {
    final uri = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: wifi.port,
        path: '/upload',
        queryParameters: {'filename': filename});
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.binary;
    request.add(data);
    return request.close();
  }

  test(
      'directory uploads retain distinct albums, CUE paths and literal percent names',
      () async {
    final paths = [
      'Album A/CDImage.wav',
      'Album A/disc.cue',
      'Album B/CDImage.wav',
      '100%25 Song.wav'
    ];
    for (var i = 0; i < paths.length; i++) {
      final response = await upload(paths[i], utf8.encode('content $i'));
      expect(response.statusCode, 200);
      await response.drain<void>();
      expect(File('${temp.path}/${paths[i]}').readAsStringSync(), 'content $i');
    }
    expect(wifi.completedCount, 4);
    expect(File('${temp.path}/Album A_CDImage.wav').existsSync(), isFalse);
  });

  test('empty uploads and traversal preserve the existing source file',
      () async {
    final existing = File('${temp.path}/keep.wav')
      ..writeAsStringSync('original');
    final empty = await upload('keep.wav', []);
    expect(empty.statusCode, 400);
    await empty.drain<void>();
    expect(existing.readAsStringSync(), 'original');
    final invalid = await upload('../escape.wav', [1]);
    expect(invalid.statusCode, 400);
    await invalid.drain<void>();
    expect(wifi.completedCount, 0);
    expect(
        temp
            .listSync(recursive: true)
            .whereType<File>()
            .any((f) => f.path.endsWith('.part')),
        isFalse);
  });

  test('uploads cannot overwrite the private music database or follow symlinks',
      () async {
    final dbFile = File('${temp.path}/hifi_player/library.db')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('private database');
    final database = await upload('hifi_player/library.db', [1, 2, 3]);
    expect(database.statusCode, 400);
    await database.drain<void>();
    expect(dbFile.readAsStringSync(), 'private database');
    final outside = Directory('${temp.path}_outside')..createSync();
    addTearDown(() => outside.deleteSync(recursive: true));
    Link('${temp.path}/escaped').createSync(outside.path);
    final symlink = await upload('escaped/song.wav', [1, 2, 3]);
    expect(symlink.statusCode, 500);
    await symlink.drain<void>();
    expect(File('${outside.path}/song.wav').existsSync(), isFalse);
  });

  test('a failed index reports saved bytes without destroying the upload',
      () async {
    MusicDatabaseService.instance.customDatabasePathForTesting = temp.path;
    final response = await upload('saved.wav', [1, 2, 3]);
    expect(response.statusCode, 200);
    final result = jsonDecode(await response.transform(utf8.decoder).join())
        as Map<String, dynamic>;
    expect(result['indexed'], isFalse);
    expect(result['scan_error'], isNotEmpty);
    expect(File('${temp.path}/saved.wav').readAsBytesSync(), [1, 2, 3]);
  });

  test('folder upload page exposes CUE and folder selection', () async {
    final request =
        await client.getUrl(Uri.parse('http://127.0.0.1:${wifi.port}/'));
    final response = await request.close();
    final html = await response.transform(utf8.decoder).join();
    expect(html, contains('webkitdirectory'));
    expect(html, contains('.cue'));
    expect(html, contains('webkitRelativePath'));
  });

  test('upload path normalization blocks absolute paths and traversal', () {
    expect(WifiTransferService.normalizeUploadPath(r'Album\Disc 1\CDImage.wav'),
        'Album/Disc 1/CDImage.wav');
    expect(
        WifiTransferService.normalizeUploadPath('/private/song.wav'), isNull);
    expect(
        WifiTransferService.normalizeUploadPath(r'C:\Music\song.wav'), isNull);
    expect(
        WifiTransferService.normalizeUploadPath('Album/../song.wav'), isNull);
    expect(
        WifiTransferService.normalizeUploadPath('Album/ .. /song.wav'), isNull);
  });
}
