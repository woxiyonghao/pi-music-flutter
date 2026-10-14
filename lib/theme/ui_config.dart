import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// 全局 UI 视觉与样式配置中心 (1:1 严格对齐 C++ UIConfig.hpp)
class UIConfig {
  // ==========================================================================
  // 1. 发烧调色板 (Colors)
  // ==========================================================================
  // [主题强调色]：用于高亮、激活图标、选中指示等 (动态联动 ThemeService)
  static Color get accent => ThemeService.instance.accentColor;

  // [背景与底板]
  static const Color windowBg = Color(0xF012161C); // 侧边栏深邃半透明暗色底
  static const Color mainStageBg = Color(0xFF0A0E14); // 右侧主舞台基底深空黑

  // [Xcode 风格液态玻璃卡片容器 (上下两大独立包裹容器)]
  static const Color containerBg = Color.fromRGBO(255, 255, 255, 14 / 255);
  static const Color containerBorder = Color.fromRGBO(255, 255, 255, 30 / 255);

  // [选中项发光液态玻璃胶囊 (Liquid Glass Active Indicator)]
  static Color get glassActiveTint => ThemeService.instance.accentColor.withValues(alpha: 60 / 255);
  static const Color glassActive = Color.fromRGBO(255, 255, 255, 30 / 255);
  static const Color glassHover = Color.fromRGBO(255, 255, 255, 18 / 255);
  static const Color glassBorder = Color.fromRGBO(255, 255, 255, 50 / 255);

  // [文字色彩层次]
  static const Color textActive = Color(0xFFFFFFFF); // 激活文字 (纯白 100%)
  static const Color textNormal = Color.fromRGBO(200, 210, 225, 220 / 255); // 普通菜单文字 (柔和浅灰)
  static const Color textMuted = Color(0xFF828C9B); // 次级小标题文字 (Apple 次级浅灰)

  // [图标色彩]
  static const Color iconNormal = Color(0xFFB4BCC8); // 未激活图标颜色

  // [DAC 硬件连接指示灯]
  static const Color dacConnected = Color(0xFF34C759); // 绿灯：Bit-Perfect 已连接直通
  static const Color dacDisconnected = Color(0xFF8C919B); // 灰灯：未连接

  // [磨砂毛玻璃卡片填充色与边框色] (对齐 GlassCardRenderer.cpp)
  static const Color frostedCardBg = Color.fromRGBO(18, 22, 32, 220 / 255); // 0xDC121620
  static const Color frostedCardBorder = Color.fromRGBO(255, 255, 255, 36 / 255); // 0x24FFFFFF
  static const Color frostedInnerBorder = Color.fromRGBO(0, 0, 0, 45 / 255);

  // ==========================================================================
  // 2. 控件尺寸与几何排版 (Layout & Dimensions)
  // ==========================================================================
  static const double sidebarWidth = 230.0; // 侧边栏固定总宽度 (px)
  static const double containerMarginX = 16.0; // 容器左右外边距 (px)
  static const double containerMarginY = 16.0; // 容器上下外边距 (px)
  static const double containerGap = 16.0; // 上下两容器垂直间距 (px)
  static const double containerRounding = 10.0; // 容器圆角半径 (px)

  static const double navItemHeight = 34.0; // 按钮触控舒适高度 (px)
  static const double navItemRounding = 8.0; // 按钮圆角半径 (px)
  static const double dacCardHeight = 42.0; // DAC 容器高度 (px)
  static const double bottomBarHeight = 48.0; // 底部胶囊高度 (px)
  static const double bottomBarOffset = 86.0; // 避让底部播放控制栏的下边距 (px)

  // ==========================================================================
  // 3. 多字阶矢量字号 (Typography Font Sizes)
  // ==========================================================================
  static const double fontSmall = 12.0; // 小字阶：小标题、格式徽标、时间戳
  static const double fontRegular = 14.5; // 默认字阶：菜单项、歌单列表、普通正文
  static const double fontMedium = 20.0; // 中字阶：次级标题、专辑名
  static const double fontLarge = 28.0; // 大字阶：正在播放巨型曲目名
}
