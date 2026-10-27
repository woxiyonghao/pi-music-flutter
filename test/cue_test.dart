import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/native_music_library.dart';

void main() {
  test('CUE parsing is owned by the shared C++ scanner', () async {
    final root = Directory.systemTemp.createTempSync('native-cue-');
    try {
      File('${root.path}/album.wav').writeAsBytesSync([]);
      File('${root.path}/album.cue').writeAsStringSync('FILE "album.wav" WAVE\nTRACK 01 AUDIO\nTITLE "First"\nINDEX 01 00:00:00\nTRACK 02 AUDIO\nTITLE "Second"\nINDEX 01 00:02:00\n');
      final result = await NativeMusicLibrary.scan(database: '${root.path}/library.db', roots: [root.path]);
      expect(result['trackCount'], 2);
      final db = NativeMusicLibrary.openDatabase('${root.path}/library.db');
      try { expect(db.select('SELECT title FROM scanned_tracks ORDER BY track_number').map((r)=>r['title']), ['First','Second']); }
      finally { db.close(); }
    } finally { root.deleteSync(recursive: true); }
  });
}
