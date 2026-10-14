import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import '../models/track.dart';

/// 发烧曲库数据库服务 (读取 C++ 纯音数播持久化 SQLite 数据库)
class MusicDatabaseService extends ChangeNotifier {
  static final MusicDatabaseService instance = MusicDatabaseService._();

  List<Track> _tracks = [];
  List<Track> get tracks => _tracks;

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  MusicDatabaseService._() {
    loadLibrary();
  }

  /// 获取 C++ SQLite 数据库默认绝对路径
  String get _databasePath {
    final home = Platform.environment['HOME'] ?? '';
    final defaultPath = '$home/.config/hifi_player/library.db';
    if (File(defaultPath).existsSync()) return defaultPath;
    if (File('/Users/mk10/.config/hifi_player/library.db').existsSync()) {
      return '/Users/mk10/.config/hifi_player/library.db';
    }
    return defaultPath;
  }

  void _ensureSettingsTable(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
  }

  /// 获取持久化设置项 (1:1 对齐 C++ MusicDatabase::getSetting)
  String getSetting(String key, String defaultValue) {
    final dbFile = File(_databasePath);
    if (!dbFile.existsSync()) return defaultValue;
    try {
      final db = sqlite3.open(_databasePath);
      _ensureSettingsTable(db);
      final stmt = db.prepare('SELECT value FROM app_settings WHERE key = ?;');
      final ResultSet res = stmt.select([key]);
      stmt.dispose();
      String val = defaultValue;
      if (res.isNotEmpty) {
        val = res.first['value'] as String? ?? defaultValue;
      }
      db.dispose();
      return val;
    } catch (e) {
      debugPrint('[MusicDatabaseService] getSetting error for $key: $e');
      return defaultValue;
    }
  }

  /// 保存持久化设置项 (1:1 对齐 C++ MusicDatabase::setSetting)
  bool setSetting(String key, String value) {
    final dbFile = File(_databasePath);
    try {
      if (!dbFile.parent.existsSync()) {
        dbFile.parent.createSync(recursive: true);
      }
      final db = sqlite3.open(_databasePath);
      _ensureSettingsTable(db);
      final stmt = db.prepare('INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?);');
      stmt.execute([key, value]);
      stmt.dispose();
      db.dispose();
      return true;
    } catch (e) {
      debugPrint('[MusicDatabaseService] setSetting error for $key: $e');
      return false;
    }
  }

