import 'package:flutter/material.dart';
import '../../../services/music_database_service.dart';
import '../../../services/theme_service.dart';

/// iPhone 专属系统设置视窗 (1:1 严格对齐发烧定制规范)
/// - 重点提供 Sidebar 主题风格即时配置与换肤
/// - 提供音频重放采样率、DSD、缓存、淡入淡出设置
/// - 呈现 Mac Finder / iTunes 文件共享公共文件夹指南
/// - 彻底去除全屏屏保、息屏超时、数据库调试等冗余项目
class IphoneSystemSettingsView extends StatefulWidget {
  final VoidCallback? onSwitchOrientation;

  const IphoneSystemSettingsView({
    super.key,
    this.onSwitchOrientation,
  });

  @override
  State<IphoneSystemSettingsView> createState() => _IphoneSystemSettingsViewState();
}

class _IphoneSystemSettingsViewState extends State<IphoneSystemSettingsView> {
  // 板块一：Sidebar 主题色
  static const List<_SidebarThemeColor> _sidebarColors = [
    _SidebarThemeColor('湖蓝名机', 'McIntosh Blue', Color(0xFF00B4D8)),
    _SidebarThemeColor('香槟纯金', 'Accuphase Gold', Color(0xFFFFB703)),
    _SidebarThemeColor('极光薄荷', 'Emerald Mint', Color(0xFF06D6A0)),
    _SidebarThemeColor('硬件大师', 'A15 Indigo', Color(0xFF6366F1)),
    _SidebarThemeColor('经典极黑', 'Pure Metal', Color(0xFF94A3B8)),
  ];

