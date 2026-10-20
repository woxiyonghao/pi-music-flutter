# 开发环境与全平台构建指南

## 1. 开发环境配置

### 1.1 Flutter 国内镜像加速配置 (推荐写入 `~/.zshrc`)
在终端中执行：
```bash
cat << 'EOF' >> ~/.zshrc

# Flutter & Dart 国内镜像源加速
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# Flutter SDK 路径 (解压至 ~/development/flutter)
export PATH="$HOME/development/flutter/bin:$PATH"
EOF
source ~/.zshrc
```

### 1.2 依赖检查
```bash
flutter doctor
```

---

## 2. 编译与运行流程

### 2.1 macOS 开发机运行
```bash
# 1. 获取 Flutter 依赖
flutter pub get

# 2. 编译 C++ 发烧音频核心动态库
cd native
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j8
cd ..

# 3. 以 Release 模式运行
zsh scripts/run_mac.sh
```

### 2.2 树莓派 5 (Linux-Lite) 交叉编译与部署
```bash
# 1. 在 Linux / 树莓派目标机器上构建（Flutter Linux 不支持直接在 macOS 上交叉构建）
bash scripts/build_linux.sh

# 2. 同步至树莓派
rsync -avz --delete build/linux/arm64/release/bundle/ winheo@winheo-pi.local:/home/winheo/pi-hifi-flutter/

# 3. 树莓派开机自启命令
cage -s -- /home/winheo/pi-hifi-flutter/hide_player_flutter
```

### 2.3 各平台统一使用 Release

| 平台 | 构建命令 | Git OTA | 系统电源控制 |
| --- | --- | --- | --- |
| macOS | `zsh scripts/build_mac.sh` | 显示 | 隐藏 |
| Windows | `powershell -File scripts/build_windows.ps1` | 显示 | 隐藏 |
| Linux 桌面 | `bash scripts/build_linux.sh` | 显示 | 隐藏 |
| 树莓派 | `bash scripts/build_pi.sh` | 显示 | 显示 |
| iPad / iPhone | `zsh scripts/build_ios.sh` | 隐藏 | 隐藏 |
| Android | `bash scripts/build_android.sh` | 隐藏 | 隐藏 |

桌面 OTA 使用同一套脚本，重新构建原生音频库并打包进 Release 应用。运行 OTA 的设备需要 Git、Flutter SDK、CMake 与该平台的构建工具。

macOS 音频以当前系统输出设备为准；高采样率或多声道音源会在解码线程转换为设备可用的 PCM 格式。DAC 参数属于偏好，不能强制改变蓝牙设备的硬件时钟，也不会缩小已分配的播放缓冲。DAC 页与侧栏显示实际输出设备，切换 AirPods、内置扬声器或 USB 解码器时会重新协商格式。

DAC 列表过滤 HDMI / DisplayPort 显示器音频，保留本机音频、蓝牙耳机和 USB 解码器。macOS 播放器通常跟随系统输出；系统选中显示器时，自动回退到真实的本机扬声器，并将系统默认输出同步到该设备，让键盘音量键控制实际播放设备。此操作仅在设备工作线程检测到输出变化时执行，写入前重新检查默认设备，避免覆盖用户同时切换到的耳机。原生枚举、采样率协商、AudioQueue 绑定使用同一输出选择规则，Flutter 服务层再次过滤显示器。Mac mini 作为当前输出时展示本机调节面板，音量和静音直接控制播放器音频流。

其他未作为当前输出的设备置灰，需在系统声音设置中切换，页面约 2 秒自动刷新。服务层同样拦截 HTTP / WebSocket 的设备切换请求，点击当前设备也不会重建播放流。USB DAC（包括系统识别的 TOPPING DX12）成为系统输出后自动激活。Flutter 自动下一曲仅响应原生 `hifi_audio_has_playback_completed`，该信号在 EOF 且解码缓冲耗尽时置位，输出重建、暂停或停止不能触发下一曲。

EQ 滤波历史属于音频流，跨回调线程保持连续。多频段提升会自动预留增益余量，参数切换与旁路采用短交叉淡化，避免硬削顶和缓冲边界脉冲；开启 EQ 后整体音量可能相应降低。

桌面滑条使用 `HifiSlider`，为 Material Slider 建立独立的本地 Overlay，保留辅助功能语义并避开 Flutter 3.47 的滑条浮层孤立节点问题（[Flutter #190357](https://github.com/flutter/flutter/issues/190357)）。该问题会使原生辅助功能树更新失败，甚至在 `AccessibilityBridge::CreateRemoveReparentedNodesUpdate` 崩溃。`test/slider_semantics_test.dart` 检查实际序列化的增量节点，覆盖对话框进出、滑条拖动和指示浮层更新。

打开歌曲前通过 Dart 异步文件服务预检读取权限，避免 macOS 等待“下载”目录授权时将 Flutter 主线程阻塞在原生 `fopen`。预检期间可以继续操作界面；新选曲或停止会取消旧的播放请求，暂停和进度选择在预检完成后保留。`test/playback_file_access_test.dart` 覆盖授权等待、拒绝与播放请求取消。开发用临时签名变化后，macOS 可能重新请求文件夹授权，需通过正常系统提示确认。
