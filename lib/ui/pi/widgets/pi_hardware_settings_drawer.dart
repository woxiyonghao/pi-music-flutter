import 'package:flutter/material.dart';
import '../../../core/platform_helper.dart';
import '../../../services/pi_system_service.dart';
import '../../../services/web_remote_service.dart';
import '../../../services/wifi_transfer_service.dart';
import '../../../services/dac_setting_service.dart';
import '../../../services/ota_update_service.dart';
import '../../../theme/hifi_theme.dart';
import '../../common/glass_card.dart';

/// 树莓派 1024x600 专属发烧硬件 DAC、防烧屏与局域网服务设置抽屉
class PiHardwareSettingsDrawer extends StatefulWidget {
  final VoidCallback onClose;

  const PiHardwareSettingsDrawer({super.key, required this.onClose});

  @override
  State<PiHardwareSettingsDrawer> createState() => _PiHardwareSettingsDrawerState();
}

class _PiHardwareSettingsDrawerState extends State<PiHardwareSettingsDrawer> {
  List<Map<String, dynamic>> get _combinedAlsaOptions {
    final detected = PiSystemService.instance.getDetectedAlsaDevices();
    if (detected.isNotEmpty) {
      final existingCards = detected.map((e) => e['card']).toSet();
      final defaults = _alsaOptions.where((e) => !existingCards.contains(e['card'])).toList();
      return [...detected, ...defaults];
    }
    return _alsaOptions;
  }

  final List<Map<String, dynamic>> _alsaOptions = [
    {
      'name': 'AK4191 + AK4499EX',
      'card': 'hw:0,0 (I2S Master Clock)',
      'desc': '双旗舰分体芯片 · 超低相噪飞秒双晶振',
      'chipIndex': 2,
    },
    {
      'name': 'HiFiBerry DAC+ Pro (PCM5122)',
      'card': 'hw:1,0 (I2S)',
      'desc': '高性价比经典 I2S 解码帽子板',
      'chipIndex': 0,
    },
    {
      'name': 'USB Audio Class 2.0 DAC',
      'card': 'hw:2,0 (USB Asynchronous)',
      'desc': '外接桌面级发烧 USB 解码器 (拓品/双木三林/钰龙)',
      'chipIndex': 1,
    },
    {
      'name': 'ALSA System Default',
      'card': 'default',
      'desc': '系统默认混音音频输出直通',
      'chipIndex': 0,
    },
  ];

  final List<Map<String, dynamic>> _chipList = [
    {
      'index': 1,
      'name': 'ES9038PRO',
      'tag': 'ESS 旗舰',
      'desc': 'HyperStream II · 8通道超低失真 · 强大瞬态与大动态',
      'color': HifiTheme.neonCyan,
    },
    {
      'index': 2,
      'name': 'AK4499EX',
      'tag': 'AKM 旗舰',
      'desc': 'VELVET SOUND · 数字模拟分体 · 细腻温润原音',
      'color': HifiTheme.accuphaseGold,
    },
    {
      'index': 3,
      'name': 'CS43198',
      'tag': 'Cirrus 旗舰',
      'desc': 'MasterHIFI · 极低失真 · 纯净通透背景黑如深海',
      'color': const Color(0xFF4EEBA8),
    },
    {
      'index': 4,
      'name': 'R-2R 纯电阻',
      'tag': '离散电阻阶梯',
      'desc': '全离散高精度电阻阵列 · 模拟黑胶温润胶片质感',
      'color': const Color(0xFFFF9E44),
    },
    {
      'index': 5,
      'name': 'ROHM 34301',
      'tag': '罗姆 MUS-IC',
      'desc': '发烧原音精粹 · 醇厚真实人声与高雅交响空间感',
      'color': const Color(0xFFC084FC),
    },
    {
      'index': 0,
      'name': 'ALSA 直通',
      'tag': '系统直通',
      'desc': '树莓派默认物理直通 · 无附加滤波与架构重塑',
      'color': HifiTheme.textMuted,
    },
  ];

  final List<int> _timeoutOptions = [1, 3, 5, 10, 0];

