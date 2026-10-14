import 'package:flutter/material.dart';
import '../../../services/theme_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// Web服务模块 (合并 Web 远程遥控与 WiFi 传歌，1:1 对齐 C++ WebServiceView.cpp 与 WifiTransferView.cpp)
class MacWebServiceView extends StatefulWidget {
  final bool isWifiTransfer;

  const MacWebServiceView({
    super.key,
    this.isWifiTransfer = false,
  });

  @override
  State<MacWebServiceView> createState() => _MacWebServiceViewState();
}

class _MacWebServiceViewState extends State<MacWebServiceView> {
  int _activeSubModule = 0; // 0: Web 远程控制与数播中枢, 1: WiFi 局域网传歌
  bool _isWebServerRunning = false;
  bool _isWifiServerRunning = false;
  final TextEditingController _ipInputController =
      TextEditingController(text: '192.168.1.100');

  @override
  void initState() {
    super.initState();
    _activeSubModule = widget.isWifiTransfer ? 1 : 0;
  }

  @override
  void dispose() {
    _ipInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ThemeService.instance.accentColor;

    return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部标题与子模块切换药丸
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    'Web 服务',
                    style: TextStyle(
                      fontSize: UIConfig.fontMedium,
                      fontWeight: FontWeight.bold,
                      color: UIConfig.textActive,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Text(
                    _activeSubModule == 0
                        ? '当前设备: macOS Desktop · 支持旧手机/平板当数播主机 · 双向毫秒级遥控'
                        : '同一局域网下电脑或手机免线拖拽传输 · 即传即播 · 自动扫描入库',
                    style: const TextStyle(
                      fontSize: UIConfig.fontSmall,
                      color: UIConfig.textMuted,
                    ),
                  ),
                ],
              ),

