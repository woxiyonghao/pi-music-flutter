import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:path/path.dart' as p;

/// CUE 分轨曲目元数据
class CueTrackInfo {
  final int trackNumber;
  final String title;
  final String performer;
  final String fileReference;
  final double startTimeSec;
  final double endTimeSec;
  final int durationSec;
  final double pregapSec;
  final String resolvedAudioPath;

  const CueTrackInfo({
    required this.trackNumber,
    required this.title,
    required this.performer,
    required this.fileReference,
    required this.startTimeSec,
    required this.endTimeSec,
    required this.durationSec,
    required this.pregapSec,
    required this.resolvedAudioPath,
  });

  CueTrackInfo copyWith({
    int? trackNumber,
    String? title,
    String? performer,
    String? fileReference,
    double? startTimeSec,
    double? endTimeSec,
    int? durationSec,
    double? pregapSec,
    String? resolvedAudioPath,
  }) {
    return CueTrackInfo(
      trackNumber: trackNumber ?? this.trackNumber,
      title: title ?? this.title,
      performer: performer ?? this.performer,
      fileReference: fileReference ?? this.fileReference,
      startTimeSec: startTimeSec ?? this.startTimeSec,
      endTimeSec: endTimeSec ?? this.endTimeSec,
      durationSec: durationSec ?? this.durationSec,
      pregapSec: pregapSec ?? this.pregapSec,
      resolvedAudioPath: resolvedAudioPath ?? this.resolvedAudioPath,
    );
  }
}

/// CUE 分轨表
class CueSheet {
  final String cuePath;
  final String albumTitle;
  final String albumPerformer;
  final List<String> referencedAudioFiles;
  final List<CueTrackInfo> tracks;

  const CueSheet({
    required this.cuePath,
    required this.albumTitle,
    required this.albumPerformer,
    required this.referencedAudioFiles,
    required this.tracks,
  });
}

/// CUE 分轨表高精度解析器 (支持 GBK / GB18030 / UTF-8 自适应编码与母带大文件关联)
class CueSheetParser {
  static const Set<String> supportedAudioExtensions = {
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

  /// 自动解码 GBK / GB18030 / UTF-8
  static String decodeBytes(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    // Some Windows authoring tools save CUE as UTF-16 with a BOM.
    if (bytes.length >= 2 &&
        ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
            (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
      final littleEndian = bytes[0] == 0xFF;
      final data = ByteData.sublistView(bytes);
      return String.fromCharCodes([
        for (var i = 2; i + 1 < bytes.length; i += 2)
          data.getUint16(i, littleEndian ? Endian.little : Endian.big),
      ]);
    }

    // 1. 检查 UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      try {
        return utf8.decode(bytes.sublist(3));
      } catch (_) {}
    }

    // 2. 尝试标准 UTF-8
    try {
      return utf8.decode(bytes);
    } catch (_) {}

    // 3. 尝试 GBK / GB18030 (绝大多数发烧华语 CUE 均为 GBK 编码)
    try {
      return gbk.decode(bytes);
    } catch (_) {}

    // 4. 兜底 Latin-1 保证不崩溃
    return latin1.decode(bytes, allowInvalid: true);
  }

