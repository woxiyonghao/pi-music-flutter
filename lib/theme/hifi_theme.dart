import 'package:flutter/material.dart';

/// HiFi 发烧纯音视觉主题规范
class HifiTheme {
  // 经典发烧配色
  static const Color background = Color(0xFF080A0E); // 深邃暗夜背景
  static const Color cardBackground = Color(0xFF121620); // 浮层暗黑卡片
  static const Color cardBorder = Color(0xFF1E2638);

  // 经典麦景图 (McIntosh) 湖蓝夜光配色
  static const Color mcIntoshBlue = Color(0xFF0077B6);
  static const Color mcIntoshGlow = Color(0xFF00B4D8);
  static const Color mcIntoshMeterBg = Color(0xFF041828);

  // 经典金嗓子 (Accuphase) 香槟金/暖琥珀配色
  static const Color accuphaseGold = Color(0xFFFFB703);
  static const Color accuphaseAmber = Color(0xFFFB8500);

  // 霓虹重低音高亮
  static const Color neonCyan = Color(0xFF06D6A0);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: mcIntoshBlue,
      colorScheme: const ColorScheme.dark(
        primary: mcIntoshBlue,
        secondary: neonCyan,
        surface: cardBackground,
      ),
      fontFamily: 'SF Pro Display',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
