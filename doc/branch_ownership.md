# 平台与引擎边界

所有分支都位于 `woxiyonghao/pi-music-flutter`。
`dev/audio_engine` 独立维护 C++、硬件后端与 C ABI；平台分支不保留重复实现。
当前分支 `dev/ipad` 的 Dart 入口固定为 `ipad`，启动时显式注入引擎。

`audio_engine.lock.json` 锁定提交与 ABI。构建脚本使用 Dart 工具拉取这个提交，
缓存放在 `.dart_tool/audio_engine/source`；移动端运行时不依赖 Git。
修改引擎应在 `dev/audio_engine` 提交并验证，再在需要该修复的平台分支更新 lock。
不要把引擎分支 merge 到 UI 分支，也不要把另一个平台的整分支 merge 过来。

会话、焦点与中断处理在 `lib/platform/platform_audio_runtime.dart`，使用 audio_session；
Swift 只提供系统输出格式/缓冲与文件保护的薄适配，不调用 C++ 播放接口。
真实硬件能力由引擎的 capability 和系统设备信息决定，不能通过 platform 字段伪造。
现有共用 UI 组件可复用；每个分支的应用入口只导入自己的主页面。

发行构建统一使用 scripts/build_* 的 Release 入口。
Pi 电源控制只用于物理树莓派；Git OTA 只在桌面/Pi 平台暴露。


## 共享曲库内核

CUE 解码（UTF-8、UTF-16、GBK/GB18030）、目录遍历、元数据解析、稳定曲目 ID 和 SQLite 连接/事务统一在 `dev/audio_engine`。
平台通过 `lib/core/native_music_library.dart` 调用同一套 C ABI，不再维护 Dart CUE/元数据解析器或单独的 Dart SQLite 实现。
WiFi 局部扫描会保留其他扫描根目录的曲目；入库失败回滚，目录不可读时保留原记录。现有 `library.db`、歌单和设置继续使用。

扫描目录只在 `LibraryScanPolicy` 选择：Pi 为 `/`（可读文件，跳过 `/proc`、`/sys`、`/dev`）；Android 为 WiFi 上传沙盒及 `/storage/emulated/0/Music`（包括 `pimusic`，不扫描 Download）；iPhone/iPad 为应用 Documents 及当前 WiFi 上传目录。
iOS 的 Documents 通过 `UIFileSharingEnabled` 与 `LSSupportsOpeningDocumentsInPlace` 在“文件”App、Mac Finder 文件共享中可见。

`flutter test` 通过 `test/flutter_test_config.dart` 自动构建锁定引擎的主机库，测试实际 C++ 扫描和数据库；可用 `HIFI_LIBRARY_TEST_DYLIB` 指向已构建库以复用同一产物。
