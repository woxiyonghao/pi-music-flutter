/// 侧边栏导航 Tab 枚举 (1:1 严格对齐 C++ SidebarTab)
enum SidebarTab {
  allMusic, // 🎵 所有音乐 (默认激活项)
  customPlaylist, // 📑 自定义歌单
  scanMusic, // 🔍 扫描音乐
  equalizer, // 🎚️ 均衡器
  msebTuning, // 🪄 调音魔棒
  dacSettings, // 🎛️ DAC 解码设置
  themeSettings, // 🎨 主题与背景动效
  systemSettings, // ⚙️ 系统设置
  webService, // 🖥️ Web 遥控服务
  wifiTransfer, // 📶 WiFi 无线传歌
  terminal, // 📟 硬件系统终端 (树莓派特有)
}
