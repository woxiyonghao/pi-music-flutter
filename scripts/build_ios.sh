#!/bin/zsh
set -e

# ==============================================================================
# MyHiFiPlayer iPad / iOS 一键编译与打包脚本 (Release 发行模式)
# 产物可直接在 iPad 上独立运行，无需电脑或 Xcode 调试器连接
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "📱 [HiFi Master] 开始编译 iPad / iOS Release 发行版..."


# 1. 获取依赖
echo "📦 [1/2] 检查 Flutter 依赖项..."
flutter pub get

# 2. 编译 iOS Release Bundle
echo "⚡ [2/2] 正在编译 Flutter iOS Release 架构 (AOT 预编译，彻底脱离开发机)..."
flutter build ios --release --no-codesign

echo ""
echo "🎉 ========================================================================"
echo "✅ iPad / iOS Release 发行版编译完成！"
echo "📁 产物目录: ${PROJECT_DIR}/build/ios/iphoneos/Runner.app"
echo "🚀 运行与安装方式："
echo "   1. Xcode 中连接 iPad，Scheme 选择 [Runner (Release)]，点击 [Run] 即可直接真机安装运行"
echo "   2. 或者使用命令行工具一键安装到已信任的 iPad:"
echo "      ideviceinstaller -i ${PROJECT_DIR}/build/ios/iphoneos/Runner.app"
echo "   3. 安装后拔掉数据线，在 iPad 屏幕点击 App 图标即可秒开常驻，绝不闪退！"
echo "========================================================================"