              // 顶部子模块药丸切换组
              Container(
                padding: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(20, 26, 36, 0.8),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    _buildSubModulePill(
                      index: 0,
                      label: 'Web 远程控制',
                      isActive: _activeSubModule == 0,
                      accent: accent,
                    ),
                    _buildSubModulePill(
                      index: 1,
                      label: 'WiFi 局域网传歌',
                      isActive: _activeSubModule == 1,
                      accent: accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // 核心内容区
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                if (_activeSubModule == 0) ..._buildWebRemoteSection(accent),
                if (_activeSubModule == 1) ..._buildWifiTransferSection(accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    return [
      // 卡片 1：服务状态主面板
      _buildCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7.0,
                      height: 7.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isWebServerRunning
                            ? const Color(0xFF34C759)
                            : UIConfig.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      _isWebServerRunning
                          ? '【本机数播服务运行中】 4 线程 8088 端口在线'
                          : '【本机数播服务已停止】 0 线程 0 端口开销',
                      style: const TextStyle(
                        fontSize: UIConfig.fontRegular,
                        fontWeight: FontWeight.w600,
                        color: UIConfig.textActive,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                const Text(
                  '遥控访问网址: http://192.168.0.100:8088',
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    color: Color(0xFF64B5F6),
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4.0),
                const Text(
                  'WebSocket 通道: ws://192.168.0.100:8088/ws · 网络: 有线直连 (Ethernet)',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: UIConfig.textMuted,
                  ),
                ),
                const SizedBox(height: 3.0),
                const Text(
                  '提示: 仅在开启服务后才占用系统端口和后台线程，平时开启 0 损耗',
                  style: TextStyle(
                    fontSize: 11.0,
                    color: UIConfig.textMuted,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => setState(() => _isWebServerRunning = !_isWebServerRunning),
              borderRadius: BorderRadius.circular(6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: _isWebServerRunning
                      ? const Color.fromRGBO(239, 68, 68, 0.2)
                      : const Color.fromRGBO(16, 185, 129, 0.2),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: _isWebServerRunning
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                ),
                child: Text(
                  _isWebServerRunning ? '停止服务' : '开启服务',
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    fontWeight: FontWeight.bold,
                    color: _isWebServerRunning
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
                children: const [
                  Text('在线遥控设备', style: TextStyle(fontSize: 11.5, color: UIConfig.textMuted)),
                  SizedBox(height: 6.0),
                  Text('0 台设备', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: UIConfig.textActive)),
                  SizedBox(height: 4.0),
                  Text('WebSocket 长连接保活', style: TextStyle(fontSize: 11.0, color: UIConfig.textMuted)),
                ],
              ),
            ),
            Container(width: 1.0, height: 50.0, color: const Color.fromRGBO(255, 255, 255, 0.08)),
            const SizedBox(width: 20.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('当前同步在播曲目', style: TextStyle(fontSize: 11.5, color: UIConfig.textMuted)),
                  SizedBox(height: 6.0),
                  Text('暂未载入曲目 - 未知', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: UIConfig.textActive)),
                  SizedBox(height: 4.0),
                  Text('状态: 暂停/空闲就绪', style: TextStyle(fontSize: 11.0, color: UIConfig.textMuted)),
                ],
              ),
            ),
            Container(width: 1.0, height: 50.0, color: const Color.fromRGBO(255, 255, 255, 0.08)),
            const SizedBox(width: 20.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('旧手机防休眠模式', style: TextStyle(fontSize: 11.5, color: UIConfig.textMuted)),
                  SizedBox(height: 6.0),
                  Text('已开启 (屏幕常亮)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                  SizedBox(height: 4.0),
                  Text('网络心跳不中断', style: TextStyle(fontSize: 11.0, color: UIConfig.textMuted)),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      filled: true,
                      fillColor: const Color.fromRGBO(10, 14, 20, 0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5.0),
                        borderSide: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.15)),
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
                  onTap: () {},
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
                    child: const Text(
                      '在浏览器中接管遥控',
                      style: TextStyle(
                        fontSize: UIConfig.fontSmall,
                        color: Color(0xFF10B981),
                      ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
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
              style: TextStyle(fontSize: 11.5, color: UIConfig.textMuted, height: 1.5),
            ),
            Text(
              '2. 极致纯净电池供电: 旧手机自带锂电池供电，天然隔绝 220V 市电高频杂波，底噪比普通 PC 和劣质开关电源更低！',
              style: TextStyle(fontSize: 11.5, color: UIConfig.textMuted, height: 1.5),
            ),
            Text(
              '3. 免路由器热点直连: 即使在展会或无 Wi-Fi 环境，旧手机开启「个人热点」，主力机连入即可通过 172.20.10.1:8088 畅快遥控。',
              style: TextStyle(fontSize: 11.5, color: UIConfig.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    ];
  }

  // ===========================================================================
  // 2. WiFi 局域网传歌模块 (对齐 cpp_tab_9_wifi.png)
  // ===========================================================================
  List<Widget> _buildWifiTransferSection(Color accent) {
    return [
      // 卡片 1：传歌主服务面板
      _buildCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7.0,
                      height: 7.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isWifiServerRunning
                            ? const Color(0xFF34C759)
                            : UIConfig.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      _isWifiServerRunning
                          ? '无线传歌服务正在运行中'
                          : '无线传歌服务已停止',
                      style: const TextStyle(
                        fontSize: UIConfig.fontRegular,
                        fontWeight: FontWeight.w600,
                        color: UIConfig.textActive,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                const Text(
                  '传歌网址: http://192.168.0.100:8080',
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    color: Color(0xFF64B5F6),
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4.0),
                const Text(
                  'Wi-Fi: 有线直连 (Ethernet) · 存储: /Users/mk10',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: UIConfig.textMuted,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => setState(() => _isWifiServerRunning = !_isWifiServerRunning),
              borderRadius: BorderRadius.circular(6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: _isWifiServerRunning
                      ? const Color.fromRGBO(239, 68, 68, 0.2)
                      : const Color.fromRGBO(16, 185, 129, 0.2),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: _isWifiServerRunning
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                ),
                child: Text(
                  _isWifiServerRunning ? '停止传歌' : '开始传歌',
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    fontWeight: FontWeight.bold,
                    color: _isWifiServerRunning
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
          children: const [
            Text(
              '实时传输看板',
              style: TextStyle(
                fontSize: UIConfig.fontSmall,
                fontWeight: FontWeight.bold,
                color: UIConfig.textActive,
              ),
            ),
            SizedBox(height: 8.0),
            Text(
              'WiFi 传歌服务尚未启动，启动后同一局域网设备可免插拔 U 盘秒级传输歌曲',
              style: TextStyle(fontSize: 11.5, color: UIConfig.textMuted),
            ),
            SizedBox(height: 4.0),
            Text(
              '传输完成后曲库将自动同步刷新，无需重启或重新扫描',
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
          children: const [
            Text(
              '本次传输清单 (已自动入库: 0 首)',
              style: TextStyle(
                fontSize: UIConfig.fontSmall,
                fontWeight: FontWeight.bold,
                color: UIConfig.textActive,
              ),
            ),
            SizedBox(height: 8.0),
            Text(
              '暂无通过 WiFi 接收的音乐文件记录',
              style: TextStyle(fontSize: 11.5, color: UIConfig.textMuted),
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
