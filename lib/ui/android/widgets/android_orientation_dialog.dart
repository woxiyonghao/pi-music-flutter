import 'package:flutter/material.dart';

/// 每次启动选择显示模式，不持久化方向偏好。
/// 依要求：不包含“记住偏好”选项，每次启动均可自由选择横屏或竖屏
class AndroidOrientationDialog extends StatefulWidget {
  final bool initialIsLandscape;
  final ValueChanged<bool> onConfirmed;
  final bool confirming;
  final String? error;

  const AndroidOrientationDialog({
    super.key,
    this.initialIsLandscape = false,
    required this.onConfirmed,
    this.confirming = false,
    this.error,
  });

  @override
  State<AndroidOrientationDialog> createState() =>
      _AndroidOrientationDialogState();
}

class _AndroidOrientationDialogState extends State<AndroidOrientationDialog> {
  late bool _selectedLandscape;

  @override
  void initState() {
    super.initState();
    _selectedLandscape = widget.initialIsLandscape;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: SingleChildScrollView(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 330.0,
            decoration: BoxDecoration(
              color: const Color(0xEB141A26),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: const Color(0x2EFFFFFF),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 35.0,
                  offset: Offset(0, 15),
                ),
              ],
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部音符图标与标题
                const Text(
                  '🎵',
                  style: TextStyle(fontSize: 26.0),
                ),
                const SizedBox(height: 6.0),
                const Text(
                  '请选择显示操作模式',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4.0),
                const Text(
                  '每次启动选择一次，退出 App 前保持锁定',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF828C9B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18.0),

                // 选项一：横屏模式
                _buildOptionCard(
                  isLandscape: true,
                  icon: Icons.sync_alt_rounded,
                  title: '横屏模式 (HiFi 桌面双表头)',
                  subtitle: '沉浸式发烧横屏界面 · 自动识别音频输出',
                  isSelected: _selectedLandscape,
                  onTap: () {
                    setState(() => _selectedLandscape = true);
                  },
                ),
                const SizedBox(height: 10.0),

                // 选项二：保留现有竖屏模式
                _buildOptionCard(
                  isLandscape: false,
                  icon: Icons.smartphone_rounded,
                  title: '竖屏模式 (便携纯音流媒体)',
                  subtitle: '顶部导航 + 对应视窗 + 歌曲信息 + 播放底栏',
                  isSelected: !_selectedLandscape,
                  onTap: () {
                    setState(() => _selectedLandscape = false);
                  },
                ),
                const SizedBox(height: 22.0),

                if (widget.error != null) ...[
                  Text(widget.error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                ],
                // 确认按钮：进入纯音系统
                SizedBox(
                  width: double.infinity,
                  height: 44.0,
                  child: ElevatedButton(
                    onPressed: widget.confirming
                        ? null
                        : () {
                            widget.onConfirmed(_selectedLandscape);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0084FF),
                      foregroundColor: Colors.white,
                      elevation: 6.0,
                      shadowColor: const Color(0x660084FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11.0),
                      ),
                    ),
                    child: const Text(
                      '进入纯音系统',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required bool isLandscape,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: widget.confirming ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x2E0084FF) : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0084FF) : const Color(0x1AFFFFFF),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x400084FF),
                    blurRadius: 12.0,
                    spreadRadius: 1.0,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // 左侧模式图标
            Container(
              width: 38.0,
              height: 38.0,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0084FF)
                    : const Color(0x1F00B4D8),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0084FF)
                      : const Color(0x4D00B4D8),
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20.0,
              ),
            ),
            const SizedBox(width: 12.0),

            // 中间文字描述
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 6.0),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4.5, vertical: 1.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759),
                            borderRadius: BorderRadius.circular(3.5),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3.0),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.0,
                      color: isSelected
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
