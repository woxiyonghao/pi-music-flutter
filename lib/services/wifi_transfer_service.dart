import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
  List<UploadedMusicFile> get uploadedFiles => List.unmodifiable(_uploadedFiles);
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
    _targetDir = (targetDir != null && targetDir.isNotEmpty)
        ? targetDir
        : _resolveDefaultMusicDir();

    // 确保目标目录存在
    try {
      final dir = Directory(_targetDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (e) {
      debugPrint('[WifiTransferService] 创建存储目录失败: $e');
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
      debugPrint('[WifiTransferService] 服务已启动: http://$_localIp:$_port (存储: $_targetDir)');

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

  Future<String> refreshIp() async {
    _localIp = await WebRemoteService.findLocalIp();
    notifyListeners();
    return _localIp;
  }

  /// 处理 HTTP 请求
  void _handleHttpRequest(HttpRequest request) async {
    // 设置通用跨域头部
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, HEAD');
    request.response.headers.set('Access-Control-Allow-Headers', '*');
    request.response.headers.set('Access-Control-Max-Age', '86400');

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
          ? 'iPad'
          : (Platform.isMacOS
              ? 'Mac'
              : (Platform.isLinux ? '树莓派' : 'HiFi主机'));
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

  /// 接收并落地音乐文件二进制流
  Future<void> _handleFileUpload(HttpRequest request) async {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, HEAD');
    request.response.headers.set('Access-Control-Allow-Headers', '*');

    // 解析文件名
    String filename = 'uploaded_track.flac';
    final queryName = request.uri.queryParameters['filename'];
    if (queryName != null && queryName.isNotEmpty) {
      try {
        filename = Uri.decodeComponent(queryName);
      } catch (_) {
        filename = queryName;
      }
    } else {
      final headerName = request.headers.value('x-filename');
      if (headerName != null && headerName.isNotEmpty) {
        try {
          filename = Uri.decodeComponent(headerName);
        } catch (_) {
          filename = headerName;
        }
      } else {
        filename = 'track_${DateTime.now().millisecondsSinceEpoch}.flac';
      }
    }

    // 安全规范化相对路径与目录结构 (防路径穿越 ../ 并支持保留无损专辑子目录)
    final parts = filename.split(RegExp(r'[/\\]'));
    final safeParts = <String>[];
    for (final seg in parts) {
      final s = seg.trim();
      if (s.isEmpty || s == '.' || s == '..') continue;
      safeParts.add(s.replaceAll(RegExp(r'[:*?"<>|]'), '_'));
    }
    final relativePath = safeParts.isNotEmpty
        ? safeParts.join(Platform.pathSeparator)
        : 'track_${DateTime.now().millisecondsSinceEpoch}.flac';

    final targetDir = Directory(_targetDir);
    if (!targetDir.existsSync()) {
      try {
        targetDir.createSync(recursive: true);
      } catch (_) {}
    }

    var finalFile = File('${targetDir.path}/$relativePath');
    final tempFile = File('${finalFile.path}.part');

    if (!finalFile.parent.existsSync()) {
      try {
        finalFile.parent.createSync(recursive: true);
      } catch (_) {}
    }

    // 避免与同名子目录冲突
    if (FileSystemEntity.isDirectorySync(finalFile.path)) {
      finalFile = File('${finalFile.path}_audio.flac');
    }

    try {
      final sink = tempFile.openWrite();
      int totalBytes = 0;

      await for (final chunk in request) {
        sink.add(chunk);
        totalBytes += chunk.length;
      }

      await sink.flush();
      await sink.close();

      // 空文件防入库拦截
      if (totalBytes == 0) {
        if (tempFile.existsSync()) {
          try { tempFile.deleteSync(); } catch (_) {}
        }
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'status': 'error',
          'message': '上传内容为空 (0 字节)',
        }));
        await request.response.close();
        return;
      }

      // 覆盖旧文件 (如有同名普通文件)
      if (finalFile.existsSync() && !FileSystemEntity.isDirectorySync(finalFile.path)) {
        try {
          finalFile.deleteSync();
        } catch (_) {}
      }
      await tempFile.rename(finalFile.path);

      // 记录到已上传列表中
      final record = UploadedMusicFile(
        name: filename,
        sizeBytes: totalBytes,
        path: finalFile.path,
        timestamp: DateTime.now(),
      );
      _uploadedFiles.insert(0, record);
      notifyListeners();

      // 核心发烧特性：即传即入库！自动触发 MusicDatabaseService 真正扫描落盘文件入库
      await MusicDatabaseService.instance.scanLibrary();

      debugPrint('[WifiTransferService] 文件上传成功: $filename ($totalBytes bytes) -> ${finalFile.path}');

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'ok',
        'filename': filename,
        'bytes': totalBytes,
      }));
      await request.response.close();
    } catch (e) {
      debugPrint('[WifiTransferService] 写入文件失败: $e');
      try {
        if (tempFile.existsSync()) tempFile.deleteSync();
      } catch (_) {}

      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'error',
        'message': '文件写入失败: $e',
      }));
      await request.response.close();
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