  // 板块二：音频重放与时钟引擎
  int _sampleRateMode = 0;    // 0: Bit-Perfect 源码直出, 1: 超采样 192k/24b, 2: 极频 384k/32b
  int _dsdMode = 0;           // 0: Native 原生直通, 1: DoP (DSD over PCM), 2: DSD 软解 PCM
  int _bufferSizeMode = 1;    // 0: 64帧极速, 1: 256帧 (标准发烧), 2: 512帧稳定
  int _fadeDurationMode = 2;  // 0: 关闭, 1: 0.3s, 2: 0.5s (发烧标准), 3: 1.0s

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final db = MusicDatabaseService.instance;
    _sampleRateMode = int.tryParse(db.getSetting('setting_sample_rate', '0'))?.clamp(0, 2) ?? 0;
    _dsdMode = int.tryParse(db.getSetting('setting_dsd_mode', '0'))?.clamp(0, 2) ?? 0;
    _bufferSizeMode = int.tryParse(db.getSetting('setting_buffer_size', '1'))?.clamp(0, 2) ?? 1;
    _fadeDurationMode = int.tryParse(db.getSetting('setting_fade_duration_mode', '2'))?.clamp(0, 3) ?? 2;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final currentAccent = ThemeService.instance.accentColor;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Sidebar 强调主题色设置
              _buildSectionCard(
                title: 'Sidebar 与界面发烧主题色',
                icon: Icons.palette_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '即时联动侧边栏高亮、发光胶囊与视觉指示灯配色',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF828C9B)),
                    ),
                    const SizedBox(height: 10.0),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 6.0,
                        mainAxisSpacing: 6.0,
                        childAspectRatio: 2.1,
                      ),
                      itemCount: _sidebarColors.length,
                      itemBuilder: (context, index) {
                        final item = _sidebarColors[index];
                        final isSelected = (item.color.toARGB32() == currentAccent.toARGB32());
                        return GestureDetector(
                          onTap: () {
                            ThemeService.instance.setAccentColor(item.color);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
                            decoration: BoxDecoration(
                              color: isSelected ? item.color.withValues(alpha: 0.22) : const Color(0x0FFFFFFF),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: isSelected ? item.color : const Color(0x1FFFFFFF),
                                width: isSelected ? 1.4 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: item.color.withValues(alpha: 0.35),
                                        blurRadius: 8.0,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8.0,
                                  height: 8.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: item.color,
                                    boxShadow: [
                                      BoxShadow(color: item.color, blurRadius: 4.0),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 5.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.0,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected ? Colors.white : const Color(0xFFC8D2E1),
                                        ),
                                      ),
                                      Text(
                                        item.enName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 7.5,
                                          color: isSelected ? item.color : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10.0),

              // 2. 音频重放与时钟引擎
              _buildSectionCard(
                title: '音频重放与时钟引擎',
                icon: Icons.graphic_eq_rounded,
                child: Column(
                  children: [
                    _buildOptionRow(
                      label: '输出采样率',
                      options: const ['Bit-Perfect 直出', '192k/24b', '384k/32b'],
                      selectedIndex: _sampleRateMode,
                      onSelected: (idx) {
                        setState(() => _sampleRateMode = idx);
                        MusicDatabaseService.instance.setSetting('setting_sample_rate', idx.toString());
                      },
                    ),
                    const SizedBox(height: 8.0),
                    _buildOptionRow(
                      label: 'DSD 解码模式',
                      options: const ['Native 直通', 'DoP 封装', 'DSD 软解'],
                      selectedIndex: _dsdMode,
                      onSelected: (idx) {
                        setState(() => _dsdMode = idx);
                        MusicDatabaseService.instance.setSetting('setting_dsd_mode', idx.toString());
                      },
                    ),
                    const SizedBox(height: 8.0),
                    _buildOptionRow(
                      label: '硬件音频缓存',
                      options: const ['64帧极低延时', '256帧发烧标准', '512帧平稳'],
                      selectedIndex: _bufferSizeMode,
                      onSelected: (idx) {
                        setState(() => _bufferSizeMode = idx);
                        MusicDatabaseService.instance.setSetting('setting_buffer_size', idx.toString());
                      },
                    ),
                    const SizedBox(height: 8.0),
                    _buildOptionRow(
                      label: '曲目切换淡入',
                      options: const ['关闭', '0.3 秒', '0.5 秒标准', '1.0 秒平滑'],
                      selectedIndex: _fadeDurationMode,
                      onSelected: (idx) {
                        setState(() => _fadeDurationMode = idx);
                        MusicDatabaseService.instance.setSetting('setting_fade_duration_mode', idx.toString());
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10.0),

              // 3. iPhone 公共共享文件夹指南 (iTunes / Mac Finder)
              _buildSectionCard(
                title: 'iPhone 外部歌曲直接导入 (公共文件夹)',
                icon: Icons.folder_shared_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '已开启 iOS iTunes File Sharing 与 Files 文件共享。操作方法：\n'
                      '1. 将 iPhone 用数据线连接至 Mac 电脑，打开「访达 (Finder)」。\n'
                      '2. 在左侧边栏点击您的「iPhone」，切换到顶部「文件 (Files)」标签。\n'
                      '3. 找到「Hide Player Flutter」应用文件夹，直接将歌曲文件 (MP3/FLAC/DSF) 拖拽拉入其中。\n'
                      '4. 亦可在 iPhone 自带「文件」App ->「我的 iPhone」->「Hide Player Flutter」中管理。',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFFC8D2E1),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            MusicDatabaseService.instance.syncPublicMusicFolder();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已重新扫描 iPhone 公共音乐文件夹'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.sync_rounded, size: 14.0),
                          label: const Text('刷新公共音乐库', style: TextStyle(fontSize: 11.0)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0x3300B4D8),
                            foregroundColor: const Color(0xFF00B4D8),
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.0),
                              side: const BorderSide(color: Color(0x6600B4D8)),
                            ),
                          ),
                        ),
                        if (widget.onSwitchOrientation != null) ...[
                          const SizedBox(width: 8.0),
                          OutlinedButton.icon(
                            onPressed: widget.onSwitchOrientation,
                            icon: const Icon(Icons.screen_rotation_rounded, size: 14.0),
                            label: const Text('切换横/竖屏模式', style: TextStyle(fontSize: 11.0)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFCBD5E1),
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10.0),

              // 4. 发烧纯音架构状态
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: const Color(0x590E121A),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0x14FFFFFF)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'iOS 15.0 · A15 Bionic · C++ Native Engine v2.0',
                      style: TextStyle(fontSize: 10.0, color: Color(0xFF64748B), fontFamily: 'monospace'),
                    ),
                    Text(
                      'BIT-PERFECT',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF06D6A0)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xB8161C28),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15.0, color: const Color(0xFF00B4D8)),
              const SizedBox(width: 6.0),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          child,
        ],
      ),
    );
  }

  Widget _buildOptionRow({
    required String label,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 82.0,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF828C9B)),
          ),
        ),
        const SizedBox(width: 6.0),
        Expanded(
          child: Row(
            children: [
              for (int i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 5.0),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(vertical: 5.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedIndex == i ? const Color(0x3300B4D8) : const Color(0x0FFFFFFF),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(
                          color: selectedIndex == i ? const Color(0xFF00B4D8) : const Color(0x14FFFFFF),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        options[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: selectedIndex == i ? FontWeight.bold : FontWeight.normal,
                          color: selectedIndex == i ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarThemeColor {
  final String name;
  final String enName;
  final Color color;
  const _SidebarThemeColor(this.name, this.enName, this.color);
}
