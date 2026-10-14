cmake_minimum_required(VERSION 3.20)
project(hifi_audio_ffi LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(SDL2 REQUIRED)

# 包含核心头文件
include_directories(
    include
    audio_engine/include
    ${SDL2_INCLUDE_DIRS}
)

# 引入底层发烧音频核心
add_subdirectory(audio_engine)

# 构建供 Flutter dart:ffi 动态调用的共享库
add_library(hifi_audio_ffi SHARED
    src/hifi_audio_ffi.cpp
)

target_link_libraries(hifi_audio_ffi PRIVATE
    audio_engine
    ${SDL2_LIBRARIES}
)

if(APPLE)
    # macOS / iOS 平台链接系统 CoreAudio / AudioToolbox
    target_link_libraries(hifi_audio_ffi PRIVATE
        "-framework CoreAudio"
        "-framework AudioToolbox"
        "-framework CoreFoundation"
    )
    set_target_properties(hifi_audio_ffi PROPERTIES
        MACOSX_RPATH ON
        INSTALL_NAME_DIR "@rpath"
    )
elseif(ANDROID)
    target_link_libraries(hifi_audio_ffi PRIVATE
        aaudio
        log
    )
elseif(UNIX AND NOT APPLE)
    # Linux / 树莓派 5
    target_link_libraries(hifi_audio_ffi PRIVATE
        asound
        pthread
    )
endif()
