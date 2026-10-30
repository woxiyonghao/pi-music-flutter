#!/bin/bash
set -e

# ==============================================================================
# MyHiFi Player 树莓派 Lite 纯净无桌面系统 (Raspberry Pi OS Lite) 一键部署脚本
# 专为发烧数播打造：零桌面占用、无窗口边框、开机纯黑底秒进 1024x600 发烧台机
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🍓 [Lite-HiFi] 正在为 Raspberry Pi OS Lite 配置开机直达纯音数播..."

# 1. 安装极简单应用 Wayland Kiosk 容器 (Cage) 与必要音视频依赖 (绝不安装任何臃肿桌面)
echo "📦 [1/3] 安装 Cage 极简合成器与发烧音频运行时依赖..."
sudo apt update
sudo apt install -y cage libgtk-3-0 libgl1-mesa-dri libasound2-dev libsdl2-dev udisks2

# 2. 确保当前用户在 input / video / audio 用户组中 (触控与音频权限)
echo "🔑 [2/3] 配置硬件触屏与 ALSA 声卡访问权限..."
sudo usermod -aG audio,video,input,render "$USER"

# 3. 配置 FAT32 (vfat) 分区 UTF-8 挂载，彻底防止歌曲中文歌名乱码
echo "🌐 [3/4] 检查并配置 /boot/firmware 分区 UTF-8 中文字符集..."
if grep -q '/boot/firmware.*vfat.*defaults' /etc/fstab && ! grep -q '/boot/firmware.*utf8' /etc/fstab; then
    sudo sed -i 's|/boot/firmware  vfat    defaults|/boot/firmware  vfat    defaults,utf8|' /etc/fstab
    sudo mount -o remount,utf8 /boot/firmware 2>/dev/null || true
    echo "✅ 已启用 /boot/firmware utf8 挂载支持"
fi

# 4. 安装开机自启 Systemd 服务 (无桌面秒启)
echo "⚙️ [4/4] 配置开机自启 systemd 纯净 Kiosk 服务..."
sudo cp -f "${SCRIPT_DIR}/myhifi.service" /etc/systemd/system/myhifi.service
sudo systemctl daemon-reload
sudo systemctl enable myhifi.service

echo ""
echo "🎉 ========================================================================"
echo "✅ 树莓派 Lite 纯音数播配置完成！"
echo "🚀 特性说明："
echo "   1. 彻底跳过任何桌面，开机直奔 1024x600 发烧纯音界面"
echo "   2. 自动捕获微雪 7 寸电容触摸屏，隐藏多余光标"
echo "   3. 内存与后台干扰极低，为 ALSA 与 DSD 解码提供极低抖动 (Jitter)"
echo "   4. 随时手动启动测试: cage -s -- ${PROJECT_DIR}/build/linux/arm64/release/bundle/hide_player_flutter"
echo "   5. 开机自启服务状态: sudo systemctl status myhifi"
echo "========================================================================"
