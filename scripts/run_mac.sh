#!/bin/zsh
set -e

# HiFi Player macOS 一键运行脚本 (CLion / 终端专用)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🎵 [HiFi Master] 准备运行 macOS 原生发烧播放器 (Release 模式)..."

export PATH="$PATH:$HOME/development/flutter/bin:/opt/homebrew/bin"

# Xcode 自动按 audio_engine.lock.json 增量构建并打包音频库。

echo "🚀 [Flutter] 启动 macOS 端 (Release AOT 模式)..."
flutter run -d macos --release "$@"
