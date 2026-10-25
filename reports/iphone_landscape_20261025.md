# iPhone 横屏对齐与曲库修复验证

日期：2026-10-25（Asia/Shanghai）

基线：`dev/iphone` a1118d7；界面与功能参考 `dev/ipad` 03d4d8b。

## 完成内容

- 首帧展示横竖屏选择；方向仅在本次进程内保存，进入后没有切换入口，冷启动重新选择。
- 横屏工作台、侧栏、播放控制、DAC、EQ、音色、主题、全屏、扫描及网络服务对齐 iPad，并适配 iPhone 安全区与小屏滚动。
- 自建歌单支持创建、加入和移出曲目；重扫保持曲目 ID 与歌单关联。
- 删除内置演示曲目和音频资产。历史自动复制的 MP3 只有完整 SHA-256 匹配才清理；真实用户文件保留。
- WAV/CUE 使用实际文件头、CUE 帧边界与准确末轨结束时间，支持嵌套目录、UTF-16 和 APFS 文件名。
- 重扫串行执行并事务保存，失败保留原曲库；修复误删其他专辑 CUE、共享母带和 ID 重用问题。
- iOS 公共音乐目录统一为 App 的 Documents（文件 App 的“我的 iPhone / HiFi Player”）。WiFi 上传保留专辑目录，并防止覆盖数据库或逃逸目录。
- DAC 显示真实系统路由与协商速率；DX1 II 采样偏好由 iOS 请求并读回验证。音色通过明确标注的 10 段 DSP 映射叠加 EQ，分别保留设置。
- 硬件看板只显示系统可读取的内存、核心数、存储、热状态及电池信息；不再随机模拟指标，也不把系统 PCM 混音标成已验证 BitPerfect。
- Web 遥控真正触发扫描，报告成功或失败；DAC 广播不再递归刷新。

## 验证

- `flutter test --no-pub --reporter expanded`：120 项全部通过，包括 13 张界面 golden。
- `flutter analyze`：No issues found。
- `git diff --check`：通过。
- `flutter build ios --simulator --debug --no-codesign`：通过。
- `flutter build ios --release --no-codesign`：通过，生成 `build/ios/iphoneos/Runner.app`。
- 三种布局尺寸 667×375、844×390、932×430，包含安全区的全部功能页面与硬件主题均通过布局验证。
- 实际运行 iPad Pro 11-inch (M5) 与 iPhone 17 Pro 的 iOS 26.5 模拟器进行对照。
- 模拟器经 WiFi 上传两个包含同名 CDImage.wav 的独立专辑及 CUE，正确生成 4 首分轨并保留目录；第二轨实际播放时长 6.5 秒，暂停与停止正常。
- 模拟器 WebSocket 确认 DAC 真状态、远程重扫成功且 ID 不变、音色参数同步。强制结束后重启重新出现方向选择。
- 验证专用音频已从模拟器移除，重新扫描后为空库。

## 边界

UI 复核：配色、字号配置、玻璃卡片、背景、共享业务页面与原有可视化沿用 iPad；全屏退出按钮已统一为 iPad 的深色玻璃样式。iPhone 保留 160/180 点侧栏、紧凑播放栏、安全区与小屏滚动适配，因此不宣称逐像素原样复制；硬件看板按真实 iPhone 可读取数据调整。

竖屏保留现有布局，仅移除切换方向入口与虚构数据。USB DAC 插拔、真实设备采样率协商及后台音频中断仍需物理 iPhone / DAC 验证；模拟器不具备相同的外设链路。Release 产物为未签名构建。

未修改或推送 `dev/audio_engine`，引擎仍锁定 f176d6291a1c1fc4f743fcf673195bc56a00ef99；其他平台分支未改动。
