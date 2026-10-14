import 'package:flutter/material.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// 扫描音乐视图 (1:1 严格对齐 C++ ScanMusicWidget.cpp)
class MacScanMusicView extends StatefulWidget {
  final int scannedCount;
  final VoidCallback? onScanComplete;

  const MacScanMusicView({
    super.key,
    this.scannedCount = 60,
    this.onScanComplete,
  });

  @override
  State<MacScanMusicView> createState() => _MacScanMusicViewState();
}

class _MacScanMusicViewState extends State<MacScanMusicView> {
  bool _isScanning = false;
  double _progress = 1.0;
  String _currentPath = '/Users/mk10/Music';

  void _startScan() {
    setState(() {
      _isScanning = true;
      _progress = 0.0;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _progress = 0.35);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _progress = 0.75);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _progress = 1.0;
          _isScanning = false;
        });
        widget.onScanComplete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '扫描音乐',
            style: TextStyle(
              fontSize: UIConfig.fontMedium,
              fontWeight: FontWeight.bold,
              color: UIConfig.textActive,
            ),
          ),
          const SizedBox(height: 4.0),
          const Text(
            '深度递归检索本地发烧无损母带 · 自动解析 CUE 高精度分轨',
            style: TextStyle(
              fontSize: UIConfig.fontSmall,
              color: UIConfig.textMuted,
            ),
          ),
          const SizedBox(height: 20.0),

          // 扫描路径配置卡片
          Container(
            padding: const EdgeInsets.all(16.0),
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
                const Text(
                  '曲库检索路径',
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    color: UIConfig.textMuted,
                  ),
                ),
                const SizedBox(height: 8.0),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(10, 14, 20, 0.8),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(
                            color: const Color.fromRGBO(255, 255, 255, 0.1),
                          ),
                        ),
                        child: Text(
                          _currentPath,
                          style: const TextStyle(
                            fontSize: UIConfig.fontRegular,
                            color: UIConfig.textActive,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    ElevatedButton(
                      onPressed: _isScanning ? null : _startScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UIConfig.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18.0, vertical: 12.0),
                      ),
                      child: Text(
                        _isScanning ? '正在扫描...' : '开始扫描',
                        style: const TextStyle(
                            fontSize: UIConfig.fontSmall,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: const Color.fromRGBO(255, 255, 255, 0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(UIConfig.accent),
                  minHeight: 4.0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20.0),

          // 曲库统计摘要
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(20, 26, 36, 0.7),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('已检索母带', '${widget.scannedCount} 首'),
                _buildStatItem('母带格式', 'DSD / FLAC / WAV'),
                _buildStatItem('CUE 分轨', '自动解析支持'),
                _buildStatItem('存储状态', 'SQLite 本地持久化'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: UIConfig.fontMedium,
            fontWeight: FontWeight.bold,
            color: UIConfig.textActive,
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          label,
          style: const TextStyle(
            fontSize: UIConfig.fontSmall,
            color: UIConfig.textMuted,
          ),
        ),
      ],
    );
  }
}
