import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import '../core/app_paths.dart';
import '../models/track.dart';
import 'audio_metadata_helper.dart';
import 'cue_parser.dart';

/// 发烧曲库数据库服务 (读取 C++ 纯音数播持久化 SQLite 数据库)
class MusicDatabaseService extends ChangeNotifier {
  static final MusicDatabaseService instance = MusicDatabaseService._();

  List<Track> _tracks = [];
  List<Track> get tracks => _tracks;

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  MusicDatabaseService._() {
    deleteSetting('setting_idle_screensaver_theme');
    loadLibrary();
  }

  @visibleForTesting
  MusicDatabaseService.forTesting(String databasePath)
      : _customDatabasePathForTesting = databasePath;

  Future<void> initializeLibrary() async {
    if (Platform.isIOS) await syncPublicMusicFolder();
    loadLibrary();
    if (_tracks.isEmpty) await scanLibrary();
  }

  /// Documents is shared with Files/Finder; never inject sample songs into it.
  Future<void> syncPublicMusicFolder() async {
    final musicDir = Directory(AppPaths.musicDirectory);
    await musicDir.create(recursive: true);
    final sample = File(p.join(musicDir.path, '03 - 石頭記.mp3'));
    // Older builds copied this bundled asset automatically. A matching title
    // alone must never delete a user import, so verify the full original bytes.
    if (await sample.exists() &&
        await sample.length() == 11609069 &&
        (await sha256.bind(sample.openRead()).first).toString() ==
            'ebff0c010c612e763455d2e79f373b1e52509a02538c496fc435add6a9acb99a') {
      await sample.delete();
    }
  }

  String? _customDatabasePathForTesting;

  @visibleForTesting
  set customDatabasePathForTesting(String? path) {
    _customDatabasePathForTesting = path;
  }

