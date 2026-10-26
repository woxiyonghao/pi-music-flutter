import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
    } catch (_) {}
    try {
      initializeSettings(db);
    } catch (_) {
      db.close();
      rethrow;
    }
    return db;
  }

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
      SELECT substr(key, 21), value FROM app_settings
      WHERE substr(key, 1, 20) = 'setting_dac_topping_';
    ''');
    // Only remove the old bundled demo signatures, never a real file with the
    // same title. Playlist names and user settings are deliberately preserved.
    if (db
        .select(
            "SELECT 1 FROM app_settings WHERE key = 'migration_demo_cleanup_v1';")
        .isNotEmpty) {
      return;
    }
    const demoPaths = {
      '/Music/goldberg.dsf',
      '/Music/此情可待.dsf',
      '/Music/草帽歌.dsf',
      '/Music/女人花.dsf',
      '/Music/Hotel_California.flac',
    };
    for (final row in db.select('SELECT id, file_path FROM scanned_tracks;')) {
      final path = row['file_path'] as String? ?? '';
      if (demoPaths.contains(path) &&
          !File(resolveTrackPath(path)).existsSync()) {
        db.execute(
            'DELETE FROM playlist_tracks WHERE track_id = ?;', [row['id']]);
        db.execute('DELETE FROM scanned_tracks WHERE id = ?;', [row['id']]);
      }
    }
    db.execute(
        "INSERT INTO app_settings (key, value) VALUES ('migration_demo_cleanup_v1', '1');");
  }

  String getDacDx1iiSetting(String key, String defaultValue) {
    final db = _openDb();
    try {
      final rows = db
          .select('SELECT value FROM dac_dx1ii_settings WHERE key = ?;', [key]);
      return rows.isEmpty ? defaultValue : rows.first['value'] as String;
    } finally {
      db.close();
    }
  }

  void setDacDx1iiSetting(String key, String value) {
    final db = _openDb();
    try {
      db.execute(
          'INSERT OR REPLACE INTO dac_dx1ii_settings (key, value) VALUES (?, ?);',
          [key, value]);
    } finally {
      db.close();
    }
  }

  Future<void> initializeLibrary() async {
    loadLibrary();
    if (_tracks.isEmpty) await scanLibrary();
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

  /// 智能解析并自愈音频路径 (1:1 严格对齐 C++ MusicDatabase::resolveTrackPath)
  /// 彻底根治 iOS / iPadOS 每次通过 Xcode 重新运行或版本升级导致 Sandbox Container UUID 变化失效的问题
  static String resolveTrackPath(String path) {
    if (!Platform.isIOS) return path;
    if (path.isEmpty) return path;

    // 1. 如果路径在当前文件系统上直接存在，直接返回
    if (File(path).existsSync()) {
      return path;
    }

    // 2. 处理 iOS / iPadOS 沙盒路径动态重定向
    if (Platform.isIOS) {
      final currentDocs = AppPaths.documentsDirectory;
      if (currentDocs.isNotEmpty) {
        // 查找 "/Documents/" 相对路径
        final docIdx = path.indexOf('/Documents/');
        if (docIdx != -1) {
          final subPath = path.substring(docIdx + '/Documents/'.length);
          final remapped = '$currentDocs/$subPath';
          if (File(remapped).existsSync()) {
            return remapped;
          }
        }

        // 尝试提取文件名在当前 Documents/music/ 下查找
        final filename = p.basename(path);
        final fallbackMusic = '$currentDocs/music/$filename';
        if (File(fallbackMusic).existsSync()) {
          return fallbackMusic;
        }

        // 尝试提取文件名在当前 Documents/ 根目录下查找
        final fallbackDoc = '$currentDocs/$filename';
        if (File(fallbackDoc).existsSync()) {
          return fallbackDoc;
        }
      }
    }

    return path;
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
      bool hasOrphanRecords = false;
      final pathsToHeal = <int, String>{};
      final metaToHeal = <int, AudioMetadata>{};

      for (final row in results) {
        final rawPath = (row['file_path'] as String?) ?? '';
        final filepath = resolveTrackPath(rawPath);
        final id = row['id'] as int? ?? 0;
        if (filepath != rawPath && filepath.isNotEmpty) {
          pathsToHeal[id] = filepath;
        }

        // 只有在路径动态自愈后依然物理不存在，才视为真正孤立失效数据
        if (!isTest && (filepath.isEmpty || !File(filepath).existsSync())) {
          hasOrphanRecords = true;
          continue;
        }

        final formatInt = row['format'] as int? ?? 1;
        final format = Track.formatFromInt(formatInt);
        int sampleRate = row['sample_rate'] as int? ?? 44100;
        int bitDepth = row['bit_depth'] as int? ?? 16;
        int durationSec = row['duration_sec'] as int? ?? 0;
        final isCueTrack = (row['is_cue_track'] as int? ?? 0) == 1;
        if (!isCueTrack &&
            durationSec <= 0 &&
            filepath.isNotEmpty &&
            File(filepath).existsSync()) {
          final parsed = AudioMetadataHelper.parse(File(filepath), format);
          if (parsed.durationSec > 0) {
            sampleRate = parsed.sampleRate;
            bitDepth = parsed.bitDepth;
            durationSec = parsed.durationSec;
            metaToHeal[id] = parsed;
          }
        }
        final track = Track(
          id: id,
          title: (row['title'] as String?)?.isNotEmpty == true
              ? (row['title'] as String)
              : '音轨 $id',
          artist: (row['artist'] as String?) ?? '',
          album: (row['album'] as String?) ?? '',
          filepath: filepath,
          format: format,
          sampleRate: sampleRate,
          bitDepth: bitDepth,
          durationSec: durationSec,
          isCueTrack: isCueTrack,
          startTimeSec: (row['start_time_sec'] as num?)?.toDouble() ?? 0.0,
          endTimeSec: (row['end_time_sec'] as num?)?.toDouble() ?? 0.0,
          cuePath: (row['cue_path'] as String?) ?? '',
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
      if (metaToHeal.isNotEmpty) {
        try {
          final metaStmt = db.prepare(
              'UPDATE scanned_tracks SET sample_rate = ?, bit_depth = ?, duration_sec = ? WHERE id = ?;');
          for (final entry in metaToHeal.entries) {
            metaStmt.execute([
              entry.value.sampleRate,
              entry.value.bitDepth,
              entry.value.durationSec,
              entry.key,
            ]);
          }
          metaStmt.close();
          debugPrint(
              '[MusicDatabaseService] 成功自愈 ${metaToHeal.length} 条零时长/音频元数据记录！');
        } catch (e) {
          debugPrint('[MusicDatabaseService] 元数据自愈失败: $e');
        }
      }

      // 如果 SQLite 表中残留了已不存在的假数据，自动执行物理擦除自愈
      if (hasOrphanRecords && !isTest) {
        try {
          if (loaded.isEmpty) {
            db.execute('DELETE FROM scanned_tracks;');
          } else {
            final validPaths = loaded
                .map((t) => "'${t.filepath.replaceAll("'", "''")}'")
                .join(',');
            db.execute(
                'DELETE FROM scanned_tracks WHERE file_path NOT IN ($validPaths);');
          }
          db.execute('DELETE FROM playlist_tracks WHERE track_id NOT IN (SELECT id FROM scanned_tracks);');
        } catch (_) {}
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
      db.execute('COMMIT;');
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
    final path = p.canonicalize(resolveTrackPath(track.filepath));
    return track.isCueTrack
        ? 'cue:$path:${track.trackNumber}:${track.startTimeSec}'
        : 'audio:$path';
  }

  Future<int> scanLibrary({String? customPath}) async {
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
      addScanDir(customPath);
    } else {
      if (Platform.isIOS) {
        addScanDir(AppPaths.documentsDirectory);
      } else if (Platform.isMacOS) {
        addScanDir('$home/Downloads/music');
        addScanDir('$home/Music');
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
      }
    }

    final newTracks = <Track>[];
    final addedKeys = <String>{};
    final existingIds = {
      for (final track in _tracks) _trackKey(track): track.id
    };
    int nextId =
        _tracks.fold<int>(0, (value, track) => max(value, track.id)) + 1;
    int idForKey(String key) => existingIds[key] ?? nextId++;
    final cueHandledAudioPaths = <String>{};
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

          final resolvedFile = File(cueTrk.resolvedAudioPath);
          if (!resolvedFile.existsSync()) continue;

          final canonicalAudio = p.canonicalize(cueTrk.resolvedAudioPath);
          cueHandledAudioPaths.add(canonicalAudio);

          final trackKey =
              'cue:$canonicalAudio:${cueTrk.trackNumber}:${cueTrk.startTimeSec}';
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
          if (durationSec <= 0) {
            if (meta.durationSec > 0 &&
                meta.durationSec > cueTrk.startTimeSec) {
              endTimeSec = meta.durationSec.toDouble();
              durationSec = max(0, (endTimeSec - cueTrk.startTimeSec).round());
            } else {
              durationSec = 180;
            }
          }

          newTracks.add(Track(
            id: idForKey(trackKey),
            title: cueTrk.title,
            artist: cueTrk.performer,
            album: sheet.albumTitle,
            filepath: cueTrk.resolvedAudioPath,
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
      if (cueHandledAudioPaths.contains(canonicalPath)) {
        debugPrint('[MusicDatabaseService] 屏蔽已被 CUE 拆解的整轨音频: $path');
        continue;
      }

      final trackKey = 'audio:$canonicalPath';
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

  /// 从曲库与 SQLite 中删除指定曲目，并可选择是否物理删除磁盘源文件
  Future<int> deleteTracks(Iterable<int> trackIds,
      {bool deleteSourceFiles = true}) async {
    final idSet = trackIds.toSet();
    if (idSet.isEmpty) return 0;

    final tracksToDelete = _tracks.where((t) => idSet.contains(t.id)).toList();
    if (tracksToDelete.isEmpty) return 0;

    // 1. 物理删除源文件 (若 deleteSourceFiles 为 true)
    if (deleteSourceFiles) {
      // 收集非 CUE 分轨文件
      final nonCuePaths = <String>{};
      // 收集 CUE 专辑分轨文件
      final cueAudioPaths = <String, Set<int>>{};
      final cueFilePaths = <String>{};

      for (final t in _tracks) {
        final path = resolveTrackPath(t.filepath);
        if (t.isCueTrack) {
          cueAudioPaths.putIfAbsent(path, () => {}).add(t.id);
          if (t.cuePath.isNotEmpty) {
            cueFilePaths.add(resolveTrackPath(t.cuePath));
          }
        }
      }

      for (final t in tracksToDelete) {
        final path = resolveTrackPath(t.filepath);
        if (!t.isCueTrack) {
          nonCuePaths.add(path);
        }
      }

      // 物理删除普通音频文件
      for (final path in nonCuePaths) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            file.deleteSync();
            debugPrint('[MusicDatabaseService] 已物理删除音频文件: $path');
          }
        } catch (e) {
          debugPrint('[MusicDatabaseService] 删除源文件失败 $path: $e');
        }
      }

      // 如果一个 CUE 专辑的所有分轨都被选中删除了，则连同整轨音频与 .cue 描述文件一起物理删除
      for (final entry in cueAudioPaths.entries) {
        final cueAudioPath = entry.key;
        final allTrackIdsForCue = entry.value;
        if (allTrackIdsForCue.every((id) => idSet.contains(id))) {
          try {
            final f = File(cueAudioPath);
            if (f.existsSync()) {
              f.deleteSync();
              debugPrint(
                  '[MusicDatabaseService] 已物理删除整轨 CUE 音频: $cueAudioPath');
            }
          } catch (e) {
            debugPrint('[MusicDatabaseService] 删除 CUE 音频失败: $e');
          }
        }
      }
      for (final cuePath in cueFilePaths) {
        try {
          final f = File(cuePath);
          if (f.existsSync()) {
            final base = p.withoutExtension(cuePath);
            final possibleAudios = [
              '$base.wav',
              '$base.flac',
              '$base.ape',
              '$base.dsf'
            ];
            final hasRemainingAudio =
                possibleAudios.any((p) => File(p).existsSync());
            if (!hasRemainingAudio) {
              f.deleteSync();
              debugPrint('[MusicDatabaseService] 已清理孤立 CUE 描述文件: $cuePath');
            }
          }
        } catch (_) {}
      }
    }

    // 2. 从 SQLite 数据库中移除记录
    try {
      final db = _openDb();
      final placeholders = List.filled(idSet.length, '?').join(',');
      final stmt =
          db.prepare('DELETE FROM scanned_tracks WHERE id IN ($placeholders);');
      stmt.execute(idSet.toList());
      stmt.close();
      db.execute('DELETE FROM playlist_tracks WHERE track_id IN ($placeholders);', idSet.toList());
      db.close();
    } catch (e) {
      debugPrint('[MusicDatabaseService] SQLite 删除曲目失败: $e');
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
