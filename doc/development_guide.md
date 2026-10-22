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

# 2. 运行调试（也可从 IDE / Xcode 启动）
flutter run -d macos

# 3. 构建独立运行的发行版
./scripts/build_mac.sh
```

macOS 工程会通过 `scripts/build_macos_audio.sh`，按 `audio_engine.lock.json`
锁定的提交增量编译音频库，放入应用的 `Contents/Frameworks` 并签名。
首次构建需要 CMake 和 Git 仓库访问权限；缓存位于 `.dart_tool/audio_engine/source`，
构建产物位于 `build/audio-engine/macos-*`。无需手动复制根目录或 `native/build`
中的动态库，旧版本库不会阻止 SDK 更新。

### 2.2 树莓派 5 (Linux-Lite) 交叉编译与部署
```bash
# 1. 在 Mac 上打包 Linux ARM64 发行版
flutter build linux --release

# 2. 同步至树莓派
rsync -avz --delete build/linux/arm64/release/bundle/ winheo@winheo-pi.local:/home/winheo/pi-hifi-flutter/

# 3. 树莓派开机自启命令
cage -s -- /home/winheo/pi-hifi-flutter/hide_player_flutter
```
