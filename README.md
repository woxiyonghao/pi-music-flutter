# HiFi audio_engine

此分支属于 **`woxiyonghao/pi-music-flutter`**，分支名为 **`dev/audio_engine`**。
这里维护独立的 C++20 音频引擎、硬件后端、公共 C ABI 和原生回归测试。
不包含原 C++ 播放器的 UI、Flutter UI 或 Flutter 插件。

## 分支与职责

| 分支 | 负责内容 |
| --- | --- |
| `dev/audio_engine` | 解码、PCM 转换、EQ、播放状态、真实输出设备探测与硬件后端 |
| `dev/iphone` | iPhone Dart UI、启动参数、audio_session 与平台策略 |
| `dev/ipad` | iPad Dart UI、启动参数、audio_session 与平台策略 |
| `dev/mac` | macOS Dart UI、输出策略、音量交互 |
| `dev/pi` | 树莓派 Dart UI、设备策略、Pi 专属系统操作 |
| `dev/android` | Android Dart UI、音频焦点与会话策略 |
| `dev/window` | Windows Dart UI、平台策略 |

平台分支通过版本锁定使用引擎。公共音频修复提交到本分支，平台 UI/会话修复
提交到对应平台分支；不要把原播放器整体复制进来。分支名称本身不会自动建立
依赖，各平台接入时必须明确锁定引擎 revision 并编译该版本。

## ABI 2：由 Flutter 注入 platform

```c
#include "hifi_audio_ffi.h"

// Flutter 启动时传入自身分支的逻辑平台，不能依赖屏幕尺寸推断 iPhone/iPad。
if (hifi_audio_get_abi_version() != 2) { /* 拒绝不兼容 SDK */ }
bool ok = hifi_audio_init_for_platform("mac",
    HIFI_EXCLUDE_DISPLAY_OUTPUTS | HIFI_SYNCHRONIZE_SYSTEM_OUTPUT);
```

允许的 `platform`：`iphone`、`ipad`、`mac`、`pi`、`android`、`window`、`linux`。
初始化身份和输出策略一经配置不可修改；相同参数可重复调用。
未注入平台时，旧 `hifi_audio_init()` 与打开曲目接口返回失败，避免静默猜测平台。
`hifi_audio_get_capabilities_json()` 返回 ABI、注入的平台、实际编译后端与可用操作。
逻辑平台不会伪造硬件能力，也不会把 macOS 预览环境变成 iOS 音频硬件。

输出策略是显式位掩码：

| 位 | 策略 | 适用后端 |
| --- | --- | --- |
| 1 | 过滤 HDMI / DisplayPort 显示器输出 | macOS |
| 2 | 将系统默认输出同步到实际播放设备，配合键盘音量键 | macOS |
| 4 | 使用 RemoteIO | iOS |
| 8 | 优先外接输出 | SDL |

会话类别、激活、音频焦点、中断恢复、蓝牙拔出后的暂停等由 Flutter/Dart
平台层负责。引擎不回调宿主 Swift 函数，也不持有 `AVAudioSession`。
iOS 平台激活会话后，必须先报告真实输出格式，再打开曲目：

```c
hifi_audio_init_for_platform("ipad", HIFI_PREFER_REMOTE_IO);
// 下列值必须来自系统实际路由，此处只展示调用形状。
hifi_audio_update_host_output(sample_rate, channels, device_uid, device_name, transport);
hifi_audio_open_and_play(path);
```

路由格式改变时再次报告；引擎在工作线程重建 PCM 管道，保留曲目和进度。
硬件缓冲偏好通过平台适配器申请，`hifi_audio_set_hardware_buffer_frames()`
只调整引擎允许的缓冲参数，不能替代平台会话 API。
JSON 返回值在同线程下一次同类查询前有效，调用方应立即复制，不得释放。
EOF C 回调在音频线程触发，Dart 应轮询 `hifi_audio_has_playback_completed()`。

## Release 构建与验证

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
ctest --test-dir build --output-on-failure
cmake --install build --config Release --prefix sdk
```

公共头文件：`include/hifi_audio_ffi.h`。
CMake 目标：`hifi_audio_ffi`（macOS/Linux/Windows/Android 共享库，iOS 自包含静态库）。
C++ 目标：`audio_engine`。默认构建类型为 Release。

macOS 使用 CoreAudio/AudioToolbox；iOS 使用 AudioQueue 或 RemoteIO；
Android 使用 AAudio（API 26+）；Linux/Windows 使用 SDL2。
Linux 编译包含 ALSA 适配器，但当前默认播放路径仍为 SDL，不能宣称正在独占 ALSA。
Windows 不宣称已实现 WASAPI 独占。USB 芯片画像只提供识别资料，不能代表已经实现
厂商滤波器、DPLL 或增益控制。设备枚举与选择以 capability 返回值为准。
模拟 TOPPING 设备仅用于显式诊断，默认关闭。

测试默认不播放可听见的声音。macOS 可选运行
`build/core_audio_playback_test --with-output` 验证实际 AudioQueue 静音输出。

## 来源

独立源码从原 `pi-hifi-player` 的 `b6d3c35` 提取；PCM 兼容、EQ 余量、真实 EOF
及 macOS 路由修复来自 Flutter 集成。原仓库只保留历史来源意义，后续引擎依赖
应指向当前 Flutter 仓库的 `dev/audio_engine` 及具体提交。

## Shared music library core

`audio_engine/library/MusicLibrary.hpp` owns filesystem enumeration, CUE decoding
(UTF-8, UTF-16, GBK/GB18030), 75-frame timestamps, metadata, stable track IDs and
transactional SQLite replacement. The host supplies scan roots and storage
permission; scanning never initializes or changes an audio output.

The additive ABI-2 functions `hifi_library_scan_json` and
`hifi_library_metadata_json` return thread-local UTF-8 JSON. Copy the result before
calling again on the same thread. Scan flag 1 preserves records outside a partial
upload scan; flag 2 scans a filesystem root, including hidden folders, while
excluding virtual proc/sys/dev trees. Other scans reject symlink escapes from the
provided roots. Unreadable directories retain their previous records.

`hifi_library_db_open/close/query_json` own SQLite connections. Query parameters
are a JSON array and are bound through SQLite; statements on one handle share a
transaction. Existing `library.db`, settings, playlists and track IDs are reused.
Old path-unique schemas are migrated so multiple CUE tracks can share one file.
SQLite 3.50.4 is bundled with hidden symbols on Unix; no platform SQLite runtime
or separate Dart database implementation is needed. Provenance is recorded in
`audio_engine/third_party/sqlite/SOURCE.md`.

Build and verify with `cmake -S . -B build && cmake --build build &&
ctest --test-dir build --output-on-failure`. `music_library_test` uses temporary
files and databases; it never scans the user's library.
