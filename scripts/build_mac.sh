#!/bin/zsh
set -e

# HiFi Player macOS 完整编译脚本
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🔨 [HiFi Master] 开始编译 macOS 完整应用 (Release 发行版)..."


# 1. 编译 C++ 动态库
echo "⚡ [AudioEngine] 编译 C++20 原生内核 (Release)..."
cmake -B native/build -S native -DCMAKE_BUILD_TYPE=Release
cmake --build native/build --config Release -j$(sysctl -n hw.ncpu)
cp -f "native/build/libhifi_audio_ffi.dylib" "libhifi_audio_ffi.dylib"

# 2. 编译 Flutter macOS 端
echo "🍎 [Flutter] 编译 macOS Release .app..."
flutter build macos --release

# 3. 将最新动态库打包注入 .app bundle (Contents/Frameworks 与 Contents/MacOS)
echo "📦 [Deploy] 同步最新原生发烧动态库到 macOS App Bundle..."
apps=("$PROJECT_DIR"/build/macos/Build/Products/Release/*.app(N))
if [ "${#apps[@]}" -ne 1 ]; then
    echo "无法确定 macOS Release 应用目录" >&2
    exit 1
fi
APP_DIR="${apps[1]}"
if [ -d "$APP_DIR" ]; then
    mkdir -p "$APP_DIR/Contents/Frameworks"
    mkdir -p "$APP_DIR/Contents/MacOS"
    cp -f "native/build/libhifi_audio_ffi.dylib" "$APP_DIR/Contents/Frameworks/libhifi_audio_ffi.dylib"
    cp -f "native/build/libhifi_audio_ffi.dylib" "$APP_DIR/Contents/MacOS/libhifi_audio_ffi.dylib"
    codesign --force --deep --sign - "$APP_DIR"
    echo "✅ 已成功注入 libhifi_audio_ffi.dylib 到 $APP_DIR"
fi

echo "✅ [完成] 产物位置: $APP_DIR"
