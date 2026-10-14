cmake_minimum_required(VERSION 3.20)
project(HiFiPlayerFlutter LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 供 CLion 自动索引 native 发烧音频内核与 FFI 接口
add_subdirectory(native)
