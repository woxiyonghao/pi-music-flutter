#!/usr/bin/env bash
set -e

# ==============================================================================
# PiHiEndMusic / HidePlayerFlutter iOS & iPadOS 静态库一键编译打包脚本
# 支持:
#   1. iOS 真机 (arm64)
#   2. iOS 模拟器 (arm64 + x86_64 通用架构，适配 Apple Silicon 与 Intel Mac)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== [1/5] 检测 Apple SDK 环境 ==="
IPHONEOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SIMULATOR_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
CLANG="$(xcrun --find clang++)"
LIBTOOL="$(xcrun --find libtool)"
LIPO="$(xcrun --find lipo)"

echo "Device SDK:    ${IPHONEOS_SDK}"
echo "Simulator SDK: ${SIMULATOR_SDK}"

BUILD_DIR="${ROOT_DIR}/build-ios"
OBJ_DEVICE_DIR="${BUILD_DIR}/obj-device"
OBJ_SIM_ARM64_DIR="${BUILD_DIR}/obj-sim-arm64"
OBJ_SIM_X86_DIR="${BUILD_DIR}/obj-sim-x86_64"
OUT_DEVICE_DIR="${BUILD_DIR}/device"
OUT_SIM_DIR="${BUILD_DIR}/simulator"

rm -rf "${BUILD_DIR}"
mkdir -p "${OBJ_DEVICE_DIR}" "${OBJ_SIM_ARM64_DIR}" "${OBJ_SIM_X86_DIR}" "${OUT_DEVICE_DIR}" "${OUT_SIM_DIR}"

INCLUDE_FLAGS=(
    -I "${ROOT_DIR}/native/include"
    -I "${ROOT_DIR}/native/audio_engine/include"
    -I "${ROOT_DIR}/native/audio_engine/third_party"
)

SOURCES=(
    "${ROOT_DIR}/native/src/hifi_audio_ffi.cpp"
    "${ROOT_DIR}/native/audio_engine/src/AudioEngine.cpp"
    "${ROOT_DIR}/native/audio_engine/src/DsfParser.cpp"
    "${ROOT_DIR}/native/audio_engine/src/decoders/FlacDecoder.cpp"
    "${ROOT_DIR}/native/audio_engine/src/decoders/WavDecoder.cpp"
    "${ROOT_DIR}/native/audio_engine/src/decoders/Mp3Decoder.cpp"
    "${ROOT_DIR}/native/audio_engine/src/decoders/AppleAudioDecoder.cpp"
    "${ROOT_DIR}/native/audio_engine/src/sinks/AudioQueueSink.cpp"
    "${ROOT_DIR}/native/audio_engine/src/sinks/RemoteIOSink.cpp"
)

echo "=== [2/5] 编译 iOS Device 切片 (arm64-apple-ios15.0) ==="
DEVICE_OBJS=()
pids=()
for src in "${SOURCES[@]}"; do
    bname="$(basename "${src}" .cpp)"
    obj="${OBJ_DEVICE_DIR}/${bname}.o"
    "${CLANG}" -target arm64-apple-ios15.0 \
        -isysroot "${IPHONEOS_SDK}" \
        -std=c++20 -O3 -fPIC -DNDEBUG \
        "${INCLUDE_FLAGS[@]}" \
        -c "${src}" -o "${obj}" &
    pids+=($!)
    DEVICE_OBJS+=("${obj}")
done
for pid in "${pids[@]}"; do
    wait "${pid}"
done
echo "  [Device] 打包静态库: ${OUT_DEVICE_DIR}/libhifi_audio_ffi.a"
"${LIBTOOL}" -static -o "${OUT_DEVICE_DIR}/libhifi_audio_ffi.a" "${DEVICE_OBJS[@]}"

echo "=== [3/5] 并行编译 iOS Simulator arm64 与 x86_64 切片 ==="
SIM_ARM64_OBJS=()
SIM_X86_OBJS=()
sim_pids=()
for src in "${SOURCES[@]}"; do
    bname="$(basename "${src}" .cpp)"
    obj_arm="${OBJ_SIM_ARM64_DIR}/${bname}.o"
    obj_x86="${OBJ_SIM_X86_DIR}/${bname}.o"

    "${CLANG}" -target arm64-apple-ios15.0-simulator \
        -isysroot "${SIMULATOR_SDK}" \
        -std=c++20 -O3 -fPIC -DNDEBUG \
        "${INCLUDE_FLAGS[@]}" \
        -c "${src}" -o "${obj_arm}" &
    sim_pids+=($!)

    "${CLANG}" -target x86_64-apple-ios15.0-simulator \
        -isysroot "${SIMULATOR_SDK}" \
        -std=c++20 -O3 -fPIC -DNDEBUG \
        "${INCLUDE_FLAGS[@]}" \
        -c "${src}" -o "${obj_x86}" &
    sim_pids+=($!)

    SIM_ARM64_OBJS+=("${obj_arm}")
    SIM_X86_OBJS+=("${obj_x86}")
done
for pid in "${sim_pids[@]}"; do
    wait "${pid}"
done

echo "  [Simulator] 打包 arm64 与 x86_64 模拟器切片..."
"${LIBTOOL}" -static -o "${BUILD_DIR}/libhifi_audio_ffi_sim_arm64.a" "${SIM_ARM64_OBJS[@]}"
"${LIBTOOL}" -static -o "${BUILD_DIR}/libhifi_audio_ffi_sim_x86_64.a" "${SIM_X86_OBJS[@]}"

echo "  [Simulator] 使用 lipo 合并为双架构通用模拟器静态库: ${OUT_SIM_DIR}/libhifi_audio_ffi.a"
"${LIPO}" -create "${BUILD_DIR}/libhifi_audio_ffi_sim_arm64.a" "${BUILD_DIR}/libhifi_audio_ffi_sim_x86_64.a" \
    -output "${OUT_SIM_DIR}/libhifi_audio_ffi.a"

echo "=== [4/5] 同步至 iOS 项目内置库目录 (ios/lib) ==="
IOS_LIB_DIR="${ROOT_DIR}/ios/lib"
mkdir -p "${IOS_LIB_DIR}/iphoneos" "${IOS_LIB_DIR}/iphonesimulator"
cp "${OUT_DEVICE_DIR}/libhifi_audio_ffi.a" "${IOS_LIB_DIR}/iphoneos/"
cp "${OUT_DEVICE_DIR}/libhifi_audio_ffi.a" "${IOS_LIB_DIR}/"
cp "${OUT_SIM_DIR}/libhifi_audio_ffi.a" "${IOS_LIB_DIR}/iphonesimulator/"

echo "=== [5/5] 打包完成！ ==="
echo " 1. Device (iphoneos):     ${IOS_LIB_DIR}/iphoneos/libhifi_audio_ffi.a"
echo " 2. Simulator (universal): ${IOS_LIB_DIR}/iphonesimulator/libhifi_audio_ffi.a"
echo "=========================================================="
