import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqlite3/sqlite3.dart';
import '../models/track.dart';
import '../core/app_paths.dart';

/// 发烧曲库数据库服务 (读取 C++ 纯音数播持久化 SQLite 数据库)
class MusicDatabaseService extends ChangeNotifier {
  static String resolveTrackPath(String path) {
    if (!Platform.isIOS) return path;
    final marker = path.indexOf('/Documents/');
    if (marker >= 0) return '${AppPaths.documentsDirectory}/${path.substring(marker + 11)}';
    return path;
  }

  static final MusicDatabaseService instance = MusicDatabaseService._();

  List<Track> _tracks = [];
  List<Track> get tracks => _tracks;

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  MusicDatabaseService._() {
    loadLibrary();
    syncPublicMusicFolder();
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

  Database _openDb() {
    final db = sqlite3.open(_databasePath);
    try {
      db.execute('PRAGMA busy_timeout = 3000;');
      db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {}
    _ensureSettingsTable(db);
    return db;
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
      final db = _openDb();
      final stmt = db.prepare('SELECT value FROM app_settings WHERE key = ?;');
      final ResultSet res = stmt.select([key]);
      stmt.close();
      String val = defaultValue;
      if (res.isNotEmpty) {
        val = (res.first['value'] as String? ?? defaultValue).trim();
        while (val.length >= 2 &&
            ((val.startsWith("'") && val.endsWith("'")) ||
             (val.startsWith('"') && val.endsWith('"')))) {
          val = val.substring(1, val.length - 1).trim();
        }
      }
      db.close();
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
      final db = _openDb();
      final stmt = db.prepare('INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?);');
      stmt.execute([key, value]);
      stmt.close();
      db.close();
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
        final db = _openDb();
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

        db.close();

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

    // 本地没有数据库或数据库为空时，扫描真实公共音乐目录
    final musicDir = Directory(AppPaths.musicDirectory);
    if (musicDir.existsSync()) {
      _scanLocalMusicDirectory(musicDir);
    } else {
      _tracks = [];
      notifyListeners();
    }
  }

  /// 同步预置歌曲到公共文件夹并扫描真实曲库
  Future<void> syncPublicMusicFolder() async {
    try {
      final musicDir = Directory(AppPaths.musicDirectory);
      if (!musicDir.existsSync()) {
        musicDir.createSync(recursive: true);
      }

      // 将预置发烧单曲 03 - 石頭記.mp3 释放至 iPhone 共享 Documents 目录
      final targetFile = File('${musicDir.path}/03 - 石頭記.mp3');
      if (!targetFile.existsSync()) {
        try {
          final byteData = await rootBundle.load('assets/03 - 石頭記.mp3');
          final bytes = byteData.buffer.asUint8List();
          await targetFile.writeAsBytes(bytes, flush: true);
          debugPrint('[MusicDatabaseService] 已同步歌曲到公共文件夹: ${targetFile.path}');
        } catch (e) {
          debugPrint('[MusicDatabaseService] 复制内置音频失败: $e');
        }
      }

      // 实时扫描 Documents 目录中真实音频文件
      _scanLocalMusicDirectory(musicDir);
    } catch (e) {
      debugPrint('[MusicDatabaseService] syncPublicMusicFolder error: $e');
    }
  }

  void _scanLocalMusicDirectory(Directory dir) {
    if (!dir.existsSync()) return;
    final List<Track> realTracks = [];
    int nextId = 1;

    try {
      final entities = dir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          final path = entity.path;
          final dotIdx = path.lastIndexOf('.');
          if (dotIdx < 0) continue;
          final ext = path.substring(dotIdx + 1).toLowerCase();
          AudioFormat format = AudioFormat.unknown;
          if (ext == 'mp3') {
            format = AudioFormat.mp3;
          } else if (ext == 'flac') {
            format = AudioFormat.flac;
          } else if (ext == 'wav') {
            format = AudioFormat.wav;
          } else if (ext == 'dsf') {
            format = AudioFormat.dsdDsf;
          } else if (ext == 'dff') {
            format = AudioFormat.dsdDff;
          } else if (ext == 'm4a' || ext == 'alac') {
            format = AudioFormat.alac;
          }

          if (format != AudioFormat.unknown) {
            final filename = entity.uri.pathSegments.last;
            final baseName = filename.substring(0, filename.lastIndexOf('.'));
            String title = baseName;
            String artist = '达明一派';
            String album = '经典发烧数播曲库';

            if (baseName.contains(' - ')) {
              final parts = baseName.split(' - ');
              if (parts.length >= 2) {
                title = parts.sublist(1).join(' - ').trim();
              }
            }

            realTracks.add(Track(
              id: nextId++,
              title: title,
              artist: artist,
              album: album,
              filepath: path,
              format: format,
              sampleRate: format == AudioFormat.dsdDsf ? 2822400 : 44100,
              bitDepth: format == AudioFormat.dsdDsf ? 1 : 16,
              durationSec: 285,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('[MusicDatabaseService] 扫描本地音乐失败: $e');
    }

    if (realTracks.isNotEmpty) {
      _tracks = realTracks;
      notifyListeners();
    }
  }

  void createPlaylist(String name) {
    if (name.trim().isEmpty) return;
    final newId = DateTime.now().millisecondsSinceEpoch;
    _playlists.add(Playlist(id: newId, name: name.trim()));
    notifyListeners();
  }
}
