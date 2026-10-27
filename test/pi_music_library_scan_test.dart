import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/core/app_paths.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';

void main() {
  test('Pi scan policy starts at the filesystem root', () {
    expect(AppPaths.linuxMusicScanDirectories(home: '/home/pi'), ['/']);
  });
  test('Pi native scanner finds arbitrary and hidden directories without looping', () async {
    final root = Directory.systemTemp.createTempSync('pi-native-scan-');
    try {
      for(final path in ['opt/album/new.wav','.hidden/hidden.flac','boot/firmware/song.dsf']) {
        final file=File('${root.path}/$path');file.parent.createSync(recursive:true);file.writeAsBytesSync([]);
      }
      Link('${root.path}/opt/loop').createSync(root.path);
      final db=MusicDatabaseService.forTesting(databasePath:'${root.path}/library.db',scanDirectories:[root.path]);
      expect(await db.scanLibrary(),3);
      expect(db.tracks.map((t)=>t.title).toSet(), {'new','hidden','song'});
      File('${root.path}/added.wav').writeAsBytesSync([]);
      expect(await db.scanLibrary(),4);
      db.dispose();
    } finally { root.deleteSync(recursive:true); }
  });
}
