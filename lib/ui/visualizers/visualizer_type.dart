/// 发烧动效主题类型定义
enum VisualizerType {
  mcIntosh,     // 经典麦景图 (McIntosh) 湖蓝夜光双动圈表头
  accuphase,    // 经典金嗓子 (Accuphase) 40周年香槟金表头
  tapeReel,     // Studer Revox 开盘磁带机双轮旋转
  ledSpectrum,  // 专业阶梯式 12/24 频段 LED 频谱仪 (带峰值保持)
  neonWaveform, // 极光赛博重低音波形瀑布
  siriOrb,      // Siri 流体发光能量球
}

extension VisualizerTypeExtension on VisualizerType {
  String get displayName {
    switch (this) {
      case VisualizerType.mcIntosh:
        return '麦景图双表头 (McIntosh)';
      case VisualizerType.accuphase:
        return '金嗓子双表头 (Accuphase)';
      case VisualizerType.tapeReel:
        return '开盘磁带机 (Studer Revox)';
      case VisualizerType.ledSpectrum:
        return '发烧 LED 频谱 (Spectrum)';
      case VisualizerType.neonWaveform:
        return '极光赛博波形 (Neon Wave)';
      case VisualizerType.siriOrb:
        return 'Siri 流体能量球 (Siri Orb)';
    }
  }

  String get subtitle {
    switch (this) {
      case VisualizerType.mcIntosh:
        return 'Precision Power Meter · 192kHz/24Bit Bit-Perfect';
      case VisualizerType.accuphase:
        return 'Accuphase Dual Balanced · Femtosecond Clock';
      case VisualizerType.tapeReel:
        return '15 IPS 2-Track Master · 0VU = +4dBu Direct';
      case VisualizerType.ledSpectrum:
        return '12-Band Peak Hold · Real-time Audio Spectrum';
      case VisualizerType.neonWaveform:
        return 'Harmonic Distortion & Radiant Resonance';
      case VisualizerType.siriOrb:
        return 'Fluid Chromatic Energy Pulsing Field';
    }
  }
}
