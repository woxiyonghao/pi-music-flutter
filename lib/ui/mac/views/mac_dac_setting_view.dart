import 'package:flutter/material.dart';
import '../../../services/music_database_service.dart';
import '../../../services/theme_service.dart';
import '../../../theme/ui_config.dart';
import '../../common/glass_card.dart';

/// DAC 解码设置视图 (1:1 严格对齐 C++ DACSettingView.cpp，支持全部 6 大芯片架构切换与 SQLite 持久化)
class MacDACSettingView extends StatefulWidget {
  const MacDACSettingView({super.key});

  @override
  State<MacDACSettingView> createState() => _MacDACSettingViewState();
}

class _MacDACSettingViewState extends State<MacDACSettingView> {
  int _selectedChip = 0; // 0: Apple 直通, 1: ES9038PRO, 2: AK4499EX, 3: CS43198, 4: R-2R 纯电阻, 5: ROHM 34301

  static const List<String> chips = [
    'Apple 直通',
    'ES9038PRO',
    'AK4499EX',
    'CS43198',
    'R-2R 纯电阻',
    'ROHM 34301',
  ];

  // 0. Apple Direct 选项状态
  bool _exclusiveMode = true;
  int _appleExclusiveFlow = 0; // 0: Bit-Perfect 独占流, 1: 系统混音共享
  int _appleSampleRateTrack = 0; // 0: 原生跟随母带 (44.1k-192k), 1: 锁定 96kHz, 2: 锁定 192kHz
  int _appleImpedanceDrive = 0; // 0: 智能检测 (1.25V~3Vrms), 1: 强制高输出 (3.0Vrms), 2: 标准输出 (1.25Vrms)
  int _appleBitDepth = 0; // 0: 32-bit Float 浮点直通, 1: 24-bit 整数定点
  int _selectedDeviceIndex = 1; // 0: LS27B61x, 1: Mac mini扬声器

  // 1. ESS Sabre ES9038PRO
  int _essPcmFilter = 0; // 0~6: 快速最小, 慢速最小, 快速线性, 慢速线性, 变迹滤波, 砖墙滤波, 混合滤波
  int _essDsdBypass = 0; // 0: Direct 1-Bit 直通, 1: FIR 模拟滤波
  int _essDsdCutoff = 0; // 0: 47.7kHz, 1: 50kHz, 2: 60kHz, 3: 70kHz
  int _essPcmDpll = 1;   // 0: 极窄带, 1: 标准平衡 (推荐), 2: 宽带
  int _essThdComp = 0;   // 0: 超低失真 (< -122dB), 1: 二次谐波 (胆味), 2: 关闭补偿
  int _essChannelMode = 0; // 0: 双芯片 8-Ch 并联 (140dB), 1: 双芯片立体声平衡
  int _essPhaseInvert = 0; // 0: 绝对正相 (0°), 1: 极性反转 (180°)

  // 2. AKM AK4499EX
  int _akmFilter = 0; // 0~5: 短延时锐滚降, 短延时慢滚降, 锐滚降, 慢滚降, 超低群延迟, 低色散短延时
  int _akmColor = 0;  // 0: 风格1 (自然), 1: 风格2 (通透), 2: 风格3 (宽厚), 3: 风格4 (监听)
  int _akmDsd = 0;    // 0: Direct 模式 (旁路调制), 1: Normal 滤波模式
  int _akmExdf = 0;   // 0: 外部超采样直通 (EXDF), 1: 内部 AK4191EQ 处理

  // 3. Cirrus Logic CS43198
  int _csFilter = 0;    // 0~4: 快速线性, 慢速线性, 快速最小, 慢速最小, NOS 无过采样
  int _csDsd = 0;       // 0: Direct DSD (直接转换), 1: DoP 硬件解调
  int _csDrive = 0;     // 0: 高推力伪差分 (2Vrms), 1: 标准单端 (1Vrms)
  int _csImpedance = 0; // 0: 自适应匹配 (16Ω~600Ω), 1: 高阻监听优先

  // 4. R-2R 纯电阻
  int _r2rMode = 0;  // 0: NOS 纯无过采样, 1: OS 线性相位超采样, 2: OS 最小相位超采样
  int _r2rDsd = 0;   // 0: 独立 1-Bit 电阻网络转换, 1: 转换为 24-bit 阶梯解码
  int _r2rClock = 0; // 0: 飞秒 FIFO 本地时钟重整, 1: 直接跟随输入源时钟
  int _r2rPhase = 0; // 0: 绝对正相 (0°), 1: 极性反转 (180°)

