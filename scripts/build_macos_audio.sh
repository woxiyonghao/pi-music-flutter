#!/bin/bash
set -euo pipefail

# Xcode runs this for Flutter CLI, IDE launches, and standalone app builds.
HIFI_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${PATH}:/opt/homebrew/bin:/usr/local/bin"
HIFI_CONFIGURATION="${CONFIGURATION:-Release}"
HIFI_ARCHS="${ARCHS:-$(uname -m)}"
HIFI_BUILD_DIR="$HIFI_PROJECT_DIR/build/audio-engine/macos-$HIFI_CONFIGURATION-${HIFI_ARCHS// /-}"
HIFI_CMAKE_ARGS=()
if [ -n "${FLUTTER_ROOT:-}" ]; then
    HIFI_CMAKE_ARGS+=("-DHIFI_DART_EXECUTABLE=$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart")
fi

# Always configure/build incrementally: an existing dylib may predate the lock/ABI.
cmake -S "$HIFI_PROJECT_DIR/native" -B "$HIFI_BUILD_DIR" \
    -DCMAKE_BUILD_TYPE="$HIFI_CONFIGURATION" \
    -DCMAKE_OSX_ARCHITECTURES="${HIFI_ARCHS// /;}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-10.15}" \
    -DCMAKE_OSX_SYSROOT="${SDKROOT:-macosx}" \
    "${HIFI_CMAKE_ARGS[@]}"
cmake --build "$HIFI_BUILD_DIR" --config "$HIFI_CONFIGURATION" \
    --target hifi_audio_ffi --parallel "$(sysctl -n hw.ncpu)"

# Bundle before Xcode signs the app, so launches never depend on the working directory.
HIFI_FRAMEWORKS_DIR="${TARGET_BUILD_DIR:?}/${FRAMEWORKS_FOLDER_PATH:?}"
mkdir -p "$HIFI_FRAMEWORKS_DIR"
HIFI_DYLIB="$HIFI_FRAMEWORKS_DIR/libhifi_audio_ffi.dylib"
cp -f "$HIFI_BUILD_DIR/libhifi_audio_ffi.dylib" "$HIFI_DYLIB"
install_name_tool -id '@rpath/libhifi_audio_ffi.dylib' "$HIFI_DYLIB"
if [ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ]; then
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "$HIFI_DYLIB"
fi
