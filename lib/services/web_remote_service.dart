import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/app_paths.dart';
import '../core/hifi_audio_bindings.dart';
import '../core/hifi_audio_service.dart';
import '../models/playback_state.dart';
import '../models/track.dart';
import 'dac_setting_service.dart';
import 'mseb_service.dart';
import 'music_database_service.dart';
import 'pi_system_service.dart';
import 'theme_service.dart';
import 'web_remote_html.dart';

/// Web 远程遥控服务端 (基于 dart:io 纯标准库原生 HttpServer 与 WebSocket)
/// 1:1 严格对齐 C++ WebService.cpp，支持多端移动端/桌面端浏览器实时毫秒级双向遥控
class WebRemoteService extends ChangeNotifier {
  static final WebRemoteService instance = WebRemoteService._();

  HttpServer? _server;
  bool get isRunning => _server != null;

  int _port = 8088;
  int get port => _port;

  String _localIp = '127.0.0.1';
  String get localIp => _localIp;

  final Set<WebSocket> _clients = {};
  int get clientCount => _clients.length;

  Timer? _broadcastTimer;

  WebRemoteService._() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _initLocalIp();
    }
  }

  Future<void> _initLocalIp() async {
    _localIp = await findLocalIp();
    notifyListeners();
  }

  /// 探测局域网真实 IPv4 地址 (过滤 127.0.0.1 回环与 169.254.* 链路本地地址)
  static Future<String> findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // 优先选择常用物理网卡 en0 (Wi-Fi/Ethernet), eth0, wlan0
      interfaces.sort((a, b) {
        final aPref = (a.name == 'en0' || a.name == 'eth0' || a.name == 'wlan0') ? 0 : 1;
        final bPref = (b.name == 'en0' || b.name == 'eth0' || b.name == 'wlan0') ? 0 : 1;
        return aPref.compareTo(bPref);
      });

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (!addr.isLoopback && !ip.startsWith('127.') && !ip.startsWith('169.254.')) {
            return ip;
          }
        }
      }
    } catch (e) {
      debugPrint('[WebRemoteService] 获取局域网 IP 异常: $e');
    }
    return '127.0.0.1';
  }

  Future<String> refreshIp() async {
    _localIp = await findLocalIp();
    notifyListeners();
    return _localIp;
  }

  /// 启动 Web 远程遥控服务 (默认端口 8088)
  Future<bool> start({int port = 8088}) async {
    if (isRunning) {
      if (_port == port) return true;
      await stop();
    }

    _port = port;
    _localIp = await findLocalIp();

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
      debugPrint('[WebRemoteService] 服务已启动: http://$_localIp:$_port (监听 0.0.0.0:$_port)');

      _server!.listen(
        _handleHttpRequest,
        onError: (err) {
          debugPrint('[WebRemoteService] HttpServer 错误: $err');
        },
      );

      _startBroadcastTimer();
      DacSettingService.instance.onBroadcastNeeded = broadcastDac;
      PiSystemService.instance.addListener(broadcastState);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[WebRemoteService] 启动失败: $e');
      _server = null;
      notifyListeners();
      return false;
    }
  }

  /// 停止 Web 远程遥控服务
  Future<void> stop() async {
    DacSettingService.instance.onBroadcastNeeded = null;
    PiSystemService.instance.removeListener(broadcastState);
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    for (final ws in _clients) {
      try {
        ws.close(WebSocketStatus.goingAway, 'Server stopping');
      } catch (_) {}
    }
    _clients.clear();

    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      debugPrint('[WebRemoteService] 服务已停止');
    }

    notifyListeners();
  }

  /// 周期性广播 (每 200ms 广播播放器状态与频谱，有客户端在线且在播放时触发)
  void _startBroadcastTimer() {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!isRunning || _clients.isEmpty) return;

      final isPlaying = HifiAudioService.instance.state.isPlaying;
      if (isPlaying) {
        broadcastState();
      }
    });
  }

  /// 处理 HTTP 请求与 WebSocket 握手升级
  void _handleHttpRequest(HttpRequest request) async {
    // 设置通用跨域头部
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    // 判断是否为 WebSocket 握手请求
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        _handleWebSocketClient(socket);
      } catch (e) {
        debugPrint('[WebRemoteService] WebSocket 升级失败: $e');
      }
      return;
    }

    final path = request.uri.path;

    // 1. GET / 或 /index.html: 返回内嵌 H5 SPA 控制中心 (同时兼容 HEAD 请求)
    if ((request.method == 'GET' || request.method == 'HEAD') &&
        (path == '/' || path == '/index.html')) {
      request.response.headers.contentType = ContentType.html;
      if (request.method == 'GET') {
        request.response.write(webRemoteHtml);
      }
      await request.response.close();
      return;
    }

    // 2. GET /api/status: 获取全局播放器状态
    if (request.method == 'GET' && path == '/api/status') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_buildStateMap()));
      await request.response.close();
      return;
    }

    // 3. GET /api/queue: 获取当前播放队列
    if (request.method == 'GET' && path == '/api/queue') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_buildQueueMap()));
      await request.response.close();
      return;
    }

    // 4. GET /api/playlists: 获取歌单列表
    if (request.method == 'GET' && path == '/api/playlists') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_buildPlaylistsMap()));
      await request.response.close();
      return;
    }

    // 5. GET /api/library: 获取曲库清单
    if (request.method == 'GET' && path == '/api/library') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_buildLibraryMap()));
      await request.response.close();
      return;
    }

    // 5.1 GET /api/debug: 诊断内部路径与音频引擎状态
    if (request.method == 'GET' && path == '/api/debug') {
      final audio = HifiAudioService.instance;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'load_error': HifiAudioBindings.instance.loadError,
        'is_loaded': HifiAudioBindings.instance.isLoaded,
        'last_debug_log': audio.lastDebugLog,
        'documents_dir': AppPaths.documentsDirectory,
        'music_dir': AppPaths.musicDirectory,
        'tracks_count': MusicDatabaseService.instance.tracks.length,
        'first_track_path': MusicDatabaseService.instance.tracks.isNotEmpty ? MusicDatabaseService.instance.tracks.first.filepath : '',
        'resolved_first_path': MusicDatabaseService.instance.tracks.isNotEmpty ? MusicDatabaseService.resolveTrackPath(MusicDatabaseService.instance.tracks.first.filepath) : '',
        'first_exists': MusicDatabaseService.instance.tracks.isNotEmpty ? File(MusicDatabaseService.resolveTrackPath(MusicDatabaseService.instance.tracks.first.filepath)).existsSync() : false,
      }));
      await request.response.close();
      return;
    }

    // 5.2 GET /api/system_info: 平台硬件与 ALSA 拓扑直通状态
    if (request.method == 'GET' && path == '/api/system_info') {
      final piSys = PiSystemService.instance;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'platform': Platform.operatingSystem,
        'platform_name': Platform.isLinux ? '树莓派 5' : (Platform.isIOS ? 'iPad' : 'macOS'),
        'temperature': piSys.socTemperature,
        'temp_color': piSys.tempColorHex,
        'dac_device': Platform.isLinux ? piSys.dacDeviceName : DacSettingService.instance.dacName,
        'alsa_card': piSys.alsaCard,
        'detected_alsa_devices': piSys.getDetectedAlsaDevices(),
        'screensaver_timeout': piSys.screenSaverTimeoutMinutes,
      }));
      await request.response.close();
      return;
    }

    // 6. REST API 控制指令 (POST /api/...)
    if (request.method == 'POST') {
      final audio = HifiAudioService.instance;
      if (path == '/api/play') {
        final db = MusicDatabaseService.instance;
        final id = int.tryParse(request.uri.queryParameters['id'] ?? '');
        final idx = int.tryParse(request.uri.queryParameters['index'] ?? '');
        if (id != null) {
          final tIdx = db.tracks.indexWhere((t) => t.id == id);
          if (tIdx != -1) {
            audio.playTracks(db.tracks, tIdx);
          } else {
            audio.play();
          }
        } else if (idx != null && idx >= 0 && idx < db.tracks.length) {
          audio.playTracks(db.tracks, idx);
        } else {
          if (audio.playlistQueue.isEmpty && db.tracks.isNotEmpty) {
            audio.playTracks(db.tracks, 0);
          } else {
            audio.play();
          }
        }
      } else if (path == '/api/pause') {
        audio.pause();
      } else if (path == '/api/toggle') {
        audio.togglePlayPause();
      } else if (path == '/api/next') {
        audio.next();
      } else if (path == '/api/prev') {
        audio.previous();
      } else if (path == '/api/mode') {
        audio.cyclePlayMode();
      } else if (path == '/api/mute') {
        audio.toggleMute();
      } else if (path == '/api/seek') {
        final val = double.tryParse(request.uri.queryParameters['value'] ?? '');
        if (val != null) audio.seek(val);
      } else if (path == '/api/volume') {
        final val = double.tryParse(request.uri.queryParameters['value'] ?? '');
        if (val != null) audio.setVolume(val);
      } else if (path == '/api/theme') {
        final id = int.tryParse(request.uri.queryParameters['id'] ?? '');
        if (id != null) ThemeService.instance.setTheme(id);
      } else if (path == '/api/visual_mode') {
        final id = int.tryParse(request.uri.queryParameters['id'] ?? '');
        if (id != null) ThemeService.instance.setBackgroundVisualMode(id);
      } else if (path == '/api/eq') {
        final en = request.uri.queryParameters['enabled'];
        if (en != null) audio.setEqEnabled(en == 'true' || en == '1');
      } else if (path == '/api/scan') {
        await MusicDatabaseService.instance.scanLibrary();
        _broadcast(jsonEncode(_buildLibraryMap()));
        _broadcast(jsonEncode(_buildQueueMap()));
      }

      broadcastState();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'ok'}));
      await request.response.close();
      return;
    }

    // 未知路径 404
    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not Found');
    await request.response.close();
  }

  /// 处理接入的 WebSocket 客户端连接
  void _handleWebSocketClient(WebSocket socket) {
    _clients.add(socket);
    notifyListeners();

    // 客户端连入时，立即全量同步一次当前播放状态、队列、歌单、曲库、DAC和MSEB参数
    try {
      socket.add(jsonEncode(_buildStateMap()));
      socket.add(jsonEncode(_buildQueueMap()));
      socket.add(jsonEncode(_buildPlaylistsMap()));
      socket.add(jsonEncode(_buildLibraryMap()));
      socket.add(jsonEncode(_buildDacMap()));
      socket.add(jsonEncode(_buildMsebMap()));
    } catch (_) {}

    socket.listen(
      (data) {
        if (data is String) {
          _processClientCommand(data, socket);
        }
      },
      onDone: () {
        _clients.remove(socket);
        notifyListeners();
      },
      onError: (_) {
        _clients.remove(socket);
        notifyListeners();
      },
      cancelOnError: true,
    );
  }

  /// 分发客户端下发的遥控动作 (1:1 严格对齐 C++ WebService 动作表)
  void _processClientCommand(String rawJson, WebSocket socket) async {
    try {
      final cmd = jsonDecode(rawJson) as Map<String, dynamic>;
      final action = cmd['action'] as String? ?? '';
      final audio = HifiAudioService.instance;
      final db = MusicDatabaseService.instance;

      switch (action) {
        case 'play':
          audio.play();
          broadcastState();
          break;
        case 'pause':
          audio.pause();
          broadcastState();
          break;
        case 'toggle':
          audio.togglePlayPause();
          broadcastState();
          break;
        case 'next':
          audio.next();
          broadcastState();
          break;
        case 'prev':
          audio.previous();
          broadcastState();
          break;
        case 'mode':
          audio.cyclePlayMode();
          broadcastState();
          break;
        case 'mute':
          audio.toggleMute();
          broadcastState();
          break;
        case 'seek':
          final val = (cmd['value'] as num?)?.toDouble();
          if (val != null) audio.seek(val);
          broadcastState();
          break;
        case 'volume':
          final val = (cmd['value'] as num?)?.toDouble();
          if (val != null) audio.setVolume(val);
          broadcastState();
          break;
        case 'play_library_index':
          final idx = (cmd['index'] as num?)?.toInt() ?? -1;
          if (idx >= 0 && idx < db.tracks.length) {
            audio.playTracks(db.tracks, idx);
            _broadcast(jsonEncode(_buildQueueMap()));
            broadcastState();
          }
          break;
        case 'play_queue_index':
          final idx = (cmd['index'] as num?)?.toInt() ?? -1;
          if (idx >= 0 && idx < audio.playlistQueue.length) {
            audio.playTrack(audio.playlistQueue[idx], audio.playlistQueue, idx);
            _broadcast(jsonEncode(_buildQueueMap()));
            broadcastState();
          }
          break;
        case 'remove_queue_index':
          final idx = (cmd['index'] as num?)?.toInt() ?? -1;
          if (idx >= 0 && idx < audio.playlistQueue.length) {
            audio.removeFromQueue(idx);
            _broadcast(jsonEncode(_buildQueueMap()));
          }
          break;
        case 'clear_queue':
          audio.clearQueue();
          _broadcast(jsonEncode(_buildQueueMap()));
          break;
        case 'add_to_queue':
          final id = (cmd['id'] as num?)?.toInt();
          if (id != null) {
            final t = db.tracks.cast<Track?>().firstWhere((item) => item?.id == id, orElse: () => null);
            if (t != null) {
              audio.addToQueue(t);
              _broadcast(jsonEncode(_buildQueueMap()));
            }
          }
          break;
        case 'create_playlist':
          final name = cmd['name'] as String? ?? '';
          if (name.trim().isNotEmpty) {
            db.createPlaylist(name.trim());
            _broadcast(jsonEncode(_buildPlaylistsMap()));
          }
          break;
        case 'get_library':
          socket.add(jsonEncode(_buildLibraryMap()));
          break;
        case 'get_queue':
          socket.add(jsonEncode(_buildQueueMap()));
          break;
        case 'get_playlists':
          socket.add(jsonEncode(_buildPlaylistsMap()));
          break;
        case 'start_scan':
          await db.scanLibrary();
          _broadcast(jsonEncode(_buildLibraryMap()));
          _broadcast(jsonEncode(_buildQueueMap()));
          broadcastState();
          break;
        case 'set_theme':
          final tid = (cmd['theme_id'] as num?)?.toInt();
          if (tid != null) {
            ThemeService.instance.setTheme(tid);
            broadcastState();
          }
          break;
        case 'set_visual_mode':
          final mode = (cmd['mode'] as num?)?.toInt();
          if (mode != null) {
            ThemeService.instance.setBackgroundVisualMode(mode);
            broadcastState();
          }
          break;
        case 'set_eq_enabled':
          final en = cmd['enabled'] as bool? ?? false;
          audio.setEqEnabled(en);
          broadcastState();
          break;
        case 'set_eq_band':
          final idx = (cmd['index'] as num?)?.toInt();
          final val = (cmd['value'] as num?)?.toDouble() ?? (cmd['gain'] as num?)?.toDouble();
          if (idx != null && val != null) {
            audio.setEqBand(idx, val);
            audio.setEqEnabled(true);
            broadcastState();
          }
          break;
        case 'reset_eq':
          audio.resetEq();
          broadcastState();
          break;
        case 'set_eq_preset':
          final bandsRaw = cmd['bands'] as List?;
          if (bandsRaw != null && bandsRaw.length == 10) {
            final bands = bandsRaw.map((e) => (e as num).toDouble()).toList();
            audio.setEqBands(bands);
            audio.setEqEnabled(true);
            broadcastState();
          }
          break;
        case 'set_mseb_enabled':
          final en = cmd['enabled'] as bool? ?? false;
          MsebService.instance.setEnabled(en);
          broadcastMseb();
          broadcastState();
          break;
        case 'set_mseb_param':
          final idx = (cmd['index'] as num?)?.toInt();
          final val = (cmd['value'] as num?)?.toDouble() ?? (cmd['gain'] as num?)?.toDouble();
          if (idx != null && val != null) {
            MsebService.instance.setParam(idx, val);
            MsebService.instance.setEnabled(true);
            broadcastMseb();
            broadcastState();
          }
          break;
        case 'reset_mseb':
          MsebService.instance.resetAll();
          broadcastMseb();
          broadcastState();
          break;
        case 'play_playlist':
          final pid = (cmd['id'] as num?)?.toInt();
          if (pid != null) {
            final pl = db.playlists.cast<Playlist?>().firstWhere(
              (p) => p?.id == pid,
              orElse: () => null,
            );
            if (pl != null && pl.tracks.isNotEmpty) {
              audio.playTracks(pl.tracks, 0);
              _broadcast(jsonEncode(_buildQueueMap()));
              broadcastState();
            }
          }
          break;
        case 'delete_playlist':
          final pid = (cmd['id'] as num?)?.toInt();
          if (pid != null) {
            db.deletePlaylist(pid);
            _broadcast(jsonEncode(_buildPlaylistsMap()));
          }
          break;
        case 'set_dac_chip':
          final chip = (cmd['chip'] as num?)?.toInt();
          if (chip != null) {
            DacSettingService.instance.setChip(chip);
            broadcastDac();
          }
          break;
        case 'set_dac_param':
          final key = cmd['key'] as String?;
          final val = ((cmd['val'] ?? cmd['value']) as num?)?.toInt();
          if (key != null && val != null) {
            DacSettingService.instance.setParam(key, val);
            broadcastDac();
          }
          break;
        case 'set_pi_dac':
          final dacName = cmd['dac_name'] as String?;
          final alsaCard = cmd['alsa_card'] as String?;
          if (dacName != null && alsaCard != null) {
            PiSystemService.instance.setDacDevice(dacName, alsaCard);
            broadcastDac();
            broadcastState();
          }
          break;
      }
    } catch (e) {
      debugPrint('[WebRemoteService] 处理客户端指令失败: $e');
    }
  }

  /// 广播状态给所有在线客户端
  void broadcastState() {
    if (_clients.isEmpty) return;
    _broadcast(jsonEncode(_buildStateMap()));
  }

  void broadcastMseb() {
    if (_clients.isEmpty) return;
    _broadcast(jsonEncode(_buildMsebMap()));
  }

  void broadcastDac() {
    if (_clients.isEmpty) return;
    _broadcast(jsonEncode(_buildDacMap()));
  }

  void _broadcast(String message) {
    for (final client in _clients) {
      try {
        client.add(message);
      } catch (_) {}
    }
  }

  Map<String, dynamic> _buildStateMap() {
    final audio = HifiAudioService.instance;
    final theme = ThemeService.instance;
    final mseb = MsebService.instance;
    final piSys = PiSystemService.instance;
    final cur = audio.currentTrack;

    String modeStr = 'list';
    if (audio.playMode == PlayMode.loopSingle) {
      modeStr = 'single';
    } else if (audio.playMode == PlayMode.shuffle) {
      modeStr = 'shuffle';
    } else if (audio.playMode == PlayMode.sequence) {
      modeStr = 'seq';
    }

    String platformName = 'macOS';
    if (Platform.isLinux) {
      platformName = '树莓派 5';
    } else if (Platform.isIOS) {
      platformName = 'iPad / iOS';
    } else if (Platform.isWindows) {
      platformName = 'Windows';
    } else if (Platform.isAndroid) {
      platformName = 'Android';
    }

    return {
      'type': 'state',
      'platform': Platform.operatingSystem,
      'platform_name': platformName,
      'temperature': piSys.socTemperature,
      'temp_color': piSys.tempColorHex,
      'dac_device': Platform.isLinux ? piSys.dacDeviceName : DacSettingService.instance.dacName,
      'alsa_card': piSys.alsaCard,
      'is_playing': audio.state.isPlaying,
      'title': cur?.title ?? '暂未载入曲目',
      'artist': cur?.artist ?? '未知艺术家',
      'album': cur?.album ?? '纯音曲库',
      'specs': cur != null
          ? '${cur.format.name.toUpperCase()} ${cur.sampleRate ~/ 1000}kHz/${cur.bitDepth}bit'
          : 'Hi-Res 直通',
      'current_time': audio.state.currentTime,
      'duration': audio.state.duration,
      'volume': audio.state.volume,
      'is_muted': audio.state.isMuted,
      'mode': modeStr,
      'spectrum': audio.state.spectrumLevels,
      'eq_enabled': audio.eqEnabled,
      'eq_bands': audio.eqBands,
      'mseb_enabled': mseb.isEnabled,
      'mseb_params': mseb.values,
      'theme_id': theme.currentThemeId,
      'visual_mode': theme.backgroundVisualMode,
      'fade_duration': 0.5,
      'is_bit_perfect': audio.state.isBitPerfect,
    };
  }

  Map<String, dynamic> _buildQueueMap() {
    final audio = HifiAudioService.instance;
    final queue = audio.playlistQueue;
    return {
      'type': 'queue',
      'current_index': audio.currentIndex,
      'tracks': queue.map((t) => {
        'id': t.id,
        'title': t.title,
        'artist': t.artist,
        'album': t.album,
        'duration': t.durationSec,
        'badge': '${t.format.name.toUpperCase()} ${t.sampleRate ~/ 1000}k',
      }).toList(),
    };
  }

  Map<String, dynamic> _buildLibraryMap() {
    final db = MusicDatabaseService.instance;
    return {
      'type': 'library',
      'tracks': db.tracks.map((t) => {
        'id': t.id,
        'title': t.title,
        'artist': t.artist,
        'album': t.album,
        'duration': t.durationSec,
        'badge': '${t.format.name.toUpperCase()} ${t.sampleRate ~/ 1000}k',
      }).toList(),
    };
  }

  Map<String, dynamic> _buildPlaylistsMap() {
    final db = MusicDatabaseService.instance;
    return {
      'type': 'playlists',
      'playlists': db.playlists.map((p) => {
        'id': p.id,
        'name': p.name,
        'track_count': 0,
        'duration': 0,
      }).toList(),
    };
  }

  Map<String, dynamic> _buildDacMap() {
    final dac = DacSettingService.instance;
    final piSys = PiSystemService.instance;
    return {
      'type': 'dac',
      'platform': Platform.operatingSystem,
      'temperature': piSys.socTemperature,
      'has_external_dac': dac.hasExternalDac,
      'dac_name': Platform.isLinux ? piSys.dacDeviceName : dac.dacName,
      'active_output': dac.activeOutput,
      'alsa_card': piSys.alsaCard,
      'detected_alsa_devices': piSys.getDetectedAlsaDevices(),
      'selected_chip': dac.selectedChip,
      'chip_name': dac.dacName,
      'params': dac.allParams,
    };
  }

  Map<String, dynamic> _buildMsebMap() {
    final mseb = MsebService.instance;
    return {
      'type': 'mseb',
      'enabled': mseb.isEnabled,
      'params': mseb.values,
    };
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