  void loadLibrary() {
    final dbFile = File(_databasePath);
    if (dbFile.existsSync()) {
      try {
        final db = sqlite3.open(_databasePath);
        final ResultSet results = db.select(
          'SELECT id, title, artist, album, file_path, format, sample_rate, bit_depth, '
          'duration_sec, is_cue_track, start_time_sec, end_time_sec, cue_path, track_number '
          'FROM scanned_tracks ORDER BY id ASC'
        );

        final loaded = <Track>[];
        for (final row in results) {
          final formatInt = row['format'] as int? ?? 1;
          final track = Track(
            id: row['id'] as int? ?? 0,
            title: (row['title'] as String?)?.isNotEmpty == true
                ? (row['title'] as String)
                : '音轨 ${row['id']}',
            artist: (row['artist'] as String?) ?? '',
            album: (row['album'] as String?) ?? '',
            filepath: (row['file_path'] as String?) ?? '',
            format: Track.formatFromInt(formatInt),
            sampleRate: row['sample_rate'] as int? ?? 44100,
            bitDepth: row['bit_depth'] as int? ?? 16,
            durationSec: row['duration_sec'] as int? ?? 0,
            isCueTrack: (row['is_cue_track'] as int? ?? 0) == 1,
            startTimeSec: (row['start_time_sec'] as num?)?.toDouble() ?? 0.0,
            endTimeSec: (row['end_time_sec'] as num?)?.toDouble() ?? 0.0,
            cuePath: (row['cue_path'] as String?) ?? '',
            trackNumber: row['track_number'] as int? ?? 0,
          );
          loaded.add(track);
        }

        // 行业标准：如果已被 CUE 拆解为分轨，绝对不在全景树中展示整轨大文件 (全小写归一化比对)
        final cueAudioFiles = <String>{};
        for (final t in loaded) {
          if (t.isCueTrack && t.filepath.isNotEmpty) {
            cueAudioFiles.add(t.filepath.toLowerCase());
          }
        }
        if (cueAudioFiles.isNotEmpty) {
          loaded.removeWhere(
              (t) => !t.isCueTrack && cueAudioFiles.contains(t.filepath.toLowerCase()));
        }

        // 读取用户播放列表
        final plLoaded = <Playlist>[];
        try {
          final plResults = db.select('SELECT id, name FROM playlists ORDER BY id ASC');
          for (final row in plResults) {
            final plId = row['id'] as int? ?? 0;
            final plName = row['name'] as String? ?? '新歌单';
            plLoaded.add(Playlist(id: plId, name: plName));
          }
        } catch (_) {}

        db.dispose();

        if (loaded.isNotEmpty) {
          _tracks = loaded;
          _playlists = plLoaded;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('[MusicDatabaseService] 无法加载 SQLite 数据库: $e');
      }
    }

    // 兜底模拟发烧曲库 (与 C++ 数据库结构 100% 吻合)
    _loadFallbackDemoTracks();
    notifyListeners();
  }

  void _loadFallbackDemoTracks() {
    _tracks = [
      const Track(
        id: 1,
        title: '此情可待',
        artist: '阿强',
        album: '此情可待 DSD',
        filepath: '/Music/此情可待.dsf',
        format: AudioFormat.dsdDsf,
        sampleRate: 2822400,
        bitDepth: 1,
        durationSec: 241,
      ),
      const Track(
        id: 2,
        title: '草帽歌',
        artist: '阿强',
        album: '此情可待 DSD',
        filepath: '/Music/草帽歌.dsf',
        format: AudioFormat.dsdDsf,
        sampleRate: 2822400,
        bitDepth: 1,
        durationSec: 274,
      ),
      const Track(
        id: 3,
        title: '女人花',
        artist: '阿强',
        album: '此情可待 DSD',
        filepath: '/Music/女人花.dsf',
        format: AudioFormat.dsdDsf,
        sampleRate: 2822400,
        bitDepth: 1,
        durationSec: 239,
      ),
      const Track(
        id: 4,
        title: '不值得',
        artist: '阿强',
        album: '此情可待 DSD',
        filepath: '/Music/不值得.dsf',
        format: AudioFormat.dsdDsf,
        sampleRate: 2822400,
        bitDepth: 1,
        durationSec: 294,
      ),
      const Track(
        id: 5,
        title: '新不了情',
        artist: '阿强',
        album: '此情可待 DSD',
        filepath: '/Music/新不了情.dsf',
        format: AudioFormat.dsdDsf,
        sampleRate: 2822400,
        bitDepth: 1,
        durationSec: 307,
      ),
      const Track(
        id: 6,
        title: '加州旅馆 (Hotel California)',
        artist: 'Eagles',
        album: 'Hell Freezes Over (Live)',
        filepath: '/Music/Hotel_California.flac',
        format: AudioFormat.flac,
        sampleRate: 192000,
        bitDepth: 24,
        durationSec: 432,
      ),
      const Track(
        id: 7,
        title: '渡口',
        artist: '蔡琴',
        album: '民歌蔡琴',
        filepath: '/Music/渡口.flac',
        format: AudioFormat.flac,
        sampleRate: 192000,
        bitDepth: 24,
        durationSec: 228,
      ),
      const Track(
        id: 8,
        title: '被遗忘的时光',
        artist: '蔡琴',
        album: '民歌蔡琴',
        filepath: '/Music/被遗忘的时光.flac',
        format: AudioFormat.flac,
        sampleRate: 96000,
        bitDepth: 24,
        durationSec: 168,
      ),
      const Track(
        id: 9,
        title: '月光奏鸣曲 (Moonlight Sonata)',
        artist: 'Beethoven',
        album: 'Classical Masters 192k',
        filepath: '/Music/Moonlight_Sonata.flac',
        format: AudioFormat.flac,
        sampleRate: 192000,
        bitDepth: 24,
        durationSec: 355,
      ),
      const Track(
        id: 10,
        title: '达坂城的姑娘',
        artist: '黑鸭子',
        album: '发烧人声示范碟',
        filepath: '/Music/达坂城的姑娘.flac',
        format: AudioFormat.flac,
        sampleRate: 192000,
        bitDepth: 24,
        durationSec: 215,
      ),
    ];
  }

  void createPlaylist(String name) {
    if (name.trim().isEmpty) return;
    final newId = DateTime.now().millisecondsSinceEpoch;
    _playlists.add(Playlist(id: newId, name: name.trim()));
    notifyListeners();
  }
}