  // 5. ROHM 34301
  int _rohmFilter = 0; // 0: Sharp Roll-Off, 1: Slow Roll-Off
  int _rohmClock = 0;  // 0: 智能倍频自适应, 1: 锁定 64x fs, 2: 锁定 128x fs
  int _rohmDsd = 0;    // 0: Direct Path 纯模拟通道, 1: 标准多级滤波处理

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final db = MusicDatabaseService.instance;
    _selectedChip = int.tryParse(db.getSetting('setting_dac_selected_chip', '0'))?.clamp(0, 5) ?? 0;

    // Apple Direct
    _appleExclusiveFlow = int.tryParse(db.getSetting('setting_dac_apple_exclusive', '0'))?.clamp(0, 1) ?? 0;
    _exclusiveMode = (_appleExclusiveFlow == 0);
    _appleSampleRateTrack = int.tryParse(db.getSetting('setting_dac_apple_sample_rate', '0'))?.clamp(0, 2) ?? 0;
    _appleImpedanceDrive = int.tryParse(db.getSetting('setting_dac_apple_drive', '0'))?.clamp(0, 2) ?? 0;
    _appleBitDepth = int.tryParse(db.getSetting('setting_dac_apple_bit_depth', '0'))?.clamp(0, 1) ?? 0;

    // ESS Sabre
    _essPcmFilter = int.tryParse(db.getSetting('setting_dac_pcm_filter', '0'))?.clamp(0, 6) ?? 0;
    _essDsdBypass = int.tryParse(db.getSetting('setting_dac_dsd_bypass', '0'))?.clamp(0, 1) ?? 0;
    _essDsdCutoff = int.tryParse(db.getSetting('setting_dac_dsd_cutoff', '0'))?.clamp(0, 3) ?? 0;
    _essPcmDpll = int.tryParse(db.getSetting('setting_dac_pcm_dpll', '1'))?.clamp(0, 2) ?? 1;
    _essThdComp = int.tryParse(db.getSetting('setting_dac_thd_comp', '0'))?.clamp(0, 2) ?? 0;
    _essChannelMode = int.tryParse(db.getSetting('setting_dac_mono_mode', '0'))?.clamp(0, 1) ?? 0;
    _essPhaseInvert = int.tryParse(db.getSetting('setting_dac_phase', '0'))?.clamp(0, 1) ?? 0;

    // AKM
    _akmFilter = int.tryParse(db.getSetting('setting_dac_akm_filter', '0'))?.clamp(0, 5) ?? 0;
    _akmColor = int.tryParse(db.getSetting('setting_dac_akm_color', '0'))?.clamp(0, 3) ?? 0;
    _akmDsd = int.tryParse(db.getSetting('setting_dac_akm_dsd', '0'))?.clamp(0, 1) ?? 0;
    _akmExdf = int.tryParse(db.getSetting('setting_dac_akm_exdf', '0'))?.clamp(0, 1) ?? 0;

    // Cirrus Logic
    _csFilter = int.tryParse(db.getSetting('setting_dac_cs_filter', '0'))?.clamp(0, 4) ?? 0;
    _csDsd = int.tryParse(db.getSetting('setting_dac_cs_dsd', '0'))?.clamp(0, 1) ?? 0;
    _csDrive = int.tryParse(db.getSetting('setting_dac_cs_drive', '0'))?.clamp(0, 1) ?? 0;
    _csImpedance = int.tryParse(db.getSetting('setting_dac_cs_impedance', '0'))?.clamp(0, 1) ?? 0;

    // R-2R
    _r2rMode = int.tryParse(db.getSetting('setting_dac_r2r_mode', '0'))?.clamp(0, 2) ?? 0;
    _r2rDsd = int.tryParse(db.getSetting('setting_dac_r2r_dsd', '0'))?.clamp(0, 1) ?? 0;
    _r2rClock = int.tryParse(db.getSetting('setting_dac_r2r_clock', '0'))?.clamp(0, 1) ?? 0;
    _r2rPhase = int.tryParse(db.getSetting('setting_dac_r2r_phase', '0'))?.clamp(0, 1) ?? 0;

