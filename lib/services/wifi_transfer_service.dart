import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../core/app_paths.dart';
import 'music_database_service.dart';
import 'web_remote_service.dart';
import 'wifi_transfer_html.dart';

/// 记录单次通过 WiFi 上传的音乐文件信息
class UploadedMusicFile {
  final String name;
  final int sizeBytes;
  final String path;
  final DateTime timestamp;

  const UploadedMusicFile({
    required this.name,
    required this.sizeBytes,
    required this.path,
    required this.timestamp,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// WiFi 局域网拖拽无线传歌服务端 (基于 dart:io 纯标准库原生 HttpServer)
/// 1:1 严格对齐 C++ WifiTransferServer.cpp，支持拖拽无缝上传至曲库并秒级自动重新扫描入库
class WifiTransferService extends ChangeNotifier {
  static final WifiTransferService instance = WifiTransferService._();

  HttpServer? _server;
  bool get isRunning => _server != null;

  int _port = 8080;
  int get port => _port;

  String _localIp = '127.0.0.1';
  String get localIp => _localIp;

  String _targetDir = '';
  String get targetDir => _targetDir;

  final List<UploadedMusicFile> _uploadedFiles = [];
  List<UploadedMusicFile> get uploadedFiles =>
      List.unmodifiable(_uploadedFiles);
  int get completedCount => _uploadedFiles.length;

  WifiTransferService._() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _initDefaults();
    }
  }

  Future<void> _initDefaults() async {
    _localIp = await WebRemoteService.findLocalIp();
    _targetDir = _resolveDefaultMusicDir();
    notifyListeners();
  }

  /// 智能探测默认音乐存储目录
  static String _resolveDefaultMusicDir() {
    return AppPaths.musicDirectory;
  }

  Future<String> refreshIp() async {
    _localIp = await WebRemoteService.findLocalIp();
    notifyListeners();
    return _localIp;
  }

  /// 启动 WiFi 传歌 HTTP 服务 (默认端口 8080)
  Future<bool> start({int port = 8080, String? targetDir}) async {
    if (isRunning) {
      if (_port == port && (targetDir == null || targetDir == _targetDir)) {
        return true;
      }
      await stop();
    }

    _port = port;
    _localIp = await WebRemoteService.findLocalIp();
    _targetDir = Platform.isIOS
        ? AppPaths.musicDirectory
        : ((targetDir != null && targetDir.isNotEmpty)
            ? targetDir
            : _resolveDefaultMusicDir());

    // 确保目标目录存在
    try {
      final dir = Directory(_targetDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (e) {
      debugPrint('[WifiTransferService] 创建存储目录失败: $e');
      return false;
    }

    try {
      _server =
          await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
      _port = _server!.port;
      debugPrint(
          '[WifiTransferService] 服务已启动: http://$_localIp:$_port (存储: $_targetDir)');

      _server!.listen(
        _handleHttpRequest,
        onError: (err) {
          debugPrint('[WifiTransferService] HttpServer 错误: $err');
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[WifiTransferService] 启动失败: $e');
      _server = null;
      notifyListeners();
      return false;
    }
  }

  /// 停止 WiFi 传歌服务
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      debugPrint('[WifiTransferService] 服务已停止');
    }
    notifyListeners();
  }

  /// 清空当前会话传输记录
  void clearTransferHistory() {
    _uploadedFiles.clear();
    notifyListeners();
  }

  /// 处理 HTTP 请求
  void _handleHttpRequest(HttpRequest request) async {
    // 设置通用跨域头部
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers
        .set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, HEAD');
    request.response.headers.set('Access-Control-Allow-Headers', '*');

    // OPTIONS 预检请求 (现代浏览器拖拽上传前必查)
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    // 1. GET / 或 /index.html: 返回 H5 拖拽传歌网页 (同时兼容 HEAD 请求)
    if ((request.method == 'GET' || request.method == 'HEAD') &&
        (path == '/' || path == '/index.html')) {
      final platformLabel = Platform.isIOS
          ? 'iPhone'
          : (Platform.isMacOS ? 'Mac' : (Platform.isLinux ? '树莓派' : 'HiFi主机'));
      final html = wifiTransferHtml.replaceAll('{{PLATFORM}}', platformLabel);

      request.response.headers.contentType = ContentType.html;
      if (request.method == 'GET') {
        request.response.write(html);
      }
      await request.response.close();
      return;
    }

    // 2. GET /api/status: 查询传歌服务状态
    if (request.method == 'GET' && path == '/api/status') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'running',
        'port': _port,
        'dir': _targetDir,
        'completed': completedCount,
      }));
      await request.response.close();
      return;
    }

