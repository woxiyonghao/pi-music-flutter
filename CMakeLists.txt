cmake_minimum_required(VERSION 3.20)
project(HiFiPlayerFlutter LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 1. 供 CLion 自动索引 native 发烧音频内核与 FFI 接口
add_subdirectory(native)

# 2. CLion 原生 CMake 运行与构建指令
add_custom_target(run_macos
    COMMAND /bin/zsh "${CMAKE_CURRENT_SOURCE_DIR}/scripts/run_mac.sh"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "🚀 [CLion] Launching Flutter macOS App..."
    USES_TERMINAL
)

add_custom_target(build_macos
    COMMAND /bin/zsh "${CMAKE_CURRENT_SOURCE_DIR}/scripts/build_mac.sh"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "🔨 [CLion] Building macOS Application..."
    USES_TERMINAL
)
