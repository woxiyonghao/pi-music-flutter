import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 固件与系统在线 OTA 更新状态
enum OtaStatus {
  idle, // 就绪待命
  checking, // 正在检测远端更新
  upToDate, // 当前已是最新版本
  updateAvailable, // 发现新版本更新
  updating, // 正在拉取代码并自动构建
  success, // OTA 升级成功
  failed, // 检测或更新失败
}

/// 纯音数播系统固件与应用 OTA 在线升级服务 (基于 Git 原生远程拉取与自编译)
/// 1:1 对齐 C++ UpdateManager，支持 macOS 桌面端与树莓派 Linux 专用数播在线检测与一键热升级
class OtaUpdateService extends ChangeNotifier {
  static final OtaUpdateService instance = OtaUpdateService._();

  OtaStatus _status = OtaStatus.idle;
  OtaStatus get status => _status;

  String _currentBranch = 'dev';
  String get currentBranch => _currentBranch;

  String _currentCommit = 'Unknown';
  String get currentCommit => _currentCommit;

  String _currentDate = '';
  String get currentDate => _currentDate;

  String _currentMessage = '';
  String get currentMessage => _currentMessage;

  String _remoteCommit = '';
  String get remoteCommit => _remoteCommit;

  int _pendingCommitCount = 0;
  int get pendingCommitCount => _pendingCommitCount;

  String _changelog = '';
  String get changelog => _changelog;

  String _progressMessage = '';
  String get progressMessage => _progressMessage;

  double _progress = 0.0;
  double get progress => _progress;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String? _repoRoot;