    // 3. POST /upload: 接收音频二进制数据流
    if (request.method == 'POST' && path.startsWith('/upload')) {
      await _handleFileUpload(request);
      return;
    }

    // 未知路径 404
    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not Found');
    await request.response.close();
  }

  @visibleForTesting
  static String? normalizeUploadPath(String filename) {
    // queryParameters has already decoded the filename exactly once.
    final normalized = filename.replaceAll(r'\', '/');
    if (normalized.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
        normalized.contains('\u0000')) {
      return null;
    }
    final parts = normalized.split('/');
    if (parts.any((part) => part == '..')) return null;
    final safeParts = parts
        .where((part) => part.isNotEmpty && part != '.')
        .map((part) => part.replaceAll(RegExp(r'[:*?"<>|]'), '_').trim())
        .toList();
    if (safeParts.isEmpty ||
        safeParts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      return null;
    }
    if (safeParts.any((part) => part.toLowerCase() == 'hifi_player') ||
        safeParts.last.toLowerCase().endsWith('.db') ||
        safeParts.last.toLowerCase().endsWith('.db-wal') ||
        safeParts.last.toLowerCase().endsWith('.db-shm')) {
      return null;
    }
    return p.joinAll(safeParts);
  }

  int _uploadSerial = 0;

  /// Receive each upload under the same public music root, retaining album
  /// folders so CUE references and duplicate CDImage.wav names remain intact.
  Future<void> _handleFileUpload(HttpRequest request) async {
    final queryName = request.uri.queryParameters['filename'];
    String filename = queryName ?? '';
    if (filename.isEmpty) {
      final headerName = request.headers.value('x-filename');
      if (headerName != null) {
        try {
          filename = Uri.decodeComponent(headerName);
        } catch (_) {
          filename = headerName;
        }
      }
    }
    filename = filename.isEmpty
        ? 'track_${DateTime.now().millisecondsSinceEpoch}.flac'
        : filename;
    final relativePath = normalizeUploadPath(filename);
    if (relativePath == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response
          .write(jsonEncode({'status': 'error', 'message': '无效的相对文件路径'}));
      await request.response.close();
      return;
    }

    final root = Directory(_targetDir).absolute;
    final finalFile = File(p.join(root.path, relativePath));
    final tempFile = File(
        '${finalFile.path}.${DateTime.now().microsecondsSinceEpoch}.${_uploadSerial++}.part');
    IOSink? sink;
    try {
      await root.create(recursive: true);
      var component = root.path;
      for (final part in p.split(relativePath)) {
        component = p.join(component, part);
        if (FileSystemEntity.isLinkSync(component)) {
          throw const FileSystemException('传歌路径不能包含符号链接');
        }
      }
      if (FileSystemEntity.isDirectorySync(finalFile.path)) {
        throw const FileSystemException('目标路径是文件夹');
      }
      await finalFile.parent.create(recursive: true);
      sink = tempFile.openWrite();
      int totalBytes = 0;
      await for (final chunk in request) {
        sink.add(chunk);
        totalBytes += chunk.length;
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (totalBytes == 0) {
        await tempFile.delete();
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response
            .write(jsonEncode({'status': 'error', 'message': '上传内容为空 (0 字节)'}));
        await request.response.close();
        return;
      }
      // On iOS/POSIX, rename atomically replaces an existing regular file.
      // Never delete the user's original before the complete upload is ready.
      await tempFile.rename(finalFile.path);
      _uploadedFiles.insert(
          0,
          UploadedMusicFile(
            name: relativePath,
            sizeBytes: totalBytes,
            path: finalFile.path,
            timestamp: DateTime.now(),
          ));
      notifyListeners();

      String? scanError;
      try {
        await MusicDatabaseService.instance.scanLibrary(customPath: _targetDir);
      } catch (error) {
        scanError = error.toString();
        debugPrint('[WifiTransferService] 文件已保存，扫描失败: $error');
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'ok',
        'filename': relativePath,
        'bytes': totalBytes,
        'indexed': scanError == null,
        if (scanError != null) 'scan_error': scanError,
      }));
      await request.response.close();
    } catch (error) {
      debugPrint('[WifiTransferService] 写入文件失败: $error');
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response
          .write(jsonEncode({'status': 'error', 'message': '文件写入失败: $error'}));
      await request.response.close();
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
