/// 发烧动效主题类型定义 (1:1 对齐 C++ BackgroundVisualMode)
enum VisualizerType {
  ledSpectrum,  // 48列全景 LED 频谱
  mcIntosh,     // 经典麦景图 (McIntosh) 湖蓝夜光双动圈表头
  accuphase,    // 经典金嗓子 (Accuphase) 香槟金大表头
  tapeReel,     // 复古开盘磁带机
  siriWave,     // Siri 流光声波
  siriOrb,      // Siri 悬浮微光球
  bubbles,      // 音乐微光气泡
  pureBlack,    // 极简纯黑纯音直通
  neonWave,     // 电光霓虹声波
  cyberGrid,    // 赛博粒子网格
  glassClock,            // 液态玻璃时钟
  piTelemetryDashboard,  // 树莓派硬件数据大屏 (Big Data Telemetry Dashboard)
}

extension VisualizerTypeExtension on VisualizerType {
  String get displayName {
    switch (this) {
      case VisualizerType.ledSpectrum:
        return '48列全景 LED 频谱';
      case VisualizerType.mcIntosh:
        return '名机动圈大表头 (McIntosh)';
      case VisualizerType.accuphase:
        return '金嗓子旗舰大表头 (Accuphase)';
      case VisualizerType.tapeReel:
        return '复古开盘磁带机 (Tape Reel)';
      case VisualizerType.siriWave:
        return 'Siri 流光声波 (Siri Wave)';
      case VisualizerType.siriOrb:
        return 'Siri 悬浮微光球 (Siri Orb)';
      case VisualizerType.bubbles:
        return '音乐微光气泡 (Bubbles)';
      case VisualizerType.pureBlack:
        return '极简纯黑纯音直通 (Pure Black)';
      case VisualizerType.neonWave:
        return '电光霓虹声波 (Neon Wave)';
      case VisualizerType.cyberGrid:
        return '赛博粒子网格 (Cyber Grid)';
      case VisualizerType.glassClock:
        return '液态玻璃时钟 (Glass Clock)';
      case VisualizerType.piTelemetryDashboard:
        return '树莓派硬件数据大屏';
    }
  }

  String get subtitle {
    switch (this) {
      case VisualizerType.ledSpectrum:
        return '48-Band Peak Hold · Real-time Audio Spectrum';
      case VisualizerType.mcIntosh:
        return 'Precision Power Meter · 192kHz/24Bit Bit-Perfect';
      case VisualizerType.accuphase:
        return 'Accuphase Dual Balanced · Femtosecond Clock';
      case VisualizerType.tapeReel:
        return '15 IPS 2-Track Master · 0VU = +4dBu Direct';
      case VisualizerType.siriWave:
        return 'Fluid Chromatic Waveform Pulsing';
      case VisualizerType.siriOrb:
        return 'Fluid Chromatic Energy Pulsing Field';
      case VisualizerType.bubbles:
        return 'Floating Acoustic Ambient Spheres';
      case VisualizerType.pureBlack:
        return 'Zero Lighting · Bit-Perfect Pure Output';
      case VisualizerType.neonWave:
        return 'Harmonic Distortion & Radiant Resonance';
      case VisualizerType.cyberGrid:
        return 'Perspective Audio Matrix Plane';
      case VisualizerType.glassClock:
        return 'Frosted Glass Precision Audio Clock';
      case VisualizerType.piTelemetryDashboard:
        return 'BCM2712 Quad-Core · Real-time Telemetry & Hardware Matrix';
    }
  }
}