  /// 获取 C++ SQLite 数据库默认绝对路径
  String get _databasePath {
    if (_customDatabasePathForTesting != null) {
      return _customDatabasePathForTesting!;
    }
    // Test fixtures must never read or overwrite the user's listening library.
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _customDatabasePathForTesting =
          '${Directory.systemTemp.createTempSync('hifi_test_').path}/library.db';
      return _customDatabasePathForTesting!;
    }
    final home = Platform.environment['HOME'] ?? '';
    if (Platform.isIOS) {
      final docs = AppPaths.documentsDirectory;
      final dir = Directory('$docs/hifi_player');
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
      return '$docs/hifi_player/library.db';
    }
    return '$home/.config/hifi_player/library.db';
  }

  Database _openDb() {
    File(_databasePath).parent.createSync(recursive: true);
    final db = sqlite3.open(_databasePath);
    try {
      db.execute('PRAGMA busy_timeout = 3000;');
      db.execute('PRAGMA journal_mode = WAL;');
      initializeSettings(db);
      return db;
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  /// Keep the theme page as the single source of visualizer preferences.
  @visibleForTesting
  static void initializeSettings(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS scanned_tracks (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        file_path TEXT NOT NULL,
        format INTEGER NOT NULL,
        sample_rate INTEGER NOT NULL,
        bit_depth INTEGER NOT NULL,
        duration_sec INTEGER NOT NULL,
        start_time_sec REAL DEFAULT 0.0,
        end_time_sec REAL DEFAULT 0.0,
        cue_path TEXT DEFAULT '',
        track_number INTEGER DEFAULT 0,
        is_cue_track INTEGER DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS playlists (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS playlist_tracks (
        playlist_id INTEGER NOT NULL,
        track_id INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (playlist_id, track_id)
      );
      CREATE TABLE IF NOT EXISTS dac_dx1ii_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
      DELETE FROM app_settings WHERE key = 'setting_idle_screensaver_theme';
    ''');
    final columns = db
        .select('PRAGMA table_info(scanned_tracks);')
        .map((row) => row['name'] as String)
        .toSet();
    const additions = {
      'start_time_sec': 'REAL DEFAULT 0.0',
      'end_time_sec': 'REAL DEFAULT 0.0',
      'cue_path': "TEXT DEFAULT ''",
      'track_number': 'INTEGER DEFAULT 0',
      'is_cue_track': 'INTEGER DEFAULT 0',
    };
    for (final entry in additions.entries) {
      if (!columns.contains(entry.key)) {
        db.execute(
            'ALTER TABLE scanned_tracks ADD COLUMN ${entry.key} ${entry.value};');
      }
    }
    db.execute('''
      INSERT OR IGNORE INTO dac_dx1ii_settings (key, value)
      SELECT substr(key, 20), value FROM app_settings
      WHERE substr(key, 1, 19) = 'setting_dac_topping_';
      INSERT OR IGNORE INTO app_settings (key, value)
      SELECT 'library_next_track_id', CAST(COALESCE(MAX(id), 0) + 1 AS TEXT)
      FROM scanned_tracks;
    ''');
    // Only remove the old bundled demo signatures, never a real file with the
    // same title. Playlist names and user settings are deliberately preserved.
    if (db
        .select(
            "SELECT 1 FROM app_settings WHERE key = 'migration_demo_cleanup_v2';")
        .isNotEmpty) {
      return;
    }
    const demoRecords = <String, Map<String, Object>>{
      '/Music/goldberg.dsf': {
        'title': 'decaud-goldberg-var5-dsd128',
        'artist': 'J.S. Bach',
        'album': 'Goldberg Variations',
        'format': 3,
        'sample_rate': 5644800,
        'bit_depth': 1,
        'duration_sec': 180,
      },
      '/Music/此情可待.dsf': {
        'title': '此情可待',
        'artist': '阿强',
        'album': '此情可待 DSD',
        'format': 3,
        'sample_rate': 2822400,
        'bit_depth': 1,
        'duration_sec': 241,
      },
      '/Music/草帽歌.dsf': {
        'title': '草帽歌',
        'artist': '阿强',
        'album': '此情可待 DSD',
        'format': 3,
        'sample_rate': 2822400,
        'bit_depth': 1,
        'duration_sec': 274,
      },
      '/Music/女人花.dsf': {
        'title': '女人花',
        'artist': '阿强',
        'album': '此情可待 DSD',
        'format': 3,
        'sample_rate': 2822400,
        'bit_depth': 1,
        'duration_sec': 239,
      },
      '/Music/Hotel_California.flac': {
        'title': '加州旅馆 (Hotel California)',
        'artist': 'Eagles',
        'album': 'Hell Freezes Over (Live)',
        'format': 1,
        'sample_rate': 192000,
        'bit_depth': 24,
        'duration_sec': 432,
      },
    };
    for (final row in db.select('SELECT * FROM scanned_tracks;')) {
      final path = row['file_path'] as String? ?? '';
      final signature = demoRecords[path];
      if (signature != null &&
          signature.entries.every((entry) => row[entry.key] == entry.value) &&
          !File(resolveTrackPath(path)).existsSync()) {
        db.execute(
            'DELETE FROM playlist_tracks WHERE track_id = ?;', [row['id']]);
        db.execute('DELETE FROM scanned_tracks WHERE id = ?;', [row['id']]);
      }
    }
    db.execute(
        "INSERT INTO app_settings (key, value) VALUES ('migration_demo_cleanup_v2', '1');");
  }

  static String resolveTrackPath(String path) {
    return AppPaths.resolveDocumentsPath(path);
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
      final stmt = db.prepare(
          'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?);');
      stmt.execute([key, value]);
      stmt.close();
      db.close();
      return true;
    } catch (e) {
      debugPrint('[MusicDatabaseService] setSetting error for $key: $e');
      return false;
    }
  }

  /// 删除持久化设置项 (彻底清理废弃配置项)
  bool deleteSetting(String key) {
    final dbFile = File(_databasePath);
    if (!dbFile.existsSync()) return true;
    try {
      final db = _openDb();
      final stmt = db.prepare('DELETE FROM app_settings WHERE key = ?;');
      stmt.execute([key]);
      stmt.close();
      db.close();
      return true;
    } catch (e) {
      debugPrint('[MusicDatabaseService] deleteSetting error for $key: $e');
      return false;
    }
  }

  /// 获取拓品 TOPPING DX1 II 专用硬件持久化设置
  String getDacDx1iiSetting(String key, String defaultValue) {
    final dbFile = File(_databasePath);
    if (!dbFile.existsSync()) return defaultValue;
    try {
      final db = _openDb();
      final stmt = db.prepare(
          'SELECT value FROM dac_dx1ii_settings WHERE key = ? LIMIT 1;');
      final ResultSet res = stmt.select([key]);
      stmt.close();
      String val = defaultValue;
      if (res.isNotEmpty) {
        val = (res.first['value'] as String? ?? defaultValue).trim();
      }
      db.close();
      return val;
    } catch (e) {
      debugPrint(
          '[MusicDatabaseService] getDacDx1iiSetting error for $key: $e');
      return defaultValue;
    }
  }

  /// 保存拓品 TOPPING DX1 II 专用硬件持久化设置
  bool setDacDx1iiSetting(String key, String value) {
    final dbFile = File(_databasePath);
    try {
      if (!dbFile.parent.existsSync()) {
        dbFile.parent.createSync(recursive: true);
      }
      final db = _openDb();
      final stmt = db.prepare(
          'INSERT OR REPLACE INTO dac_dx1ii_settings (key, value) VALUES (?, ?);');
      stmt.execute([key, value]);
      stmt.close();
      db.close();
      return true;
    } catch (e) {
      debugPrint(
          '[MusicDatabaseService] setDacDx1iiSetting error for $key: $e');
      return false;
    }
  }

  /// 获取拓品 TOPPING DX1 II 全量硬件配置字典
  Map<String, String> getAllDacDx1iiSettings() {
    final dbFile = File(_databasePath);
    if (!dbFile.existsSync()) return {};
    final map = <String, String>{};
    try {
      final db = _openDb();
      final ResultSet res =
          db.select('SELECT key, value FROM dac_dx1ii_settings;');
      for (final row in res) {
        final k = row['key'] as String?;
        final v = row['value'] as String?;
        if (k != null && v != null) {
          map[k] = v;
        }
      }
      db.close();
    } catch (e) {
      debugPrint('[MusicDatabaseService] getAllDacDx1iiSettings error: $e');
    }
    return map;
  }

  /// 检查本地是否已有拓品 DX1 II 的专用配置表数据
  bool hasDacDx1iiSettings() {
    final dbFile = File(_databasePath);
    if (!dbFile.existsSync()) return false;
    try {
      final db = _openDb();
      final ResultSet res =
          db.select('SELECT count(*) as cnt FROM dac_dx1ii_settings;');
      final cnt = res.isNotEmpty ? (res.first['cnt'] as int? ?? 0) : 0;
      db.close();
      return cnt > 0;
    } catch (_) {}
    return false;
  }

  void loadLibrary() {
    final dbFile = File(_databasePath);
    if (!dbFile.existsSync()) {
      _tracks = [];
      _playlists = [];
      notifyListeners();
      return;
    }

    try {
      final db = _openDb();
      final ResultSet results = db.select(
          'SELECT id, title, artist, album, file_path, format, sample_rate, bit_depth, '
          'duration_sec, is_cue_track, start_time_sec, end_time_sec, cue_path, track_number '
          'FROM scanned_tracks ORDER BY id ASC');

      final loaded = <Track>[];
      final isTest = Platform.environment.containsKey('FLUTTER_TEST');
      final pathsToHeal = <int, String>{};

      for (final row in results) {
        final rawPath = (row['file_path'] as String?) ?? '';
        final filepath = resolveTrackPath(rawPath);
        final id = row['id'] as int? ?? 0;
        if (filepath != rawPath && filepath.isNotEmpty) {
          pathsToHeal[id] = filepath;
        }

        // 只有在路径动态自愈后依然物理不存在，才视为真正孤立失效数据
        if (!isTest && (filepath.isEmpty || !File(filepath).existsSync())) {
          continue;
        }

        final formatInt = row['format'] as int? ?? 1;
        final track = Track(
          id: id,
          title: (row['title'] as String?)?.isNotEmpty == true
              ? (row['title'] as String)
              : '音轨 $id',
          artist: (row['artist'] as String?) ?? '',
          album: (row['album'] as String?) ?? '',
          filepath: filepath,
          format: Track.formatFromInt(formatInt),
          sampleRate: row['sample_rate'] as int? ?? 44100,
          bitDepth: row['bit_depth'] as int? ?? 16,
          durationSec: row['duration_sec'] as int? ?? 0,
          isCueTrack: (row['is_cue_track'] as int? ?? 0) == 1,
          startTimeSec: (row['start_time_sec'] as num?)?.toDouble() ?? 0.0,
          endTimeSec: (row['end_time_sec'] as num?)?.toDouble() ?? 0.0,
          cuePath: resolveTrackPath((row['cue_path'] as String?) ?? ''),
          trackNumber: row['track_number'] as int? ?? 0,
        );
        loaded.add(track);
      }

      // 如果发生了 iOS 沙盒 Container UUID 迁移，自动在 SQLite 中静默自愈落盘
      if (pathsToHeal.isNotEmpty && !isTest) {
        try {
          final healStmt = db
              .prepare('UPDATE scanned_tracks SET file_path = ? WHERE id = ?;');
          for (final entry in pathsToHeal.entries) {
            healStmt.execute([entry.value, entry.key]);
          }
          healStmt.close();
          debugPrint(
              '[MusicDatabaseService] 成功自愈 ${pathsToHeal.length} 条沙盒变更音频记录！');
        } catch (e) {
          debugPrint('[MusicDatabaseService] 路径自愈失败: $e');
        }
      }

      // 行业标准：如果已被 CUE 拆解为分轨，绝对不在全景树中展示整轨大文件 (全小写归一化比对)
      final cueAudioFiles = <String>{};
      for (final t in loaded) {
        if (t.isCueTrack && t.filepath.isNotEmpty) {
          cueAudioFiles.add(t.filepath.toLowerCase());
        }
      }
      if (cueAudioFiles.isNotEmpty) {
        loaded.removeWhere((t) =>
            !t.isCueTrack && cueAudioFiles.contains(t.filepath.toLowerCase()));
      }

      // 读取用户播放列表
      final plLoaded = <Playlist>[];
      try {
        final plResults =
            db.select('SELECT id, name FROM playlists ORDER BY id ASC');
        for (final row in plResults) {
          final plId = row['id'] as int? ?? 0;
          final plName = row['name'] as String? ?? '新歌单';
          final playlist = Playlist(id: plId, name: plName);
          final trackMap = {for (final track in loaded) track.id: track};
          for (final member in db.select(
              'SELECT track_id FROM playlist_tracks WHERE playlist_id = ? ORDER BY sort_order;',
              [plId])) {
            final track = trackMap[member['track_id']];
            if (track != null) playlist.tracks.add(track);
          }
          plLoaded.add(playlist);
        }
      } catch (_) {}

      db.close();

      _tracks = loaded;
      _playlists = plLoaded;
      notifyListeners();
    } catch (e) {
      debugPrint('[MusicDatabaseService] 无法加载 SQLite 数据库: $e');
      _tracks = [];
      _playlists = [];
      notifyListeners();
    }
  }

  /// 彻底清空曲库与历史数据
  void cleanLibrary() {
    try {
      final db = _openDb();
      db.execute('DELETE FROM scanned_tracks;');
      db.execute('DELETE FROM playlists;');
      db.execute('DELETE FROM playlist_tracks;');
      db.close();
    } catch (_) {}
    _tracks = [];
    _playlists = [];
    notifyListeners();
  }

  /// 保存全量扫描曲目至 SQLite (1:1 严格对齐 C++ MusicDatabase::saveScannedTracks)
  bool saveScannedTracks(List<Track> newTracks) {
    Database? db;
    try {
      db = _openDb();
      db.execute('BEGIN IMMEDIATE;');
      db.execute('DELETE FROM scanned_tracks;');
      if (newTracks.isNotEmpty) {
        final stmt = db.prepare('''
          INSERT INTO scanned_tracks (
            id, title, artist, album, file_path, format, sample_rate, bit_depth,
            duration_sec, start_time_sec, end_time_sec, cue_path, track_number, is_cue_track
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''');
        for (final t in newTracks) {
          stmt.execute([
            t.id,
            t.title,
            t.artist,
            t.album,
            t.filepath,
            t.formatInt,
            t.sampleRate,
            t.bitDepth,
            t.durationSec,
            t.startTimeSec,
            t.endTimeSec,
            t.cuePath,
            t.trackNumber,
            t.isCueTrack ? 1 : 0,
          ]);
        }
        stmt.close();
      }
      db.execute(
          'DELETE FROM playlist_tracks WHERE track_id NOT IN (SELECT id FROM scanned_tracks);');
      final nextId =
          newTracks.fold<int>(0, (value, track) => max(value, track.id)) + 1;
      db.execute('''INSERT OR REPLACE INTO app_settings (key, value)
        SELECT 'library_next_track_id', CAST(MAX(COALESCE(
          (SELECT CAST(value AS INTEGER) FROM app_settings WHERE key = 'library_next_track_id'), 1), ?) AS TEXT);''',
          [nextId]);
      db.execute('COMMIT;');
      db.close();
      db = null;
      loadLibrary();
      return true;
    } catch (e) {
      try {
        db?.execute('ROLLBACK;');
      } catch (_) {}
      debugPrint('[MusicDatabaseService] 保存扫描曲目失败: $e');
      return false;
    } finally {
      db?.close();
    }
  }

  /// 扫描指定或默认音乐目录下的所有发烧音频文件 (深度支持 CUE 分轨表与真实音频母带头解析)
  static String _trackKey(Track track) {
    final path = p.canonicalize(resolveTrackPath(track.filepath)).toLowerCase();
    return track.isCueTrack
        ? 'cue:$path:${track.trackNumber}:${track.startTimeSec}'
        : 'audio:$path';
  }

  Future<void> _scanQueue = Future<void>.value();

  Future<int> scanLibrary({String? customPath}) {
    final next = _scanQueue.then((_) => _scanLibrary(customPath: customPath));
    _scanQueue = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<int> _scanLibrary({String? customPath}) async {
    final home = Platform.environment['HOME'] ?? '';
    final scanDirs = <String>{};

    void addScanDir(String? dirPath) {
      if (dirPath == null || dirPath.isEmpty) return;
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        scanDirs.add(p.canonicalize(dir.absolute.path));
      }
    }

    if (customPath != null) {
      final path = AppPaths.resolveDocumentsPath(customPath);
      if (!Directory(path).existsSync()) {
        throw FileSystemException('扫描目录不存在，原曲库已保留', path);
      }
      addScanDir(path);
    } else {
      if (Platform.isIOS) {
        await Directory(AppPaths.musicDirectory).create(recursive: true);
        addScanDir(AppPaths.musicDirectory);
      } else if (Platform.isMacOS) {
        addScanDir('$home/Downloads/music');
        addScanDir('$home/Music');
        addScanDir('$home/Desktop/music2');
        final desktop = Directory('$home/Desktop');
        if (desktop.existsSync()) {
          try {
            for (final d in desktop.listSync()) {
              if (d is Directory) {
                final base = p.basename(d.path).toLowerCase();
                if (base.contains('music') || base.contains('hifi')) {
                  addScanDir(d.path);
                }
              }
            }
          } catch (_) {}
        }
      } else {
        addScanDir('$home/Music');
      }
    }

    // 过滤掉已被父目录包含的冗余子目录，避免二次递归
    final sortedDirs = scanDirs.toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    final normalizedDirs = <String>[];
    for (final dir in sortedDirs) {
      if (!normalizedDirs.any((parent) => p.isWithin(parent, dir))) {
        normalizedDirs.add(dir);
      }
    }

    const audioExtensions = {
      '.flac',
      '.wav',
      '.mp3',
      '.dsf',
      '.dff',
      '.alac',
      '.m4a',
      '.aac',
      '.aiff',
      '.aif',
      '.caf',
      '.ape'
    };

    final foundAudioFiles = <String, File>{};
    final foundCueFiles = <String, File>{};

    for (final dirPath in normalizedDirs) {
      final dir = Directory(dirPath);
      try {
        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final filename = entity.uri.pathSegments.last;
          if (filename.startsWith('.')) continue; // 跳过隐藏文件

          // 跳过 app 内部配置或数据库
          if (entity.path.contains('/hifi_player/') ||
              entity.path.endsWith('.db') ||
              entity.path.endsWith('.db-wal') ||
              entity.path.endsWith('.db-shm')) {
            continue;
          }

          final ext = p.extension(filename).toLowerCase();
          final canonical = p.canonicalize(entity.absolute.path);
          if (ext == '.cue') {
            foundCueFiles[canonical] = entity;
          } else if (audioExtensions.contains(ext)) {
            foundAudioFiles[canonical] = entity;
          }
        }
      } catch (e) {
        debugPrint('[MusicDatabaseService] 遍历目录 $dirPath 异常: $e');
        rethrow;
      }
    }

    final newTracks = <Track>[];
    final addedKeys = <String>{};
    final existingIds = {
      for (final track in _tracks) _trackKey(track): track.id
    };
    int nextId = max(
        _tracks.fold<int>(0, (value, track) => max(value, track.id)) + 1,
        int.tryParse(getSetting('library_next_track_id', '1')) ?? 1);
    int idForKey(String key) => existingIds[key] ?? nextId++;
    final cueHandledAudioPathsLower = <String>{};
    final audioMetaCache = <String, AudioMetadata>{};

    // 1. 优先解析 CUE 分轨表，按音轨拆分虚拟单曲 (完美解决 WAV+CUE 整轨无歌名问题)
    for (final cueFile in foundCueFiles.values) {
      try {
        final sheet = CueSheetParser.parse(cueFile);
        if (sheet == null || sheet.tracks.isEmpty) continue;

        debugPrint(
            '[MusicDatabaseService] 成功解析 CUE: ${cueFile.path} (专辑: ${sheet.albumTitle}, 艺术家: ${sheet.albumPerformer}, 音轨数: ${sheet.tracks.length})');

        for (final cueTrk in sheet.tracks) {
          if (cueTrk.resolvedAudioPath.isEmpty) continue;

          final referencedFile = File(cueTrk.resolvedAudioPath);
          final resolvedPath = p.canonicalize(referencedFile.absolute.path);
          // Only use files discovered under the scan root. File identity also
          // handles APFS Unicode normalization and Windows CUE path casing.
          File? resolvedFile = foundAudioFiles[resolvedPath];
          if (resolvedFile == null) {
            for (final entry in foundAudioFiles.entries) {
              var sameFile =
                  entry.key.toLowerCase() == resolvedPath.toLowerCase();
              if (!sameFile) {
                try {
                  sameFile = FileSystemEntity.identicalSync(
                      entry.value.path, referencedFile.path);
                } catch (_) {}
              }
              if (sameFile) {
                resolvedFile = entry.value;
                break;
              }
            }
          }
          if (resolvedFile == null) continue;
          final canonicalAudio = p.canonicalize(resolvedFile.absolute.path);
          cueHandledAudioPathsLower.add(canonicalAudio.toLowerCase());
          cueHandledAudioPathsLower.add(cueTrk.resolvedAudioPath.toLowerCase());

          final trackKey =
              'cue:${canonicalAudio.toLowerCase()}:${cueTrk.trackNumber}:${cueTrk.startTimeSec}';
          if (!addedKeys.add(trackKey)) continue;

          // 缓存并读取物理母带音频真实采样率、位深与总时长
          AudioMetadata? meta = audioMetaCache[canonicalAudio];
          final ext = p.extension(cueTrk.resolvedAudioPath).toLowerCase();
          final fmt = Track.formatFromExtension(ext);
          if (meta == null) {
            meta = AudioMetadataHelper.parse(resolvedFile, fmt);
            audioMetaCache[canonicalAudio] = meta;
          }

          int durationSec = cueTrk.durationSec;
          double endTimeSec = cueTrk.endTimeSec;
          if (endTimeSec <= cueTrk.startTimeSec) {
            if (meta.durationSeconds > cueTrk.startTimeSec) {
              endTimeSec = meta.durationSeconds;
              durationSec = max(0, (endTimeSec - cueTrk.startTimeSec).round());
            } else {
              durationSec = 0;
            }
          }

          newTracks.add(Track(
            id: idForKey(trackKey),
            title: cueTrk.title,
            artist: cueTrk.performer,
            album: sheet.albumTitle,
            filepath: resolvedFile.path,
            format: fmt,
            sampleRate: meta.sampleRate,
            bitDepth: meta.bitDepth,
            durationSec: durationSec,
            isCueTrack: true,
            startTimeSec: cueTrk.startTimeSec,
            endTimeSec: endTimeSec,
            cuePath: sheet.cuePath,
            trackNumber: cueTrk.trackNumber,
          ));
        }
      } catch (e) {
        debugPrint(
            '[MusicDatabaseService] 解析 CUE 失败: ${cueFile.path}, error: $e');
      }
    }

    // 2. 解析普通独立音频文件。精准过滤已被 CUE 拆解的整轨大文件，避免出现重复的大母带记录
    for (final file in foundAudioFiles.values) {
      final path = file.path;
      final canonicalPath = p.canonicalize(path);
      if (cueHandledAudioPathsLower.contains(canonicalPath.toLowerCase()) ||
          cueHandledAudioPathsLower.contains(path.toLowerCase())) {
        debugPrint('[MusicDatabaseService] 屏蔽已被 CUE 拆解的整轨音频: $path');
        continue;
      }

      final trackKey = 'audio:${canonicalPath.toLowerCase()}';
      if (!addedKeys.add(trackKey)) continue;

      final filename = file.uri.pathSegments.last;
      final dotIdx = filename.lastIndexOf('.');
      final rawName = dotIdx != -1 ? filename.substring(0, dotIdx) : filename;
      final ext = dotIdx != -1 ? filename.substring(dotIdx).toLowerCase() : '';

      String title = rawName;
      String artist = '';
      String album = '';

      if (rawName.contains(' - ')) {
        final parts = rawName.split(' - ');
        if (parts.length >= 2) {
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }
      }

      final segments =
          file.parent.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final parentName = segments.isNotEmpty ? segments.last : '';
      if (parentName.isNotEmpty &&
          parentName != 'Documents' &&
          parentName != 'Music') {
        album = parentName;
        if (artist.isEmpty && album.contains(' - ')) {
          final albParts = album.split(' - ');
          artist = albParts[0].trim();
        }
      }

      final fmt = Track.formatFromExtension(ext);
      final meta = AudioMetadataHelper.parse(file, fmt);

      newTracks.add(Track(
        id: idForKey(trackKey),
        title: title,
        artist: artist.isNotEmpty ? artist : '未知艺术家',
        album: album.isNotEmpty ? album : '默认专辑',
        filepath: path,
        format: fmt,
        sampleRate: meta.sampleRate,
        bitDepth: meta.bitDepth,
        durationSec: meta.durationSec,
      ));
    }

    if (!saveScannedTracks(newTracks)) {
      throw StateError('无法保存扫描结果，原曲库已保留');
    }
    return newTracks.length;
  }

  void createPlaylist(String name) {
    if (name.trim().isEmpty) return;
    final newId = DateTime.now().millisecondsSinceEpoch;
    _playlists.add(Playlist(id: newId, name: name.trim()));
    try {
      final db = _openDb();
      final stmt = db.prepare(
          'INSERT OR REPLACE INTO playlists (id, name) VALUES (?, ?);');
      stmt.execute([newId, name.trim()]);
      stmt.close();
      db.close();
    } catch (_) {}
    notifyListeners();
  }

  /// Playlist membership uses the stable track ID retained by rescans.
  bool addTrackToPlaylist(int playlistId, int trackId) {
    Database? db;
    try {
      db = _openDb();
      if (db.select(
              'SELECT id FROM playlists WHERE id = ?;', [playlistId]).isEmpty ||
          db.select('SELECT id FROM scanned_tracks WHERE id = ?;',
              [trackId]).isEmpty) {
        return false;
      }
      db.execute(
          '''INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, sort_order)
        SELECT ?, ?, COALESCE(MAX(sort_order), -1) + 1
        FROM playlist_tracks WHERE playlist_id = ?;''',
          [playlistId, trackId, playlistId]);
      db.close();
      db = null;
      loadLibrary();
      return true;
    } catch (error) {
      debugPrint('[MusicDatabaseService] 加入歌单失败: $error');
      return false;
    } finally {
      db?.close();
    }
  }

  bool removeTrackFromPlaylist(int playlistId, int trackId) {
    Database? db;
    try {
      db = _openDb();
      db.execute(
          'DELETE FROM playlist_tracks WHERE playlist_id = ? AND track_id = ?;',
          [playlistId, trackId]);
      db.close();
      db = null;
      loadLibrary();
      return true;
    } catch (error) {
      debugPrint('[MusicDatabaseService] 移出歌单失败: $error');
      return false;
    } finally {
      db?.close();
    }
  }

  void deletePlaylist(int id) {
    _playlists.removeWhere((p) => p.id == id);
    try {
      final db = _openDb();
      final stmt = db.prepare('DELETE FROM playlists WHERE id = ?;');
      stmt.execute([id]);
      stmt.close();
      db.execute('DELETE FROM playlist_tracks WHERE playlist_id = ?;', [id]);
      db.close();
    } catch (_) {}
    notifyListeners();
  }

  /// Library edits share the scan queue so an in-flight rescan cannot restore
  /// records for a source file that the user has just deleted.
  Future<int> deleteTracks(Iterable<int> trackIds,
      {bool deleteSourceFiles = true}) {
    final ids = trackIds.toSet();
    final next = _scanQueue
        .then((_) => _deleteTracks(ids, deleteSourceFiles: deleteSourceFiles));
    _scanQueue = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<int> _deleteTracks(Set<int> idSet,
      {required bool deleteSourceFiles}) async {
    if (idSet.isEmpty) return 0;
    final tracksToDelete = _tracks.where((t) => idSet.contains(t.id)).toList();
    if (tracksToDelete.isEmpty) return 0;

    if (deleteSourceFiles) {
      String pathKey(String path) =>
          p.canonicalize(resolveTrackPath(path)).toLowerCase();
      final affectedAudioPaths = {
        for (final track in tracksToDelete)
          pathKey(track.filepath): resolveTrackPath(track.filepath),
      };
      for (final entry in affectedAudioPaths.entries) {
        // A virtual CUE track shares its recording with its siblings. Delete
        // that recording only when every library reference was selected.
        final hasRemainingTracks = _tracks.any((track) =>
            !idSet.contains(track.id) && pathKey(track.filepath) == entry.key);
        if (!hasRemainingTracks) {
          final source = File(entry.value);
          if (source.existsSync()) source.deleteSync();
        }
      }

      final affectedCuePaths = {
        for (final track in tracksToDelete)
          if (track.isCueTrack && track.cuePath.isNotEmpty)
            pathKey(track.cuePath): resolveTrackPath(track.cuePath),
      };
      for (final entry in affectedCuePaths.entries) {
        final members = _tracks.where((track) =>
            track.isCueTrack &&
            track.cuePath.isNotEmpty &&
            pathKey(track.cuePath) == entry.key);
        final hasRemainingTracks =
            members.any((track) => !idSet.contains(track.id));
        final hasRemainingAudio = members.any(
            (track) => File(resolveTrackPath(track.filepath)).existsSync());
        // CUE and audio filenames need not match. Never guess a recording by
        // basename and never touch descriptors from unrelated albums.
        if (!hasRemainingTracks && !hasRemainingAudio) {
          final cue = File(entry.value);
          if (cue.existsSync()) cue.deleteSync();
        }
      }
    }

    Database? db;
    try {
      db = _openDb();
      db.execute('BEGIN IMMEDIATE;');
      final placeholders = List.filled(idSet.length, '?').join(',');
      db.execute('DELETE FROM scanned_tracks WHERE id IN ($placeholders);',
          idSet.toList());
      db.execute(
          'DELETE FROM playlist_tracks WHERE track_id IN ($placeholders);',
          idSet.toList());
      db.execute('COMMIT;');
    } catch (error) {
      try {
        db?.execute('ROLLBACK;');
      } catch (_) {}
      debugPrint('[MusicDatabaseService] SQLite 删除曲目失败: $error');
      rethrow;
    } finally {
      db?.close();
    }

    // 3. 从内存列表中移除
    _tracks.removeWhere((t) => idSet.contains(t.id));
    for (final pl in _playlists) {
      pl.tracks.removeWhere((t) => idSet.contains(t.id));
    }
    notifyListeners();

    return tracksToDelete.length;
  }
}
