> 当前分层以 [分支职责](branch_ownership.md) 为准；下文历史路径中的 native/audio_engine 已由锁定的引擎 SDK 替代。

# 深度架构设计文档：C++20 发烧音频引擎与 Flutter 的融合机制

## 1. 架构动机与问题背景
在原项目中，采用 Dear ImGui 直接绘制全部用户界面。虽然在树莓派单板上启动迅速，但在移动端（iPhone、Android、iPad）面临如下致命痛点：
* 缺乏原生触控弹性惯性滑动（Momentum Scrolling）；
* 移动端虚拟软键盘和中文输入法（IME）适配极其繁琐；
* 刘海屏、灵动岛、安全区（SafeArea）需要大量手动坐标硬编码；
* 多端页面状态与响应式自适应布局代码膨胀。

通过将 UI 重构至 Flutter，同时**完整保留 C++20 `audio_engine` 发烧音频内核**，实现了发烧级音质与现代多端交互的最佳平衡。

---

## 2. 60fps 动效与无锁内存直连原理

### 2.1 传统跨语言调用的性能陷阱
在常规跨语言架构（如 Flutter MethodChannel 或 Electron IPC）中，高频传输音频频谱数据需要进行 JSON 序列化与内存拷贝，导致：
1. 频繁触发垃圾回收（GC），引发界面掉帧（Jank）；
2. 音频线程与 UI 线程锁竞争，引起声卡缓冲区欠载（Buffer Underrun 爆音）。

### 2.2 本项目的零拷贝无锁设计
1. **音频侧（C++）**：
   在 `AudioEngine.hpp` 中，12 频段音频频谱振幅采用无锁原子数组维护：
   ```cpp
   std::array<std::atomic<float>, 12> spectrum_levels_{};
   ```
   音频渲染回调写入频谱时无需获取任何互斥锁。
2. **桥接侧（C-API）**：
   通过 `hifi_audio_get_spectrum_levels(float* out_levels_12)` 导出，仅接收外部传入的内存地址。
3. **Flutter 侧（Dart FFI）**：
   在 `HifiAudioBindings` 初始化时一次性分配固定的 48 字节原生内存：
   ```dart
   final Pointer<Float> _spectrumBuffer = calloc<Float>(12);
   ```
   每一帧（16ms / 60fps）只需纳秒级指针直接访问，**零对象分配、零 GC 触发、零 CPU 锁等待**。

---

## 3. 平台分化与自适应路由矩阵

| 平台目录 | 物理分辨率/场景 | 核心设计特点 |
| :--- | :--- | :--- |
| `lib/ui/iphone/` | 竖屏 (安全区避让) | 沉浸式 Now Playing，灵动岛自适应，麦景图表头自适应单手操作 |
| `lib/ui/android/` | 竖屏 Material 3 | 高刷流畅，AAudio 底层直通指示 |
| `lib/ui/pi/` | 1024×600 (微雪 7寸 QLED) | 横屏台机设计，大触控热区，大字号防眩光，匹配 3D 打印 15° 仰角外壳 |
| `lib/ui/ipad/` | 平板大屏横/竖屏 | 双栏分屏 (Master-Detail)，左侧曲库，右侧大尺寸双表头 |
| `lib/ui/mac/` | 桌面宽屏窗口 | macOS 专属侧边栏，CoreAudio 独占 (Hog Mode) 状态呈现 |
| `lib/ui/window/` | 桌面宽屏窗口 | WASAPI 源码直出，发烧仪表工作台 |
