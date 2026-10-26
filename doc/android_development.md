# 在 CLion 开发 Android

打开仓库根目录 `CMakeLists.txt`，使用本机默认 CMake 工具链，重载 CMake。
`dev/android` 入口为 `lib/main.dart`，启动时先选择横屏或竖屏，再进入 Android 播放器。

显示模式与 iPhone 一致：默认选中横屏，每次冷启动重新选择，后台恢复保留本次选择。
选择页先于磁盘、插件和音频引擎初始化显示；启动失败时可重试。
手机请求锁定为所选方向；Android 大屏或多窗口可能忽略方向请求，此时播放器按可用
窗口尺寸重新排布，仍保留所选模式，不会卡在等待旋转画面。

音乐通过 WiFi 传歌写入应用 Documents 目录，扫描后保存到应用沙盒中的 SQLite 曲库。
首次曲库为空；扫描以文件名和文件夹建立索引，尚未检测的音频规格显示“规格待检测”。

## 环境

- Flutter SDK：优先使用 `FLUTTER_ROOT`，其次 `android/local.properties` 中的 `flutter.sdk`，最后使用 `PATH`。
- Android SDK：安装 SDK Platform、Build Tools、Platform Tools、Flutter 指定版本的 NDK 和 CMake 3.22.1；运行 `flutter doctor -v` 检查环境。
- Java 使用 Flutter 选择的 JDK，可通过 `flutter doctor -v` 查看。不要使用 CLion 自身的 JVM 代替 Android 构建 JDK。
- `android/local.properties` 是本机配置，不提交。CLion CMake 可用 `-DHIFI_FLUTTER_SDK=/path/to/flutter` 或 `-DHIFI_DART_EXECUTABLE=/path/to/dart` 指定 SDK。

在 Android Studio Device Manager 启动模拟器，或运行：

```bash
flutter emulators
flutter emulators --launch <emulator-id>
adb devices -l
```

真机需要打开 USB 调试并授权此电脑。脚本只选择已连接的 Android 设备。
有多个设备时，在 CLion 运行配置的环境变量中填 `HIFI_ANDROID_DEVICE=设备序列号`，
或在脚本参数中填 `-d 设备序列号`。

## 运行与构建

CLion 运行配置 `运行 Android (Flutter Debug)` 使用 `scripts/run_android.sh`。
运行窗口的终端中，`r` 热重载，`R` 热重启，`q` 退出。
将脚本参数设为 `--release` 可运行 Release，`--profile` 可运行 Profile。
这里的配置启动 Flutter CLI；Dart 断点与 DevTools 使用 CLI 输出的调试链接。

运行配置 `编译 Android APK (Release)` 生成默认 Release APK。
将脚本参数设为 `--debug` 可编译 Debug APK。也可直接在 CLion 终端使用：

```bash
bash scripts/run_android.sh
bash scripts/run_android.sh -d emulator-5554 --release
bash scripts/build_android.sh --debug
bash scripts/build_android.sh
bash scripts/build_android.sh --target-platform android-arm64 --split-per-abi
```

APK 输出到 `build/app/outputs/flutter-apk/`。当前 Android Gradle 配置的 Release 使用
开发签名，正式发布前需要单独配置发行签名。
只需要 ARM64 时，使用上面的 `--target-platform android-arm64 --split-per-abi`，
产物为 `app-arm64-v8a-release.apk`，确保 APK 中所有原生库使用同一 ABI。
运行与构建脚本跳过 Flutter 的联网版本检查，避免该检查占用启动锁；SDK 更新单独执行。

对应 CMake targets 为 `run_android`、`run_android_release`、`build_android_debug`、
`build_android`。需要交互热重载时，使用上述 Shell 运行配置。

## 音频 SDK 与 CMake

脚本先用 `scripts/fetch_audio_engine.dart` 校验并拉取 `audio_engine.lock.json`
锁定的 SDK。Android Gradle 调用 `native/CMakeLists.txt`，按 APK 的 ABI 构建并打包
`libhifi_audio_ffi.so`，无需手动复制本机的动态库。

CLion 根 CMake 的 `hifi_audio_ffi` target 用于本机 C++ 索引与单独检查，默认构建不编译它。
Android APK 通过 `build_android*` target 构建。只需要 Dart/Android 工作流时，
可用 `-DHIFI_INDEX_NATIVE=OFF` 关闭本机原生 SDK 索引；引擎源码继续在
`dev/audio_engine` 维护，不在 `.dart_tool/audio_engine/source` 中修改。

## 验证

```bash
flutter --no-version-check test --concurrency=1
bash scripts/build_android.sh --release --target-platform android-arm64 --split-per-abi
```

自动测试覆盖开屏选择、后台恢复、启动重试、方向请求失败恢复、曲库导入、播放队列、
所有 Android 功能页，以及小屏和两倍字体布局。连接真机后还需检查实际旋转、音频输出
和耳机拔出暂停；模拟器不能代替 USB DAC 的硬件验证。

2026-10-25 本机验证：69 项自动测试全部通过；纯 ARM64 Release APK 构建与签名校验
通过，包含 Flutter、应用、音频引擎和 C++ 运行库。模拟器因可用磁盘空间不足未能启动，
真机旋转与音频输出尚未验证。
