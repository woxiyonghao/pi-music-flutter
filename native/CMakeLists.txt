cmake_minimum_required(VERSION 3.20)
project(hifi_audio_ffi LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build." FORCE)
endif()

if(NOT APPLE)
    find_package(SDL2 REQUIRED)
endif()

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

if(WIN32 AND TARGET SDL2::SDL2)
    get_target_property(SDL2_TYPE SDL2::SDL2 TYPE)
    if(SDL2_TYPE STREQUAL "SHARED_LIBRARY")
        add_custom_command(TARGET hifi_audio_ffi POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                $<TARGET_FILE:SDL2::SDL2> $<TARGET_FILE_DIR:hifi_audio_ffi>
        )
    endif()
endif()

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

if(APPLE)
    # 音频库全格式回归测试与解码健全性审计可执行工具 (依赖 AppleAudioDecoder)
    add_executable(audit_audio_library
        tests/audit_audio_library.cpp
    )

    target_include_directories(audit_audio_library PRIVATE
        include
        audio_engine/include
        audio_engine/third_party
    )

    target_link_libraries(audit_audio_library PRIVATE
        audio_engine
        sqlite3
        ${SDL2_LIBRARIES}
        "-framework CoreAudio"
        "-framework AudioToolbox"
        "-framework CoreFoundation"
    )
    option(HIFI_BUILD_TESTS "Build native audio regression tests" OFF)
    if(HIFI_BUILD_TESTS)
        enable_testing()
        add_executable(core_audio_playback_test tests/core_audio_playback_test.cpp)
        target_link_libraries(core_audio_playback_test PRIVATE audio_engine)
        add_test(NAME core_audio_pcm COMMAND core_audio_playback_test)
        add_executable(graphic_equalizer_test tests/graphic_equalizer_test.cpp)
        target_include_directories(graphic_equalizer_test PRIVATE audio_engine/include)
        add_test(NAME graphic_equalizer COMMAND graphic_equalizer_test)
    endif()
endif()

