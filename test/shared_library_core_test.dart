import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/library_scan_policy.dart';
import 'package:hide_player_flutter/core/native_music_library.dart';

void main() {
  test('Pi scans the filesystem root, Android public roots exclude Download', () {
    expect(LibraryScanPolicy.roots(platform: 'pi', documents: ''), ['/']);
    expect(LibraryScanPolicy.androidPublicMusic.every((p) => p.contains('/Music')), isTrue);
    expect(LibraryScanPolicy.androidPublicMusic.any((p) => p.contains('/Download')), isFalse);
  });
  test('mobile Documents and WiFi roots share the same native scanner', () async {
    final root = Directory.systemTemp.createTempSync('shared-library-policy-');
    try {
      final docs = Directory('${root.path}/Documents')..createSync();
      final wifi = Directory('${root.path}/Documents/WiFi')..createSync();
      File('${wifi.path}/sample.wav').writeAsBytesSync([]);
      for (final platform in ['iphone', 'ipad', 'android']) {
        final roots = LibraryScanPolicy.roots(platform: platform, documents: docs.path, wifiDirectory: wifi.path, customPath: wifi.path);
        final result = await NativeMusicLibrary.scan(database: '${root.path}/$platform.db', roots: roots, documents: docs.path);
        expect(result['trackCount'], 1);
      }
    } finally { root.deleteSync(recursive: true); }
  });
  test('native SQL bindings retain Unicode values and rollback atomically', () {
    final root = Directory.systemTemp.createTempSync('shared-library-sql-');
    final db = NativeMusicLibrary.openDatabase('${root.path}/library.db');
    try {
      db.execute('CREATE TABLE example(value TEXT)');
      db.execute('INSERT INTO example VALUES (?)', ["歌曲'😀"]);
      db.execute('BEGIN IMMEDIATE');
      db.execute('DELETE FROM example');
      db.execute('ROLLBACK');
      expect(db.select('SELECT value FROM example').single['value'], "歌曲'😀");
    } finally { db.close(); root.deleteSync(recursive: true); }
  });
}
