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

# 3. 运行调试
flutter run -d macos
```

### 2.2 树莓派 5 (Linux-Lite) 交叉编译与部署
```bash
# 1. 在 Mac 上打包 Linux ARM64 发行版
flutter build linux --release

# 2. 同步至树莓派
rsync -avz --delete build/linux/arm64/release/bundle/ winheo@winheo-pi.local:/home/winheo/pi-hifi-flutter/

# 3. 树莓派开机自启命令
cage -s -- /home/winheo/pi-hifi-flutter/hide_player_flutter
```
