#!/bin/zsh
set -e

# HiFi Player macOS 一键运行脚本 (CLion / 终端专用)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🎵 [HiFi Master] 准备运行 macOS 原生发烧播放器 (Release 模式)..."

# 1. 确保 Flutter 路径在 PATH 中
export PATH="/opt/homebrew/bin:/Users/mk10/development/flutter/bin:$PATH"

# 2. 检查并编译 C++20 audio_engine 原生动态库
if [ ! -f "native/build/libhifi_audio_ffi.dylib" ]; then
    echo "⚡ [AudioEngine] 首次运行，正在编译 C++20 FFI 动态库 (Release)..."
    cmake -B native/build -S native -DCMAKE_BUILD_TYPE=Release
    cmake --build native/build --config Release -j$(sysctl -n hw.ncpu)
fi

# 确保根目录有 dylib 供开发期链接
if [ -f "native/build/libhifi_audio_ffi.dylib" ]; then
    cp -f "native/build/libhifi_audio_ffi.dylib" "libhifi_audio_ffi.dylib"
fi

echo "🚀 [Flutter] 启动 macOS 端 (Release AOT 模式，脱离开发环境独立秒开)..."
flutter run -d macos --release "$@"
