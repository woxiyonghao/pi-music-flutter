/// 内嵌全功能 Web 遥控中心 SPA 单页应用 (来自 C++ WebService.cpp 1:1 原生实现)
const String webRemoteHtml = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="theme-color" content="#090d14">
<title>PiHiFi 发烧纯音远程中枢</title>
<style>
:root {
  --bg-color: #090d14;
  --card-bg: rgba(22, 30, 46, 0.72);
  --card-border: rgba(255, 255, 255, 0.09);
  --accent: #10b981;
  --accent-glow: rgba(16, 185, 129, 0.35);
  --text-active: #ffffff;
  --text-normal: #cbd5e1;
  --text-muted: #64748b;
  --progress-bg: #1e293b;
  --danger: #ef4444;
}
* { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Microsoft YaHei", sans-serif; -webkit-tap-highlight-color: transparent; }
body {
  background: var(--bg-color);
  color: var(--text-normal);
  min-height: 100vh;
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 16px 14px max(34px, env(safe-area-inset-bottom));
  background-image: radial-gradient(circle at 50% 10%, rgba(16, 185, 129, 0.10), transparent 55%);
}
.container { width: 100%; max-width: 760px; margin: 0 auto; box-sizing: border-box; }

/* 头部与状态 */
.header { text-align: center; margin-bottom: 14px; }
.header h1 { font-size: 20px; font-weight: 700; color: var(--text-active); letter-spacing: 0.5px; margin-bottom: 4px; }
.badge { display: inline-flex; align-items: center; gap: 6px; padding: 3px 12px; background: rgba(16, 185, 129, 0.12); border: 1px solid var(--accent); border-radius: 20px; color: var(--accent); font-size: 11px; font-weight: 600; }
.badge-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--accent); box-shadow: 0 0 8px var(--accent); }
.badge.disconnected { background: rgba(239, 68, 68, 0.12); border-color: var(--danger); color: var(--danger); }
.badge.disconnected .badge-dot { background: var(--danger); box-shadow: 0 0 8px var(--danger); }

