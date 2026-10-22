import 'package:flutter_test/flutter_test.dart';
import 'package:hide_player_flutter/services/music_database_service.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
      'removes the old fullscreen theme without changing theme or idle settings',
      () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    MusicDatabaseService.initializeSettings(db);
    for (final entry in {
      'setting_idle_screensaver_theme': '3',
      'bg_visual_mode': '1',
      'theme_id': '1',
      'setting_idle_fullscreen': '0',
    }.entries) {
      db.execute('INSERT INTO app_settings (key, value) VALUES (?, ?)',
          [entry.key, entry.value]);
    }

    MusicDatabaseService.initializeSettings(db);
    MusicDatabaseService.initializeSettings(db);

    expect(
        db.select(
            "SELECT value FROM app_settings WHERE key = 'setting_idle_screensaver_theme'"),
        isEmpty);
    expect({
      for (final row in db.select('SELECT key, value FROM app_settings'))
        row['key']: row['value'],
    }, {
      'bg_visual_mode': '1',
      'theme_id': '1',
      'setting_idle_fullscreen': '0',
    });
  });
}
