#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
cmake -S native -B native/build -DCMAKE_BUILD_TYPE=Release
cmake --build native/build --target hifi_audio_ffi --parallel
flutter build linux --release
# Flutter names the directory for the host architecture (x64 or arm64).
mapfile -t bundles < <(find build/linux -path '*/release/bundle' -type d)
if [ "${#bundles[@]}" -ne 1 ]; then
  echo "Cannot identify the Linux Release bundle" >&2
  exit 1
fi
cp native/build/libhifi_audio_ffi.so "${bundles[0]}/lib/"
echo "Release bundle: ${bundles[0]}"
