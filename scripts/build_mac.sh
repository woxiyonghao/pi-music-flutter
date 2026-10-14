#!/bin/zsh
set -e

# HiFi Player macOS 完整编译脚本
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🔨 [HiFi Master] 开始编译 macOS 完整应用..."

export PATH="/opt/homebrew/bin:/Users/mk10/development/flutter/bin:$PATH"

# 1. 编译 C++ 动态库
echo "⚡ [AudioEngine] 编译 C++20 原生内核..."
cmake -B native/build -S native -DCMAKE_BUILD_TYPE=Debug
cmake --build native/build -j$(sysctl -n hw.ncpu)
cp -f "native/build/libhifi_audio_ffi.dylib" "libhifi_audio_ffi.dylib"

# 2. 编译 Flutter macOS 端
echo "🍎 [Flutter] 编译 macOS Debug .app..."
flutter build macos --debug

echo "✅ [完成] 产物位置: $PROJECT_DIR/build/macos/Build/Products/Debug/hide_player_flutter.app"
