import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/platform_helper.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../services/ota_update_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/web_remote_service.dart';
import '../../../services/wifi_transfer_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';
import '../../common/module_scroll_view.dart';

/// Web服务模块 (合并 Web 远程遥控与 WiFi 传歌，1:1 对齐 C++ WebServiceView.cpp 与 WifiTransferView.cpp)
class MacWebServiceView extends StatefulWidget {
  final bool isWifiTransfer;
  final HifiPlatformType? platform;

  const MacWebServiceView({
    super.key,
    this.isWifiTransfer = false,
    this.platform,
  });

  @override
  State<MacWebServiceView> createState() => _MacWebServiceViewState();
}

class _MacWebServiceViewState extends State<MacWebServiceView> {
  int _activeSubModule = 0; // 0: Web 远程控制与数播中枢, 1: WiFi 局域网传歌
  late final TextEditingController _ipInputController;

  @override
  void initState() {
    super.initState();
    _activeSubModule = widget.isWifiTransfer ? 1 : 0;
    _ipInputController =
        TextEditingController(text: WebRemoteService.instance.localIp);
    _refreshIps();
  }

  void _refreshIps() async {
    final ip = await WebRemoteService.instance.refreshIp();
    await WifiTransferService.instance.refreshIp();
    if (mounted) {
      _ipInputController.text = ip;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ipInputController.dispose();
    super.dispose();
  }

  void _openUrl(String url) {
    try {
      if (Platform.isMacOS) {
        Process.run('open', [url]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [url]);
      } else if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', url]);
      }
    } catch (e) {
      debugPrint('[MacWebServiceView] 无法打开 URL $url: $e');
    }
  }

