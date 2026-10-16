# 树莓派 5 (Raspberry Pi 5) 发烧数播开发进度与交接上下文文档

> **文档定位**：供开发者在不同电脑（Mac 笔记本 / 家里台式机 / 树莓派真机）无缝接续开发使用的权威全景进度与技术上下文指南。  
> **更新时间**：2026-10-16 18:00  
> **当前活动分支**：`dev/pi`  
> **远程仓库地址**：`git@github.com:woxiyonghao/pi-music-flutter.git`  
> **最新 Commit**：`ce4f6c5` (已全量推送至 `origin/dev/pi`)

---

## 一、 快速克隆与环境启动（换电脑后怎么跑）

### 1. 代码拉取与分支切换
```bash
# 克隆仓库（如已有仓库直接 git fetch）
git clone git@github.com:woxiyonghao/pi-music-flutter.git
cd pi-music-flutter

# 切换到树莓派专属主开发分支
git checkout dev/pi
git pull origin dev/pi

# 获取 Flutter 依赖
flutter pub get
```

### 2. 在 Mac 电脑上即时运行与模拟
```bash
# 启动 macOS 桌面端运行（默认即进入树莓派 7 寸台机发烧视窗，可随时在右上角切换预览）
flutter run -d macos

# 或者执行全量自动化测试（保证全部 47 个测试用例通过）
flutter test

# 静态代码检查（保证 0 报错 0 警告）
flutter analyze lib/
```

### 3. 在树莓派 5 (Raspberry Pi OS Lite) 上构建与启动
```bash
# 1. 运行一键环境依赖配置脚本（首次部署需执行，安装 Cage、ALSA、编译工具链）
bash scripts/setup_pi_lite.sh

# 2. 编译 Linux 原生动态库与 Flutter Release Bundle
bash scripts/build_pi.sh

# 3. 终端无桌面独立运行测试（Cage Kiosk 极速全屏启动）
cage -s -- ./build/linux/arm64/release/bundle/hide_player_flutter

# 4. 或者通过 systemd 守护服务自启（开机 6 秒自动进入播放器）
sudo systemctl enable --now myhifi.service
```

---

## 二、 核心开发进度与已完成能力清单

### 1. 横屏发烧全景 UI 架构统一 (iPad / Mac / 树莓派 100% 保持一致)
* **消除割裂**：彻底移除了原先临时抽屉式（Drawer）过渡代码，建立了全新的 **统一横屏发烧主视窗 (`LandscapeMainView`)**，精简了 1100+ 行重复与碎片化代码。
* **1024×600 完美自适应**：
  * **左侧发烧导航栏 (230px)**：包含全部音乐、自定义歌单、扫描曲库、10段EQ、调音魔棒、DAC设置、主题视效、系统设置、Web服务。
  * **左下角硬件状态卡**：实时读取 `PiSystemService`，动态显示 ALSA 硬件声卡名（如 `AK4191 + AK4499EX` 或 USB DAC）与 SoC 核心实时温度（如 `42.0°C`），点击直达 DAC 设置。
  * **中央主舞台 (778×498)**：底层 GPU 独立渲染麦景图双表头 / 金嗓子表头 / 磁带机 / 频谱动效；上层液态玻璃卡片自适应平滑滚动。
  * **底部播放控制胶囊栏 (48px)**：切歌、播放/暂停、曲目名、192k/DSD 金标、时间轴滑块、音量调节、全屏切换。
* **空闲自动屏保 (Idle Screensaver)**：无操作 15s/30s/1m/5m 后四角面板以 0.4s 平滑移出屏幕，进入纯净麦景图/金嗓子大表头全屏沉浸（QLED 防烧屏台机摆件模式），轻触屏幕任意位置平滑唤醒。
* **触控手势全面优化**：全局注入 `MouseDraggableScrollBehavior`，在微雪 7 寸电容屏上用手指随意上下拖拽列表，触控热区保持 $\ge 44\text{dp}$。

### 2. 智能 CUE 分轨与硬盘曲库扫描引擎
* **CUE 智能解析**：`lib/services/music_database_service.dart` 支持自动识别 GBK、UTF-8 编码的 `.cue` 文件。
* **防重复屏蔽**：自动提取 CUE 中各分轨（音轨号、曲名、艺术家、起止时间戳），并**自动屏蔽已被拆解的母带整轨音频文件（如 `CDImage.wav` / `CDImage.flac`）**，彻底避免曲库列表中出现重复大文件。
* **全盘递归检索**：支持自动扫描 `/media/pi/*`（外接移动硬盘/U盘）、`/mnt/*`、NVMe 固态硬盘分区及用户音乐目录。

### 3. ALSA 物理硬件声卡自适应与 DAC 控制
* **硬件动态探测**：`PiSystemService` 实时读取 Linux 底层 `/proc/asound/cards`，自适应抓取 I2S / USB 硬件声卡设备名及通道。
* **芯片滤波模型**：DAC 设置页自适应 Linux 环境，首选芯片自动显示为 **`ALSA 直通`**，支持 6 大发烧芯片架构（ES9038PRO、AK4499EX、CS43198、R-2R 纯电阻、ROHM 34301）与实时声卡拓扑切换。
* **Bit-Perfect 0 压缩直出**：
  * 本地音频引擎绝不强制降频（0 SRC），绝不动态压缩（0 DRC）。
  * 遇到 768kHz 超高采样率或 DSD 母带时，只要外接 DAC 硬件支持，直接通过 ALSA 源码输出。