/* 顶部分段导航栏 (6 大核心功能) */
.nav-tabs {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  background: rgba(15, 23, 42, 0.7);
  border: 1px solid var(--card-border);
  border-radius: 12px;
  padding: 4px;
  margin-bottom: 16px;
  gap: 4px;
  backdrop-filter: blur(16px);
}
.nav-tab {
  text-align: center;
  padding: 8px 2px;
  font-size: 11px;
  font-weight: 600;
  border-radius: 8px;
  cursor: pointer;
  color: var(--text-muted);
  transition: all 0.2s ease;
  user-select: none;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.nav-tab.active {
  background: var(--accent);
  color: #0c1017;
  box-shadow: 0 2px 10px var(--accent-glow);
}

.tab-pane { display: none; }
.tab-pane.active { display: block; }

/* 通用毛玻璃卡片 */
.card {
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: 18px;
  padding: 20px 16px;
  box-shadow: 0 10px 32px rgba(0, 0, 0, 0.45);
  backdrop-filter: blur(20px);
  margin-bottom: 14px;
  box-sizing: border-box;
  overflow: hidden;
}

/* 子切换药丸按钮 */
.sub-switcher {
  display: flex;
  background: rgba(15, 23, 42, 0.6);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 10px;
  padding: 3px;
  margin-bottom: 16px;
  gap: 4px;
}
.sub-pill {
  flex: 1;
  text-align: center;
  padding: 6px 4px;
  font-size: 12px;
  font-weight: 600;
  border-radius: 7px;
  color: var(--text-muted);
  cursor: pointer;
  transition: all 0.2s;
  user-select: none;
}
.sub-pill.active {
  background: rgba(16, 185, 129, 0.18);
  color: var(--accent);
  border: 1px solid rgba(16, 185, 129, 0.4);
}

/* ================== Tab 1: 播放面板 ================== */
.disc-wrapper { display: flex; justify-content: center; align-items: center; margin: 4px 0 16px; }
.vinyl-disc {
  width: 140px;
  height: 140px;
  border-radius: 50%;
  background: radial-gradient(circle, #2a3344 0%, #151b26 30%, #080b10 70%, #151b26 100%);
  border: 3px solid rgba(255, 255, 255, 0.1);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.65), inset 0 0 15px rgba(0,0,0,0.8);
  display: flex;
  justify-content: center;
  align-items: center;
  position: relative;
  animation: spin 16s linear infinite;
  animation-play-state: paused;
}
.vinyl-disc.playing { animation-play-state: running; }
.vinyl-center {
  width: 46px;
  height: 46px;
  border-radius: 50%;
  background: var(--accent);
  border: 2px solid #ffffff;
  display: flex;
  justify-content: center;
  align-items: center;
  color: #0c1017;
  font-size: 18px;
  box-shadow: 0 0 12px var(--accent-glow);
}
@keyframes spin { 100% { transform: rotate(360deg); } }

.track-info { text-align: center; margin-bottom: 14px; }
.track-title { font-size: 18px; font-weight: 700; color: var(--text-active); margin-bottom: 4px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.track-artist { font-size: 13px; color: var(--text-muted); margin-bottom: 8px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.format-badge { display: inline-block; padding: 2px 10px; background: rgba(255, 255, 255, 0.08); border-radius: 12px; font-size: 11px; color: var(--accent); border: 1px solid rgba(16, 185, 129, 0.3); }

/* 12 频段实时动态 LED 频谱条 */
.spectrum-wrap {
  display: flex;
  justify-content: center;
  align-items: flex-end;
  gap: 5px;
  height: 38px;
  margin: 10px 0 16px;
  padding: 0 20px;
}
.spec-bar {
  flex: 1;
  max-width: 14px;
  height: 4px;
  background: linear-gradient(to top, var(--accent), #34d399);
  border-radius: 3px 3px 1px 1px;
  transition: height 0.12s ease-out;
  box-shadow: 0 0 6px var(--accent-glow);
}

.progress-container { margin-bottom: 18px; }
.progress-bar-wrap { position: relative; width: 100%; height: 8px; background: var(--progress-bg); border-radius: 4px; cursor: pointer; touch-action: none; }
.progress-fill { height: 100%; width: 0%; background: var(--accent); border-radius: 4px; box-shadow: 0 0 10px var(--accent-glow); transition: width 0.08s linear; pointer-events: none; }
.time-labels { display: flex; justify-content: space-between; font-size: 12px; color: var(--text-muted); margin-top: 6px; }

.controls { display: flex; justify-content: center; align-items: center; gap: 16px; margin-bottom: 18px; }
.btn-icon { background: transparent; border: none; color: var(--text-normal); font-size: 20px; cursor: pointer; width: 42px; height: 42px; border-radius: 50%; display: flex; align-items: center; justify-content: center; transition: all 0.2s; }
.btn-icon:hover { background: rgba(255, 255, 255, 0.08); color: var(--text-active); }
.btn-play { width: 56px; height: 56px; background: var(--accent); color: #0c1017; font-size: 24px; border-radius: 50%; box-shadow: 0 4px 18px var(--accent-glow); }
.btn-play:hover { filter: brightness(1.1); transform: scale(1.04); }

.volume-wrap { display: flex; align-items: center; gap: 12px; padding: 0 6px; }
.vol-slider { flex: 1; -webkit-appearance: none; appearance: none; height: 6px; background: var(--progress-bg); border-radius: 3px; outline: none; }
.vol-slider::-webkit-slider-thumb { -webkit-appearance: none; appearance: none; width: 18px; height: 18px; border-radius: 50%; background: var(--accent); cursor: pointer; box-shadow: 0 0 8px var(--accent-glow); }
.vol-slider::-moz-range-thumb { width: 18px; height: 18px; border-radius: 50%; background: var(--accent); cursor: pointer; border: none; }

/* ================== Tab 2: 播放列表与歌单 ================== */
.queue-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; }
.queue-title { font-size: 14px; font-weight: 700; color: var(--text-active); }
.song-list { display: flex; flex-direction: column; gap: 6px; max-height: 480px; overflow-y: auto; padding-right: 2px; }
.song-item { display: flex; justify-content: space-between; align-items: center; padding: 10px 12px; border-radius: 10px; background: rgba(15, 23, 42, 0.5); border: 1px solid rgba(255, 255, 255, 0.05); cursor: pointer; transition: all 0.2s; }
.song-item:hover { background: rgba(16, 185, 129, 0.08); border-color: rgba(16, 185, 129, 0.25); }
.song-item.active { background: rgba(16, 185, 129, 0.15); border-color: var(--accent); color: var(--accent); }
.song-left { display: flex; align-items: center; gap: 10px; flex: 1; min-width: 0; }
.song-idx { font-size: 12px; font-weight: 700; color: var(--text-muted); width: 22px; text-align: center; }
.song-item.active .song-idx { color: var(--accent); }
.song-main { flex: 1; min-width: 0; }
.song-title { font-size: 13px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.song-sub { font-size: 11px; color: var(--text-muted); margin-top: 2px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.song-actions { display: flex; align-items: center; gap: 8px; }
.song-meta { font-size: 11px; color: var(--text-muted); text-align: right; white-space: nowrap; }
.btn-del { background: transparent; border: none; color: var(--text-muted); cursor: pointer; font-size: 14px; padding: 4px; border-radius: 4px; transition: color 0.2s; }
.btn-del:hover { color: var(--danger); }

/* 歌单网格卡片 */
.playlists-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 10px; margin-top: 8px; }
.playlist-card { background: rgba(15, 23, 42, 0.55); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 12px; padding: 12px; display: flex; flex-direction: column; justify-content: space-between; transition: all 0.2s; }
.playlist-card:hover { border-color: var(--accent); transform: translateY(-2px); }
.playlist-header { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }
.playlist-name { font-size: 13px; font-weight: 700; color: var(--text-active); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.playlist-count { font-size: 11px; color: var(--text-muted); margin-bottom: 10px; }
.playlist-btns { display: flex; gap: 6px; }

/* ================== Tab 3: 曲库与搜索 ================== */
.lib-header { display: flex; gap: 10px; margin-bottom: 12px; }
.lib-search { flex: 1; background: rgba(15, 23, 42, 0.7); border: 1px solid var(--card-border); border-radius: 10px; padding: 8px 12px; color: var(--text-active); font-size: 13px; outline: none; }
.lib-search:focus { border-color: var(--accent); }
.btn-sm { padding: 8px 14px; border-radius: 10px; border: 1px solid rgba(255, 255, 255, 0.12); background: rgba(255, 255, 255, 0.05); color: var(--text-active); font-size: 12px; font-weight: 600; cursor: pointer; white-space: nowrap; transition: all 0.2s; }
.btn-sm:hover { background: rgba(16, 185, 129, 0.15); border-color: var(--accent); color: var(--accent); }
.btn-sm.primary { background: var(--accent); color: #0c1017; border-color: var(--accent); }

/* ================== Tab 4: 调音 (EQ + 魔棒) ================== */
.eq-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; }
.eq-switch-wrap { display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 600; color: var(--text-active); }
.switch { position: relative; display: inline-block; width: 44px; height: 24px; }
.switch input { opacity: 0; width: 0; height: 0; }
.slider-toggle { position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: #334155; transition: .3s; border-radius: 24px; }
.slider-toggle:before { position: absolute; content: ""; height: 18px; width: 18px; left: 3px; bottom: 3px; background-color: white; transition: .3s; border-radius: 50%; }
input:checked + .slider-toggle { background-color: var(--accent); }
input:checked + .slider-toggle:before { transform: translateX(20px); }

.presets-scroll { display: flex; gap: 6px; overflow-x: auto; padding-bottom: 8px; margin-bottom: 14px; -webkit-overflow-scrolling: touch; scrollbar-width: none; }
.presets-scroll::-webkit-scrollbar { display: none; }
.preset-chip { padding: 6px 12px; background: rgba(255, 255, 255, 0.06); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 16px; font-size: 12px; white-space: nowrap; cursor: pointer; transition: all 0.2s; color: var(--text-normal); }
.preset-chip.active, .preset-chip:hover { background: rgba(16, 185, 129, 0.15); border-color: var(--accent); color: var(--accent); }

/* 10 段垂直滑动推子 (完美限制在父容器内，杜绝溢出) */
.eq-scroll-container { width: 100%; overflow-x: auto; -webkit-overflow-scrolling: touch; scrollbar-width: thin; padding-bottom: 4px; box-sizing: border-box; }
.eq-sliders-grid {
  display: grid;
  grid-template-columns: repeat(10, minmax(36px, 1fr));
  gap: 4px;
  width: 100%;
  box-sizing: border-box;
  padding: 10px 0;
  align-items: center;
  justify-items: center;
}
.eq-col {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  height: 180px;
  box-sizing: border-box;
}
.eq-vslider-wrap {
  height: 120px;
  width: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
}
.eq-vslider {
  writing-mode: vertical-lr;
  direction: rtl;
  -webkit-appearance: slider-vertical;
  appearance: slider-vertical;
  width: 24px;
  height: 120px;
  padding: 0;
  margin: 0;
  accent-color: var(--accent);
  cursor: pointer;
}
.eq-gain-lbl { font-size: 11px; color: var(--accent); font-weight: 600; min-height: 16px; line-height: 16px; }
.eq-freq-lbl { font-size: 11px; color: var(--text-muted); font-weight: 500; min-height: 16px; line-height: 16px; }

/* MSEB 调音魔棒界面 */
.mseb-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 10px;
  margin-top: 12px;
}
.mseb-card {
  background: rgba(15, 23, 42, 0.55);
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: 12px;
  padding: 10px 14px;
}
.mseb-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 6px;
}
.mseb-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-active);
}
.mseb-val {
  font-size: 12px;
  font-weight: 700;
  color: var(--accent);
}
.mseb-slider-row {
  display: flex;
  align-items: center;
  gap: 8px;
}
.mseb-lbl-l, .mseb-lbl-r {
  font-size: 10px;
  color: var(--text-muted);
  white-space: nowrap;
  width: 48px;
}
.mseb-lbl-l { text-align: right; }
.mseb-lbl-r { text-align: left; }
.mseb-slider {
  flex: 1;
  -webkit-appearance: none;
  appearance: none;
  height: 6px;
  background: var(--progress-bg);
  border-radius: 3px;
  outline: none;
}
.mseb-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: var(--accent);
  cursor: pointer;
  box-shadow: 0 0 6px var(--accent-glow);
}

/* ================== Tab 5: DAC 硬件与解码模式 ================== */
.dac-hw-banner {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  background: rgba(15, 23, 42, 0.65);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  margin-bottom: 16px;
}
.dac-hw-icon { font-size: 24px; color: var(--accent); }
.dac-hw-info { flex: 1; min-width: 0; }
.dac-hw-name { font-size: 14px; font-weight: 700; color: var(--text-active); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.dac-hw-desc { font-size: 11px; color: var(--text-muted); margin-top: 2px; }

.dac-devices-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 8px;
}
.dac-device-card {
  padding: 12px;
  border-radius: 10px;
  background: rgba(15, 23, 42, 0.5);
  border: 1px solid rgba(255, 255, 255, 0.07);
}
.dac-device-card.active {
  background: rgba(16, 185, 129, 0.15);
  border-color: var(--accent);
}
.dac-device-name { font-size: 12px; font-weight: 700; overflow-wrap: anywhere; }
.dac-device-details { font-size: 11px; color: var(--text-muted); margin-top: 4px; }
.dac-device-card.active .dac-device-name { color: var(--accent); }

/* ================== Tab 6: 视觉与系统设定 ================== */
.section-title { font-size: 13px; font-weight: 700; color: var(--text-active); margin-bottom: 10px; }
.grid-2col { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 16px; }
.theme-card { padding: 10px; border-radius: 10px; background: rgba(15, 23, 42, 0.5); border: 1px solid rgba(255, 255, 255, 0.06); cursor: pointer; display: flex; align-items: center; gap: 8px; transition: all 0.2s; }
.theme-card:hover { border-color: var(--accent); }
.theme-card.active { background: rgba(16, 185, 129, 0.15); border-color: var(--accent); color: var(--accent); }
.theme-dot { width: 12px; height: 12px; border-radius: 50%; flex-shrink: 0; }
.theme-name { font-size: 12px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

.settings-row { display: flex; justify-content: space-between; align-items: center; padding: 12px 0; border-bottom: 1px solid rgba(255, 255, 255, 0.05); }
.settings-row:last-child { border-bottom: none; }
.settings-lbl { font-size: 13px; color: var(--text-active); }
.settings-sub { font-size: 11px; color: var(--text-muted); margin-top: 2px; }
.timer-btns { display: flex; gap: 6px; }
.timer-btn { padding: 4px 10px; border-radius: 8px; background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.1); font-size: 11px; color: var(--text-normal); cursor: pointer; }
.timer-btn.active { background: var(--accent); color: #0c1017; border-color: var(--accent); font-weight: 700; }

/* 模态弹窗 */
.modal-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.7); backdrop-filter: blur(8px); display: none; align-items: center; justify-content: center; z-index: 999; }
.modal-overlay.active { display: flex; }
.modal-box { background: var(--bg-color); border: 1px solid var(--card-border); border-radius: 16px; padding: 20px; width: 90%; max-width: 360px; box-shadow: 0 10px 40px rgba(0,0,0,0.8); }
.modal-title { font-size: 15px; font-weight: 700; color: var(--text-active); margin-bottom: 12px; }
.modal-input { width: 100%; background: rgba(15, 23, 42, 0.8); border: 1px solid var(--card-border); border-radius: 8px; padding: 10px; color: var(--text-active); font-size: 13px; margin-bottom: 16px; outline: none; }
.modal-btns { display: flex; justify-content: flex-end; gap: 8px; }
</style>
</head>
<body>

<div class="container">
  <!-- 头部信息 -->
  <div class="header">
    <h1>PiHiFi 发烧纯音远程中枢</h1>
    <div class="badge disconnected" id="connStatus">
      <div class="badge-dot"></div>
      <span id="connText">正在连接数播 WebSocket...</span>
    </div>
  </div>

  <!-- 顶部分段导航 (6 大功能模块) -->
  <div class="nav-tabs">
    <div class="nav-tab active" data-tab="tabPlayer">♪ 播放</div>
    <div class="nav-tab" data-tab="tabQueue">≡ 列表</div>
    <div class="nav-tab" data-tab="tabLib">📁 曲库</div>
    <div class="nav-tab" data-tab="tabEQ">🎚 调音</div>
    <div class="nav-tab" data-tab="tabDAC">⚡ DAC</div>
    <div class="nav-tab" data-tab="tabSettings">⚙ 设置</div>
  </div>

  <!-- ==================== Tab 1: 正在播放 ==================== -->
  <div class="tab-pane active" id="tabPlayer">
    <div class="card">
      <div class="disc-wrapper">
        <div class="vinyl-disc" id="vinylDisc">
          <div class="vinyl-center">&#9835;</div>
        </div>
      </div>

      <div class="track-info">
        <div class="track-title" id="trackTitle">暂未载入曲目</div>
        <div class="track-artist" id="trackArtist">未知艺术家</div>
        <div class="format-badge" id="formatBadge">Hi-Res 直通</div>
      </div>

      <!-- 12 频段实时 LED 动态跳动频谱 -->
      <div class="spectrum-wrap" id="spectrumBar">
        <div class="spec-bar"></div><div class="spec-bar"></div><div class="spec-bar"></div>
        <div class="spec-bar"></div><div class="spec-bar"></div><div class="spec-bar"></div>
        <div class="spec-bar"></div><div class="spec-bar"></div><div class="spec-bar"></div>
        <div class="spec-bar"></div><div class="spec-bar"></div><div class="spec-bar"></div>
      </div>

      <!-- 时间轴进度条 -->
      <div class="progress-container">
        <div class="progress-bar-wrap" id="progressBar">
          <div class="progress-fill" id="progressFill"></div>
        </div>
        <div class="time-labels">
          <span id="timeCurrent">00:00</span>
          <span id="timeTotal">00:00</span>
        </div>
      </div>

      <!-- 核心播放控制 -->
      <div class="controls">
        <button class="btn-icon" id="btnMode" title="循环模式">&#10227;</button>
        <button class="btn-icon" id="btnPrev" title="上一曲">&#9198;</button>
        <button class="btn-icon btn-play" id="btnPlay" title="播放/暂停">&#9654;</button>
        <button class="btn-icon" id="btnNext" title="下一曲">&#9197;</button>
        <button class="btn-icon" id="btnMute" title="静音">&#128266;</button>
      </div>

      <!-- 硬件音量旋钮控制 -->
      <div class="volume-wrap">
        <span style="font-size: 14px; color: var(--text-muted);">&#128265;</span>
        <input type="range" class="vol-slider" id="volSlider" min="0" max="100" value="80">
        <span id="volLabel" style="font-size: 12px; color: var(--text-muted); min-width: 32px;">80%</span>
      </div>
    </div>
  </div>

  <!-- ==================== Tab 2: 播放列表与歌单 ==================== -->
  <div class="tab-pane" id="tabQueue">
    <div class="card">
      <div class="sub-switcher">
        <div class="sub-pill active" id="pillQueue">正在播放队列 (<span id="qCountBadge">0</span>)</div>
        <div class="sub-pill" id="pillPlaylists">发烧歌单 (<span id="plCountBadge">0</span>)</div>
      </div>

      <!-- 正在播放队列子面板 -->
      <div id="paneQueueList">
        <div class="queue-header">
          <div class="queue-title">播放队列 · 共 <span id="qTotal">0</span> 首</div>
          <button class="btn-sm" id="btnClearQueue">清空队列</button>
        </div>
        <div class="song-list" id="queueList">
          <div style="text-align: center; color: var(--text-muted); padding: 30px 0; font-size: 13px;">队列为空</div>
        </div>
      </div>

      <!-- 发烧歌单子面板 -->
      <div id="panePlaylistsList" style="display: none;">
        <div class="queue-header">
          <div class="queue-title">我的歌单 · 共 <span id="plTotal">0</span> 个</div>
          <button class="btn-sm primary" id="btnOpenCreatePlModal">＋ 新建歌单</button>
        </div>
        <div class="playlists-grid" id="playlistsGrid">
          <!-- 动态渲染歌单卡片 -->
        </div>
      </div>
    </div>
  </div>

  <!-- ==================== Tab 3: 本地曲库与搜索 ==================== -->
  <div class="tab-pane" id="tabLib">
    <div class="card">
      <div class="lib-header">
        <input type="text" class="lib-search" id="libSearchInput" placeholder="搜索歌曲、艺术家或专辑...">
        <button class="btn-sm primary" id="btnScanMusic">&#8635; 扫描曲库</button>
      </div>
      <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 10px;">全部本地扫描曲目 · 共 <span id="libTotal">0</span> 首</div>
      <div class="song-list" id="libSongList">
        <div style="text-align: center; color: var(--text-muted); padding: 30px 0; font-size: 13px;">正在载入曲库...</div>
      </div>
    </div>
  </div>

  <!-- ==================== Tab 4: 调音 (EQ + 魔棒) ==================== -->
  <div class="tab-pane" id="tabEQ">
    <div class="card">
      <div class="sub-switcher">
        <div class="sub-pill active" id="pillEq">10段专业图形EQ</div>
        <div class="sub-pill" id="pillMseb">🪄 调音魔棒 (MSEB)</div>
      </div>

      <!-- 10段图形EQ子面板 -->
      <div id="paneEq">
        <div class="eq-header">
          <div class="eq-switch-wrap">
            <span>图形EQ开关</span>
            <label class="switch">
              <input type="checkbox" id="eqToggle" checked>
              <span class="slider-toggle"></span>
            </label>
          </div>
          <button class="btn-sm" id="btnResetEq">一键归零</button>
        </div>

        <div class="presets-scroll" id="eqPresetsList">
          <div class="preset-chip active" data-preset="flat">原音直通</div>
          <div class="preset-chip" data-preset="pop">流行音乐</div>
          <div class="preset-chip" data-preset="rock">摇滚现场</div>
          <div class="preset-chip" data-preset="vocal">经典人声</div>
          <div class="preset-chip" data-preset="classic">古典交响</div>
          <div class="preset-chip" data-preset="bass">震撼低音</div>
          <div class="preset-chip" data-preset="treble">通透高音</div>
        </div>

        <!-- 10 频段垂直滑块容器 (带滚动与绝对防溢出) -->
        <div class="eq-scroll-container">
          <div class="eq-sliders-grid" id="eqSliders">
            <!-- 由 JS 渲染 10 列推子 (31Hz ~ 16kHz) -->
          </div>
        </div>
      </div>

      <!-- MSEB 调音魔棒子面板 -->
      <div id="paneMseb" style="display: none;">
        <div class="eq-header">
          <div class="eq-switch-wrap">
            <span>魔棒调音</span>
            <label class="switch">
              <input type="checkbox" id="msebToggle" checked>
              <span class="slider-toggle"></span>
            </label>
          </div>
          <button class="btn-sm" id="btnResetMseb">全部归零</button>
        </div>
        <div style="font-size: 11px; color: var(--text-muted); margin-bottom: 8px;">心理声学主观听感微调 · 实时映射高精度双二阶滤波器</div>
        <div class="mseb-grid" id="msebGrid">
          <!-- 由 JS 动态渲染 10 个听感滑块 -->
        </div>
      </div>
    </div>
  </div>

  <!-- ==================== Tab 5: DAC 硬件与解码模式 ==================== -->
  <div class="tab-pane" id="tabDAC">
    <div class="card">
      <!-- 物理硬件连接状态卡片 -->
      <!-- 物理硬件连接状态卡片 -->
      <div class="dac-hw-banner">
        <div class="dac-hw-icon" id="dacStatusIcon">&#9889;</div>
        <div class="dac-hw-info">
          <div class="dac-hw-name" id="dacDeviceName">物理 DAC 检测中...</div>
          <div class="dac-hw-desc" id="dacDeviceDesc">正在读取实际音频设备…</div>
        </div>
      </div>

      <div id="dacDevicesSection" hidden>
        <div class="section-title">已连接的音频设备</div>
        <div class="dac-devices-grid" id="dacDevicesGrid"></div>
      </div>
    </div>
  </div>

  <!-- ==================== Tab 6: 视觉主题与系统设定 ==================== -->
  <div class="tab-pane" id="tabSettings">
    <div class="card">
      <div class="section-title">机身名机皇主题配色 (9 款经典)</div>
      <div class="grid-2col" id="themesGrid">
        <div class="theme-card active" data-theme="0"><div class="theme-dot" style="background:#FA2D48;"></div><div class="theme-name">现代深空玫红</div></div>
        <div class="theme-card" data-theme="1"><div class="theme-dot" style="background:#00B4D8;"></div><div class="theme-name">麦景图湖蓝</div></div>
        <div class="theme-card" data-theme="2"><div class="theme-dot" style="background:#E2C792;"></div><div class="theme-name">金嗓子香槟金</div></div>
        <div class="theme-card" data-theme="3"><div class="theme-dot" style="background:#F59E0B;"></div><div class="theme-name">复古琥珀卡座</div></div>
        <div class="theme-card" data-theme="5"><div class="theme-dot" style="background:#10B981;"></div><div class="theme-name">马兰士翡翠绿</div></div>
        <div class="theme-card" data-theme="6"><div class="theme-dot" style="background:#94A3B8;"></div><div class="theme-name">柏林之声冷银</div></div>
        <div class="theme-card" data-theme="7"><div class="theme-dot" style="background:#22C55E;"></div><div class="theme-name">英国名暗夜翠</div></div>
        <div class="theme-card" data-theme="8"><div class="theme-dot" style="background:#EF4444;"></div><div class="theme-name">马克莱文森赤晶</div></div>
        <div class="theme-card" data-theme="9"><div class="theme-dot" style="background:#00E5FF;"></div><div class="theme-name">iPad 硬件大师</div></div>
      </div>

      <div class="section-title">数播大屏全景动效模式 (12 种)</div>
      <div class="grid-2col" id="visualsGrid">
        <div class="theme-card active" data-vmode="2"><div class="theme-name">金嗓子精密大表头</div></div>
        <div class="theme-card" data-vmode="1"><div class="theme-name">麦景图动圈双表头</div></div>
        <div class="theme-card" data-vmode="0"><div class="theme-name">48列全景LED频谱</div></div>
        <div class="theme-card" data-vmode="3"><div class="theme-name">复古开盘磁带机</div></div>
        <div class="theme-card" data-vmode="4"><div class="theme-name">Siri流光正弦波</div></div>
        <div class="theme-card" data-vmode="5"><div class="theme-name">Siri悬浮微光光球</div></div>
        <div class="theme-card" data-vmode="6"><div class="theme-name">音乐共鸣升腾气泡</div></div>
        <div class="theme-card" data-vmode="8"><div class="theme-name">电光霓虹脉冲波</div></div>
        <div class="theme-card" data-vmode="9"><div class="theme-name">赛博3D粒子网格</div></div>
        <div class="theme-card" data-vmode="10"><div class="theme-name">液态StandBy时钟</div></div>
        <div class="theme-card" data-vmode="7"><div class="theme-name">纯净暗黑省电模式</div></div>
        <div class="theme-card" data-vmode="11"><div class="theme-name">iPad 硬件大师大屏</div></div>
      </div>

      <div class="section-title">发烧级输出与睡眠定时</div>
      <div class="settings-row">
        <div>
          <div class="settings-lbl">切歌平滑淡入淡出</div>
          <div class="settings-sub">Hann 窗口无缝音频插值防爆音</div>
        </div>
        <input type="range" id="fadeSlider" min="0" max="2" step="0.1" value="0.5" style="width: 100px;">
      </div>
      <div class="settings-row">
        <div>
          <div class="settings-lbl">睡眠定时关机</div>
          <div class="settings-sub" id="sleepTimerStatus">未开启睡眠定时</div>
        </div>
        <div class="timer-btns">
          <button class="timer-btn" data-min="15">15分</button>
          <button class="timer-btn" data-min="30">30分</button>
          <button class="timer-btn" data-min="60">60分</button>
          <button class="timer-btn active" data-min="0">关闭</button>
        </div>
      </div>
      <div class="settings-row">
        <div>
          <div class="settings-lbl">Bit-Perfect 源码输出</div>
          <div class="settings-sub">100% 原始数据无衰减硬件直通</div>
        </div>
        <span class="badge" id="bitPerfectBadge">生效中</span>
      </div>
      <div class="settings-row">
        <div>
          <div class="settings-lbl">WiFi 网页无线传歌</div>
          <div class="settings-sub">打开同机 8080 端口上传音乐</div>
        </div>
        <a id="btnWifiUploadLink" href="#" target="_blank" class="btn-sm" style="text-decoration:none; display:inline-block;">打开传歌页面 &rarr;</a>
      </div>
    </div>
  </div>
</div>

<!-- 新建歌单模态框 -->
<div class="modal-overlay" id="createPlModal">
  <div class="modal-box">
    <div class="modal-title">新建发烧自定义歌单</div>
    <input type="text" class="modal-input" id="newPlNameInput" placeholder="输入歌单名称 (例如: 深夜人声)..." maxlength="32">
    <div class="modal-btns">
      <button class="btn-sm" id="btnCancelCreatePl">取消</button>
      <button class="btn-sm primary" id="btnConfirmCreatePl">立即创建</button>
    </div>
  </div>
</div>

<script>
// ==================== 全局状态与 WebSocket 引擎 ====================
let ws = null;
let isSeeking = false;
let currentDuration = 0;
let queueData = [];
let playlistsData = [];
let libraryData = [];
let dacConfigData = null;
let activeDacChip = 0;

// MSEB 参数定义
const msebDefs = [
  { name: "声音冷暖", left: "偏冷通透", right: "偏暖醇厚" },
  { name: "低音下潜", left: "紧致轻盈", right: "深沉澎湃" },
  { name: "低音质感", left: "速度迅捷", right: "蓬松弹性" },
  { name: "音符厚度", left: "纤细轻盈", right: "扎实饱满" },
  { name: "人声位置", left: "舞台后缩", right: "贴耳靠前" },
  { name: "女声甜度", left: "自然平直", right: "润泽甜美" },
  { name: "齿音消除", left: "柔化去刺", right: "原生锋芒" },
  { name: "冲激响应", left: "柔和松弛", right: "硬朗凌厉" },
  { name: "空气感",   left: "凝聚内敛", right: "空灵弥漫" },
  { name: "声场重塑", left: "紧凑聚焦", right: "宏大宽广" }
];

// 10 频段 EQ 定义
const eqFreqs = ['31Hz','62Hz','125Hz','250Hz','500Hz','1kHz','2kHz','4kHz','8kHz','16kHz'];
const eqPresets = {
  flat:    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  pop:     [1.5, 2.0, 1.0, 0, -1.0, -1.0, 0.5, 1.5, 2.5, 3.0],
  rock:    [4.0, 3.0, 1.5, 0, -1.0, -0.5, 1.5, 3.0, 4.0, 4.5],
  vocal:   [-1.5, -1.0, 0, 1.5, 3.0, 3.5, 2.5, 1.0, 0, -0.5],
  classic: [3.5, 2.5, 1.5, 0.5, 0, 0, 1.0, 2.0, 3.0, 3.5],
  bass:    [6.0, 5.0, 3.5, 2.0, 1.0, 0, 0, 0, 0, 0],
  treble:  [-1.0, -0.5, 0, 0, 0.5, 1.0, 2.5, 4.0, 5.5, 6.0]
};

// 格式化秒数为 mm:ss
function formatTime(sec) {
  if (isNaN(sec) || sec < 0) return "00:00";
  let m = Math.floor(sec / 60);
  let s = Math.floor(sec % 60);
  return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
}

// 建立 WebSocket 连接
function initWebSocket() {
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const wsUrl = protocol + '//' + window.location.host;
  
  ws = new WebSocket(wsUrl);

  ws.onopen = () => {
    document.getElementById('connStatus').className = 'badge';
    document.getElementById('connText').textContent = 'WebSocket 毫秒级同步在线';
  };

  ws.onclose = () => {
    document.getElementById('connStatus').className = 'badge disconnected';
    document.getElementById('connText').textContent = '未连接数播 (请确保数播端“Web服务”已开启)';
    setTimeout(initWebSocket, 2000);
  };

  ws.onerror = () => {
    document.getElementById('connStatus').className = 'badge disconnected';
  };

  ws.onmessage = (e) => {
    try {
      const data = JSON.parse(e.data);
      if (data.type === 'state') updateState(data);
      else if (data.type === 'queue') updateQueue(data);
      else if (data.type === 'playlists') updatePlaylists(data);
      else if (data.type === 'library') updateLibrary(data);
      else if (data.type === 'dac') updateDac(data);
      else if (data.type === 'mseb') updateMseb(data);
    } catch (err) {
      console.error("WS Parse err:", err);
    }
  };
}

function sendAction(msg) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(msg));
  }
}

