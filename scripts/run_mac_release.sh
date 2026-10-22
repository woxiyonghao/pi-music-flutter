#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$PATH:$HOME/development/flutter/bin:/opt/homebrew/bin"
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"


# Keep platform branches separate: the Mac button always runs dev/mac.
if [[ "$(git -C "$PROJECT_DIR" branch --show-current)" == "dev/mac" ]]; then
    MAC_WORKSPACE="$PROJECT_DIR"
else
    MAC_WORKSPACE=""
    WORKTREE_PATH=""
    while IFS= read -r line; do
        case "$line" in
            'worktree '*) WORKTREE_PATH="${line#worktree }" ;;
            'branch refs/heads/dev/mac') MAC_WORKSPACE="$WORKTREE_PATH"; break ;;
        esac
    done < <(git -C "$PROJECT_DIR" worktree list --porcelain)

    if [[ -z "$MAC_WORKSPACE" ]]; then
        if ! git -C "$PROJECT_DIR" show-ref --verify --quiet refs/heads/dev/mac; then
            git -C "$PROJECT_DIR" branch --track dev/mac origin/dev/mac
        fi
        MAC_WORKSPACE="$PROJECT_DIR/.dart_tool/macos-release"
        mkdir -p "$PROJECT_DIR/.dart_tool"
        git -C "$PROJECT_DIR" worktree add "$MAC_WORKSPACE" dev/mac
    fi
fi

cd "$MAC_WORKSPACE"
echo "macOS Release | dev/mac | $MAC_WORKSPACE"
echo "Xcode 会先构建并打包锁定版本的 audio_engine 音频库。"
exec flutter run -d macos --release "$@"
