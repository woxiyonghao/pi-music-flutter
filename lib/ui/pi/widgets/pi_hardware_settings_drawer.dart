import 'package:flutter/material.dart';
import '../../../services/pi_system_service.dart';
import '../../../services/web_remote_service.dart';
import '../../../theme/hifi_theme.dart';
import '../../common/glass_card.dart';

/// 树莓派 1024x600 专属硬件 DAC 与系统设置抽屉
class PiHardwareSettingsDrawer extends StatefulWidget {
  final VoidCallback onClose;

  const PiHardwareSettingsDrawer({super.key, required this.onClose});

  @override
  State<PiHardwareSettingsDrawer> createState() => _PiHardwareSettingsDrawerState();
}

class _PiHardwareSettingsDrawerState extends State<PiHardwareSettingsDrawer> {
  final List<Map<String, String>> _dacOptions = [
    {
      'name': 'AK4191 + AK4499EX',
      'card': 'hw:0,0 (I2S Master Clock)',
      'desc': '双旗舰分体芯片 · 超低相噪飞秒双晶振'
    },
    {
      'name': 'HiFiBerry DAC+ Pro (PCM5122)',
      'card': 'hw:1,0 (I2S)',
      'desc': '高性价比经典 I2S 解码帽子板'
    },
    {
      'name': 'USB Audio Class 2.0 DAC',
      'card': 'hw:2,0 (USB Asynchronous)',
      'desc': '外接桌面级发烧 USB 解码器直通'
    },
    {
      'name': 'ALSA System Default',
      'card': 'default',
      'desc': '系统默认混音音频输出'
    },
  ];

  final List<int> _timeoutOptions = [1, 3, 5, 10, 0];

  @override
  Widget build(BuildContext context) {
    final piSys = PiSystemService.instance;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: GlassCard(
            borderRadius: 16.0,
            backgroundColor: HifiTheme.cardBackground.withValues(alpha: 0.94),
            padding: const EdgeInsets.all(16),
            child: Column(
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

                    const Text(
                      '树莓派 5 发烧硬件与系统设置',
                      style: TextStyle(
                        color: HifiTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Spacer(),

                    // 实时温度标牌
                    ListenableBuilder(
                      listenable: piSys,
                      builder: (context, _) {
                        return Container(
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
                        );
                      },
                    ),
                  ],
                ),

                const Divider(color: HifiTheme.cardBorder, height: 20),

                // 2. 左右双栏设置区
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左栏：ALSA 硬件 DAC 映射与 DSD 直出
                      Expanded(
                        flex: 52,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.speaker_group_rounded, color: HifiTheme.mcIntoshGlow, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'ALSA 物理硬件声卡 (Bit-Perfect Direct)',
                                  style: TextStyle(
                                    color: HifiTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Expanded(
                              child: ListView.builder(
                                itemCount: _dacOptions.length,
                                itemBuilder: (context, idx) {
                                  final item = _dacOptions[idx];
                                  final isSelected = piSys.dacDeviceName == item['name'];

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Material(
                                      color: isSelected
                                          ? HifiTheme.mcIntoshBlue.withValues(alpha: 0.22)
                                          : Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            piSys.setDacDevice(item['name']!, item['card']!);
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
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
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item['name']!,
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? HifiTheme.mcIntoshGlow
                                                            : HifiTheme.textPrimary,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${item['card']} · ${item['desc']}',
                                                      style: const TextStyle(
                                                        color: HifiTheme.textMuted,
                                                        fontSize: 11,
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
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // 右栏：QLED 屏幕防烧屏与局域网 Web 遥控配置
                      Expanded(
                        flex: 48,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.shield_moon_rounded, color: HifiTheme.neonCyan, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  '微雪 7 寸 QLED 防烧屏与节能微光',
                                  style: TextStyle(
                                    color: HifiTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

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
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  onSelected: (_) {
                                    setState(() {
                                      piSys.setScreenSaverTimeout(mins);
                                    });
                                  },
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),

                            const Row(
                              children: [
                                Icon(Icons.wifi_rounded, color: HifiTheme.accuphaseGold, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  '局域网 Web 遥控与无线传歌',
                                  style: TextStyle(
                                    color: HifiTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Container(
                              padding: const EdgeInsets.all(12),
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
                                      const Icon(Icons.phone_android_rounded, color: HifiTheme.mcIntoshGlow, size: 18),
                                      const SizedBox(width: 8),
                                      const Text('手机浏览器遥控: ', style: TextStyle(color: HifiTheme.textMuted, fontSize: 12)),
                                      Text(
                                        'http://${WebRemoteService.instance.localIp}:${WebRemoteService.instance.port}',
                                        style: const TextStyle(
                                          color: HifiTheme.neonCyan,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.upload_file_rounded, color: HifiTheme.accuphaseGold, size: 18),
                                      const SizedBox(width: 8),
                                      const Text('电脑无线拖拽传歌: ', style: TextStyle(color: HifiTheme.textMuted, fontSize: 12)),
                                      Text(
                                        'http://${WebRemoteService.instance.localIp}:8080',
                                        style: const TextStyle(
                                          color: HifiTheme.accuphaseGold,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
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
  }
}