### 4. 局域网服务中枢 (Web Remote & 无线传歌)
* **Web 远程遥控 (:8088)**：开机自动启动 HTTP / WebSocket 服务，支持手机/平板扫描局域网二维码或输入 IP 进行切歌、调音、音量控制。
* **WiFi 无线传歌 (:8080)**：浏览器直接拖拽上传无损音频文件（FLAC/WAV/DSF/DFF/CUE），服务端上传完成自动触发曲库重新索引。
* **Git 远程 OTA 升级**：集成在系统设置中，支持一键检测与更新。

---

## 三、 硬件搭配与接线拓扑指南

针对树莓派发烧台机组装与外接设备，最佳拓扑方案如下：

```
+-------------------------------------------------------------------------+
| [树莓派 5 主控台机]                                                      |
|   · 系统: Raspberry Pi OS Lite 64-bit (Cage Kiosk 无桌面 6秒秒启)       |
|   · 屏幕: 微雪 7 寸 QLED 电容屏 (1024×600, 15° 仰角 3D 打印外壳)        |
|   · 存储: NVMe M.2 固态 / USB 3.0 移动硬盘 (自动扫描挂载)                |
+-------------------------------------------------------------------------+
       |                                          |
       | (USB Audio Class 2.0 异步直通)           | (局域网 WiFi / 网线)
       v                                          v
+-------------------------------+       +---------------------------------+
| [外置 DAC / 功放一体机]        |       | [手机 / 平板 / 电脑 远程交互]    |
| 推荐: 飞傲 LEVEL 1 (地平线1号)|       |   · Web 遥控: http://pi:8088    |
|   · USB-C 输入: 接树莓派      |       |   · 无线传歌: http://pi:8080    |
|   · RCA 模拟输入: 接索尼老 CD |       +---------------------------------+
|   · 芯片: TPA3255 纯 D 类大推力|
|   · 喇叭输出: 镀金香蕉头接音箱 |
+-------------------------------+
       |
       v
+-------------------------------+
| [无源书架音箱]                |
| (彻底替代淘汰老旧笨重的山水功放)|
+-------------------------------+
```

---

## 四、 核心代码文件导航与速查

| 文件路径 | 模块作用与说明 |
| :--- | :--- |
| [`lib/ui/landscape/landscape_main_view.dart`](file:///Users/mk10/Desktop/hide_player_flutter/lib/ui/landscape/landscape_main_view.dart) | **统一横屏发烧主视窗入口**（Mac/iPad/树莓派公用入口） |
| [`lib/ui/pi/pi_main_view.dart`](file:///Users/mk10/Desktop/hide_player_flutter/lib/ui/pi/pi_main_view.dart) | 树莓派 7 寸专职视窗（自动联动 `PiSystemService` DAC 状态） |
| [`lib/ui/mac/mac_main_view.dart`](file:///Users/mk10/Desktop/hide_player_flutter/lib/ui/mac/mac_main_view.dart) | 全景 Master-Detail 架构实现（四角移出屏保动效、10个子视图调度） |
| [`lib/ui/mac/mac_sidebar_widget.dart`](file:///Users/mk10/Desktop/hide_player_flutter/lib/ui/mac/mac_sidebar_widget.dart) | 侧边栏导航、自定义歌单列表、ALSA/DAC 绿灯状态指示与温度角标 |
| [`lib/ui/mac/views/mac_dac_setting_view.dart`](file:///Users/mk10/Desktop/hide_player_flutter/lib/ui/mac/views/mac_dac_setting_view.dart) | DAC 设置页：ALSA 直通、Linux ALSA 硬件声卡实时拓扑与芯片滤波选择 |
| [`lib/services/pi_system_service.dart`](file:///Users/mk10/Desktop/hide_player_flutter/lib/services/pi_system_service.dart) | 树莓派系统服务：ALSA 声卡探测、SoC 核心温度监控、防烧屏超时 |
| [`lib/services/music_database_service.dart`](file:///Users/mk10/Desktop/hide_player_flutter/lib/services/music_database_service.dart) | SQLite 数据库、CUE 分轨解析、全盘/外接硬盘曲库索引 |
| [`lib/core/hifi_audio_service.dart`](file:///Users/mk10/Desktop/hide_player_flutter/lib/core/hifi_audio_service.dart) | 全局音频业务状态机、10段EQ调音控制、Bit-Perfect 0dB 调度 |
| [`native/audio_engine/src/AudioEngine.cpp`](file:///Users/mk10/Desktop/hide_player_flutter/native/audio_engine/src/AudioEngine.cpp) | C++20 发烧音频引擎：原生无锁环形缓冲、EOF 状态机、多格式解码 |
| [`native/audio_engine/src/sinks/AlsaAudioSink.cpp`](file:///Users/mk10/Desktop/hide_player_flutter/native/audio_engine/src/sinks/AlsaAudioSink.cpp) | Linux ALSA 硬件直通输出流实现 |
| [`scripts/setup_pi_lite.sh`](file:///Users/mk10/Desktop/hide_player_flutter/scripts/setup_pi_lite.sh) | 树莓派 OS Lite 自动部署脚本（Cage Kiosk、开机自启 systemd） |

---

## 五、 今晚接续开发建议任务 (To-Do List)

1. **如果在树莓派真机上**：
   - 运行 `bash scripts/setup_pi_lite.sh`，测试开机无桌面 Cage 自动拉起播放器；
   - 插入 USB 硬盘或外接声卡，在侧边栏查看声卡识别与实时温度；
   - 用手机连接同一 WiFi，打开 `http://<树莓派IP>:8088` 体验手机遥控切歌，打开 `:8080` 上传几首新歌。
2. **如果在个人电脑 (Mac / PC) 上继续开发**：
   - 在 `lib/ui/` 下可以继续微调主舞台各视图在 1024×600 紧凑视口下的字体字阶或触控反馈细节；
   - 构思与规划后续的手机端竖屏（iPhone / Android）交互形式；
   - 扩展更多自定义 EQ 预设或视觉表头模式。
