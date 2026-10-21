# 平台与引擎边界

所有分支都位于 `woxiyonghao/pi-music-flutter`。
`dev/audio_engine` 独立维护 C++、硬件后端与 C ABI；平台分支不保留重复实现。
当前分支 `dev/iphone` 的 Dart 入口固定为 `iphone`，启动时显式注入引擎。

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
