#!/bin/zsh
set -e

# ==============================================================================
# MyHiFiPlayer iPhone / iPad / iOS 一键编译与打包脚本 (Release 发行模式)
# 产物直接在 iPhone / iPad 上独立秒开运行，默认 Release 架构，彻底去除 LLDB 调试器附加
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "📱 [HiFi Master] 开始编译 iPhone / iOS Release 发行版..."


# 1. 获取依赖
echo "📦 [1/2] 检查 Flutter 依赖项..."
flutter pub get

# 2. 编译 iOS Release Bundle
echo "⚡ [2/2] 正在编译 Flutter iOS Release 架构 (AOT 预编译，生产环境打包，彻底脱离开发机)..."
flutter build ios --release --no-codesign

echo ""
echo "🎉 ========================================================================"
echo "✅ iPhone / iOS Release 发行版编译完成！"
echo "📁 产物目录: ${PROJECT_DIR}/build/ios/iphoneos/Runner.app"
echo "🚀 运行与安装方式："
echo "   1. Xcode 中连接 iPhone，Scheme 选择 [Runner]，点击 [Run]（默认 Release 模式，无 LLDB 停顿）"
echo "   2. 或者使用命令行工具一键安装到已信任的 iPhone:"
echo "      ideviceinstaller -i ${PROJECT_DIR}/build/ios/iphoneos/Runner.app"
echo "   3. 安装后可拔掉数据线，在 iPhone 屏幕点击 App 图标独立秒开常驻！"
echo "========================================================================"
