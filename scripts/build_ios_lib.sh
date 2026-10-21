#!/usr/bin/env bash
set -euo pipefail
HIFI_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HIFI_SDK="${PLATFORM_NAME:-iphoneos}"
case "$HIFI_SDK" in
  iphoneos) HIFI_ARCHS="${ARCHS:-arm64}" ;;
  iphonesimulator) HIFI_ARCHS="${ARCHS:-arm64 x86_64}" ;;
  *) echo "Unsupported iOS SDK: $HIFI_SDK" >&2; exit 1 ;;
esac
HIFI_ARCHS="${HIFI_ARCHS// /;}"
HIFI_BUILD_DIR="$HIFI_PROJECT_DIR/build/audio-engine/$HIFI_SDK"
HIFI_CMAKE_ARGS=()
if [ -n "${FLUTTER_ROOT:-}" ]; then
  HIFI_CMAKE_ARGS+=("-DHIFI_DART_EXECUTABLE=$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart")
fi
cmake -S "$HIFI_PROJECT_DIR/native" -B "$HIFI_BUILD_DIR" -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$HIFI_SDK" \
  -DCMAKE_OSX_ARCHITECTURES="$HIFI_ARCHS" -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_BUILD_TYPE=Release "${HIFI_CMAKE_ARGS[@]}"
cmake --build "$HIFI_BUILD_DIR" --config Release --target hifi_audio_ffi --parallel -- CODE_SIGNING_ALLOWED=NO
mkdir -p "$HIFI_PROJECT_DIR/ios/lib/$HIFI_SDK"
cp "$HIFI_BUILD_DIR/Release/libhifi_audio_ffi.a" "$HIFI_PROJECT_DIR/ios/lib/$HIFI_SDK/"
