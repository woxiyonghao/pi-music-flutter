import 'package:flutter/material.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// Web服务与WiFi传歌视图 (1:1 严格对齐 C++ WebServiceView.cpp / WifiTransferView.cpp)
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
  bool _isRunning = true;
  final int _port = 8088;

  @override
  Widget build(BuildContext context) {
    final title = widget.isWifiTransfer ? 'WiFi 无线传歌' : 'Web 局域网控制服务';
    final desc = widget.isWifiTransfer
        ? '在同一局域网的手机或电脑浏览器中打开下方网址，即可无线上传 DSD/FLAC 发烧无损母带至本地曲库。'
        : '开启本地发烧 Web API 中枢，支持同局域网手机、平板免装客户端浏览器远程触控数播。';

    return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: UIConfig.fontMedium,
                      fontWeight: FontWeight.bold,
                      color: UIConfig.textActive,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: UIConfig.fontSmall,
                      color: UIConfig.textMuted,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _isRunning,
                activeColor: UIConfig.accent,
                onChanged: (val) {
                  setState(() {
                    _isRunning = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24.0),

          // 服务地址展示卡片
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(20, 26, 36, 0.7),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.1),
              ),
            ),
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
                        color: _isRunning
                            ? UIConfig.dacConnected
                            : UIConfig.dacDisconnected,
                        boxShadow: _isRunning
                            ? [
                                BoxShadow(
                                  color: UIConfig.dacConnected.withOpacity(0.6),
                                  blurRadius: 6.0,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      _isRunning ? '服务正在运行中' : '服务已停止',
                      style: TextStyle(
                        fontSize: UIConfig.fontSmall,
                        color: _isRunning
                            ? UIConfig.textActive
                            : UIConfig.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14.0),
                const Text(
                  '浏览器访问地址 (局域网 HTTP):',
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    color: UIConfig.textMuted,
                  ),
                ),
                const SizedBox(height: 6.0),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(10, 14, 20, 0.8),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.1),
                    ),
                  ),
                  child: Text(
                    'http://127.0.0.1:$_port  /  http://192.168.1.100:$_port',
                    style: const TextStyle(
                      fontSize: UIConfig.fontRegular,
                      color: Color(0xFF64B5F6),
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
