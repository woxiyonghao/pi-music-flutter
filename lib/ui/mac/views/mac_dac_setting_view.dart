import 'package:flutter/material.dart';
import '../../../models/dac_device_info.dart';
import '../../../services/dac_setting_service.dart';
import '../../../services/theme_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// 动态发烧 DAC 解码设置视图 (Master-Detail 架构)
/// 严格根据实际连接的物理硬件 (如【本机解码器】与【外接解码器: 拓品 TOPPING DX12】) 动态呈现，
/// 彻底移除未连接芯片的冗余干扰项，专享高保真硬件参数配置。
class MacDACSettingView extends StatefulWidget {
  const MacDACSettingView({super.key});

  @override
  State<MacDACSettingView> createState() => _MacDACSettingViewState();
}

class _MacDACSettingViewState extends State<MacDACSettingView> {
  @override
  void initState() {
    super.initState();
    DacSettingService.instance.refreshDevices();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        DacSettingService.instance,
        ThemeService.instance,
      ]),
      builder: (context, _) {
        final dac = DacSettingService.instance;
        final theme = ThemeService.instance;
        final accent = theme.accentColor;
        final devices = dac.connectedDevices;
        final currentDev = dac.currentDevice;

        return GlassCard(
          borderRadius: UIConfig.containerRounding,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 顶栏：标题与动态状态指示
              _buildHeader(theme, accent, dac),
              const SizedBox(height: 12),

              // 2. 实际连接的解码器选项卡 (如: 本机解码器、外接解码器 TOPPING DX12)
              _buildConnectedDeviceTabs(devices, dac, accent),
              const SizedBox(height: 14),

              // 3. 下方详情设置区：根据当前选中的解码器动态呈现其专属支持项
              Expanded(
                child: currentDev == null
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 硬件能力全景名片
                            _buildHardwareBadgeCard(currentDev, accent),
                            const SizedBox(height: 14),

                            // 专有设置选项
                            if (currentDev.isBuiltIn)
                              _buildBuiltinSettings(currentDev, dac, accent)
                            else
                              _buildExternalDacSettings(currentDev, dac, accent),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 顶栏：标题与硬件自适应提示
  Widget _buildHeader(ThemeService theme, Color accent, DacSettingService dac) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.album_rounded, color: accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '发烧 DAC 物理硬件与解码设置',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '动态硬件感知',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '仅显示实际连接的解码设备及其物理支持的参数，未连接芯片已自动剔除',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
              ),
            ],
          ),
        ),
        // 模拟/物理外接设备调试开关 (方便用户在买到真机前调校)
        if (!dac.hasExternalDac)
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: Icon(Icons.add_circle_outline_rounded, size: 14, color: accent),
            label: Text(
              '模拟接入 TOPPING DX12 调校',
              style: TextStyle(color: accent, fontSize: 11),
            ),
            onPressed: () {
              dac.toggleMockExternal(true);
            },
          )
        else
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.usb_off_rounded, size: 14, color: Colors.white54),
            label: const Text(
              '移除模拟外设',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            onPressed: () {
              dac.toggleMockExternal(false);
            },
          ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '重新探测已连接的音频设备',
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
          onPressed: () {
            dac.refreshDevices();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已重新扫描硬件音频总线与 USB 外接设备'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }

  /// 已连接解码器切换卡片 (本机解码器 vs 外接解码器 TOPPING DX12)
  Widget _buildConnectedDeviceTabs(List<DacDeviceInfo> devices, DacSettingService dac, Color accent) {
    if (devices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: List.generate(devices.length, (idx) {
        final dev = devices[idx];
        final isSelected = (idx == dac.selectedDeviceIndex);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: idx < devices.length - 1 ? 12.0 : 0.0),
            child: GestureDetector(
              onTap: () => dac.selectDevice(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? accent.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? accent : Colors.white.withValues(alpha: 0.1),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? accent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        dev.isBuiltIn ? Icons.laptop_mac_rounded : Icons.usb_rounded,
                        color: isSelected ? accent : Colors.white70,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                dev.isBuiltIn ? '本机解码器' : '外接解码器',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: (dev.isBuiltIn ? Colors.blue : Colors.amber).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  dev.transport,
                                  style: TextStyle(
                                    color: dev.isBuiltIn ? Colors.lightBlueAccent : Colors.amberAccent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dev.name,
                            style: TextStyle(
                              color: isSelected ? accent : Colors.white60,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: accent, size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 硬件规格全景名片
  Widget _buildHardwareBadgeCard(DacDeviceInfo dev, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141924).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dev.brand.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dev.model,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withValues(alpha: 0.25), accent.withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      dev.specBadge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildBadgeInfo('核心 DAC', dev.chipModel, Icons.memory_rounded),
              _buildBadgeInfo('传输界面', dev.usbInterface.isNotEmpty ? dev.usbInterface : '原生总线', Icons.sync_alt_rounded),
              _buildBadgeInfo('DSD 模式', dev.maxDsdRate, Icons.graphic_eq_rounded),
              _buildBadgeInfo('协商速率', '${(dev.currentSampleRate / 1000).round()} kHz', Icons.speed_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeInfo(String title, String val, IconData icon) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                Text(
                  val,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 本机解码器专属设置区 (Apple Direct / Linux ALSA Direct)
  Widget _buildBuiltinSettings(DacDeviceInfo dev, DacSettingService dac, Color accent) {
    final exclusiveHog = dac.getParam('apple_exclusive', 0) == 0;
    final bufferIdx = dac.getParam('builtin_buffer_size', 2); // 0:64, 1:128, 2:256, 3:512, 4:1024
    final sampleRateMode = dac.getParam('apple_sample_rate', 0);
    final bitDepthMode = dac.getParam('apple_bit_depth', 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('系统原生独占与硬件缓冲区控制', Icons.tune_rounded, accent),
        const SizedBox(height: 8),

        // 1. CoreAudio Hog Mode 独占直通
        _buildSwitchTile(
          title: 'CoreAudio 独占模式 (Exclusive Hog Mode)',
          subtitle: '独占声卡物理访问权，彻底绕过系统音频混音器与格式二次重采样，保证 100% Bit-Perfect 源码输出',
          value: exclusiveHog,
          accent: accent,
          onChanged: (val) {
            dac.setParam('apple_exclusive', val ? 0 : 1);
          },
        ),
        const SizedBox(height: 10),

        // 2. 硬件缓冲区大小
        _buildCapsuleSelector(
          title: '声卡硬件缓冲区深度 (Hardware Buffer Size)',
          subtitle: '控制推流时钟延迟，64 帧极速响应，256 帧发烧平衡推荐，1024 帧抗爆音断流',
          options: const ['64 帧 (1.4ms)', '128 帧 (2.9ms)', '256 帧 (5.8ms)', '512 帧 (11.6ms)', '1024 帧 (23.2ms)'],
          selectedIndex: bufferIdx,
          accent: accent,
          onSelected: (idx) {
            dac.setParam('builtin_buffer_size', idx);
          },
        ),
        const SizedBox(height: 10),

        // 3. 原生采样率跟踪
        _buildCapsuleSelector(
          title: '硬件主时钟采样率策略',
          subtitle: '跟随正在播放的母带音频自动自适应物理切换声卡时钟，或强制锁定输出',
          options: const ['原生跟随母带 (44.1k - 192k)', '锁定 96kHz 超解析', '锁定 192kHz 母带直出'],
          selectedIndex: sampleRateMode,
          accent: accent,
          onSelected: (idx) {
            dac.setParam('apple_sample_rate', idx);
          },
        ),
        const SizedBox(height: 10),

        // 4. 数字音频位深
        _buildCapsuleSelector(
          title: '数字信号输出位深',
          subtitle: '32-Bit Float 浮点无损直通具备 1500dB 极高动态余量，杜绝数字削顶失真',
          options: const ['32-Bit Float 浮点直通 (推荐)', '24-Bit 定点高保真'],
          selectedIndex: bitDepthMode,
          accent: accent,
          onSelected: (idx) {
            dac.setParam('apple_bit_depth', idx);
          },
        ),
      ],
    );
  }

  /// 外接解码器专属设置区 (以 TOPPING DX12 / ESS ES9039Q2M 架构为核心)
  Widget _buildExternalDacSettings(DacDeviceInfo dev, DacSettingService dac, Color accent) {
    final filterIdx = dac.getParam('topping_filter', 0).clamp(0, dev.digitalFilters.length - 1);
    final dpllIdx = dac.getParam('topping_dpll', 1).clamp(0, 4);
    final dsdCutoffIdx = dac.getParam('topping_dsd_cutoff', 0).clamp(0, 3);
    final uacIdx = dac.getParam('topping_uac_mode', 0).clamp(0, 1);
    final lineOutBypass = dac.getParam('topping_lineout_bypass', 0) == 0;
    final gainIdx = dac.getParam('topping_gain', 0).clamp(0, 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('${dev.model} · 发烧芯片与数字滤波调教', Icons.tune_rounded, accent),
        const SizedBox(height: 8),

        // 1. 核心数字滤波器选择 (ESS ES9039Q2M 官方 8 种滤波曲线)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141924).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.waves_rounded, color: accent, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'ESS Sabre 芯片级数字滤波器 (Digital Roll-off Filter)',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '直接改变 DAC 芯片内过采样数字重构滤波响应曲线，塑造不同瞬态动态与结像声场听感',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
              ),
              const SizedBox(height: 12),
              // 8 种滤波网格/列表
              Column(
                children: List.generate(dev.digitalFilters.length, (idx) {
                  final isSel = (filterIdx == idx);
                  final filterName = dev.digitalFilters[idx];
                  final desc = idx < dev.filterDescriptions.length ? dev.filterDescriptions[idx] : '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => dac.setParam('topping_filter', idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? accent : Colors.white12,
                            width: isSel ? 1.2 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              size: 16,
                              color: isSel ? accent : Colors.white38,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    filterName,
                                    style: TextStyle(
                                      color: isSel ? Colors.white : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      desc,
                                      style: TextStyle(
                                        color: isSel ? accent.withValues(alpha: 0.9) : Colors.white38,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSel)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '当前生效',
                                  style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. ESS DPLL 时钟抖动消除带宽
        _buildCapsuleSelector(
          title: 'ESS DPLL 时钟抖动抑制带宽 (DPLL Jitter Bandwidth)',
          subtitle: '锁定输入音频时钟抖动。低档位（极窄带）声音背景极黑、细节极通透；高档位兼容性更佳',
          options: const ['极窄带 1 (极致透明)', '标准带宽 2 (推荐)', '均衡带宽 3', '高容错 4', '宽带 5 (抗断流)'],
          selectedIndex: dpllIdx,
          accent: accent,
          onSelected: (idx) {
            dac.setParam('topping_dpll', idx);
          },
        ),
        const SizedBox(height: 12),

        // 3. DSD 模拟截止频率与直通策略
        _buildCapsuleSelector(
          title: 'DSD 模拟低通滤波截止频率 (DSD Cutoff Frequency)',
          subtitle: '过滤 DSD 1-Bit 超高频调制高频噪声。47.7kHz 适合标准发烧录音，70kHz 还原极致微动态',
          options: const ['47.7kHz (标准推荐)', '50.0kHz', '60.0kHz', '70.0kHz (宽频大动态)'],
          selectedIndex: dsdCutoffIdx,
          accent: accent,
          onSelected: (idx) {
            dac.setParam('topping_dsd_cutoff', idx);
          },
        ),
        const SizedBox(height: 12),

        // 4. UAC 协议模式 (USB Audio Class 2.0 vs 1.0)
        _buildCapsuleSelector(
          title: 'UAC 协议通信模式 (USB Audio Class)',
          subtitle: 'UAC 2.0 释放 384kHz/32Bit 与 DSD256 极限性能；UAC 1.0 免驱动即插即用（限 96kHz）',
          options: const ['UAC 2.0 (全速异步传输 · 384k/DSD256)', 'UAC 1.0 (标准免驱 · 兼容游戏机/PS5/Switch)'],
          selectedIndex: uacIdx,
          accent: accent,
          onSelected: (idx) {
            dac.setParam('topping_uac_mode', idx);
          },
        ),
        const SizedBox(height: 12),

        // 5. 输出增益与前级 0dB 直通
        Row(
          children: [
            Expanded(
              child: _buildSwitchTile(
                title: '0dB 纯解码直出 (Line Out Bypass)',
                subtitle: '旁路软件数字音量调节，固定 0dB 全电平源码直通给外接功放/耳放',
                value: lineOutBypass,
                accent: accent,
                onChanged: (val) {
                  dac.setParam('topping_lineout_bypass', val ? 0 : 1);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCapsuleSelector(
                title: '耳机放大推力增益 (Gain Mode)',
                subtitle: '低增益适配高敏 IEM 入耳耳塞；高增益释放 1000mW 大推力驱动大耳',
                options: const ['0dB 低增益 (IEM 入耳)', '+6dB 高增益 (平衡大推力)'],
                selectedIndex: gainIdx,
                accent: accent,
                onSelected: (idx) {
                  dac.setParam('topping_gain', idx);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color accent) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Color accent,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141924).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: accent,
            activeTrackColor: accent.withValues(alpha: 0.35),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleSelector({
    required String title,
    required String subtitle,
    required List<String> options,
    required int selectedIndex,
    required Color accent,
    required ValueChanged<int> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141924).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(options.length, (idx) {
              final isSel = (idx == selectedIndex);
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onSelected(idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? accent : Colors.white12,
                      width: isSel ? 1.2 : 0.8,
                    ),
                  ),
                  child: Text(
                    options[idx],
                    style: TextStyle(
                      color: isSel ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.usb_off_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          const Text(
            '未检测到已连接的音频硬件',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '请检查外接 USB DAC 或内置声卡驱动连接状态',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