// ==================== 状态更新与渲染 ====================
function updateState(s) {
  document.getElementById('trackTitle').textContent = s.title || '暂未载入曲目';
  document.getElementById('trackArtist').textContent = s.artist || '未知艺术家';
  document.getElementById('formatBadge').textContent = s.specs || 'Hi-Res 直通';

  const disc = document.getElementById('vinylDisc');
  const btnPlay = document.getElementById('btnPlay');
  if (s.is_playing) {
    disc.classList.add('playing');
    btnPlay.innerHTML = '&#10074;&#10074;';
  } else {
    disc.classList.remove('playing');
    btnPlay.innerHTML = '&#9654;';
  }

  currentDuration = s.duration || 0;
  document.getElementById('timeTotal').textContent = formatTime(currentDuration);

  if (!isSeeking) {
    const curTime = s.current_time || 0;
    document.getElementById('timeCurrent').textContent = formatTime(curTime);
    const pct = currentDuration > 0 ? (curTime / currentDuration) * 100 : 0;
    document.getElementById('progressFill').style.width = pct + '%';
  }

  // 音量
  const volPct = Math.round((s.volume || 0.8) * 100);
  document.getElementById('volSlider').value = volPct;
  document.getElementById('volLabel').textContent = volPct + '%';

  // 静音按钮
  document.getElementById('btnMute').innerHTML = s.is_muted ? '&#128263;' : '&#128266;';

  // 模式
  const modeBtn = document.getElementById('btnMode');
  if (s.mode === 'single') modeBtn.innerHTML = '&#128472;';
  else if (s.mode === 'shuffle') modeBtn.innerHTML = '&#128256;';
  else modeBtn.innerHTML = '&#10227;';

  // 12 频段频谱跳动
  if (s.spectrum && s.spectrum.length === 12) {
    const bars = document.querySelectorAll('.spec-bar');
    s.spectrum.forEach((v, idx) => {
      if (bars[idx]) {
        const h = Math.max(4, Math.round(v * 36));
        bars[idx].style.height = h + 'px';
      }
    });
  }

  // 均衡器开关与增益
  document.getElementById('eqToggle').checked = s.eq_enabled;
  if (s.eq_bands && s.eq_bands.length === 10) {
    s.eq_bands.forEach((g, idx) => {
      const slider = document.querySelector(`.eq-vslider[data-band="${idx}"]`);
      if (slider) slider.value = g;
      const lbl = document.getElementById(`eqGain${idx}`);
      if (lbl) lbl.textContent = (g > 0 ? '+' : '') + g.toFixed(1);
    });
  }

  // 调音魔棒状态与数值
  if (s.mseb_enabled !== undefined) {
    document.getElementById('msebToggle').checked = s.mseb_enabled;
  }
  if (s.mseb_params && s.mseb_params.length === 10) {
    s.mseb_params.forEach((val, idx) => {
      const slider = document.querySelector(`.mseb-slider[data-param="${idx}"]`);
      if (slider) slider.value = val;
      const valLbl = document.getElementById(`msebVal${idx}`);
      if (valLbl) valLbl.textContent = (val > 0 ? '+' : '') + val.toFixed(1);
    });
  }

  // 主题与动效模式激活态
  document.querySelectorAll('#themesGrid .theme-card').forEach(c => {
    c.classList.toggle('active', parseInt(c.dataset.theme) === s.theme_id);
  });
  document.querySelectorAll('#visualsGrid .theme-card').forEach(c => {
    c.classList.toggle('active', parseInt(c.dataset.vmode) === s.visual_mode);
  });

  // 淡入淡出
  if (s.fade_duration !== undefined) {
    document.getElementById('fadeSlider').value = s.fade_duration;
  }

  // 源码直通状态
  const bp = document.getElementById('bitPerfectBadge');
  if (s.is_bit_perfect) {
    bp.textContent = '源码直通中';
    bp.className = 'badge';
  } else {
    bp.textContent = '软件混音';
    bp.className = 'badge disconnected';
  }
}

