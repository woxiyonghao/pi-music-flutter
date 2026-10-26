#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  printf '%s\n' 'Usage: scripts/run_android.sh [flutter run options]' \
    'Default: debug with hot reload, on the single connected Android device.' \
    'Select a device with -d SERIAL or HIFI_ANDROID_DEVICE=SERIAL.' \
    'Use --release or --profile to change the build mode.' \
    'Start an emulator first: flutter emulators --launch <emulator-id>'
  exit 0
fi

flutter_sdk="${FLUTTER_ROOT:-}"
android_sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -f android/local.properties ]]; then
  if [[ -z "$flutter_sdk" ]]; then
    flutter_sdk="$(sed -n 's/^flutter\.sdk=//p' android/local.properties | head -1 | tr -d '\r')"
  fi
  if [[ -z "$android_sdk" ]]; then
    android_sdk="$(sed -n 's/^sdk\.dir=//p' android/local.properties | head -1 | tr -d '\r')"
  fi
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
export PATH="$(dirname "$flutter_bin"):${android_sdk:+$android_sdk/platform-tools:}$PATH"
if ! command -v adb >/dev/null 2>&1; then
  printf '%s\n' 'Android adb not found. Set ANDROID_HOME to the Android SDK directory.' >&2
  exit 1
fi

device="${HIFI_ANDROID_DEVICE:-}"
flutter_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device-id)
      if [[ $# -lt 2 || -z "$2" ]]; then
        printf '%s\n' 'The device option requires an Android device serial.' >&2
        exit 1
      fi
      device="$2"
      shift 2
      ;;
    --device-id=*) device="${1#*=}"; shift ;;
    *) flutter_args+=("$1"); shift ;;
  esac
done

devices=()
while IFS= read -r serial; do
  [[ -n "$serial" ]] && devices+=("$serial")
done < <(adb devices | awk '$2 == "device" { print $1 }')

if [[ -z "$device" ]]; then
  if [[ ${#devices[@]} -ne 1 ]]; then
    printf '%s\n' 'Connect one Android device, or select one with -d SERIAL / HIFI_ANDROID_DEVICE.' >&2
    adb devices -l >&2
    printf '%s\n' 'Emulators: flutter emulators; launch: flutter emulators --launch <emulator-id>' >&2
    exit 1
  fi
  device="${devices[0]}"
fi
found=false
for serial in ${devices[@]+"${devices[@]}"}; do
  [[ "$serial" == "$device" ]] && found=true
done
if [[ "$found" != true ]]; then
  printf 'Android device is not connected/authorized: %s\n' "$device" >&2
  adb devices -l >&2
  exit 1
fi

# Android native libraries are built and packaged by Gradle for the device ABI.
dart scripts/fetch_audio_engine.dart
printf 'Running Android on %s (r: hot reload, R: hot restart, q: quit in debug mode).\n' "$device"
# The guarded expansion also supports macOS's system Bash 3.2 with nounset.
exec "$flutter_bin" --no-version-check run -d "$device" ${flutter_args[@]+"${flutter_args[@]}"}
