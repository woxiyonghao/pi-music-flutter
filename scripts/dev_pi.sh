#!/bin/bash
# ==============================================================================
# MyHiFiPlayer 树莓派 5 自动化开发、同步与远程 Debug 脚本
# 支持：Mac 本地修改一键同步、远程增量构建、Cage 交互运行与实时日志流 Debug
# ==============================================================================

set -e

PI_USER="winheo"
PI_HOST="192.168.1.200"
PI_DIR="/home/${PI_USER}/pi-music-flutter"
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

function log_info() {
    echo -e "\033[1;34m[dev_pi]\033[0m $1"
}

function log_succ() {
    echo -e "\033[1;32m[dev_pi] ✅\033[0m $1"
}

function log_warn() {
    echo -e "\033[1;33m[dev_pi] ⚠️\033[0m $1"
}

function log_err() {
    echo -e "\033[1;31m[dev_pi] ❌\033[0m $1"
}

function check_conn() {
    if ! ping -c 1 -W 2000 "${PI_HOST}" >/dev/null 2>&1; then
        log_err "无法连接到树莓派 (${PI_HOST})，请检查网络连接！"
        exit 1
    fi
}

function sync_code() {
    check_conn
    log_info "正在增量同步本地代码至树莓派 (${PI_DIR})..."
    rsync -avz --delete \
        --exclude '.git' \
        --exclude 'build' \
        --exclude '.dart_tool' \
        --exclude '.idea' \
        --exclude '.vscode' \
        "${LOCAL_DIR}/" "${PI_USER}@${PI_HOST}:${PI_DIR}/"
    log_succ "代码同步完成！"
}

function build_native() {
    check_conn
    log_info "正在树莓派上构建 C++20 发烧音频引擎 (libhifi_audio_ffi.so)..."
    ssh -n "${PI_USER}@${PI_HOST}" "bash -c '
        cd ${PI_DIR}/native
        mkdir -p build && cd build
        cmake .. -DCMAKE_BUILD_TYPE=Release
        cmake --build . --target hifi_audio_ffi -j4
        cp -f libhifi_audio_ffi.so ${PI_DIR}/libhifi_audio_ffi.so
    '"
    log_succ "原生动态库编译完成！"
}

function build_app() {
    sync_code
    build_native
    log_info "正在树莓派上打包 Flutter Linux Release Bundle..."
    ssh -n "${PI_USER}@${PI_HOST}" "bash -c '
        export PATH=\"/home/${PI_USER}/flutter/bin:\$PATH\"
        export PUB_HOSTED_URL=https://pub.flutter-io.cn
        export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
        cd ${PI_DIR}
        flutter pub get
        flutter build linux --release
        mkdir -p ${PI_DIR}/build/linux/arm64/release/bundle/lib
        cp -f ${PI_DIR}/libhifi_audio_ffi.so ${PI_DIR}/build/linux/arm64/release/bundle/lib/
    '"
    log_succ "Flutter Linux Bundle 打包完成！"
}

function run_interactive() {
    check_conn
    log_info "停止后台服务并进入前台交互式 Cage 调试模式 (Ctrl+C 退出)..."
    ssh -n "${PI_USER}@${PI_HOST}" "sudo systemctl stop myhifi.service 2>/dev/null || true"
    ssh -t "${PI_USER}@${PI_HOST}" "bash -c '
        cd ${PI_DIR}
        export XDG_RUNTIME_DIR=/run/user/1000
        export PI_KIOSK=1
        export LIBSEAT_BACKEND=seatd
        cage -s -- ${PI_DIR}/build/linux/arm64/release/bundle/hide_player_flutter
    '"
}

function show_logs() {
    check_conn
    log_info "正在实时捕获树莓派 myhifi.service 日志流 (Ctrl+C 退出)..."
    ssh -t "${PI_USER}@${PI_HOST}" "journalctl -u myhifi.service -f --no-tail"
}

function restart_service() {
    check_conn
    log_info "正在重启树莓派 myhifi.service 服务..."
    ssh -n "${PI_USER}@${PI_HOST}" "sudo systemctl restart myhifi.service"
    sleep 2
    check_status
}

function check_status() {
    check_conn
    log_info "获取树莓派发烧台机硬件与服务运行状态..."
    ssh -n "${PI_USER}@${PI_HOST}" "bash -c '
        echo \"=== [1] 服务运行状态 ===\"
        systemctl status myhifi.service --no-pager -n 5 2>/dev/null || echo \"服务未运行\"
        echo \"\"
        echo \"=== [2] 7寸屏幕与显示模式 ===\"
        cat /sys/class/drm/card*-*/status 2>/dev/null || true
        echo \"\"
        echo \"=== [3] ALSA 物理声卡拓扑 ===\"
        cat /proc/asound/cards 2>/dev/null || true
        echo \"\"
        echo \"=== [4] Web 远程中枢状态 (:8088) ===\"
        curl -s -m 2 http://127.0.0.1:8088/api/status 2>/dev/null || echo \"Web 服务未响应\"
        echo \"\"
    '"
}

function show_help() {
    echo "======================================================================"
    echo "🎵 MyHiFiPlayer 树莓派 5 自动化开发与远程 Debug 工具 (scripts/dev_pi.sh)"
    echo "======================================================================"
    echo "用法: $0 [命令]"
    echo ""
    echo "常用指令:"
    echo "  sync          增量同步本地修改的代码到树莓派"
    echo "  build-native  在树莓派上编译 C++ 音频核心动态库 (libhifi_audio_ffi.so)"
    echo "  build         同步代码并在树莓派上完整编译原生引擎 + Flutter Bundle"
    echo "  run           在树莓派物理屏幕上前台以 Cage 运行 Flutter，实时输出控制台 Debug"
    echo "  restart       重启树莓派后台 systemd 开机自启服务 (myhifi.service)"
    echo "  logs          实时滚动监听树莓派 systemd 运行日志与异常堆栈"
    echo "  status        检查树莓派服务运行状态、物理屏幕连接与声卡拓扑"
    echo "======================================================================"
}

case "$1" in
    sync)
        sync_code
        ;;
    build-native)
        build_native
        ;;
    build)
        build_app
        ;;
    run)
        run_interactive
        ;;
    restart)
        restart_service
        ;;
    logs)
        show_logs
        ;;
    status)
        check_status
        ;;
    *)
        show_help
        ;;
esac