// ==================== 播放队列渲染 ====================
function updateQueue(q) {
  queueData = q.tracks || [];
  const curIdx = q.current_index || 0;
  document.getElementById('qCountBadge').textContent = queueData.length;
  document.getElementById('qTotal').textContent = queueData.length;

  const list = document.getElementById('queueList');
  if (queueData.length === 0) {
    list.innerHTML = '<div style="text-align: center; color: var(--text-muted); padding: 30px 0; font-size: 13px;">队列为空，快去曲库添加歌曲吧</div>';
    return;
  }

  let html = '';
  queueData.forEach((t, i) => {
    const isAct = (i === curIdx);
    html += `
      <div class="song-item ${isAct ? 'active' : ''}" data-idx="${i}">
        <div class="song-left">
          <div class="song-idx">${isAct ? '&#9654;' : (i + 1 < 10 ? '0' + (i + 1) : i + 1)}</div>
          <div class="song-main">
            <div class="song-title">${t.title || '未知歌曲'}</div>
            <div class="song-sub">${t.artist || '未知艺术家'} &middot; ${t.album || '纯音专辑'}</div>
          </div>
        </div>
        <div class="song-actions">
          <div class="song-meta">${formatTime(t.duration)}</div>
          <button class="btn-del" data-del="${i}" title="从队列中移除">&times;</button>
        </div>
      </div>`;
  });
  list.innerHTML = html;

  // 绑定点击起播与删除
  list.querySelectorAll('.song-item').forEach(item => {
    item.addEventListener('click', (e) => {
      if (e.target.closest('.btn-del')) return;
      const idx = parseInt(item.dataset.idx);
      sendAction({ action: 'play_queue_index', index: idx });
    });
  });

  list.querySelectorAll('.btn-del').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const idx = parseInt(btn.dataset.del);
      sendAction({ action: 'remove_queue_index', index: idx });
    });
  });
}