  OtaUpdateService._() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      initLocalVersionInfo();
    }
  }

  /// 获取 Git 源码根目录
  String getRepoRoot() {
    if (_repoRoot != null) return _repoRoot!;

    try {
      final res = Process.runSync('git', ['rev-parse', '--show-toplevel']);
      if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
        _repoRoot = res.stdout.toString().trim();
        return _repoRoot!;
      }
    } catch (_) {}

    // 备用探测路径
    final candidates = [
      Directory.current.path,
      '/Users/mk10/Desktop/hide_player_flutter',
      '/home/pi/hide_player_flutter',
    ];
    for (final cand in candidates) {
      if (Directory('$cand/.git').existsSync()) {
        _repoRoot = cand;
        return cand;
      }
    }

    _repoRoot = Directory.current.path;
    return _repoRoot!;
  }

  /// 刷新本地 Git 版本元数据
  Future<void> initLocalVersionInfo() async {
    final root = getRepoRoot();
    try {
      // 1. 获取当前分支
      final branchRes = await Process.run('git', ['-C', root, 'rev-parse', '--abbrev-ref', 'HEAD']);
      if (branchRes.exitCode == 0 && branchRes.stdout.toString().trim().isNotEmpty) {
        _currentBranch = branchRes.stdout.toString().trim();
      }

      // 2. 获取当前 commit 简短哈希
      final hashRes = await Process.run('git', ['-C', root, 'rev-parse', '--short', 'HEAD']);
      if (hashRes.exitCode == 0 && hashRes.stdout.toString().trim().isNotEmpty) {
        _currentCommit = hashRes.stdout.toString().trim();
      }

      // 3. 获取最近提交日期与提交日志
      final logRes = await Process.run('git', [
        '-C',
        root,
        'log',
        '-1',
        '--format=%cd%x09%s',
        '--date=short',
      ]);
      if (logRes.exitCode == 0) {
        final parts = logRes.stdout.toString().trim().split('\t');
        if (parts.isNotEmpty) _currentDate = parts[0];
        if (parts.length > 1) _currentMessage = parts[1];
      }
    } catch (e) {
      debugPrint('[OtaUpdateService] 初始化版本信息失败: $e');
    }
    notifyListeners();
  }

  /// 异步检测云端远端仓库是否有新提交 (零阻塞 UI 与发烧音频重放)
  Future<void> checkForUpdates() async {
    if (_status == OtaStatus.checking || _status == OtaStatus.updating) {
      return;
    }

    _status = OtaStatus.checking;
    _progressMessage = '正在连接 GitHub 远程仓库同步最新元数据 (git fetch)...';
    _errorMessage = '';
    _progress = 0.0;
    notifyListeners();

    await initLocalVersionInfo();
    final root = getRepoRoot();

    try {
      // 执行 git fetch origin <branch>
      final fetchRes = await Process.run(
        'git',
        ['-C', root, 'fetch', 'origin', _currentBranch, '--quiet'],
      ).timeout(const Duration(seconds: 25));

      if (fetchRes.exitCode != 0) {
        _status = OtaStatus.failed;
        _errorMessage = '远端同步失败: ${fetchRes.stderr.toString().trim()}';
        _progressMessage = '';
        notifyListeners();
        return;
      }

      // 获取 FETCH_HEAD 的短哈希
      final revRes = await Process.run('git', ['-C', root, 'rev-parse', '--short', 'FETCH_HEAD']);
      if (revRes.exitCode == 0 && revRes.stdout.toString().trim().isNotEmpty) {
        _remoteCommit = revRes.stdout.toString().trim();
      }

      // 计算落后远端的 commit 数量
      final countRes = await Process.run('git', ['-C', root, 'rev-list', '--count', 'HEAD..FETCH_HEAD']);
      int count = 0;
      if (countRes.exitCode == 0) {
        count = int.tryParse(countRes.stdout.toString().trim()) ?? 0;
      }
      _pendingCommitCount = count;

      if (_pendingCommitCount > 0) {
        // 读取待更新的 commit 详细日志列表
        final diffLogRes = await Process.run('git', [
          '-C',
          root,
          'log',
          '-n',
          '5',
          '--format=* %h %s (%cr)',
          'HEAD..FETCH_HEAD',
        ]);
        if (diffLogRes.exitCode == 0) {
          _changelog = diffLogRes.stdout.toString().trim();
        }
        _status = OtaStatus.updateAvailable;
        _progressMessage = '发现 $_pendingCommitCount 个最新发烧更新提交，可点击一键升级';
      } else {
        _status = OtaStatus.upToDate;
        _changelog = '';
        _progressMessage = '当前数播系统已是最新版本 ($_currentCommit)';
      }
    } on TimeoutException {
      _status = OtaStatus.failed;
      _errorMessage = '网络连接超时，请检查局域网或 GitHub 连通性';
      _progressMessage = '';
    } catch (e) {
      _status = OtaStatus.failed;
      _errorMessage = '检测更新异常: $e';
      _progressMessage = '';
    }

    notifyListeners();
  }

  /// 执行一键 OTA 升级拉取并触发重新编译构建
  Future<bool> executeUpdate() async {
    if (_status == OtaStatus.updating) return false;

    _status = OtaStatus.updating;
    _progress = 0.2;
    _progressMessage = '正在拉取远端更新代码 (git pull --rebase)...';
    _errorMessage = '';
    notifyListeners();

    final root = getRepoRoot();

    try {
      // 1. 执行 git pull
      final pullRes = await Process.run('git', [
        '-C',
        root,
        'pull',
        '--rebase',
        'origin',
        _currentBranch,
      ]).timeout(const Duration(seconds: 60));

      if (pullRes.exitCode != 0) {
        _status = OtaStatus.failed;
        _errorMessage = '拉取代码失败: ${pullRes.stderr.toString().trim()}';
        _progressMessage = '';
        notifyListeners();
        return false;
      }

      _progress = 0.55;
      _progressMessage = '代码同步完成！正在本地并发编译全新应用 (flutter build macos)...';
      notifyListeners();

      // 2. 根据运行平台编译目标
      if (Platform.isMacOS) {
        final buildRes = await Process.run(
          'flutter',
          ['build', 'macos', '--debug'],
          workingDirectory: root,
        ).timeout(const Duration(minutes: 5));

        if (buildRes.exitCode != 0) {
          _status = OtaStatus.failed;
          _errorMessage = '编译构建失败: ${buildRes.stderr.toString().trim()}';
          _progressMessage = '';
          notifyListeners();
          return false;
        }
      }

      await initLocalVersionInfo();
      _progress = 1.0;
      _status = OtaStatus.success;
      _progressMessage = 'OTA 升级成功！全新版本 ($_currentCommit) 已编译就绪，请点击下方重启生效。';
      notifyListeners();
      return true;
    } catch (e) {
      _status = OtaStatus.failed;
      _errorMessage = '升级执行异常: $e';
      _progressMessage = '';
      notifyListeners();
      return false;
    }
  }

  /// 重启应用程序
  void restartApplication() {
    final root = getRepoRoot();
    if (Platform.isMacOS) {
      final appPath = '$root/build/macos/Build/Products/Debug/PiHifiPlayer.app';
      if (Directory(appPath).existsSync()) {
        Process.run('sh', [
          '-c',
          'sleep 1 && open -g "$appPath"',
        ]);
        exit(0);
      }
    } else if (Platform.isLinux) {
      // 树莓派 Linux 下重启 systemd 服务或启动脚本
      Process.run('systemctl', ['restart', 'pi_hifi_player']);
      exit(0);
    }
  }
}