    // ROHM
    _rohmFilter = int.tryParse(db.getSetting('setting_dac_rohm_filter', '0'))?.clamp(0, 1) ?? 0;
    _rohmClock = int.tryParse(db.getSetting('setting_dac_rohm_clock', '0'))?.clamp(0, 2) ?? 0;
    _rohmDsd = int.tryParse(db.getSetting('setting_dac_rohm_dsd', '0'))?.clamp(0, 1) ?? 0;
  }

  void _onChipSelected(int index) {
    setState(() {
      _selectedChip = index;
    });
    MusicDatabaseService.instance.setSetting('setting_dac_selected_chip', index.toString());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final accent = ThemeService.instance.accentColor;

        return GlassCard(
      borderRadius: UIConfig.containerRounding,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题「DAC 设置」
          const Text(
            'DAC 设置',
            style: TextStyle(
              fontSize: UIConfig.fontMedium,
              fontWeight: FontWeight.bold,
              color: UIConfig.textActive,
            ),
          ),
          const SizedBox(height: 14.0),

          // 顶部芯片架构分段选择 Chips
          Row(
            children: [
              for (int i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 8.0),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onChipSelected(i),
                    child: Container(
                      height: 32.0,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedChip == i
                            ? accent.withOpacity(0.28)
                            : const Color.fromRGBO(255, 255, 255, 0.04),
                        borderRadius: BorderRadius.circular(7.0),
                        border: Border.all(
                          color: _selectedChip == i
                              ? accent
                              : const Color.fromRGBO(255, 255, 255, 0.1),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        chips[i],
                        style: TextStyle(
                          fontSize: UIConfig.fontSmall,
                          fontWeight: _selectedChip == i
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedChip == i
                              ? UIConfig.textActive
                              : UIConfig.textNormal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12.0),

          // 状态横幅卡片：声卡硬件与独占模式就绪指示 (所有芯片通用共享)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(20, 26, 36, 0.7),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: const Color.fromRGBO(255, 255, 255, 0.08),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.7),
                            blurRadius: 4.0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    const Text(
                      '声卡硬件: Mac mini扬声器  |  独占模式就绪 (起播锁定)  |  44 kHz',
                      style: TextStyle(
                        fontSize: UIConfig.fontSmall,
                        color: UIConfig.textActive,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _exclusiveMode = !_exclusiveMode;
                      _appleExclusiveFlow = _exclusiveMode ? 0 : 1;
                    });
                    MusicDatabaseService.instance.setSetting('setting_dac_apple_exclusive', _exclusiveMode ? '0' : '1');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: _exclusiveMode
                          ? accent.withOpacity(0.25)
                          : const Color.fromRGBO(255, 255, 255, 0.05),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: _exclusiveMode
                            ? accent
                            : const Color.fromRGBO(255, 255, 255, 0.15),
                      ),
                    ),
                    child: Text(
                      _exclusiveMode ? '独占: 已开启' : '独占: 已旁路',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _exclusiveMode ? UIConfig.textActive : UIConfig.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),

          // 主滚动区：根据选中芯片架构切换对应设置面板
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildActiveChipSection(accent),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildActiveChipSection(Color accent) {
    switch (_selectedChip) {
      case 0:
        return _buildAppleDirectSection(accent);
      case 1:
        return _buildESSSabreSection(accent);
      case 2:
        return _buildAKMVelvetSection(accent);
      case 3:
        return _buildCirrusSection(accent);
      case 4:
        return _buildR2RSection(accent);
      case 5:
        return _buildROHMSection(accent);
      default:
        return _buildAppleDirectSection(accent);
    }
  }

  // ===========================================================================
  // 0. Apple Direct (CoreAudio Bit-Perfect)
  // ===========================================================================
  Widget _buildAppleDirectSection(Color accent) {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Mac 硬件直通通道 (Apple CoreAudio Bit-Perfect)',
          children: [
            _buildSegmentedRow(
              label: '硬件独占流',
              options: const ['Bit-Perfect 独占流', '系统混音共享'],
              selectedIndex: _appleExclusiveFlow,
              onSelected: (idx) {
                setState(() {
                  _appleExclusiveFlow = idx;
                  _exclusiveMode = (idx == 0);
                });
                MusicDatabaseService.instance.setSetting('setting_dac_apple_exclusive', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '采样率追踪',
              options: const ['原生跟随母带 (44.1k-192k)', '锁定 96kHz', '锁定 192kHz'],
              selectedIndex: _appleSampleRateTrack,
              onSelected: (idx) {
                setState(() => _appleSampleRateTrack = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_apple_sample_rate', idx.toString());
              },
              accent: accent,
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        _buildSectionCard(
          title: '高阻抗耳机智能驱动与数据精度 (Impedance & Bit Depth)',
          children: [
            _buildSegmentedRow(
              label: '阻抗驱动力',
              options: const [
                '智能检测 (1.25V~3Vrms)',
                '强制高输出 (3.0Vrms)',
                '标准输出 (1.25Vrms)',
              ],
              selectedIndex: _appleImpedanceDrive,
              onSelected: (idx) {
                setState(() => _appleImpedanceDrive = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_apple_drive', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '数据位深',
              options: const ['32-bit Float 浮点直通', '24-bit 整数定点'],
              selectedIndex: _appleBitDepth,
              onSelected: (idx) {
                setState(() => _appleBitDepth = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_apple_bit_depth', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            const Text(
              'Apple Direct 说明: MacBook Pro 硬件直通，Bit-Perfect 独占流绕过系统混音，原生 0 损耗输出。支持 3.5mm 智能阻抗自适应放大。',
              style: TextStyle(
                fontSize: 11.0,
                color: UIConfig.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        _buildSectionCard(
          title: 'CoreAudio 音频输出设备拓扑 (实时枚举)',
          children: [
            _buildDeviceRow(
              index: 0,
              name: 'LS27B61x',
              arch: '架构: AppleHDA',
              isBuiltIn: true,
              isCurrent: _selectedDeviceIndex == 0,
              onTap: () => setState(() => _selectedDeviceIndex = 0),
              accent: accent,
            ),
            const SizedBox(height: 6.0),
            _buildDeviceRow(
              index: 1,
              name: 'Mac mini扬声器',
              arch: '架构: AppleHDA',
              isBuiltIn: true,
              isCurrent: _selectedDeviceIndex == 1,
              onTap: () => setState(() => _selectedDeviceIndex = 1),
              accent: accent,
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 1. ESS Sabre (ES9038PRO / ES9039PRO 双并联架构)
  // ===========================================================================
  Widget _buildESSSabreSection(Color accent) {
    const firDescs = [
      '快速最小: 消除前置振铃，低频冲击力与厚实人声极佳 (现代流媒体发烧推荐)',
      '慢速最小: 瞬态衰减平滑，极低相位延迟，模拟韵味醇厚',
      '快速线性: 频响开阔平坦，全频段高解析监听与宏大声场',
      '慢速线性: 消除高频突兀，古典弦乐与大编制交响温润自然',
      '变迹滤波: 彻底滤除早期母带残留高频混叠与杂散伪影',
      '砖墙滤波: 超陡峭截止，彻底隔绝带外高频噪声，理论指标极致',
      '混合滤波: 融汇线性与最小相位优势，声场宽阔通透',
    ];

    return Column(
      children: [
        _buildSectionCard(
          title: 'ESS Sabre ES9038PRO 硬件 FIR 滤波特性 (8通道双并联 HyperStream II)',
          children: [
            _buildSegmentedRow(
              label: '滤波特性 (1)',
              options: const ['快速最小 (推荐)', '慢速最小', '快速线性', '慢速线性'],
              selectedIndex: _essPcmFilter < 4 ? _essPcmFilter : -1,
              onSelected: (idx) {
                setState(() => _essPcmFilter = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_pcm_filter', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '滤波特性 (2)',
              options: const ['变迹滤波', '砖墙滤波', '混合滤波'],
              selectedIndex: _essPcmFilter >= 4 ? (_essPcmFilter - 4) : -1,
              onSelected: (idx) {
                final realIdx = idx + 4;
                setState(() => _essPcmFilter = realIdx);
                MusicDatabaseService.instance.setSetting('setting_dac_pcm_filter', realIdx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            Text(
              firDescs[_essPcmFilter.clamp(0, firDescs.length - 1)],
              style: const TextStyle(fontSize: 11.0, color: UIConfig.textMuted, height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        _buildSectionCard(
          title: 'DSD 模拟低通滤波与 DPLL 飞秒抖动消除器 (DSD & DPLL)',
          children: [
            _buildSegmentedRow(
              label: 'DSD 数据通路',
              options: const ['Direct 1-Bit 直通', 'FIR 模拟滤波'],
              selectedIndex: _essDsdBypass,
              onSelected: (idx) {
                setState(() => _essDsdBypass = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_dsd_bypass', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: 'DSD 截止频率',
              options: const ['47.7kHz', '50kHz', '60kHz', '70kHz'],
              selectedIndex: _essDsdCutoff,
              onSelected: (idx) {
                setState(() => _essDsdCutoff = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_dsd_cutoff', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: 'DPLL 时钟锁定',
              options: const ['极窄带 (超低抖动)', '标准平衡 (推荐)', '宽带 (抗失锁)'],
              selectedIndex: _essPcmDpll,
              onSelected: (idx) {
                setState(() => _essPcmDpll = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_pcm_dpll', idx.toString());
              },
              accent: accent,
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        _buildSectionCard(
          title: 'THD 谐波补偿与双芯片并联架构 (THD & Parallel Architecture)',
          children: [
            _buildSegmentedRow(
              label: 'THD 谐波补偿',
              options: const ['超低失真 (< -122dB)', '二次谐波 (胆味)', '关闭补偿'],
              selectedIndex: _essThdComp,
              onSelected: (idx) {
                setState(() => _essThdComp = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_thd_comp', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '并联解码架构',
              options: const ['双芯片 8-Ch 并联 (140dB)', '双芯片立体声平衡'],
              selectedIndex: _essChannelMode,
              onSelected: (idx) {
                setState(() => _essChannelMode = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_mono_mode', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '输出绝对相位',
              options: const ['绝对正相 (0°)', '极性反转 (180°)'],
              selectedIndex: _essPhaseInvert,
              onSelected: (idx) {
                setState(() => _essPhaseInvert = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_phase', idx.toString());
              },
              accent: accent,
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. AKM 旭化成 (AK4499EX + AK4191EQ Velvet Sound Verita)
  // ===========================================================================
  Widget _buildAKMVelvetSection(Color accent) {
    const akmDescs = [
      '短延时锐滚降: 声音结像深厚温润，人声饱满耐听，AKM 旗舰代表音色',
      '短延时慢滚降: 极富宽松空气感，微弱残响还原逼真，适合爵士与流行',
      '锐滚降: 超高解析力与动态对比，全频段精准监听',
      '慢滚降: 纯模拟温厚声底，彻底消除数码生硬毛刺感',
      '超低群延迟: 极高冲击力响应，低频瞬态饱满凝聚',
      '低色散短延时: AKM 独家全频段无色散相位对齐技术',
    ];

    return Column(
      children: [
        _buildSectionCard(
          title: 'AKM Velvet Sound 6 种数字滤波器 (AK4191EQ 独立数字处理)',
          children: [
            _buildSegmentedRow(
              label: '滤波特性 (1)',
              options: const ['短延时锐滚降', '短延时慢滚降', '锐滚降'],
              selectedIndex: _akmFilter < 3 ? _akmFilter : -1,
              onSelected: (idx) {
                setState(() => _akmFilter = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_akm_filter', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '滤波特性 (2)',
              options: const ['慢滚降', '超低群延迟', '低色散短延时'],
              selectedIndex: _akmFilter >= 3 ? (_akmFilter - 3) : -1,
              onSelected: (idx) {
                final realIdx = idx + 3;
                setState(() => _akmFilter = realIdx);
                MusicDatabaseService.instance.setSetting('setting_dac_akm_filter', realIdx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            Text(
              akmDescs[_akmFilter.clamp(0, akmDescs.length - 1)],
              style: const TextStyle(fontSize: 11.0, color: UIConfig.textMuted, height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        _buildSectionCard(
          title: 'Sound Color 声音风格与数字模拟完全分离架构 (Sound Style & EXDF)',
          children: [
            _buildSegmentedRow(
              label: '声音色彩风格',
              options: const ['风格1 (自然)', '风格2 (通透)', '风格3 (宽厚)', '风格4 (监听)'],
              selectedIndex: _akmColor,
              onSelected: (idx) {
                setState(() => _akmColor = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_akm_color', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: 'DSD 直通模式',
              options: const ['Direct 模式 (旁路调制)', 'Normal 滤波模式'],
              selectedIndex: _akmDsd,
              onSelected: (idx) {
                setState(() => _akmDsd = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_akm_dsd', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '数字滤波通路',
              options: const ['外部超采样直通 (EXDF)', '内部 AK4191EQ 处理'],
              selectedIndex: _akmExdf,
              onSelected: (idx) {
                setState(() => _akmExdf = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_akm_exdf', idx.toString());
              },
              accent: accent,
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. Cirrus Logic (CS43198 / CS43131 MasterHIFI)
  // ===========================================================================
  Widget _buildCirrusSection(Color accent) {
    const csDescs = [
      '快速线性: 动态平坦，通透解析，标准高保真回放',
      '慢速线性: 高频滚降柔和，空气感出众，极佳耐听度',
      '快速最小: 人声甜美温润，低音弹性好，无前置振铃',
      '慢速最小: 自然模拟声学衰减，声音温厚纯净',
      'NOS (Non-Oversampling): 旁路数字插值滤波，阶梯原生方波再现',
    ];

    return Column(
      children: [
        _buildSectionCard(
          title: 'MasterHIFI 5 种滤波特性与 NOS 模式 (CS43198 Filter Modes)',
          children: [
            _buildSegmentedRow(
              label: '滤波特性 (1)',
              options: const ['快速线性', '慢速线性', '快速最小'],
              selectedIndex: _csFilter < 3 ? _csFilter : -1,
              onSelected: (idx) {
                setState(() => _csFilter = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_cs_filter', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '滤波特性 (2)',
              options: const ['慢速最小', 'NOS 无过采样'],
              selectedIndex: _csFilter >= 3 ? (_csFilter - 3) : -1,
              onSelected: (idx) {
                final realIdx = idx + 3;
                setState(() => _csFilter = realIdx);
                MusicDatabaseService.instance.setSetting('setting_dac_cs_filter', realIdx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            Text(
              csDescs[_csFilter.clamp(0, csDescs.length - 1)],
              style: const TextStyle(fontSize: 11.0, color: UIConfig.textMuted, height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        _buildSectionCard(
          title: 'Direct DSD 原生模拟与模拟放大架构 (Analog & Driver)',
          children: [
            _buildSegmentedRow(
              label: 'DSD 解码模式',
              options: const ['Direct DSD (直接转换)', 'DoP 硬件解调'],
              selectedIndex: _csDsd,
              onSelected: (idx) {
                setState(() => _csDsd = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_cs_dsd', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '模拟驱动模式',
              options: const ['高推力伪差分 (2Vrms)', '标准单端 (1Vrms)'],
              selectedIndex: _csDrive,
              onSelected: (idx) {
                setState(() => _csDrive = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_cs_drive', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '阻抗探测模式',
              options: const ['自适应匹配 (16Ω~600Ω)', '高阻监听优先'],
              selectedIndex: _csImpedance,
              onSelected: (idx) {
                setState(() => _csImpedance = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_cs_impedance', idx.toString());
              },
              accent: accent,
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. R-2R 纯分立电阻网络 (NOS / OS 架构)
  // ===========================================================================
  Widget _buildR2RSection(Color accent) {
    return Column(
      children: [
        _buildSectionCard(
          title: '分立梯形电阻架构模式 (R-2R Ladder Mode & 1-Bit DSD)',
          children: [
            _buildSegmentedRow(
              label: '过采样模式',
              options: const ['NOS 纯无过采样 (方波原生)', 'OS 线性相位超采样', 'OS 最小相位超采样'],
              selectedIndex: _r2rMode,
              onSelected: (idx) {
                setState(() => _r2rMode = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_r2r_mode', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: 'DSD 网络模式',
              options: const ['独立 1-Bit 电阻网络转换', '转换为 24-bit 阶梯解码'],
              selectedIndex: _r2rDsd,
              onSelected: (idx) {
                setState(() => _r2rDsd = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_r2r_dsd', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            const Text(
              'R-2R 说明: NOS 纯无过采样零数字滤波，方波瞬态真实，还原纯模拟黑胶听感。',
              style: TextStyle(fontSize: 11.0, color: UIConfig.textMuted, height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        _buildSectionCard(
          title: '本地飞秒时钟 FIFO 缓存与绝对相位 (Clock FIFO Reclocking)',
          children: [
            _buildSegmentedRow(
              label: '时钟重整机制',
              options: const ['飞秒 FIFO 本地时钟重整', '直接跟随输入源时钟'],
              selectedIndex: _r2rClock,
              onSelected: (idx) {
                setState(() => _r2rClock = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_r2r_clock', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '模拟信号极性',
              options: const ['绝对正相 (0°)', '极性反转 (180°)'],
              selectedIndex: _r2rPhase,
              onSelected: (idx) {
                setState(() => _r2rPhase = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_r2r_phase', idx.toString());
              },
              accent: accent,
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 5. ROHM 罗姆 (MUS-IC BD34301EKV 旗舰)
  // ===========================================================================
  Widget _buildROHMSection(Color accent) {
    return Column(
      children: [
        _buildSectionCard(
          title: 'ROHM MUS-IC 声音微调滤波与调制器时钟 (Sound Tuning & Modulator)',
          children: [
            _buildSegmentedRow(
              label: '声音微调滤波',
              options: const ['Sharp Roll-Off (高解析宏大声场)', 'Slow Roll-Off (浓郁宽松自然感)'],
              selectedIndex: _rohmFilter,
              onSelected: (idx) {
                setState(() => _rohmFilter = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_rohm_filter', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            _buildSegmentedRow(
              label: '调制器采样率',
              options: const ['智能倍频自适应', '锁定 64x fs', '锁定 128x fs'],
              selectedIndex: _rohmClock,
              onSelected: (idx) {
                setState(() => _rohmClock = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_rohm_clock', idx.toString());
              },
              accent: accent,
            ),
            const SizedBox(height: 10.0),
            const Text(
              'ROHM 说明: 日本罗姆旗舰 MUS-IC，力士 D-10X 旗舰唱机核心，具备天然宽松乐感。',
              style: TextStyle(fontSize: 11.0, color: UIConfig.textMuted, height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        _buildSectionCard(
          title: 'DSD 纯模拟直接旁路通道 (Direct DSD Path)',
          children: [
            _buildSegmentedRow(
              label: 'DSD 处理通道',
              options: const ['Direct Path 纯模拟通道', '标准多级滤波处理'],
              selectedIndex: _rohmDsd,
              onSelected: (idx) {
                setState(() => _rohmDsd = idx);
                MusicDatabaseService.instance.setSetting('setting_dac_rohm_dsd', idx.toString());
              },
              accent: accent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(20, 26, 36, 0.7),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: UIConfig.fontRegular,
              fontWeight: FontWeight.w600,
              color: UIConfig.textActive,
            ),
          ),
          const SizedBox(height: 14.0),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSegmentedRow({
    required String label,
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    required Color accent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120.0,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: UIConfig.fontSmall,
              color: UIConfig.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              for (int i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 8.0),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(i),
                    child: Container(
                      height: 28.0,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedIndex == i
                            ? accent.withOpacity(0.28)
                            : const Color.fromRGBO(255, 255, 255, 0.04),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(
                          color: selectedIndex == i
                              ? accent
                              : const Color.fromRGBO(255, 255, 255, 0.1),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        options[i],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: selectedIndex == i
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selectedIndex == i
                              ? UIConfig.textActive
                              : UIConfig.textNormal,
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

  Widget _buildDeviceRow({
    required int index,
    required String name,
    required String arch,
    required bool isBuiltIn,
    required bool isCurrent,
    required VoidCallback onTap,
    required Color accent,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isCurrent
              ? accent.withOpacity(0.18)
              : const Color.fromRGBO(255, 255, 255, 0.03),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: isCurrent
                ? accent
                : const Color.fromRGBO(255, 255, 255, 0.08),
            width: isCurrent ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: UIConfig.fontSmall,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: isCurrent ? UIConfig.textActive : UIConfig.textNormal,
                  ),
                ),
                const SizedBox(width: 30.0),
                Text(
                  arch,
                  style: const TextStyle(
                    fontSize: 11.0,
                    color: UIConfig.textMuted,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (isBuiltIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, 0.08),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: const Text(
                      'Mac 内置',
                      style: TextStyle(fontSize: 10.0, color: UIConfig.textNormal),
                    ),
                  ),
                if (isCurrent) ...[
                  const SizedBox(width: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(16, 185, 129, 0.25),
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: const Text(
                      '当前输出',
                      style: TextStyle(fontSize: 10.0, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