// ==================== 发烧歌单渲染 ====================
function updatePlaylists(p) {
  playlistsData = p.playlists || [];
  document.getElementById('plCountBadge').textContent = playlistsData.length;
  document.getElementById('plTotal').textContent = playlistsData.length;

  const grid = document.getElementById('playlistsGrid');
  if (playlistsData.length === 0) {
    grid.innerHTML = '<div style="grid-column: 1/-1; text-align: center; color: var(--text-muted); padding: 30px 0; font-size: 13px;">暂未创建歌单，点击上方“＋ 新建歌单”开始</div>';
    return;
  }

  let html = '';
  playlistsData.forEach(pl => {
    html += `
      <div class="playlist-card" data-plid="${pl.id}">
        <div>
          <div class="playlist-header">
            <span style="font-size: 18px; color: var(--accent);">&#128193;</span>
            <div class="playlist-name">${pl.name}</div>
          </div>
          <div class="playlist-count">${pl.track_count} 首曲目 &middot; ${formatTime(pl.duration)}</div>
        </div>
        <div class="playlist-btns">
          <button class="btn-sm primary btn-play-pl" data-plid="${pl.id}">&#9654; 启播歌单</button>
          <button class="btn-sm btn-del-pl" data-plid="${pl.id}" style="color:var(--danger);">&#128465;</button>
        </div>
      </div>`;
  });
  grid.innerHTML = html;

  grid.querySelectorAll('.btn-play-pl').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = parseInt(btn.dataset.plid);
      sendAction({ action: 'play_playlist', id: id, start_index: 0 });
    });
  });

  grid.querySelectorAll('.btn-del-pl').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = parseInt(btn.dataset.plid);
      if (confirm('确定要删除此歌单吗？')) {
        sendAction({ action: 'delete_playlist', id: id });
      }
    });
  });
}