  /// 去除双引号或单引号
  static String cleanQuotedValue(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('"') && s.length >= 2) {
      final endQ = s.indexOf('"', 1);
      if (endQ != -1) return s.substring(1, endQ);
      return s.substring(1);
    }
    if (s.startsWith("'") && s.length >= 2) {
      final endQ = s.indexOf("'", 1);
      if (endQ != -1) return s.substring(1, endQ);
      return s.substring(1);
    }
    return s;
  }

  /// 清洗 CUE 中引用的音频文件名 (移除 WAVE、FLAC 等尾部类型修饰及 Windows 绝对路径)
  static String cleanAudioFilename(String raw) {
    var s = cleanQuotedValue(raw);
    final upper = s.toUpperCase();
    const keywords = [
      ' WAVE',
      ' BINARY',
      ' FLAC',
      ' MP3',
      ' AIFF',
      ' MOTOROLA'
    ];
    for (final kw in keywords) {
      if (upper.endsWith(kw)) {
        s = s.substring(0, s.length - kw.length).trim();
        s = cleanQuotedValue(s);
        break;
      }
    }

    s = s.replaceAll(r'\', '/');
    // Absolute paths from the machine that authored the CUE are not portable.
    // Relative album paths must survive folder uploads (Disc 1/CDImage.wav).
    if (p.isAbsolute(s) || RegExp(r'^[A-Za-z]:/').hasMatch(s)) {
      s = p.basename(s);
    }
    return s.trim();
  }

  /// 解析时间戳 mm:ss:ff (75 帧/秒) 为浮点秒数
  static double parseTimestamp(String timeStr) {
    final parts = timeStr.trim().split(':');
    if (parts.length == 3) {
      final mm = int.tryParse(parts[0]) ?? 0;
      final ss = int.tryParse(parts[1]) ?? 0;
      final ff = int.tryParse(parts[2]) ?? 0;
      return mm * 60.0 + ss + (ff / 75.0);
    } else if (parts.length == 2) {
      final mm = int.tryParse(parts[0]) ?? 0;
      final ss = int.tryParse(parts[1]) ?? 0;
      return mm * 60.0 + ss.toDouble();
    }
    return 0.0;
  }

  /// 关联同目录下的真实物理音频文件
  static String resolveAudioFile(
      Directory cueDir, String filename, String cueStem,
      {bool allowAlbumFallback = true}) {
    final cleanName = cleanAudioFilename(filename);

    if (cleanName.isNotEmpty) {
      // 1. 同级目录下完全匹配
      final direct = File(p.join(cueDir.path, cleanName));
      if (direct.existsSync()) return direct.path;

      // Resolve one path segment at a time for Windows CUEs on a case-sensitive
      // filesystem, including nested disc folders.
      var candidate = cueDir.path;
      var matched = true;
      for (final segment in p.split(p.normalize(cleanName))) {
        if (segment == '.') continue;
        if (segment == '..') {
          candidate = p.dirname(candidate);
          continue;
        }
        try {
          final matches = Directory(candidate)
              .listSync(followLinks: false)
              .where((entry) =>
                  p.basename(entry.path).toLowerCase() ==
                  segment.toLowerCase());
          if (matches.isEmpty) {
            matched = false;
            break;
          }
          candidate = matches.first.path;
        } catch (_) {
          matched = false;
          break;
        }
      }
      if (matched && File(candidate).existsSync()) return candidate;

      // 2. 大小写不敏感匹配
      final cleanLower = p.basename(cleanName).toLowerCase();
      try {
        final list = cueDir.listSync(followLinks: false);
        for (final item in list) {
          if (item is File) {
            final bName = p.basename(item.path);
            if (bName.toLowerCase() == cleanLower) {
              return item.path;
            }
          }
        }
      } catch (_) {}

      // 3. 同名格式转写匹配 (如 CUE 记录的是 CDImage.wav，但实际为 CDImage.flac 等)
      final targetStem = p.basenameWithoutExtension(cleanName).toLowerCase();
      try {
        final list = cueDir.listSync(followLinks: false);
        for (final item in list) {
          if (item is File) {
            final ext = p.extension(item.path).toLowerCase();
            if (supportedAudioExtensions.contains(ext)) {
              final stemLower =
                  p.basenameWithoutExtension(item.path).toLowerCase();
              if (stemLower == targetStem) {
                return item.path;
              }
            }
          }
        }
      } catch (_) {}

      // 3.5 前缀模糊匹配 (兼容 wifi 传输平铺文件名如: prefix_CDImage.wav)
      final cuePrefix = cueStem.contains('_')
          ? cueStem.substring(0, cueStem.lastIndexOf('_') + 1)
          : '';
      if (cuePrefix.isNotEmpty) {
        final prefixed = File(p.join(cueDir.path, '$cuePrefix$cleanName'));
        if (prefixed.existsSync()) return prefixed.path;
      }
    }

    // For a multi-file CUE, a missing disc/song must remain missing rather than
    // silently reusing the remaining recording as a different track.
    if (!allowAlbumFallback) return '';

    // 4. 目录内同名 CUE 关联匹配 (如 CDImage.cue 关联同目录 CDImage.wav)
    final cueStemTarget = cueStem.isEmpty ? p.basename(cueDir.path) : cueStem;
    final cueStemLower = cueStemTarget.toLowerCase();
    try {
      final list = cueDir.listSync(followLinks: false);
      for (final item in list) {
        if (item is File) {
          final ext = p.extension(item.path).toLowerCase();
          if (supportedAudioExtensions.contains(ext)) {
            final stemLower =
                p.basenameWithoutExtension(item.path).toLowerCase();
            if (stemLower == cueStemLower) {
              return item.path;
            }
          }
        }
      }
    } catch (_) {}

    // 5. 目录内单一大母带音频自适应匹配 (发烧整轨 CD 经典模式)
    try {
      final list = cueDir.listSync(followLinks: false);
      final supportedAudioFiles = <File>[];
      for (final item in list) {
        if (item is File) {
          final ext = p.extension(item.path).toLowerCase();
          if (supportedAudioExtensions.contains(ext)) {
            supportedAudioFiles.add(item);
          }
        }
      }
      if (supportedAudioFiles.length == 1) {
        return supportedAudioFiles.first.path;
      }
    } catch (_) {}

    return '';
  }

  /// 解析指定的 .cue 文件
  static CueSheet? parse(File cueFile) {
    if (!cueFile.existsSync()) return null;

    final Uint8List bytes;
    try {
      bytes = cueFile.readAsBytesSync();
    } catch (_) {
      return null;
    }

    final text = decodeBytes(bytes);
    if (text.isEmpty) return null;

    final cueDir = cueFile.parent;
    final cueStem = p.basenameWithoutExtension(cueFile.path);

    String albumTitle = '';
    String albumPerformer = '';
    final referencedFiles = <String>[];
    final parsedTracks = <CueTrackInfo>[];

    String currentFile = '';
    CueTrackInfo? currentTrack;

    final lines = const LineSplitter().convert(text);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final spIdx = trimmed.indexOf(RegExp(r'\s'));
      final cmd =
          (spIdx == -1 ? trimmed : trimmed.substring(0, spIdx)).toUpperCase();
      final rest = spIdx == -1 ? '' : trimmed.substring(spIdx).trim();

      if (cmd == 'REM') {
        continue;
      } else if (cmd == 'PERFORMER' || cmd == 'SONGWRITER') {
        final val = cleanQuotedValue(rest);
        if (currentTrack != null) {
          currentTrack = currentTrack.copyWith(performer: val);
        } else {
          albumPerformer = val;
        }
      } else if (cmd == 'TITLE') {
        final val = cleanQuotedValue(rest);
        if (currentTrack != null) {
          currentTrack = currentTrack.copyWith(title: val);
        } else {
          albumTitle = val;
        }
      } else if (cmd == 'FILE') {
        currentFile = cleanAudioFilename(rest);
        referencedFiles.add(currentFile);
      } else if (cmd == 'TRACK') {
        if (currentTrack != null) {
          parsedTracks.add(currentTrack);
        }
        final trackParts = rest.split(RegExp(r'\s+'));
        final trackNum =
            int.tryParse(trackParts.first) ?? (parsedTracks.length + 1);
        currentTrack = CueTrackInfo(
          trackNumber: trackNum,
          title: '',
          performer: albumPerformer,
          fileReference: currentFile,
          startTimeSec: 0.0,
          endTimeSec: 0.0,
          durationSec: 0,
          pregapSec: 0.0,
          resolvedAudioPath: '',
        );
      } else if (cmd == 'INDEX') {
        final idxParts = rest.split(RegExp(r'\s+'));
        if (idxParts.length >= 2 && currentTrack != null) {
          final idxNum = int.tryParse(idxParts[0]) ?? -1;
          final timeStr = idxParts[1];
          final timeSec = parseTimestamp(timeStr);
          if (idxNum == 1) {
            currentTrack = currentTrack.copyWith(startTimeSec: timeSec);
          } else if (idxNum == 0) {
            currentTrack = currentTrack.copyWith(pregapSec: timeSec);
          }
        }
      }
    }

    if (currentTrack != null) {
      parsedTracks.add(currentTrack);
    }

    if (parsedTracks.isEmpty) return null;

    if (albumTitle.isEmpty) {
      albumTitle = cueStem;
    }
    if (albumPerformer.isEmpty) {
      albumPerformer = '未知艺术家';
    }

    // 解析各音轨关联的物理音频路径
    final resolvedTracks = <CueTrackInfo>[];
    for (final trk in parsedTracks) {
      final ref = trk.fileReference.isEmpty ? currentFile : trk.fileReference;
      final resolvedPath = resolveAudioFile(cueDir, ref, cueStem,
          allowAlbumFallback: referencedFiles
                  .map((name) => name.toLowerCase())
                  .toSet()
                  .length <=
              1);
      final trkTitle =
          trk.title.isNotEmpty ? trk.title : 'Track ${trk.trackNumber}';
      final trkPerformer =
          trk.performer.isNotEmpty ? trk.performer : albumPerformer;
      resolvedTracks.add(trk.copyWith(
        title: trkTitle,
        performer: trkPerformer,
        resolvedAudioPath: resolvedPath,
      ));
    }

    // 依据 CUE 的 INDEX 精准切分时间区间
    final finalTracks = <CueTrackInfo>[];
    for (int i = 0; i < resolvedTracks.length; i++) {
      final trk = resolvedTracks[i];
      if (i + 1 < resolvedTracks.length &&
          trk.resolvedAudioPath.isNotEmpty &&
          trk.resolvedAudioPath == resolvedTracks[i + 1].resolvedAudioPath) {
        final nextTrk = resolvedTracks[i + 1];
        final nextStart = (nextTrk.pregapSec > trk.startTimeSec)
            ? nextTrk.pregapSec
            : nextTrk.startTimeSec;
        final dur = max(0.0, nextStart - trk.startTimeSec);
        finalTracks.add(trk.copyWith(
          endTimeSec: nextStart,
          durationSec: dur.round(),
        ));
      } else {
        // 最后一首或当前文件最后一个分轨
        finalTracks.add(trk.copyWith(
          endTimeSec: 0.0,
          durationSec: 0,
        ));
      }
    }

    return CueSheet(
      cuePath: cueFile.path,
      albumTitle: albumTitle,
      albumPerformer: albumPerformer,
      referencedAudioFiles: referencedFiles,
      tracks: finalTracks,
    );
  }
}
