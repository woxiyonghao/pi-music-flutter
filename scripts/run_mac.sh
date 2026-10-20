#!/bin/zsh
set -e

# HiFi Player macOS 一键运行脚本 (CLion / 终端专用)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🎵 [HiFi Master] 准备运行 macOS 原生发烧播放器 (Release 模式)..."

# 1. 确保 Flutter 路径在 PATH 中
export PATH="/opt/homebrew/bin:/Users/mk10/development/flutter/bin:$PATH"

# 2. 检查并增量编译 C++20 audio_engine 原生动态库 (Release)
echo "⚡ [AudioEngine] 检查并同步 C++20 原生内核 (Release)..."
cmake -B native/build -S native -DCMAKE_BUILD_TYPE=Release
cmake --build native/build --config Release -j$(sysctl -n hw.ncpu)

# 确保根目录与现有 App Bundle 有最新 dylib 供开发与运行加载
if [ -f "native/build/libhifi_audio_ffi.dylib" ]; then
    cp -f "native/build/libhifi_audio_ffi.dylib" "libhifi_audio_ffi.dylib"
    for d in "build/macos/Build/Products/Release/PiHifiPlayer.app"; do
        if [ -d "$d" ]; then
            mkdir -p "$d/Contents/Frameworks" "$d/Contents/MacOS"
            cp -f "native/build/libhifi_audio_ffi.dylib" "$d/Contents/Frameworks/libhifi_audio_ffi.dylib"
            cp -f "native/build/libhifi_audio_ffi.dylib" "$d/Contents/MacOS/libhifi_audio_ffi.dylib"
        fi
    done
fi

echo "🚀 [Flutter] 启动 macOS 端 (Release AOT 模式，脱离开发环境独立秒开)..."
flutter run -d macos --release "$@"