// ==================== 曲库渲染与搜索 ====================
function updateLibrary(l) {
  libraryData = l.tracks || [];
  document.getElementById('libTotal').textContent = libraryData.length;
  renderLibraryList(libraryData);
}

function renderLibraryList(tracks) {
  const list = document.getElementById('libSongList');
  if (tracks.length === 0) {
    list.innerHTML = '<div style="text-align: center; color: var(--text-muted); padding: 30px 0; font-size: 13px;">未找到匹配曲目</div>';
    return;
  }

  let html = '';
  tracks.forEach((t, i) => {
    html += `
      <div class="song-item" data-libidx="${i}" data-id="${t.id}">
        <div class="song-left">
          <div class="song-idx">${i + 1 < 10 ? '0' + (i + 1) : i + 1}</div>
          <div class="song-main">
            <div class="song-title">${t.title || '未知曲目'}</div>
            <div class="song-sub">${t.artist || '未知艺术家'} &middot; ${t.badge || 'FLAC'}</div>
          </div>
        </div>
        <div class="song-actions">
          <div class="song-meta">${formatTime(t.duration)}</div>
          <button class="btn-sm btn-add-q" data-id="${t.id}" title="加入播放队列">＋ 队列</button>
        </div>
      </div>`;
  });
  list.innerHTML = html;

  list.querySelectorAll('.song-item').forEach(item => {
    item.addEventListener('click', (e) => {
      if (e.target.closest('.btn-add-q')) return;
      const idx = parseInt(item.dataset.libidx);
      sendAction({ action: 'play_library_index', index: idx });
    });
  });

  list.querySelectorAll('.btn-add-q').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const tid = parseInt(btn.dataset.id);
      sendAction({ action: 'add_to_queue', id: tid });
      btn.textContent = '已添加';
      btn.style.borderColor = 'var(--accent)';
      setTimeout(() => { btn.textContent = '＋ 队列'; }, 1000);
    });
  });
}

