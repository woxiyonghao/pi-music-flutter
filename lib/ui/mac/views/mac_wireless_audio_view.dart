import 'package:flutter/material.dart';
import '../../../core/hifi_audio_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/wireless_audio_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// 树莓派无线音频接收页面（蓝牙 A2DP Sink 与 AirPlay，互斥使用 USB DAC）
class MacWirelessAudioView extends StatelessWidget {
  const MacWirelessAudioView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeService.instance,
        WirelessAudioService.instance,
        HifiAudioService.instance,
      ]),
      builder: (context, _) {
        final accent = ThemeService.instance.accentColor;
        final wireless = WirelessAudioService.instance;
        final btOn = wireless.isBluetoothEnabled;
        final airplayOn = wireless.isAirplayEnabled;
        final switching = wireless.isSwitching;

        final statusLabel = btOn
            ? '蓝牙已开启'
            : airplayOn
                ? 'AirPlay 已开启'
                : '本机音乐模式';
        final statusColor =
            (btOn || airplayOn) ? accent : const Color(0xFF10B981);

        final btSubtitle = btOn
            ? (wireless.connectedBluetoothDevice != null
                ? '已连接设备: ${wireless.connectedBluetoothDevice} · 通过 DX1 II 输出'
                : '等待手机连接蓝牙 "${WirelessAudioService.deviceBroadcastName}" (可配对)')
            : '默认无线方式 · 关闭状态下由本机曲库独享 DX1 II';

        final airplaySubtitle = airplayOn
            ? '已在局域网广播 "${WirelessAudioService.deviceBroadcastName}" · 通过 DX1 II 输出'
            : '同一 Wi-Fi 下 iPhone / iPad / Mac 隔空播放无损直出';

        return GlassCard(
          borderRadius: UIConfig.containerRounding,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '无线播放',
                        style: TextStyle(
                          fontSize: UIConfig.fontMedium,
                          fontWeight: FontWeight.bold,
                          color: UIConfig.textActive,
                        ),
                      ),
                      SizedBox(width: 12.0),
                      Text(
                        '外部设备推送音频至数播 DX1 II 输出',
                        style: TextStyle(
                          fontSize: UIConfig.fontSmall,
                          color: UIConfig.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7.0,
                          height: 7.0,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _WirelessSwitchCell(
                      key: const Key('wireless-bluetooth-cell'),
                      switchKey: const Key('wireless-bluetooth-switch'),
                      icon: Icons.bluetooth_audio_rounded,
                      title: '蓝牙',
                      badge: '默认',
                      subtitle: btSubtitle,
                      value: btOn,
                      enabled: !switching,
                      accent: accent,
                      onChanged: wireless.setBluetoothEnabled,
                    ),
                    const SizedBox(height: 10.0),
                    _WirelessSwitchCell(
                      key: const Key('wireless-airplay-cell'),
                      switchKey: const Key('wireless-airplay-switch'),
                      icon: Icons.airplay_rounded,
                      title: 'AirPlay',
                      subtitle: airplaySubtitle,
                      value: airplayOn,
                      enabled: !switching,
                      accent: accent,
                      onChanged: wireless.setAirplayEnabled,
                    ),
                    const SizedBox(height: 16.0),
                    Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.03),
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.07),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16.0,
                            color: accent,
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                              switching
                                  ? '正在切换音频输出通道，请稍候…'
                                  : (btOn || airplayOn)
                                      ? '已停止本机音乐并释放 DX1 II，关闭开关或点播本机歌曲可切回本地无损播放。'
                                      : '当前处于本机播放模式；开启蓝牙或 AirPlay 后将自动停止本机音乐并转接外部音频。',
                              style: const TextStyle(
                                fontSize: 12.0,
                                color: UIConfig.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (wireless.errorMessage != null) ...[
                      const SizedBox(height: 12.0),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: const Color(0x26EF4444),
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: const Color(0x66EF4444)),
                        ),
                        child: Text(
                          '切换失败: ${wireless.errorMessage}',
                          style: const TextStyle(
                            fontSize: 12.0,
                            color: Color(0xFFFCA5A5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WirelessSwitchCell extends StatelessWidget {
  final Key switchKey;
  final IconData icon;
  final String title;
  final String? badge;
  final String subtitle;
  final bool value;
  final bool enabled;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _WirelessSwitchCell({
    super.key,
    required this.switchKey,
    required this.icon,
    required this.title,
    this.badge,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: value
            ? accent.withValues(alpha: 0.12)
            : const Color.fromRGBO(255, 255, 255, 0.04),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: value
              ? accent.withValues(alpha: 0.55)
              : const Color.fromRGBO(255, 255, 255, 0.08),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38.0,
            height: 38.0,
            decoration: BoxDecoration(
              color: (value ? accent : Colors.white).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(
              icon,
              size: 20.0,
              color: value ? accent : UIConfig.textNormal,
            ),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: UIConfig.textActive,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6.0, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(5.0),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3.0),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: UIConfig.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          Switch(
            key: switchKey,
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: accent,
            activeTrackColor: accent.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}
