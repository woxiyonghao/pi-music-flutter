#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  printf '%s\n' 'Usage: scripts/build_android.sh [flutter build apk options]' \
    'Default: release APK. Use --debug or --profile to change the build mode.' \
    'Set FLUTTER_ROOT if Flutter is not in android/local.properties or PATH.'
  exit 0
fi

flutter_sdk="${FLUTTER_ROOT:-}"
if [[ -z "$flutter_sdk" && -f android/local.properties ]]; then
  flutter_sdk="$(sed -n 's/^flutter\.sdk=//p' android/local.properties | head -1 | tr -d '\r')"
fi
if [[ -n "$flutter_sdk" ]]; then
  flutter_bin="$flutter_sdk/bin/flutter"
else
  flutter_bin="$(command -v flutter || true)"
fi
if [[ ! -x "$flutter_bin" ]]; then
  printf '%s\n' 'Flutter SDK not found. Set FLUTTER_ROOT or add flutter to PATH.' >&2
  exit 1
fi
export PATH="$(dirname "$flutter_bin"):$PATH"

# Fetch and validate the exact SDK revision before Gradle invokes native CMake.
dart scripts/fetch_audio_engine.dart
# Keep the CLion action focused on this build; update Flutter separately.
exec "$flutter_bin" --no-version-check build apk "$@"
