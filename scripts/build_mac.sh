#!/bin/zsh
set -e

# HiFi Player macOS 完整编译脚本
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🔨 [HiFi Master] 开始编译 macOS 完整应用 (Release 发行版)..."
# Xcode 自动构建并签名与锁定 SDK 匹配的音频库。
echo "🍎 [Flutter] 编译 macOS Release .app..."
flutter build macos --release

apps=("$PROJECT_DIR"/build/macos/Build/Products/Release/*.app(N))
if [ "${#apps[@]}" -ne 1 ]; then
    echo "无法确定 macOS Release 应用目录" >&2
    exit 1
fi
APP_DIR="${apps[1]}"

echo "✅ [完成] 产物位置: $APP_DIR"
