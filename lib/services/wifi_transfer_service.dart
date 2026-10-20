import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/app_paths.dart';
import '../core/platform_helper.dart';
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

  /// 智能探测默认音乐存储目录 (严格遵循 AppPaths.musicDirectory，保障 iOS/iPadOS 沙盒写权限与曲库即传即播)
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
      _server!.idleTimeout = const Duration(minutes: 15);
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

  /// 处理 HTTP 请求
  void _handleHttpRequest(HttpRequest request) async {
    // 设置通用跨域头部
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
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
      final platformLabel = PlatformHelper.isIpad
          ? 'iPad'
          : (PlatformHelper.isMac
              ? 'Mac'
              : (PlatformHelper.isPi ? '树莓派' : (Platform.isAndroid ? 'Android' : 'HiFi主机')));
      final platformTitle = PlatformHelper.isPi ? 'PiHiFi' : 'MyHiFi';
      final html = wifiTransferHtml
          .replaceAll('{{PLATFORM}}', platformLabel)
          .replaceAll('{{PLATFORM_LABEL}}', platformLabel)
          .replaceAll('{{PLATFORM_TITLE}}', platformTitle);

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

    // 3. GET /upload_status: 查询特定文件上传与断点续传状态
    if (request.method == 'GET' && path.startsWith('/upload_status')) {
      await _handleUploadStatus(request);
      return;
    }

    // 4. POST /upload_chunk: 分片流式接收超大无损母带/镜像 (断点续传与抗弱网)
    if (request.method == 'POST' && path.startsWith('/upload_chunk')) {
      await _handleChunkUpload(request);
      return;
    }

    // 5. POST /upload: 接收单次音频二进制数据流
    if (request.method == 'POST' && path.startsWith('/upload')) {
      await _handleFileUpload(request);
      return;
    }

    // 未知路径 404
    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not Found');
    await request.response.close();
  }

  /// 查询特定文件当前传输状态 (支持断点续传秒验与同名大小一致去重)
  Future<void> _handleUploadStatus(HttpRequest request) async {
    final query = request.uri.queryParameters;
    String filename = query['filename'] ?? '';
    try {
      filename = Uri.decodeComponent(filename);
    } catch (_) {}
    filename = filename
        .replaceAll('/', '_')
        .replaceAll(r'\', '_')
        .replaceAll('..', '_')
        .trim();

    final targetDir = Directory(_targetDir);
    final tempFile = File('${targetDir.path}/$filename.part');
    final finalFile = File('${targetDir.path}/$filename');

    final int clientSize = int.tryParse(query['size'] ?? query['totalBytes'] ?? '') ?? 0;
    final bool exists = finalFile.existsSync();
    final int finalBytes = exists ? finalFile.lengthSync() : 0;
    final bool hasPartial = tempFile.existsSync();
    final int partialBytes = hasPartial ? tempFile.lengthSync() : 0;

    // 🌟 用户需求：同名且文件大小完全一致，判定已存在，跳过重新写入
    final bool alreadyExists = exists && clientSize > 0 && finalBytes == clientSize;

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'status': 'ok',
      'filename': filename,
      'exists': exists,
      'alreadyExists': alreadyExists,
      'finalBytes': finalBytes,
      'hasPartial': hasPartial,
      'partialBytes': partialBytes,
      'message': alreadyExists ? '文件已存在且大小一致，跳过写入' : null,
    }));
    await request.response.close();
  }

  /// 分片流式接收超大音频文件 (WAV/DSD/ISO/FLAC)
  Future<void> _handleChunkUpload(HttpRequest request) async {
    final query = request.uri.queryParameters;
    String filename = 'uploaded_track.flac';
    final queryName = query['filename'];
    if (queryName != null && queryName.isNotEmpty) {
      try {
        filename = Uri.decodeComponent(queryName);
      } catch (_) {
        filename = queryName;
      }
    }

    // 文件名安全过滤 (防路径穿越)
    filename = filename
        .replaceAll('/', '_')
        .replaceAll(r'\', '_')
        .replaceAll('..', '_')
        .trim();
    if (filename.isEmpty) {
      filename = 'track_${DateTime.now().millisecondsSinceEpoch}.flac';
    }

    final chunkIndex = int.tryParse(query['chunk'] ?? '0') ?? 0;
    final totalChunks = int.tryParse(query['totalChunks'] ?? '1') ?? 1;
    final totalBytes = int.tryParse(query['totalBytes'] ?? '0') ?? 0;
    final chunkSize = int.tryParse(query['chunkSize'] ?? '0') ?? 0;
    final explicitOffset = int.tryParse(query['offset'] ?? '');
    final offset = explicitOffset ?? (chunkIndex * chunkSize);

    final targetDir = Directory(_targetDir);
    if (!targetDir.existsSync()) {
      try {
        targetDir.createSync(recursive: true);
      } catch (_) {}
    }

    final tempFile = File('${targetDir.path}/$filename.part');
    final finalFile = File('${targetDir.path}/$filename');

    // 🌟 用户需求：如果已存在同名且大小完全一样的文件，跳过写入，避免重复写入
    if (finalFile.existsSync() && totalBytes > 0 && finalFile.lengthSync() == totalBytes) {
      if (tempFile.existsSync()) {
        try { tempFile.deleteSync(); } catch (_) {}
      }
      debugPrint('[WifiTransferService] 检测到同名且大小一致的文件，跳过写入: $filename ($totalBytes bytes)');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'ok',
        'completed': true,
        'skipped': true,
        'filename': filename,
        'bytes': totalBytes,
        'message': '文件已存在且大小完全一致，已跳过写入',
      }));
      await request.response.close();
      return;
    }

    try {
      // 仅在明确传入 reset=true 或全新第0分片且未指定 offset 时清理历史残余
      if (query['reset'] == 'true' || (offset == 0 && chunkIndex == 0 && query['offset'] == null)) {
        if (tempFile.existsSync()) {
          try {
            tempFile.deleteSync();
          } catch (_) {}
        }
      }

      if (!tempFile.existsSync()) {
        tempFile.createSync(recursive: true);
      }

      // 使用 RandomAccessFile 准确定位写入，保障断点重试不发生字节错位或尾部虚增
      final raf = await tempFile.open(mode: FileMode.writeOnly);
      if (offset > 0) {
        await raf.setPosition(offset);
      }

      int chunkBytes = 0;
      await for (final chunk in request) {
        await raf.writeFrom(chunk);
        chunkBytes += chunk.length;
      }
      await raf.flush();
      await raf.close();

      final currentPartSize = tempFile.existsSync() ? tempFile.lengthSync() : 0;
      final isLastChunk = (chunkIndex >= totalChunks - 1) || (totalBytes > 0 && currentPartSize >= totalBytes);

      if (isLastChunk) {
        // 覆盖旧文件 (如有同名)
        if (finalFile.existsSync()) {
          try {
            finalFile.deleteSync();
          } catch (_) {}
        }
        await tempFile.rename(finalFile.path);

        final actualSize = finalFile.existsSync() ? finalFile.lengthSync() : totalBytes;
        final record = UploadedMusicFile(
          name: filename,
          sizeBytes: actualSize,
          path: finalFile.path,
          timestamp: DateTime.now(),
        );
        _uploadedFiles.insert(0, record);
        notifyListeners();

        debugPrint('[WifiTransferService] 分片全部完成: $filename ($actualSize bytes) -> ${finalFile.path}');

        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'status': 'ok',
          'completed': true,
          'filename': filename,
          'bytes': actualSize,
        }));
        await request.response.close();

        // 异步入库扫描
        unawaited(MusicDatabaseService.instance.scanLibrary());
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'status': 'ok',
          'completed': false,
          'chunk': chunkIndex,
          'offset': offset,
          'bytes': chunkBytes,
          'currentSize': currentPartSize,
        }));
        await request.response.close();
      }
    } catch (e) {
      debugPrint('[WifiTransferService] 分片写入失败: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'error',
        'message': '分片写入失败: $e',
      }));
      await request.response.close();
    }
  }

  /// 接收并落地单次上传音频文件二进制流
  Future<void> _handleFileUpload(HttpRequest request) async {
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

    // 文件名安全过滤 (防路径穿越)
    filename = filename
        .replaceAll('/', '_')
        .replaceAll(r'\', '_')
        .replaceAll('..', '_')
        .trim();
    if (filename.isEmpty) {
      filename = 'track_${DateTime.now().millisecondsSinceEpoch}.flac';
    }

    final targetDir = Directory(_targetDir);
    if (!targetDir.existsSync()) {
      try {
        targetDir.createSync(recursive: true);
      } catch (_) {}
    }

    final tempFile = File('${targetDir.path}/$filename.part');
    final finalFile = File('${targetDir.path}/$filename');

    // 🌟 用户需求：单流上传同名同大小去重跳过
    final reqLen = request.contentLength;
    if (finalFile.existsSync() && reqLen > 0 && finalFile.lengthSync() == reqLen) {
      await request.drain();
      debugPrint('[WifiTransferService] 单流上传：文件已存在且大小一致，跳过写入: $filename');
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'ok',
        'completed': true,
        'skipped': true,
        'filename': filename,
        'bytes': reqLen,
        'message': '文件已存在且大小完全一致，已跳过写入',
      }));
      await request.response.close();
      return;
    }

    try {
      final sink = tempFile.openWrite();
      int totalBytes = 0;

      await sink.addStream(request.map((chunk) {
        totalBytes += chunk.length;
        return chunk;
      }));

      await sink.flush();
      await sink.close();

      // 覆盖旧文件 (如有同名)
      if (finalFile.existsSync()) {
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

      debugPrint('[WifiTransferService] 文件上传成功: $filename ($totalBytes bytes) -> ${finalFile.path}');

      // 立即向客户端返回 200 OK 确认响应，解除前端等待
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'ok',
        'filename': filename,
        'bytes': totalBytes,
      }));
      await request.response.close();

      // 核心发烧特性：即传即入库！在响应发送完成后，异步触发全盘扫描，彻底杜绝客户端阻塞或超时
      unawaited(MusicDatabaseService.instance.scanLibrary());
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
