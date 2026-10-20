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
  // Widget tests change persistent settings and scan fixtures. Keep those writes
  // away from the user's real library, including when tests run concurrently.
  static final String? _testDatabasePath = Platform.environment.containsKey('FLUTTER_TEST')
      ? '${Directory.systemTemp.createTempSync('hifi_player_test_').path}/library.db'
      : null;
  static final MusicDatabaseService instance = MusicDatabaseService._();

  List<Track> _tracks = [];
  List<Track> get tracks => _tracks;

  @visibleForTesting
  void setTracksForTesting(List<Track> tracks) {
    _tracks = List.from(tracks);
    notifyListeners();
  }

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  MusicDatabaseService._() {
    loadLibrary();
  }

  /// 获取 C++ SQLite 数据库默认绝对路径
  String get _databasePath {
    if (_testDatabasePath != null) return _testDatabasePath!;
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
    final defaultPath = '$home/.config/hifi_player/library.db';
    if (File(defaultPath).existsSync()) return defaultPath;
    if (File('/Users/mk10/.config/hifi_player/library.db').existsSync()) {
      return '/Users/mk10/.config/hifi_player/library.db';
    }
    return defaultPath;
  }

  Database? _cachedDb;
  bool _tableInitialized = false;
  final Map<String, String> _settingsCache = {};

  Database _openDb() {
    if (_cachedDb != null) {
      return _cachedDb!;
    }
    final dbFile = File(_databasePath);
    if (!dbFile.parent.existsSync()) {
      try {
        dbFile.parent.createSync(recursive: true);
      } catch (_) {}
    }
    final db = sqlite3.open(_databasePath);
    try {
      db.execute('PRAGMA busy_timeout = 3000;');
      db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {}
    if (!_tableInitialized) {
      _ensureSettingsTable(db);
      _tableInitialized = true;
    }
    _cachedDb = db;
    return db;
  }

  void _ensureSettingsTable(Database db) {
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
    ''');

    try {
      final masterSql = db.select("SELECT sql FROM sqlite_master WHERE tbl_name='scanned_tracks' AND type='table';");
      if (masterSql.isNotEmpty) {
        final sql = masterSql.first['sql'] as String? ?? '';
        if (sql.contains('file_path TEXT UNIQUE')) {
          db.execute('''
            CREATE TABLE scanned_tracks_migration (
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
            INSERT INTO scanned_tracks_migration SELECT 
              id, title, artist, album, file_path, format, sample_rate, bit_depth, duration_sec,
              start_time_sec, end_time_sec, cue_path, track_number, is_cue_track
            FROM scanned_tracks;
            DROP TABLE scanned_tracks;
            ALTER TABLE scanned_tracks_migration RENAME TO scanned_tracks;
          ''');
        }
      }

      final info = db.select('PRAGMA table_info(scanned_tracks);');
      final existingCols = info.map((row) => row['name'] as String).toSet();
      if (!existingCols.contains('is_cue_track')) {
        db.execute('ALTER TABLE scanned_tracks ADD COLUMN is_cue_track INTEGER DEFAULT 0;');
      }
      if (!existingCols.contains('start_time_sec')) {
        db.execute('ALTER TABLE scanned_tracks ADD COLUMN start_time_sec REAL DEFAULT 0.0;');
      }
      if (!existingCols.contains('end_time_sec')) {
        db.execute('ALTER TABLE scanned_tracks ADD COLUMN end_time_sec REAL DEFAULT 0.0;');
      }
      if (!existingCols.contains('cue_path')) {
        db.execute('ALTER TABLE scanned_tracks ADD COLUMN cue_path TEXT DEFAULT "";');
      }
      if (!existingCols.contains('track_number')) {
        db.execute('ALTER TABLE scanned_tracks ADD COLUMN track_number INTEGER DEFAULT 0;');
      }
    } catch (_) {}
  }

  /// 获取持久化设置项 (1:1 对齐 C++ MusicDatabase::getSetting，内置内存热缓存与纳秒级直读)
  String getSetting(String key, String defaultValue) {
    if (_settingsCache.containsKey(key)) {
      return _settingsCache[key]!;
    }
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
      _settingsCache[key] = val;
      return val;
    } catch (e) {
      debugPrint('[MusicDatabaseService] getSetting error for $key: $e');
      return defaultValue;
    }
  }

  /// 保存持久化设置项 (1:1 对齐 C++ MusicDatabase::setSetting)
  bool setSetting(String key, String value) {
    _settingsCache[key] = value;
    try {
      final db = _openDb();
      final stmt = db.prepare('INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?);');
      stmt.execute([key, value]);
      stmt.close();
      return true;
    } catch (e) {
      debugPrint('[MusicDatabaseService] setSetting error for $key: $e');
      return false;
    }
  }

  /// 批量持久化设置项 (单次事务提交，杜绝 SQLite 重复开关与锁冲突)
  bool setSettings(Map<String, String> entries) {
    if (entries.isEmpty) return true;
    for (final e in entries.entries) {
      _settingsCache[e.key] = e.value;
    }
    try {
      final db = _openDb();
      db.execute('BEGIN TRANSACTION;');
      final stmt = db.prepare('INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?);');
      for (final e in entries.entries) {
        stmt.execute([e.key, e.value]);
      }
      stmt.close();
      db.execute('COMMIT;');
      return true;
    } catch (e) {
      debugPrint('[MusicDatabaseService] setSettings batch error: $e');
      return false;
    }
  }
  /// 智能解析并自愈音频路径 (1:1 严格对齐 C++ MusicDatabase::resolveTrackPath)
  /// 彻底根治 iOS / iPadOS 每次通过 Xcode 重新运行或版本升级导致 Sandbox Container UUID 变化失效的问题
  static String resolveTrackPath(String path) {
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
        'FROM scanned_tracks ORDER BY id ASC'
      );

      final loaded = <Track>[];
      final isTest = Platform.environment.containsKey('FLUTTER_TEST');
      bool hasOrphanRecords = false;
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
          hasOrphanRecords = true;
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
          cuePath: (row['cue_path'] as String?) ?? '',
          trackNumber: row['track_number'] as int? ?? 0,
        );
        loaded.add(track);
      }

      // 如果发生了 iOS 沙盒 Container UUID 迁移，自动在 SQLite 中静默自愈落盘
      if (pathsToHeal.isNotEmpty && !isTest) {
        try {
          final healStmt = db.prepare('UPDATE scanned_tracks SET file_path = ? WHERE id = ?;');
          for (final entry in pathsToHeal.entries) {
            healStmt.execute([entry.value, entry.key]);
          }
          healStmt.close();
          debugPrint('[MusicDatabaseService] 成功自愈 ${pathsToHeal.length} 条沙盒变更音频记录！');
        } catch (e) {
          debugPrint('[MusicDatabaseService] 路径自愈失败: $e');
        }
      }

      // 如果 SQLite 表中残留了已不存在的假数据，自动执行物理擦除自愈
      if (hasOrphanRecords && !isTest) {
        try {
          if (loaded.isEmpty) {
            db.execute('DELETE FROM scanned_tracks;');
          } else {
            final validPaths = loaded.map((t) => "'${t.filepath.replaceAll("'", "''")}'").join(',');
            db.execute('DELETE FROM scanned_tracks WHERE file_path NOT IN ($validPaths);');
          }
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
    } catch (_) {}
    _tracks = [];
    _playlists = [];
    notifyListeners();
  }

  /// 保存全量扫描曲目至 SQLite (1:1 严格对齐 C++ MusicDatabase::saveScannedTracks)
  bool saveScannedTracks(List<Track> newTracks) {
    try {
      final db = _openDb();
      db.execute('DELETE FROM scanned_tracks;');
      if (newTracks.isNotEmpty) {
        db.execute('BEGIN TRANSACTION;');
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
        db.execute('COMMIT;');
      }
      loadLibrary();
      return true;
    } catch (e) {
      debugPrint('[MusicDatabaseService] 保存扫描曲目失败: $e');
      return false;
    }
  }

  /// 扫描指定或默认音乐目录下的所有发烧音频文件 (深度支持 CUE 分轨表与真实音频母带头解析)
  Future<int> scanLibrary({String? customPath}) async {
    final home = Platform.environment['HOME'] ?? '';
    final scanDirs = <String>[];

    if (customPath != null && Directory(customPath).existsSync()) {
      scanDirs.add(customPath);
    } else {
      if (Platform.isIOS) {
        final docs = AppPaths.documentsDirectory;
        if (Directory(docs).existsSync()) {
          scanDirs.add(docs);
        }
      } else if (Platform.isMacOS) {
        final downloadsMusic = '$home/Downloads/music';
        if (Directory(downloadsMusic).existsSync()) scanDirs.add(downloadsMusic);
        final music = '$home/Music';
        if (Directory(music).existsSync()) scanDirs.add(music);
      } else if (Platform.isLinux) {
        final homeMusic = '$home/Music';
        if (Directory(homeMusic).existsSync()) scanDirs.add(homeMusic);
        const piMusic = '/home/pi/Music';
        if (Directory(piMusic).existsSync() && !scanDirs.contains(piMusic)) scanDirs.add(piMusic);
        // 自动探测挂载在 /media/pi 或 /media 下的所有 U 盘、SATA 与 NVMe 固态硬盘
        final mediaPiDir = Directory('/media/pi');
        if (mediaPiDir.existsSync()) {
          try {
            for (final sub in mediaPiDir.listSync()) {
              if (sub is Directory && !scanDirs.contains(sub.path)) scanDirs.add(sub.path);
            }
          } catch (_) {}
        }
        final mediaDir = Directory('/media');
        if (mediaDir.existsSync() && !scanDirs.contains('/media')) scanDirs.add('/media');
        final mntDir = Directory('/mnt');
        if (mntDir.existsSync()) {
          try {
            for (final sub in mntDir.listSync()) {
              if (sub is Directory && !scanDirs.contains(sub.path)) scanDirs.add(sub.path);
            }
          } catch (_) {}
          if (!scanDirs.contains('/mnt')) scanDirs.add('/mnt');
        }
      } else {
        final music = '$home/Music';
        if (Directory(music).existsSync()) scanDirs.add(music);
      }
    }

    const audioExtensions = {
      '.flac', '.wav', '.mp3', '.dsf', '.dff', '.alac', '.m4a', '.aac', '.aiff', '.aif', '.caf', '.ape'
    };

    final foundAudioFiles = <File>[];
    final foundCueFiles = <File>[];

    for (final dirPath in scanDirs) {
      final dir = Directory(dirPath);
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
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

          final dotIdx = filename.lastIndexOf('.');
          if (dotIdx == -1) continue;
          final ext = filename.substring(dotIdx).toLowerCase();
          if (ext == '.cue') {
            foundCueFiles.add(entity);
          } else if (audioExtensions.contains(ext)) {
            foundAudioFiles.add(entity);
          }
        }
      } catch (e) {
        debugPrint('[MusicDatabaseService] 遍历目录 $dirPath 异常: $e');
      }
    }

    final newTracks = <Track>[];
    int currentId = 1;
    final cueHandledAudioPathsLower = <String>{};
    final audioMetaCache = <String, AudioMetadata>{};

    // 1. 优先解析 CUE 分轨表，按音轨拆分虚拟单曲 (完美解决 WAV+CUE 整轨无歌名问题)
    for (final cueFile in foundCueFiles) {
      try {
        final sheet = CueSheetParser.parse(cueFile);
        if (sheet == null || sheet.tracks.isEmpty) continue;

        debugPrint('[MusicDatabaseService] 成功解析 CUE: ${cueFile.path} (专辑: ${sheet.albumTitle}, 艺术家: ${sheet.albumPerformer}, 音轨数: ${sheet.tracks.length})');

        for (final cueTrk in sheet.tracks) {
          if (cueTrk.resolvedAudioPath.isEmpty) continue;

          final resolvedFile = File(cueTrk.resolvedAudioPath);
          if (!resolvedFile.existsSync()) continue;

          cueHandledAudioPathsLower.add(cueTrk.resolvedAudioPath.toLowerCase());

          // 缓存并读取物理母带音频真实采样率、位深与总时长
          AudioMetadata? meta = audioMetaCache[cueTrk.resolvedAudioPath];
          final ext = p.extension(cueTrk.resolvedAudioPath).toLowerCase();
          final fmt = Track.formatFromExtension(ext);
          if (meta == null) {
            meta = AudioMetadataHelper.parse(resolvedFile, fmt);
            audioMetaCache[cueTrk.resolvedAudioPath] = meta;
          }

          int durationSec = cueTrk.durationSec;
          double endTimeSec = cueTrk.endTimeSec;
          if (durationSec <= 0) {
            if (meta.durationSec > 0 && meta.durationSec > cueTrk.startTimeSec) {
              endTimeSec = meta.durationSec.toDouble();
              durationSec = max(0, (endTimeSec - cueTrk.startTimeSec).round());
            } else {
              durationSec = 180;
            }
          }

          newTracks.add(Track(
            id: currentId++,
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
        debugPrint('[MusicDatabaseService] 解析 CUE 失败: ${cueFile.path}, error: $e');
      }
    }

    // 2. 解析普通独立音频文件。精准过滤已被 CUE 拆解的整轨大文件，避免出现重复的大母带记录
    for (final file in foundAudioFiles) {
      final path = file.path;
      if (cueHandledAudioPathsLower.contains(path.toLowerCase())) {
        debugPrint('[MusicDatabaseService] 屏蔽已被 CUE 拆解的整轨音频: $path');
        continue;
      }

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
          final p0 = parts[0].trim();
          final p1 = parts.sublist(1).join(' - ').trim();

          // 情况 1: 前缀为纯数字序号，例如 "03 - 石頭記"
          if (RegExp(r'^\d+$').hasMatch(p0)) {
            title = p1;
          }
          // 情况 2: 后缀包含方括号专辑名，例如 "讲不出再见 - 谭咏麟[二十年白金畅销金曲全记录]"
          else if (p1.contains('[') && p1.endsWith(']')) {
            final bStart = p1.indexOf('[');
            final artCandidate = p1.substring(0, bStart).trim();
            final albCandidate = p1.substring(bStart + 1, p1.length - 1).trim();
            title = p0;
            if (artCandidate.isNotEmpty) artist = artCandidate;
            if (albCandidate.isNotEmpty) album = albCandidate;
          }
          // 情况 3: 前缀包含方括号专辑名，例如 "谭咏麟[二十年白金畅销金曲全记录] - 讲不出再见"
          else if (p0.contains('[') && p0.endsWith(']')) {
            final bStart = p0.indexOf('[');
            final artCandidate = p0.substring(0, bStart).trim();
            final albCandidate = p0.substring(bStart + 1, p0.length - 1).trim();
            title = p1;
            if (artCandidate.isNotEmpty) artist = artCandidate;
            if (albCandidate.isNotEmpty) album = albCandidate;
          }
          // 默认情况: "艺术家 - 歌名"
          else {
            artist = p0;
            title = p1;
          }
        }
      }

      final segments = file.parent.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final parentName = segments.isNotEmpty ? segments.last : '';
      if (parentName.isNotEmpty && parentName != 'Documents' && parentName != 'Music') {
        album = parentName;
        if (artist.isEmpty && album.contains(' - ')) {
          final albParts = album.split(' - ');
          artist = albParts[0].trim();
        }
      }

      final fmt = Track.formatFromExtension(ext);
      final meta = AudioMetadataHelper.parse(file, fmt);

      newTracks.add(Track(
        id: currentId++,
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

    saveScannedTracks(newTracks);
    return newTracks.length;
  }

  void createPlaylist(String name) {
    if (name.trim().isEmpty) return;
    final newId = DateTime.now().millisecondsSinceEpoch;
    _playlists.add(Playlist(id: newId, name: name.trim()));
    try {
      final db = _openDb();
      final stmt = db.prepare('INSERT OR REPLACE INTO playlists (id, name) VALUES (?, ?);');
      stmt.execute([newId, name.trim()]);
      stmt.close();
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
    } catch (_) {}
    notifyListeners();
  }
}
