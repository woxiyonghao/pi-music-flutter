/// 内嵌 WiFi 局域网拖拽传歌 Web 单页应用 (来自 C++ WifiTransferServer.cpp 1:1 原生实现)
const String wifiTransferHtml = r'''<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>PiHiFi 无线传歌中枢</title>
<style>
:root {
  --bg-color: #0c1017;
  --card-bg: rgba(22, 28, 40, 0.85);
  --card-border: rgba(255, 255, 255, 0.12);
  --accent: #10b981;
  --accent-glow: rgba(16, 185, 129, 0.35);
  --text-active: #ffffff;
  --text-normal: #cbd5e1;
  --text-muted: #64748b;
  --progress-bg: #1e293b;
  --danger: #ef4444;
}
* { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Microsoft YaHei", sans-serif; }
body {
  background: var(--bg-color);
  color: var(--text-normal);
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 24px 16px;
  background-image: radial-gradient(circle at 50% 10%, rgba(16, 185, 129, 0.08), transparent 45%);
}
.container { width: 100%; max-width: 680px; }
.header { text-align: center; margin-bottom: 24px; }
.header h1 { font-size: 26px; font-weight: 700; color: var(--text-active); letter-spacing: 0.5px; margin-bottom: 8px; }
.header p { font-size: 14px; color: var(--text-muted); }
.badge { display: inline-flex; align-items: center; gap: 6px; padding: 4px 12px; background: rgba(16, 185, 129, 0.12); border: 1px solid var(--accent); border-radius: 20px; color: var(--accent); font-size: 12px; font-weight: 600; margin-top: 10px; }
.badge-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--accent); box-shadow: 0 0 8px var(--accent); }
.card {
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(16px);
  margin-bottom: 20px;
}
.drop-zone {
  border: 2px dashed rgba(255, 255, 255, 0.2);
  border-radius: 12px;
  padding: 40px 20px;
  text-align: center;
  cursor: pointer;
  transition: all 0.25s ease;
  background: rgba(15, 23, 42, 0.4);
}
.drop-zone:hover, .drop-zone.dragover {
  border-color: var(--accent);
  background: rgba(16, 185, 129, 0.05);
  box-shadow: 0 0 20px var(--accent-glow);
}
.drop-icon { font-size: 44px; margin-bottom: 12px; color: var(--accent); }
.drop-title { font-size: 17px; font-weight: 600; color: var(--text-active); margin-bottom: 6px; }
.drop-sub { font-size: 13px; color: var(--text-muted); line-height: 1.5; }
.file-formats { margin-top: 12px; font-size: 12px; color: var(--text-muted); }
.file-formats span { background: rgba(255, 255, 255, 0.06); padding: 2px 6px; border-radius: 4px; margin: 0 2px; }
input[type="file"] { display: none; }
.actions { display: flex; gap: 12px; margin-top: 16px; }
.btn {
  flex: 1;
  padding: 12px;
  border-radius: 10px;
  border: none;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}
.btn-primary { background: var(--accent); color: #0c1017; }
.btn-primary:hover:not(:disabled) { filter: brightness(1.1); box-shadow: 0 0 16px var(--accent-glow); }
.btn-primary:disabled { opacity: 0.4; cursor: not-allowed; }
.btn-outline { background: transparent; border: 1px solid rgba(255, 255, 255, 0.2); color: var(--text-normal); }
.btn-outline:hover:not(:disabled) { background: rgba(255, 255, 255, 0.08); }
.queue-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; font-size: 14px; font-weight: 600; color: var(--text-active); }
.queue-list { display: flex; flex-direction: column; gap: 10px; max-height: 320px; overflow-y: auto; padding-right: 4px; }
.queue-item {
  background: rgba(15, 23, 42, 0.6);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 10px;
  padding: 12px 14px;
}
.queue-top { display: flex; justify-content: space-between; font-size: 14px; margin-bottom: 8px; }
.file-name { font-weight: 500; color: var(--text-active); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 75%; }
.file-status { font-size: 12px; color: var(--text-muted); }
.progress-bar-bg { width: 100%; height: 6px; background: var(--progress-bg); border-radius: 3px; overflow: hidden; }
.progress-bar-fill { height: 100%; width: 0%; background: var(--accent); border-radius: 3px; transition: width 0.15s ease; }
.status-success { color: var(--accent) !important; font-weight: 600; }
.status-skipped { color: #38bdf8 !important; font-weight: 600; }
.status-error { color: var(--danger) !important; }
.empty-tip { text-align: center; color: var(--text-muted); padding: 24px; font-size: 14px; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>{{PLATFORM_TITLE}} 发烧纯音无线传歌中枢</h1>
    <p>{{PLATFORM_LABEL}}局域网极速无损传输 · 即传即播 · 自动扫描入库</p>
    <div class="badge"><div class="badge-dot"></div><span>{{PLATFORM_LABEL}}服务已就绪 · 本地直连</span></div>
  </div>

  <div class="card">
    <div class="drop-zone" id="dropZone">
      <div class="drop-icon">&#9835;</div>
      <div class="drop-title">拖拽音频文件到此处，或点击浏览文件</div>
      <div class="drop-sub">支持单选、多选或批量拖拽，传输完毕后数播自动更新曲库</div>
      <div class="file-formats">
        <span>FLAC</span><span>WAV</span><span>CUE</span><span>DSF</span><span>DFF</span><span>APE</span><span>MP3</span><span>M4A</span><span>AAC</span>
      </div>
      <input type="file" id="fileInput" multiple accept=".flac,.wav,.cue,.dsf,.dff,.ape,.mp3,.m4a,.aac,.ogg,.wma,.iso,audio/*">
    </div>
    <div class="actions">
      <button class="btn btn-primary" id="btnUpload" disabled>开始批量传输 (0)</button>
      <button class="btn btn-outline" id="btnClear" disabled>清空列表</button>
    </div>
  </div>

  <div class="card">
    <div class="queue-header">
      <span>传输队列与状态 (<span id="queueCount">0</span>)</span>
      <span id="overallSpeed" style="font-size:12px; color:var(--text-muted);">空闲</span>
    </div>
    <div class="queue-list" id="queueList">
      <div class="empty-tip" id="emptyTip">暂无待上传音频文件</div>
    </div>
  </div>
</div>

<script>
const dropZone = document.getElementById('dropZone');
const fileInput = document.getElementById('fileInput');
const btnUpload = document.getElementById('btnUpload');
const btnClear = document.getElementById('btnClear');
const queueList = document.getElementById('queueList');
const emptyTip = document.getElementById('emptyTip');
const queueCount = document.getElementById('queueCount');
const overallSpeed = document.getElementById('overallSpeed');

let fileQueue = [];
let isUploading = false;

dropZone.addEventListener('click', () => fileInput.click());
dropZone.addEventListener('dragover', (e) => { e.preventDefault(); dropZone.classList.add('dragover'); });
dropZone.addEventListener('dragleave', () => dropZone.classList.remove('dragover'));
dropZone.addEventListener('drop', (e) => {
  e.preventDefault();
  dropZone.classList.remove('dragover');
  if (e.dataTransfer.files.length > 0) {
    addFiles(e.dataTransfer.files);
  }
});
fileInput.addEventListener('change', () => {
  if (fileInput.files.length > 0) {
    addFiles(fileInput.files);
  }
});

function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function addFiles(files) {
  for (let file of files) {
    if (!fileQueue.some(item => item.file.name === file.name && item.file.size === file.size)) {
      fileQueue.push({ file: file, status: 'pending', loaded: 0, total: file.size, speed: '0 MB/s' });
    }
  }
  renderQueue();
}

function renderQueue() {
  if (fileQueue.length === 0) {
    emptyTip.style.display = 'block';
    queueCount.textContent = '0';
    btnUpload.disabled = true;
    btnClear.disabled = true;
    btnUpload.textContent = '开始批量传输 (0)';
    return;
  }

  emptyTip.style.display = 'none';
  queueCount.textContent = fileQueue.length;
  btnUpload.disabled = isUploading;
  btnClear.disabled = isUploading;
  btnUpload.textContent = `开始批量传输 (${fileQueue.filter(i => i.status === 'pending').length})`;

  queueList.innerHTML = '';
  fileQueue.forEach((item, index) => {
    const div = document.createElement('div');
    div.className = 'queue-item';
    let pct = item.total > 0 ? Math.round((item.loaded / item.total) * 100) : 0;
    if (item.status === 'success' || item.status === 'skipped') pct = 100;

    let statusText = '等待上传';
    let statusClass = 'file-status';
    if (item.status === 'uploading') {
      statusText = `上传中 ${pct}% · ${item.speed}`;
    } else if (item.status === 'success') {
      statusText = '已入库 ✓';
      statusClass = 'file-status status-success';
    } else if (item.status === 'skipped') {
      statusText = '已存在 (大小一致跳过) ✓';
      statusClass = 'file-status status-skipped';
    } else if (item.status === 'error') {
      statusText = item.errorMsg ? `失败: ${item.errorMsg} ✗` : '上传失败 ✗';
      statusClass = 'file-status status-error';
    }

    div.innerHTML = `
      <div class="queue-top">
        <span class="file-name" title="${item.file.name}">${item.file.name}</span>
        <span class="${statusClass}">${statusText}</span>
      </div>
      <div class="progress-bar-bg">
        <div class="progress-bar-fill" style="width: ${pct}%"></div>
      </div>
      <div class="queue-bottom">
        <span>${formatBytes(item.loaded)} / ${formatBytes(item.total)}</span>
        <span>${item.status === 'uploading' ? item.speed : ''}</span>
      </div>
    `;
    queueList.appendChild(div);
  });
}

btnClear.addEventListener('click', () => {
  if (isUploading) return;
  fileQueue = [];
  renderQueue();
});

btnUpload.addEventListener('click', async () => {
  if (isUploading) return;
  isUploading = true;
  btnUpload.disabled = true;
  btnClear.disabled = true;

  for (let i = 0; i < fileQueue.length; ++i) {
    let item = fileQueue[i];
    if (item.status === 'success') continue;

    item.status = 'uploading';
    renderQueue();

    try {
      await uploadSingleFile(item);
      item.status = 'success';
      item.loaded = item.total;
    } catch (err) {
      item.status = 'error';
      item.errorMsg = err.message || '传输中断';
    }
    renderQueue();
  }

  isUploading = false;
  let failed = fileQueue.filter(i => i.status === 'error').length;
  if (failed > 0) {
    overallSpeed.textContent = `传输结束: ${failed} 个文件失败`;
    btnUpload.textContent = `重试失败项目 (${failed})`;
  } else {
    overallSpeed.textContent = '全部传输完成';
    btnUpload.textContent = '传输已完成';
  }
  btnUpload.disabled = false;
  btnClear.disabled = false;
});

async function uploadSingleFile(item) {
  const CHUNK_SIZE = 512 * 1024; // 512 KB 黄金分片尺寸 (抗 2.4G 弱网、丢包秒级恢复)
  const file = item.file;
  const encodedName = encodeURIComponent(file.name);

  // 1. 探测远端服务断点信息与去重校验 (支持同名同大小秒级跳过)
  let startByte = 0;
  try {
    const statusResp = await fetch(`/upload_status?filename=${encodedName}&size=${file.size}`);
    if (statusResp.ok) {
      const info = await statusResp.json();
      if ((info.exists && info.finalBytes === file.size) || info.alreadyExists) {
        // 🌟 文件已存在且大小完全一致，跳过重复写入
        item.status = 'skipped';
        item.loaded = file.size;
        item.speed = '已跳过 (文件一致)';
        overallSpeed.textContent = `跳过写入: ${file.name} 已存在且大小完全一致`;
        renderQueue();
        return;
      }
      if (info.hasPartial && info.partialBytes > 0 && info.partialBytes < file.size) {
        // 断点续传：对齐到最近的 512KB 分片边界，避免碎片错位
        startByte = Math.floor(info.partialBytes / CHUNK_SIZE) * CHUNK_SIZE;
        item.loaded = startByte;
        overallSpeed.textContent = `断点续传中: ${file.name} 从 ${formatBytes(startByte)} 继续...`;
        renderQueue();
      }
    }
  } catch (e) {
    console.warn('[WiFiUpload] 断点状态探测跳过:', e);
  }

  // 2. 超小文件 (<= 512KB 且无断点) 走单片快速传输
  if (file.size <= CHUNK_SIZE && startByte === 0) {
    const res = await uploadSingleChunk(file, file.name, 0, 1, file.size, 0, (loaded) => {
      item.loaded = loaded;
      renderQueue();
    });
    if (res && res.skipped) {
      item.status = 'skipped';
      item.loaded = file.size;
      item.speed = '已跳过 (文件一致)';
      overallSpeed.textContent = `跳过写入: ${file.name} 已存在且大小完全一致`;
    } else {
      item.status = 'success';
      item.loaded = file.size;
    }
    renderQueue();
    return;
  }

  // 3. 超大无损母带/镜像分片流式上传
  const totalChunks = Math.ceil(file.size / CHUNK_SIZE);
  const startChunkIdx = Math.floor(startByte / CHUNK_SIZE);
  let startTime = Date.now();
  let lastLoaded = startByte;

  for (let chunkIdx = startChunkIdx; chunkIdx < totalChunks; chunkIdx++) {
    const start = chunkIdx * CHUNK_SIZE;
    const end = Math.min(start + CHUNK_SIZE, file.size);
    const chunkBlob = file.slice(start, end);

    let success = false;
    let lastErr = null;

    // 每个分片最多自动重试 5 次 (智能规避 2.4G WiFi 丢包或短暂信道拥堵)
    for (let attempt = 1; attempt <= 5; attempt++) {
      try {
        const chunkRes = await uploadSingleChunk(chunkBlob, file.name, chunkIdx, totalChunks, file.size, start, (chunkLoaded) => {
          item.loaded = start + chunkLoaded;
          let now = Date.now();
          let elapsed = (now - startTime) / 1000;
          if (elapsed > 0.3) {
            let bytesDiff = item.loaded - lastLoaded;
            let speedKB = (bytesDiff / elapsed / 1024);
            let speedText = speedKB >= 1024 ? (speedKB / 1024).toFixed(1) + ' MB/s' : Math.round(speedKB) + ' KB/s';
            item.speed = speedText;
            overallSpeed.textContent = `传输中: ${file.name} (${chunkIdx + 1}/${totalChunks}片) · ${item.speed}`;
            startTime = now;
            lastLoaded = item.loaded;
            renderQueue();
          }
        });
        if (chunkRes && chunkRes.skipped) {
          item.status = 'skipped';
          item.loaded = file.size;
          item.speed = '已跳过 (文件一致)';
          overallSpeed.textContent = `跳过写入: ${file.name} 已存在且大小完全一致`;
          renderQueue();
          return;
        }
        success = true;
        break;
      } catch (err) {
        lastErr = err;
        console.warn(`[WiFiUpload] 分片 ${chunkIdx + 1}/${totalChunks} 失败，准备第 ${attempt} 次重试...`, err);
        overallSpeed.textContent = `弱网自愈重试 (${chunkIdx + 1}/${totalChunks}片, 第${attempt}次)...`;
        await new Promise(r => setTimeout(r, 1000 * attempt));
      }
    }

    if (!success) {
      throw new Error(`分片 ${chunkIdx + 1}/${totalChunks} 传输失败: ${lastErr ? lastErr.message : '网络中断'}`);
    }
  }

  item.loaded = file.size;
  renderQueue();
}

function uploadSingleChunk(blob, filename, chunkIdx, totalChunks, totalBytes, offset, onProgress) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    const encodedName = encodeURIComponent(filename);
    xhr.open('POST', `/upload_chunk?filename=${encodedName}&chunk=${chunkIdx}&totalChunks=${totalChunks}&totalBytes=${totalBytes}&offset=${offset}`);
    xhr.timeout = 45000; // 512KB 分片给足 45 秒超时窗口

    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable && onProgress) {
        onProgress(e.loaded);
      }
    };

    xhr.onload = () => {
      if (xhr.status === 200) {
        let isSkipped = false;
        try {
          const resp = JSON.parse(xhr.responseText);
          if (resp && resp.skipped) isSkipped = true;
        } catch (_) {}
        resolve({ skipped: isSkipped });
      } else {
        let msg = `HTTP ${xhr.status}`;
        try {
          const resp = JSON.parse(xhr.responseText);
          if (resp && resp.message) msg = resp.message;
        } catch (_) {}
        reject(new Error(msg));
      }
    };

    xhr.onerror = () => reject(new Error('网络连接中断'));
    xhr.ontimeout = () => reject(new Error('分片上传超时'));
    xhr.onabort = () => reject(new Error('上传被中止'));

    xhr.send(blob);
  });
}
</script>
</body>
</html>
''';