// ==================== 10段图形 EQ 渲染 ====================
function renderEqSliders() {
  let html = '';
  for (let i = 0; i < 10; ++i) {
    html += `
      <div class="eq-col">
        <div class="eq-gain-lbl" id="eqGain${i}">0.0</div>
        <div class="eq-vslider-wrap">
          <input type="range" class="eq-vslider" min="-12" max="12" step="0.5" value="0" data-band="${i}">
        </div>
        <div class="eq-freq-lbl">${eqFreqs[i]}</div>
      </div>`;
  }
  document.getElementById('eqSliders').innerHTML = html;

  document.querySelectorAll('.eq-vslider').forEach(slider => {
    slider.addEventListener('input', (e) => {
      const idx = parseInt(e.target.dataset.band);
      const val = parseFloat(e.target.value);
      const lbl = document.getElementById(`eqGain${idx}`);
      if (lbl) lbl.textContent = (val > 0 ? '+' : '') + val.toFixed(1);
      sendAction({ action: 'set_eq_band', index: idx, value: val });
    });
  });
}

// ==================== 调音魔棒 (MSEB) 渲染 ====================
function renderMseb() {
  let html = '';
  msebDefs.forEach((def, i) => {
    html += `
      <div class="mseb-card">
        <div class="mseb-top">
          <span class="mseb-name">${def.name}</span>
          <span class="mseb-val" id="msebVal${i}">0.0</span>
        </div>
        <div class="mseb-slider-row">
          <span class="mseb-lbl-l">${def.left}</span>
          <input type="range" class="mseb-slider" min="-10" max="10" step="0.5" value="0" data-param="${i}">
          <span class="mseb-lbl-r">${def.right}</span>
        </div>
      </div>`;
  });
  document.getElementById('msebGrid').innerHTML = html;

  document.querySelectorAll('.mseb-slider').forEach(slider => {
    slider.addEventListener('input', (e) => {
      const idx = parseInt(e.target.dataset.param);
      const val = parseFloat(e.target.value);
      const lbl = document.getElementById(`msebVal${idx}`);
      if (lbl) lbl.textContent = (val > 0 ? '+' : '') + val.toFixed(1);
      sendAction({ action: 'set_mseb_param', index: idx, value: val });
    });
  });
}

function updateMseb(m) {
  document.getElementById('msebToggle').checked = m.enabled;
  if (m.params && m.params.length === 10) {
    m.params.forEach((val, idx) => {
      const slider = document.querySelector(`.mseb-slider[data-param="${idx}"]`);
      if (slider) slider.value = val;
      const lbl = document.getElementById(`msebVal${idx}`);
      if (lbl) lbl.textContent = (val > 0 ? '+' : '') + val.toFixed(1);
    });
  }
}

// ==================== 实际音频输出状态（只读） ====================
function dacDeviceDetails(device) {
  const details = [];
  if (device.transport) details.push(device.transport);
  const rate = Number(device.sample_rate);
  if (Number.isFinite(rate) && rate > 0) details.push((rate / 1000) + ' kHz');
  return details.join(' · ');
}

function updateDac(d) {
  const devices = Array.isArray(d.devices) ? d.devices : [];
  document.getElementById('dacDeviceName').textContent = d.dac_name || '未获取到当前音频设备';
  const details = dacDeviceDetails(d);
  const policy = d.follows_system_output ? '音频输出由 iPadOS 系统管理' : '';
  document.getElementById('dacDeviceDesc').textContent = [details, policy].filter(Boolean).join(' · ');
  document.getElementById('dacStatusIcon').style.color = d.dac_name ? 'var(--accent)' : 'var(--text-muted)';

  const grid = document.getElementById('dacDevicesGrid');
  grid.replaceChildren();
  document.getElementById('dacDevicesSection').hidden = devices.length === 0;
  devices.forEach(device => {
    const card = document.createElement('div');
    card.className = 'dac-device-card' + (device.is_active ? ' active' : '');
    const name = document.createElement('div');
    name.className = 'dac-device-name';
    name.textContent = device.name || '未命名音频设备';
    const detail = document.createElement('div');
    detail.className = 'dac-device-details';
    detail.textContent = [device.is_active ? '当前输出' : '', dacDeviceDetails(device)].filter(Boolean).join(' · ');
    card.append(name, detail);
    grid.append(card);
  });
}