  @override
  Widget build(BuildContext context) {
    final piSys = PiSystemService.instance;
    final dac = DacSettingService.instance;
    final wifi = WifiTransferService.instance;
    final webRemote = WebRemoteService.instance;

    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: GlassCard(
            borderRadius: 16.0,
            backgroundColor: HifiTheme.cardBackground.withValues(alpha: 0.95),
            padding: const EdgeInsets.all(16),
            child: ListenableBuilder(
              listenable: Listenable.merge([piSys, dac, wifi, webRemote]),
              builder: (context, _) {
                return Column(
                  children: [
                    // 1. 顶部标题栏
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            onTap: widget.onClose,
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                                border: Border.all(color: HifiTheme.cardBorder),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        const Expanded(
                          child: Text(
                            '树莓派 5 发烧硬件与系统设置',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: HifiTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // 当前 DAC 芯片指示
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: HifiTheme.mcIntoshBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: HifiTheme.mcIntoshGlow.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.memory_rounded, color: HifiTheme.mcIntoshGlow, size: 15),
                              const SizedBox(width: 5),
                              Text(
                                '架构: ${dac.dacName}',
                                style: const TextStyle(
                                  color: HifiTheme.mcIntoshGlow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // 实时温度标牌
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: piSys.tempColorHex == 'red'
                                  ? Colors.redAccent
                                  : (piSys.tempColorHex == 'amber'
                                      ? Colors.orangeAccent
                                      : HifiTheme.neonCyan),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.thermostat_rounded,
                                color: piSys.tempColorHex == 'red'
                                    ? Colors.redAccent
                                    : (piSys.tempColorHex == 'amber'
                                        ? Colors.orangeAccent
                                        : HifiTheme.neonCyan),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'SoC 温度: ${piSys.socTemperature.toStringAsFixed(1)}°C',
                                style: const TextStyle(
                                  color: HifiTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(color: HifiTheme.cardBorder, height: 18),

                    // 2. 左右双栏设置区 (包裹滚动以彻底避免任何溢出)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左栏：ALSA 物理硬件直通与发烧 DAC 芯片微调架构
                          Expanded(
                            flex: 52,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 子区 1：ALSA 物理声卡直通
                                  const Row(
                                    children: [
                                      Icon(Icons.speaker_group_rounded, color: HifiTheme.mcIntoshGlow, size: 18),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'ALSA 物理硬件声卡 (Bit-Perfect Direct)',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: HifiTheme.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  ..._combinedAlsaOptions.map((item) {
                                    final isSelected = piSys.dacDeviceName == item['name'];

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: Material(
                                        color: isSelected
                                            ? HifiTheme.mcIntoshBlue.withValues(alpha: 0.22)
                                            : Colors.white.withValues(alpha: 0.03),
                                        borderRadius: BorderRadius.circular(8),
                                        child: InkWell(
                                          onTap: () {
                                            piSys.setDacDevice(item['name'] as String, item['card'] as String);
                                            final cIdx = item['chipIndex'] as int?;
                                            if (cIdx != null && cIdx > 0) {
                                              dac.setChip(cIdx);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? HifiTheme.mcIntoshGlow
                                                    : HifiTheme.cardBorder,
                                                width: 1.2,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isSelected
                                                      ? Icons.radio_button_checked_rounded
                                                      : Icons.radio_button_unchecked_rounded,
                                                  color: isSelected
                                                      ? HifiTheme.mcIntoshGlow
                                                      : HifiTheme.textMuted,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        item['name'] as String,
                                                        style: TextStyle(
                                                          color: isSelected
                                                              ? HifiTheme.mcIntoshGlow
                                                              : HifiTheme.textPrimary,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${item['card']} · ${item['desc']}',
                                                        style: const TextStyle(
                                                          color: HifiTheme.textMuted,
                                                          fontSize: 10.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),

                                  const SizedBox(height: 12),

                                  // 子区 2：发烧 DAC 芯片微调架构 (Web 遥控实时同步)
                                  Row(
                                    children: [
                                      const Icon(Icons.memory_rounded, color: HifiTheme.neonCyan, size: 18),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          '发烧 DAC 解码芯片架构 (Web 遥控同步)',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: HifiTheme.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '当前: ${dac.dacName}',
                                        style: const TextStyle(
                                          color: HifiTheme.neonCyan,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // 芯片网格卡片
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _chipList.map((item) {
                                      final idx = item['index'] as int;
                                      final isSelected = dac.selectedChip == idx;
                                      final color = item['color'] as Color;

                                      return Material(
                                        color: isSelected
                                            ? color.withValues(alpha: 0.2)
                                            : Colors.white.withValues(alpha: 0.03),
                                        borderRadius: BorderRadius.circular(8),
                                        child: InkWell(
                                          onTap: () {
                                            dac.setChip(idx);
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: 142,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected ? color : HifiTheme.cardBorder,
                                                width: 1.2,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      item['name'] as String,
                                                      style: TextStyle(
                                                        color: isSelected ? color : HifiTheme.textPrimary,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    if (isSelected)
                                                      Icon(Icons.check_circle_rounded, color: color, size: 12),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item['tag'] as String,
                                                  style: TextStyle(
                                                    color: isSelected ? color.withValues(alpha: 0.8) : HifiTheme.textMuted,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // 右栏：QLED 屏幕防烧屏与局域网 Web 遥控配置
                          Expanded(
                            flex: 48,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 防烧屏设置
                                  const Row(
                                    children: [
                                      Icon(Icons.shield_moon_rounded, color: HifiTheme.neonCyan, size: 18),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '微雪 7 寸 QLED 防烧屏与节能微光',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: HifiTheme.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  Wrap(
                                    spacing: 8,
                                    children: _timeoutOptions.map((mins) {
                                      final isSel = piSys.screenSaverTimeoutMinutes == mins;
                                      final label = mins == 0 ? '关闭屏保' : '$mins 分钟';
                                      return ChoiceChip(
                                        label: Text(label),
                                        selected: isSel,
                                        selectedColor: HifiTheme.mcIntoshBlue,
                                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                                        labelStyle: TextStyle(
                                          color: isSel ? Colors.white : HifiTheme.textMuted,
                                          fontSize: 11,
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        onSelected: (_) {
                                          piSys.setScreenSaverTimeout(mins);
                                        },
                                      );
                                    }).toList(),
                                  ),

                                  const SizedBox(height: 14),

                                  // 局域网服务
                                  const Row(
                                    children: [
                                      Icon(Icons.wifi_tethering_rounded, color: HifiTheme.accuphaseGold, size: 18),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '局域网 Web 遥控与无线传歌',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: HifiTheme.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // 服务卡片 1：Web 手机遥控中枢
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: HifiTheme.cardBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.phone_android_rounded, color: HifiTheme.neonCyan, size: 16),
                                            const SizedBox(width: 6),
                                            const Text(
                                              '手机/平板 Web 发烧遥控',
                                              style: TextStyle(
                                                color: HifiTheme.textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: HifiTheme.neonCyan.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                webRemote.isRunning ? '● 运行中 (:8088)' : '○ 未启动',
                                                style: const TextStyle(
                                                  color: HifiTheme.neonCyan,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'http://${webRemote.localIp}:${webRemote.port}',
                                          style: const TextStyle(
                                            color: HifiTheme.neonCyan,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          '浏览器打开上述地址，极低延迟遥控播放、10段EQ与DAC设置',
                                          style: TextStyle(
                                            color: HifiTheme.textMuted,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // 服务卡片 2：WiFi 拖拽传歌服务 (带触控开关)
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: wifi.isRunning
                                            ? HifiTheme.accuphaseGold.withValues(alpha: 0.5)
                                            : HifiTheme.cardBorder,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.upload_file_rounded, color: HifiTheme.accuphaseGold, size: 16),
                                            const SizedBox(width: 6),
                                            const Text(
                                              '电脑无线拖拽传歌服务',
                                              style: TextStyle(
                                                color: HifiTheme.textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: wifi.isRunning
                                                    ? HifiTheme.accuphaseGold.withValues(alpha: 0.15)
                                                    : Colors.white.withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                wifi.isRunning ? '● 运行中 (:8080)' : '○ 已停止 (省电)',
                                                style: TextStyle(
                                                  color: wifi.isRunning ? HifiTheme.accuphaseGold : HifiTheme.textMuted,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          wifi.isRunning
                                              ? 'http://${wifi.localIp}:${wifi.port}'
                                              : '服务已关闭 (点击下方按钮开启)',
                                          style: TextStyle(
                                            color: wifi.isRunning ? HifiTheme.accuphaseGold : HifiTheme.textMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          wifi.completedCount > 0
                                              ? '✓ 本次已上传 ${wifi.completedCount} 首音频 (已自动重新扫描入库)'
                                              : '电脑浏览器访问该网址，即可将 FLAC/DSD 直接拖拽入树莓派',
                                          style: TextStyle(
                                            color: wifi.completedCount > 0 ? HifiTheme.neonCyan : HifiTheme.textMuted,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // 传歌服务启停触控按钮
                                        SizedBox(
                                          width: double.infinity,
                                          height: 38,
                                          child: Material(
                                            color: wifi.isRunning
                                                ? Colors.redAccent.withValues(alpha: 0.15)
                                                : HifiTheme.accuphaseGold.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(8),
                                            child: InkWell(
                                              onTap: () async {
                                                if (wifi.isRunning) {
                                                  await wifi.stop();
                                                } else {
                                                  await wifi.start(port: 8080);
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: wifi.isRunning
                                                        ? Colors.redAccent.withValues(alpha: 0.5)
                                                        : HifiTheme.accuphaseGold.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      wifi.isRunning ? Icons.stop_circle_outlined : Icons.bolt_rounded,
                                                      size: 16,
                                                      color: wifi.isRunning ? Colors.redAccent : HifiTheme.accuphaseGold,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      wifi.isRunning ? '停止传歌服务 (节省内存)' : '开启 WiFi 传歌服务 (:8080)',
                                                      style: TextStyle(
                                                        color: wifi.isRunning ? Colors.redAccent : HifiTheme.accuphaseGold,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // 服务卡片 3：系统固件 OTA 在线升级 (仅在具备 Git 环境的硬件平台展示)
                                  if (PlatformHelper.supportsGitOta()) ...[
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: HifiTheme.cardBorder),
                                    ),
                                    child: ListenableBuilder(
                                      listenable: OtaUpdateService.instance,
                                      builder: (context, _) {
                                        final ota = OtaUpdateService.instance;
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.system_update_alt_rounded, color: HifiTheme.neonCyan, size: 16),
                                                const SizedBox(width: 6),
                                                const Expanded(
                                                  child: Text(
                                                    '系统固件 OTA 在线升级 (Git)',
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: HifiTheme.textPrimary,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: ota.status == OtaStatus.updateAvailable
                                                        ? Colors.orangeAccent.withValues(alpha: 0.2)
                                                        : Colors.white.withValues(alpha: 0.05),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    ota.status == OtaStatus.checking
                                                        ? '检查中...'
                                                        : (ota.status == OtaStatus.updateAvailable
                                                            ? '可升级 (${ota.pendingCommitCount}个更新)'
                                                            : (ota.status == OtaStatus.upToDate ? '已是最新' : '就绪')),
                                                    style: TextStyle(
                                                      color: ota.status == OtaStatus.updateAvailable ? Colors.orangeAccent : HifiTheme.textMuted,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '分支: ${ota.currentBranch} · 版本: ${ota.currentCommit.length > 7 ? ota.currentCommit.substring(0, 7) : ota.currentCommit}',
                                              style: const TextStyle(
                                                color: HifiTheme.textMuted,
                                                fontSize: 10.5,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 36,
                                              child: Material(
                                                color: ota.status == OtaStatus.updateAvailable
                                                    ? HifiTheme.neonCyan.withValues(alpha: 0.2)
                                                    : Colors.white.withValues(alpha: 0.06),
                                                borderRadius: BorderRadius.circular(8),
                                                child: InkWell(
                                                  onTap: ota.status == OtaStatus.checking || ota.status == OtaStatus.updating
                                                      ? null
                                                      : () async {
                                                          if (ota.status == OtaStatus.updateAvailable) {
                                                            await ota.executeUpdate();
                                                          } else {
                                                            await ota.checkForUpdates();
                                                          }
                                                        },
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: ota.status == OtaStatus.updateAvailable
                                                            ? HifiTheme.neonCyan
                                                            : HifiTheme.cardBorder,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      ota.status == OtaStatus.checking
                                                          ? '正在检查远程更新...'
                                                          : (ota.status == OtaStatus.updating
                                                              ? '正在拉取代码升级...'
                                                              : (ota.status == OtaStatus.updateAvailable ? '⚡ 立即一键升级固件' : '检查在线固件更新')),
                                                      style: TextStyle(
                                                        color: ota.status == OtaStatus.updateAvailable ? HifiTheme.neonCyan : HifiTheme.textPrimary,
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