  void _openWebUrl(String url) async {
    if (!WebRemoteService.instance.isRunning) {
      await WebRemoteService.instance.start();
    }
    if (Platform.isIOS) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已复制 Web 遥控网址至剪贴板: $url\n请在同一局域网电脑/手机浏览器打开即可远程控制'),
            backgroundColor: const Color(0xFF3B82F6),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      _openUrl(url);
    }
  }

  void _openWifiUrl(String url) async {
    if (!WifiTransferService.instance.isRunning) {
      await WifiTransferService.instance.start();
    }
    if (Platform.isIOS) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已复制传歌网址至剪贴板: $url\n请在同一局域网电脑浏览器访问此地址，直接拖拽上传歌曲'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      _openUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.instance,
        WebRemoteService.instance,
        WifiTransferService.instance,
        HifiAudioService.instance,
        OtaUpdateService.instance,
      ]),
      builder: (context, _) {
        final accent = ThemeService.instance.accentColor;

        return GlassCard(
          borderRadius: UIConfig.containerRounding,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: ModuleScrollView(
            storageId: 'web-module-scroll',
            platform: widget.platform,
            header: [
              _buildHeader(accent),
              const SizedBox(height: 16.0),
            ],
            children: [
              if (_activeSubModule == 0) ..._buildWebRemoteSection(accent),
              if (_activeSubModule == 1) ..._buildWifiTransferSection(accent),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color accent) =>
      LayoutBuilder(builder: (context, constraints) {
        final isIphone = (widget.platform ?? PlatformHelper.currentPlatform) ==
            HifiPlatformType.iphone;
        final subtitle =
            _activeSubModule == 0 ? '电脑 / 平板远程遥控 · 实时同步播放状态' : '局域网传歌 · 自动扫描入库';
        const heading = Text('Web 服务',
            style: TextStyle(
                fontSize: UIConfig.fontMedium,
                fontWeight: FontWeight.bold,
                color: UIConfig.textActive));
        final title = isIphone
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                heading,
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: UIConfig.fontSmall,
                        color: UIConfig.textMuted)),
              ])
            : Row(children: [
                heading,
                const SizedBox(width: 12),
                Expanded(
                    child: Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: UIConfig.fontSmall,
                            color: UIConfig.textMuted))),
              ]);
        final modules = Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(20, 26, 36, 0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _buildSubModulePill(
                index: 0,
                label: 'Web 远程控制',
                isActive: _activeSubModule == 0,
                accent: accent),
            _buildSubModulePill(
                index: 1,
                label: 'WiFi 局域网传歌',
                isActive: _activeSubModule == 1,
                accent: accent),
          ]),
        );
        if (!isIphone && constraints.maxWidth < 600) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 8),
                modules,
              ]);
        }
        return Row(
            crossAxisAlignment:
                isIphone ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              SizedBox(width: isIphone ? 12 : 16),
              modules
            ]);
      });

  Widget _buildSubModulePill({
    required int index,
    required String label,
    required bool isActive,
    required Color accent,
  }) {
    return InkWell(
      onTap: () => setState(() => _activeSubModule = index),
      borderRadius: BorderRadius.circular(6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isActive ? accent.withValues(alpha: 0.28) : Colors.transparent,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: isActive ? accent : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? UIConfig.textActive : UIConfig.textNormal,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Web 远程遥控模块 (对齐 cpp_tab_10_web.png)
  // ===========================================================================
  List<Widget> _buildWebRemoteSection(Color accent) {
    final webService = WebRemoteService.instance;
    final isRunning = webService.isRunning;
    final port = webService.port;
    final ip = webService.localIp;
    final clientCount = webService.clientCount;
    final webUrl = 'http://$ip:$port';
    final wsUrl = 'ws://$ip:$port/ws';

    final audio = HifiAudioService.instance;
    final track = audio.currentTrack;
    final isPlaying = audio.state.isPlaying;
    final isPaused = audio.state.isPaused;

    return [
      // 卡片 1：服务状态主面板
      _buildCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRunning
                              ? const Color(0xFF34C759)
                              : UIConfig.textMuted,
                          boxShadow: isRunning
                              ? [
                                  const BoxShadow(
                                    color: Color(0xFF34C759),
                                    blurRadius: 6.0,
                                    spreadRadius: 1.0,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          isRunning
                              ? '【本机数播服务运行中】 $clientCount 个遥控连接 · 端口 $port'
                              : '【本机数播服务已停止】',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: UIConfig.fontRegular,
                            fontWeight: FontWeight.w600,
                            color: UIConfig.textActive,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),

                  // 遥控访问网址 (支持点击一键在浏览器打开)
                  InkWell(
                    onTap: () => _openWebUrl(webUrl),
                    borderRadius: BorderRadius.circular(4.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '遥控访问网址: $webUrl',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: UIConfig.fontSmall,
                                color: Color(0xFF64B5F6),
                                fontFamily: 'monospace',
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF64B5F6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          const Icon(
                            Icons.open_in_new,
                            size: 13.0,
                            color: Color(0xFF64B5F6),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 4.0),
                  Text(
                    'WebSocket 通道: $wsUrl · ${isRunning ? '服务已开启' : '服务未开启'}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: UIConfig.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3.0),
                  const Text(
                    '提示：请连接同一局域网，并保持应用在前台以使用遥控和 WiFi 传歌。',
                    style: TextStyle(
                      fontSize: 11.0,
                      color: UIConfig.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16.0),
            InkWell(
              onTap: () async {
                if (isRunning) {
                  await webService.stop();
                } else {
                  await webService.start();
                }
              },
              borderRadius: BorderRadius.circular(6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isRunning
                      ? const Color.fromRGBO(239, 68, 68, 0.2)
                      : const Color.fromRGBO(16, 185, 129, 0.2),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: isRunning
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                ),
                child: Text(
                  isRunning ? '停止服务' : '开启服务',
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    fontWeight: FontWeight.bold,
                    color: isRunning
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12.0),

      // 卡片 2：实时三列统计卡
      _buildCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('在线遥控设备',
                      style:
                          TextStyle(fontSize: 11.5, color: UIConfig.textMuted)),
                  const SizedBox(height: 6.0),
                  Text('$clientCount 个连接',
                      style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: UIConfig.textActive)),
                  const SizedBox(height: 4.0),
                  const Text('当前 WebSocket 连接',
                      style:
                          TextStyle(fontSize: 11.0, color: UIConfig.textMuted)),
                ],
              ),
            ),
            Container(
                width: 1.0,
                height: 50.0,
                color: const Color.fromRGBO(255, 255, 255, 0.08)),
            const SizedBox(width: 20.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('当前同步在播曲目',
                      style:
                          TextStyle(fontSize: 11.5, color: UIConfig.textMuted)),
                  const SizedBox(height: 6.0),
                  Text(
                    track != null
                        ? '${track.title} - ${track.artist}'
                        : '暂未载入曲目 - 未知',
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: UIConfig.textActive),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    isPlaying
                        ? '状态: 正在同步播放'
                        : (isPaused ? '状态: 已暂停' : '状态: 待机/空闲就绪'),
                    style: const TextStyle(
                        fontSize: 11.0, color: UIConfig.textMuted),
                  ),
                ],
              ),
            ),
            Container(
                width: 1.0,
                height: 50.0,
                color: const Color.fromRGBO(255, 255, 255, 0.08)),
            const SizedBox(width: 20.0),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('连接使用提示',
                      style:
                          TextStyle(fontSize: 11.5, color: UIConfig.textMuted)),
                  SizedBox(height: 6.0),
                  Text('保持应用在前台',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981))),
                  SizedBox(height: 4.0),
                  Text('休眠由系统控制',
                      style:
                          TextStyle(fontSize: 11.0, color: UIConfig.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12.0),

      // 卡片 3：客户端模式连接局域网内的其他数播设备
      _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '【客户端模式】连接局域网内的其他数播设备 (树莓派 / 旧手机数播)',
              style: TextStyle(
                fontSize: UIConfig.fontSmall,
                fontWeight: FontWeight.bold,
                color: UIConfig.textActive,
              ),
            ),
            const SizedBox(height: 4.0),
            const Text(
              '输入对方设备的 IP 地址，即可在浏览器或当前界面中发起遥控:',
              style: TextStyle(
                fontSize: 11.5,
                color: UIConfig.textMuted,
              ),
            ),
            const SizedBox(height: 10.0),
            Row(
              children: [
                SizedBox(
                  width: 200.0,
                  height: 32.0,
                  child: TextField(
                    controller: _ipInputController,
                    style: const TextStyle(
                      fontSize: UIConfig.fontSmall,
                      color: UIConfig.textActive,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 6.0),
                      filled: true,
                      fillColor: const Color.fromRGBO(10, 14, 20, 0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5.0),
                        borderSide: const BorderSide(
                            color: Color.fromRGBO(255, 255, 255, 0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5.0),
                        borderSide: BorderSide(color: accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                InkWell(
                  onTap: () {
                    final targetIp = _ipInputController.text.trim();
                    if (targetIp.isNotEmpty) {
                      final url = targetIp.startsWith('http')
                          ? targetIp
                          : 'http://$targetIp:8088';
                      _openWebUrl(url);
                    }
                  },
                  borderRadius: BorderRadius.circular(6.0),
                  child: Container(
                    height: 32.0,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(16, 185, 129, 0.15),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_browser,
                            size: 14.0, color: Color(0xFF10B981)),
                        SizedBox(width: 6.0),
                        Text(
                          '在浏览器中接管遥控',
                          style: TextStyle(
                            fontSize: UIConfig.fontSmall,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12.0),

      // 卡片 4：变废为宝实战秘籍
      _buildCard(
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '【旧手机当数播实战秘籍】变废为宝打造发烧纯音转盘',
              style: TextStyle(
                fontSize: UIConfig.fontSmall,
                fontWeight: FontWeight.bold,
                color: UIConfig.textActive,
              ),
            ),
            SizedBox(height: 8.0),
            Text(
              '1. 硬件连接直通: 旧 iPhone / iPad (Lightning/Type-C 转接线) 或 Android (OTG 线) 直接连接外置 USB DAC 或发烧耳放小尾巴。',
              style: TextStyle(
                  fontSize: 11.5, color: UIConfig.textMuted, height: 1.5),
            ),
            Text(
              '2. 稳定供电: 使用 USB DAC 时确保手机与外设电量充足；高功耗设备可能需要带供电的 USB 转接器。',
              style: TextStyle(
                  fontSize: 11.5, color: UIConfig.textMuted, height: 1.5),
            ),
            Text(
              '3. 网络连接: 遥控设备和播放器需连接同一 Wi-Fi 或热点；请使用本页面显示的实际访问网址。',
              style: TextStyle(
                  fontSize: 11.5, color: UIConfig.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12.0),

      // 卡片 5：系统在线 OTA 升级 (通过 Git 远程极速检查更新与一键热升级)
      if (PlatformHelper.supportsGitOta(
          widget.platform ?? PlatformHelper.currentPlatform))
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.system_update_alt,
                                size: 16.0, color: accent),
                            const SizedBox(width: 8.0),
                            const Text(
                              '【系统在线 OTA 升级】Git 云端远程固件与应用热更新',
                              style: TextStyle(
                                fontSize: UIConfig.fontSmall,
                                fontWeight: FontWeight.bold,
                                color: UIConfig.textActive,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        const Text(
                          '支持 macOS 桌面端与树莓派 Linux 硬件直连 GitHub 官方源码库 · 差量秒级升级 · 自动编译部署',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: UIConfig.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  _buildOtaActionButton(accent),
                ],
              ),
              const SizedBox(height: 12.0),
              _buildOtaVersionBanner(accent),
              ..._buildOtaDetails(accent),
            ],
          ),
        ),
    ];
  }

  Widget _buildOtaVersionBanner(Color accent) {
    final ota = OtaUpdateService.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(10, 14, 20, 0.7),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.06),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Text(
                  '当前本地版本: ',
                  style: TextStyle(fontSize: 11.5, color: UIConfig.textMuted),
                ),
                Text(
                  '分支 ${ota.currentBranch} · 提交 ${ota.currentCommit}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: UIConfig.textActive,
                  ),
                ),
                if (ota.currentDate.isNotEmpty) ...[
                  const SizedBox(width: 8.0),
                  Text(
                    '(${ota.currentDate})',
                    style: const TextStyle(
                        fontSize: 11.0, color: UIConfig.textMuted),
                  ),
                ],
              ],
            ),
          ),
          _buildOtaStatusBadge(ota, accent),
        ],
      ),
    );
  }

  Widget _buildOtaStatusBadge(OtaUpdateService ota, Color accent) {
    Color badgeColor;
    String badgeText;
    switch (ota.status) {
      case OtaStatus.idle:
        badgeColor = UIConfig.textMuted;
        badgeText = '就绪待命';
        break;
      case OtaStatus.checking:
        badgeColor = const Color(0xFF64B5F6);
        badgeText = '正在检测远端...';
        break;
      case OtaStatus.upToDate:
        badgeColor = const Color(0xFF10B981);
        badgeText = '已是最新版本 ✓';
        break;
      case OtaStatus.updateAvailable:
        badgeColor = const Color(0xFFFFB300);
        badgeText = '发现新版本 (${ota.pendingCommitCount} 提交) ⚡';
        break;
      case OtaStatus.updating:
        badgeColor = const Color(0xFF64B5F6);
        badgeText = '正在编译构建...';
        break;
      case OtaStatus.success:
        badgeColor = const Color(0xFF10B981);
        badgeText = '升级完成待重启 ✓';
        break;
      case OtaStatus.failed:
        badgeColor = const Color(0xFFEF4444);
        badgeText = '检测/更新失败 ✗';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildOtaActionButton(Color accent) {
    final ota = OtaUpdateService.instance;
    final isBusy =
        ota.status == OtaStatus.checking || ota.status == OtaStatus.updating;

    if (ota.status == OtaStatus.updateAvailable) {
      return InkWell(
        onTap: isBusy ? null : () => ota.executeUpdate(),
        borderRadius: BorderRadius.circular(6.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(16, 185, 129, 0.25),
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: const Color(0xFF10B981)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_circle_up, size: 14.0, color: Color(0xFF10B981)),
              SizedBox(width: 6.0),
              Text(
                '一键 OTA 升级',
                style: TextStyle(
                  fontSize: UIConfig.fontSmall,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (ota.status == OtaStatus.success) {
      return InkWell(
        onTap: () => ota.restartApplication(),
        borderRadius: BorderRadius.circular(6.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restart_alt, size: 14.0, color: Colors.white),
              SizedBox(width: 6.0),
              Text(
                '立即重启生效',
                style: TextStyle(
                  fontSize: UIConfig.fontSmall,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: isBusy ? null : () => ota.checkForUpdates(),
      borderRadius: BorderRadius.circular(6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isBusy
              ? const Color.fromRGBO(255, 255, 255, 0.05)
              : accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: isBusy ? const Color.fromRGBO(255, 255, 255, 0.15) : accent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy) ...[
              SizedBox(
                width: 12.0,
                height: 12.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(width: 6.0),
            ] else ...[
              Icon(Icons.refresh, size: 14.0, color: accent),
              const SizedBox(width: 6.0),
            ],
            Text(
              isBusy ? '正在检测...' : '检查更新',
              style: TextStyle(
                fontSize: UIConfig.fontSmall,
                fontWeight: FontWeight.bold,
                color: isBusy ? UIConfig.textMuted : accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOtaDetails(Color accent) {
    final ota = OtaUpdateService.instance;
    return [
      if (ota.status == OtaStatus.checking ||
          ota.status == OtaStatus.updating) ...[
        const SizedBox(height: 10.0),
        ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: LinearProgressIndicator(
            value: ota.status == OtaStatus.updating ? ota.progress : null,
            backgroundColor: const Color.fromRGBO(255, 255, 255, 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
            minHeight: 4.0,
          ),
        ),
        const SizedBox(height: 6.0),
        Text(
          ota.progressMessage,
          style: const TextStyle(fontSize: 11.0, color: Color(0xFF64B5F6)),
        ),
      ],
      if (ota.status == OtaStatus.updateAvailable &&
          ota.changelog.isNotEmpty) ...[
        const SizedBox(height: 10.0),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 179, 0, 0.08),
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: const Color.fromRGBO(255, 179, 0, 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.new_releases,
                      size: 14.0, color: Color(0xFFFFB300)),
                  const SizedBox(width: 6.0),
                  Text(
                    '待升级云端提交 (${ota.pendingCommitCount} 个新提交):',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFB300),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              Text(
                ota.changelog,
                style: const TextStyle(
                  fontSize: 11.0,
                  fontFamily: 'monospace',
                  color: UIConfig.textNormal,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
      if (ota.status == OtaStatus.upToDate) ...[
        const SizedBox(height: 8.0),
        const Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 14.0, color: Color(0xFF10B981)),
            SizedBox(width: 6.0),
            Text(
              '当前已是最新纯音发烧版本，运行代码与 GitHub 官方源完全一致',
              style: TextStyle(fontSize: 11.0, color: Color(0xFF10B981)),
            ),
          ],
        ),
      ],
      if (ota.status == OtaStatus.failed && ota.errorMessage.isNotEmpty) ...[
        const SizedBox(height: 8.0),
        Row(
          children: [
            const Icon(Icons.error_outline,
                size: 14.0, color: Color(0xFFEF4444)),
            const SizedBox(width: 6.0),
            Expanded(
              child: Text(
                ota.errorMessage,
                style:
                    const TextStyle(fontSize: 11.0, color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  // ===========================================================================
  // 2. WiFi 局域网传歌模块 (对齐 cpp_tab_9_wifi.png)
  // ===========================================================================
  List<Widget> _buildWifiTransferSection(Color accent) {
    final wifiService = WifiTransferService.instance;
    final isRunning = wifiService.isRunning;
    final port = wifiService.port;
    final ip = wifiService.localIp;
    final wifiUrl = 'http://$ip:$port';
    final targetDir = wifiService.targetDir;
    final files = wifiService.uploadedFiles;

    return [
      // 卡片 1：传歌主服务面板
      _buildCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRunning
                              ? const Color(0xFF34C759)
                              : UIConfig.textMuted,
                          boxShadow: isRunning
                              ? [
                                  const BoxShadow(
                                    color: Color(0xFF34C759),
                                    blurRadius: 6.0,
                                    spreadRadius: 1.0,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          isRunning ? '无线传歌服务正在运行中 (端口: $port)' : '无线传歌服务已停止',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: UIConfig.fontRegular,
                            fontWeight: FontWeight.w600,
                            color: UIConfig.textActive,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),

                  // 传歌网址 (支持点击一键在浏览器打开)
                  InkWell(
                    onTap: () => _openWifiUrl(wifiUrl),
                    borderRadius: BorderRadius.circular(4.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '传歌网址: $wifiUrl',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: UIConfig.fontSmall,
                                color: Color(0xFF64B5F6),
                                fontFamily: 'monospace',
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF64B5F6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          const Icon(
                            Icons.open_in_new,
                            size: 13.0,
                            color: Color(0xFF64B5F6),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 4.0),
                  Text(
                    '${isRunning ? '传歌服务已开启' : '传歌服务未开启'} · 存储路径: $targetDir',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: UIConfig.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16.0),
            InkWell(
              onTap: () async {
                if (isRunning) {
                  await wifiService.stop();
                } else {
                  await wifiService.start();
                }
              },
              borderRadius: BorderRadius.circular(6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isRunning
                      ? const Color.fromRGBO(239, 68, 68, 0.2)
                      : const Color.fromRGBO(16, 185, 129, 0.2),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: isRunning
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                ),
                child: Text(
                  isRunning ? '停止传歌' : '开始传歌',
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    fontWeight: FontWeight.bold,
                    color: isRunning
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12.0),

      // 卡片 2：实时传输看板
      _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '实时传输看板',
              style: TextStyle(
                fontSize: UIConfig.fontSmall,
                fontWeight: FontWeight.bold,
                color: UIConfig.textActive,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              isRunning
                  ? 'WiFi 传歌服务运行中，请在同一局域网手机/电脑浏览器中访问 $wifiUrl 即可直接免线拖拽传歌'
                  : 'WiFi 传歌服务尚未启动，启动后同一局域网设备可免插拔 U 盘秒级传输歌曲',
              style: const TextStyle(fontSize: 11.5, color: UIConfig.textMuted),
            ),
            const SizedBox(height: 4.0),
            const Text(
              '传输完成后曲库将自动同步刷新并秒级入库，支持 FLAC / WAV / DSD (DSF/DFF) / CUE 分轨',
              style: TextStyle(fontSize: 11.5, color: UIConfig.textMuted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12.0),

      // 卡片 3：本次传输清单
      _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '本次传输清单 (已自动入库: ${wifiService.completedCount} 首)',
                  style: const TextStyle(
                    fontSize: UIConfig.fontSmall,
                    fontWeight: FontWeight.bold,
                    color: UIConfig.textActive,
                  ),
                ),
                if (files.isNotEmpty)
                  InkWell(
                    onTap: () => wifiService.clearTransferHistory(),
                    child: const Text(
                      '清空清单',
                      style:
                          TextStyle(fontSize: 11.0, color: UIConfig.textMuted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8.0),
            if (files.isEmpty)
              const Text(
                '暂无通过 WiFi 接收的音乐文件记录',
                style: TextStyle(fontSize: 11.5, color: UIConfig.textMuted),
              )
            else
              ...files.map(
                (file) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note,
                          size: 16.0, color: Color(0xFF10B981)),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          file.name,
                          style: const TextStyle(
                              fontSize: 12.0, color: UIConfig.textActive),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${file.formattedSize} · ${file.formattedTime}',
                        style: const TextStyle(
                            fontSize: 11.0, color: UIConfig.textMuted),
                      ),
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(16, 185, 129, 0.2),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: const Text(
                          '已入库 ✓',
                          style: TextStyle(
                              fontSize: 10.0, color: Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(20, 26, 36, 0.7),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.08),
        ),
      ),
      child: child,
    );
  }
}