// ==================== 事件监听绑定 ====================
document.addEventListener('DOMContentLoaded', () => {
  renderEqSliders();
  renderMseb();
  initWebSocket();

  // 6 大顶层 Tab 切换
  document.querySelectorAll('.nav-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
      tab.classList.add('active');
      const targetPane = document.getElementById(tab.dataset.tab);
      if (targetPane) targetPane.classList.add('active');
    });
  });

  // 列表 Sub-Pill 切换
  document.getElementById('pillQueue').addEventListener('click', () => {
    document.getElementById('pillQueue').classList.add('active');
    document.getElementById('pillPlaylists').classList.remove('active');
    document.getElementById('paneQueueList').style.display = 'block';
    document.getElementById('panePlaylistsList').style.display = 'none';
  });
  document.getElementById('pillPlaylists').addEventListener('click', () => {
    document.getElementById('pillPlaylists').classList.add('active');
    document.getElementById('pillQueue').classList.remove('active');
    document.getElementById('panePlaylistsList').style.display = 'block';
    document.getElementById('paneQueueList').style.display = 'none';
  });

  // 调音 Sub-Pill 切换
  document.getElementById('pillEq').addEventListener('click', () => {
    document.getElementById('pillEq').classList.add('active');
    document.getElementById('pillMseb').classList.remove('active');
    document.getElementById('paneEq').style.display = 'block';
    document.getElementById('paneMseb').style.display = 'none';
  });
  document.getElementById('pillMseb').addEventListener('click', () => {
    document.getElementById('pillMseb').classList.add('active');
    document.getElementById('pillEq').classList.remove('active');
    document.getElementById('paneMseb').style.display = 'block';
    document.getElementById('paneEq').style.display = 'none';
  });

  // 播放控制
  document.getElementById('btnPlay').addEventListener('click', () => sendAction({ action: 'toggle' }));
  document.getElementById('btnPrev').addEventListener('click', () => sendAction({ action: 'prev' }));
  document.getElementById('btnNext').addEventListener('click', () => sendAction({ action: 'next' }));
  document.getElementById('btnMode').addEventListener('click', () => sendAction({ action: 'mode' }));
  document.getElementById('btnMute').addEventListener('click', () => sendAction({ action: 'mute' }));

  // 音量控制
  const vol = document.getElementById('volSlider');
  vol.addEventListener('input', (e) => {
    const v = parseInt(e.target.value);
    document.getElementById('volLabel').textContent = v + '%';
    sendAction({ action: 'volume', value: v / 100.0 });
  });

  // 进度条拖拽
  const pBar = document.getElementById('progressBar');
  pBar.addEventListener('click', (e) => {
    const rect = pBar.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    if (currentDuration > 0) {
      sendAction({ action: 'seek', value: ratio * currentDuration });
    }
  });

  // 均衡器开关与归零
  document.getElementById('eqToggle').addEventListener('change', (e) => {
    sendAction({ action: 'set_eq_enabled', enabled: e.target.checked });
  });
  document.getElementById('btnResetEq').addEventListener('click', () => {
    sendAction({ action: 'reset_eq' });
  });

  // 均衡器预设点击
  document.querySelectorAll('#eqPresetsList .preset-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('#eqPresetsList .preset-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      const presetKey = chip.dataset.preset;
      if (eqPresets[presetKey]) {
        sendAction({ action: 'set_eq_preset', bands: eqPresets[presetKey] });
      }
    });
  });

  // 魔棒开关与归零
  document.getElementById('msebToggle').addEventListener('change', (e) => {
    sendAction({ action: 'set_mseb_enabled', enabled: e.target.checked });
  });
  document.getElementById('btnResetMseb').addEventListener('click', () => {
    sendAction({ action: 'reset_mseb' });
  });

  // 清空队列
  document.getElementById('btnClearQueue').addEventListener('click', () => {
    if (confirm('确定要清空正在播放队列吗？')) {
      sendAction({ action: 'clear_queue' });
    }
  });

  // 新建歌单弹窗
  const modal = document.getElementById('createPlModal');
  document.getElementById('btnOpenCreatePlModal').addEventListener('click', () => {
    document.getElementById('newPlNameInput').value = '';
    modal.classList.add('active');
  });
  document.getElementById('btnCancelCreatePl').addEventListener('click', () => {
    modal.classList.remove('active');
  });
  document.getElementById('btnConfirmCreatePl').addEventListener('click', () => {
    const name = document.getElementById('newPlNameInput').value.trim();
    if (name) {
      sendAction({ action: 'create_playlist', name: name });
      modal.classList.remove('active');
    }
  });

  // 曲库搜索
  document.getElementById('libSearchInput').addEventListener('input', (e) => {
    const kw = e.target.value.toLowerCase().trim();
    if (!kw) {
      renderLibraryList(libraryData);
      return;
    }
    const filtered = libraryData.filter(t => 
      (t.title && t.title.toLowerCase().includes(kw)) ||
      (t.artist && t.artist.toLowerCase().includes(kw)) ||
      (t.album && t.album.toLowerCase().includes(kw))
    );
    renderLibraryList(filtered);
  });

  // 扫描曲库
  document.getElementById('btnScanMusic').addEventListener('click', () => {
    sendAction({ action: 'start_scan' });
    alert('已向数播发送本地全盘扫描指令');
  });

  // 主题配色点击
  document.querySelectorAll('#themesGrid .theme-card').forEach(card => {
    card.addEventListener('click', () => {
      const tid = parseInt(card.dataset.theme);
      sendAction({ action: 'set_theme', theme_id: tid });
    });
  });

  // 视觉动效点击
  document.querySelectorAll('#visualsGrid .theme-card').forEach(card => {
    card.addEventListener('click', () => {
      const mode = parseInt(card.dataset.vmode);
      sendAction({ action: 'set_visual_mode', mode: mode });
    });
  });

  // 淡入淡出
  document.getElementById('fadeSlider').addEventListener('change', (e) => {
    sendAction({ action: 'set_fade', value: parseFloat(e.target.value) });
  });

  // 睡眠定时
  document.querySelectorAll('.timer-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.timer-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const min = parseInt(btn.dataset.min);
      sendAction({ action: 'set_sleep_timer', minutes: min });
      document.getElementById('sleepTimerStatus').textContent = min > 0 ? `将在 ${min} 分钟后自动关机` : '未开启睡眠定时';
    });
  });

  // WiFi 网页传歌跳转链接
  document.getElementById('btnWifiUploadLink').href = window.location.protocol + '//' + window.location.hostname + ':8080';
});
</script>
</body>
</html>
''';
