#!/bin/bash
set -e

# ==============================================================================
# MyHiFiPlayer 树莓派 5 (Raspberry Pi 5) 一键编译与打包脚本
# 支持在树莓派本机编译，或在配置了 aarch64-linux-gnu 工具链的主机交叉编译
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🍓 [Pi-HiFi] 开始为树莓派 5 构建发烧数播系统..."
echo "📁 项目根目录: ${PROJECT_DIR}"

cd "${PROJECT_DIR}"

# 1. 编译 C++20 高性能无锁发烧纯音动态库
echo "⚡ [1/3] 编译 C++20 原生音频核心动态库 (libhifi_audio_ffi.so)..."
cd native
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# 复制产物至项目根目录与动态链接库搜寻目录
if [ -f "libhifi_audio_ffi.so" ]; then
    cp -f libhifi_audio_ffi.so "${PROJECT_DIR}/libhifi_audio_ffi.so"
    echo "✅ [1/3] libhifi_audio_ffi.so 编译成功"
elif [ -f "libhifi_audio_ffi.dylib" ]; then
    # 若在 macOS 交叉编译或测试
    cp -f libhifi_audio_ffi.dylib "${PROJECT_DIR}/libhifi_audio_ffi.dylib"
    echo "ℹ️ [1/3] 编译为 macOS dylib 测试产物"
fi

cd "${PROJECT_DIR}"

# 2. 获取 Flutter 依赖
echo "📦 [2/3] 同步 Flutter 依赖项..."
flutter pub get

# 3. 构建 Linux Release Bundle
echo "🚀 [3/3] 打包 Linux 发行版本 (flutter build linux --release)..."
if [[ "$OSTYPE" == "linux"* ]]; then
    flutter build linux --release
    mkdir -p "${PROJECT_DIR}/build/linux/arm64/release/bundle/lib"
    if [ -f "${PROJECT_DIR}/native/build/libhifi_audio_ffi.so" ]; then
        cp -f "${PROJECT_DIR}/native/build/libhifi_audio_ffi.so" "${PROJECT_DIR}/build/linux/arm64/release/bundle/lib/"
        echo "✅ 已打包 libhifi_audio_ffi.so 到 bundle/lib/"
    fi
    echo ""
    echo "🎉 ========================================================================"
    echo "✅ 树莓派 5 发行版构建完成！"
    echo "📁 产物目录: ${PROJECT_DIR}/build/linux/arm64/release/bundle/"
    echo "🚀 运行方式 (Cage 极简 Wayland 纯终端秒启):"
    echo "   cage -s -- ${PROJECT_DIR}/build/linux/arm64/release/bundle/hide_player_flutter"
    echo "========================================================================"
else
    echo "ℹ️ 当前宿主机为非 Linux 系统 (${OSTYPE})。"
    echo "   本地可直接运行: zsh scripts/run_mac.sh (Release 模式)"
    echo "   若需部署至树莓派，请通过 git 将本分支推送到树莓派并在树莓派上执行: ./scripts/build_pi.sh"
fi
