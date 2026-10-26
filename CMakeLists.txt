cmake_minimum_required(VERSION 3.20)
project(HiFiPlayerFlutter LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# CLion's host CMake profile provides native SDK indexing. Android libraries are
# cross-compiled and packaged by Gradle through native/CMakeLists.txt instead.
option(HIFI_INDEX_NATIVE "Index the locked native audio SDK in CLion" ON)
if(HIFI_INDEX_NATIVE)
    if(NOT HIFI_DART_EXECUTABLE)
        set(HIFI_FLUTTER_SDK "$ENV{FLUTTER_ROOT}" CACHE PATH "Flutter SDK for CLion")
        if(NOT HIFI_FLUTTER_SDK AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/android/local.properties")
            file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/android/local.properties" HIFI_FLUTTER_PROPERTY
                REGEX "^flutter\\.sdk=")
            string(REGEX REPLACE "^flutter\\.sdk=" "" HIFI_FLUTTER_SDK "${HIFI_FLUTTER_PROPERTY}")
        endif()
        find_program(HIFI_CLION_DART NAMES dart dart.bat
            HINTS "${HIFI_FLUTTER_SDK}/bin/cache/dart-sdk/bin" "${HIFI_FLUTTER_SDK}/bin")
        if(HIFI_CLION_DART)
            set(HIFI_DART_EXECUTABLE "${HIFI_CLION_DART}")
        endif()
    endif()
    add_subdirectory(native EXCLUDE_FROM_ALL)
endif()

add_custom_target(run_android
    COMMAND /bin/bash "${CMAKE_CURRENT_SOURCE_DIR}/scripts/run_android.sh"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "[CLion] Run Android with Flutter hot reload"
    USES_TERMINAL
)

add_custom_target(run_android_release
    COMMAND /bin/bash "${CMAKE_CURRENT_SOURCE_DIR}/scripts/run_android.sh" --release
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "[CLion] Run Android release application"
    USES_TERMINAL
)

add_custom_target(build_android
    COMMAND /bin/bash "${CMAKE_CURRENT_SOURCE_DIR}/scripts/build_android.sh"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "[CLion] Build Android release APK"
    USES_TERMINAL
)

add_custom_target(build_android_debug
    COMMAND /bin/bash "${CMAKE_CURRENT_SOURCE_DIR}/scripts/build_android.sh" --debug
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "[CLion] Build Android debug APK"
    USES_TERMINAL
)

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
