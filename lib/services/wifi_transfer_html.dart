/// 内嵌 WiFi 局域网拖拽与文件夹递归传歌 Web 单页应用
/// 支持批量拖拽、文件夹递归解析 (HTML5 Directory Entry API)、多格式发烧音频即传即入库
const String wifiTransferHtml = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>PiHiFi 无线传歌中枢</title>
<style>
:root {
  --bg-color: #0c1017;
  --card-bg: rgba(22, 28, 40, 0.88);
  --card-border: rgba(255, 255, 255, 0.12);
  --accent: #10b981;
  --accent-glow: rgba(16, 185, 129, 0.35);
  --text-active: #ffffff;
  --text-normal: #cbd5e1;
  --text-muted: #64748b;
  --progress-bg: #1e293b;
  --danger: #ef4444;
  --warning: #f59e0b;
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
.container { width: 100%; max-width: 720px; }
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
  padding: 36px 20px;
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
.drop-icon { font-size: 40px; margin-bottom: 12px; color: var(--accent); }
.drop-title { font-size: 17px; font-weight: 600; color: var(--text-active); margin-bottom: 6px; }
.drop-sub { font-size: 13px; color: var(--text-muted); line-height: 1.5; }
.file-formats { margin-top: 12px; font-size: 12px; color: var(--text-muted); }
.file-formats span { background: rgba(255, 255, 255, 0.06); padding: 2px 6px; border-radius: 4px; margin: 0 2px; }
.select-buttons { display: flex; gap: 12px; margin-top: 18px; justify-content: center; }
.btn-select {
  padding: 8px 16px;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.15);
  color: var(--text-active);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}
.btn-select:hover { background: rgba(255, 255, 255, 0.15); border-color: var(--accent); }
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
.queue-list { display: flex; flex-direction: column; gap: 10px; max-height: 380px; overflow-y: auto; padding-right: 4px; }
.queue-item {
  background: rgba(15, 23, 42, 0.6);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 10px;
  padding: 12px 14px;
}
.queue-top { display: flex; justify-content: space-between; font-size: 14px; margin-bottom: 8px; }
.file-name { font-weight: 500; color: var(--text-active); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 70%; }
.file-status { font-size: 12px; color: var(--text-muted); }
.progress-bar-bg { width: 100%; height: 6px; background: var(--progress-bg); border-radius: 3px; overflow: hidden; }
.progress-bar-fill { height: 100%; width: 0%; background: var(--accent); border-radius: 3px; transition: width 0.15s ease; }
.queue-bottom { display: flex; justify-content: space-between; font-size: 12px; color: var(--text-muted); margin-top: 6px; }
.status-success { color: var(--accent) !important; font-weight: 600; }
.status-error { color: var(--danger) !important; }
.empty-tip { text-align: center; color: var(--text-muted); padding: 24px; font-size: 14px; }
.scan-tip { display: none; text-align: center; color: var(--warning); padding: 8px; font-size: 13px; font-weight: 500; }
.tip-banner { margin-top: 14px; padding: 10px 14px; border-radius: 8px; background: rgba(59, 130, 246, 0.08); border: 1px solid rgba(59, 130, 246, 0.2); font-size: 12px; color: #93c5fd; line-height: 1.5; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>{{PLATFORM}} 发烧纯音无线传歌中枢</h1>
    <p>{{PLATFORM}}局域网极速无损传输 · 即传即播 · 自动扫描入库</p>
    <div class="badge"><div class="badge-dot"></div><span>{{PLATFORM}}服务已就绪 · 本地直连</span></div>
  </div>

  <div class="card">
    <div class="drop-zone" id="dropZone">
      <div class="drop-icon">&#9835;</div>
      <div class="drop-title">拖拽音频文件或音乐文件夹到此处</div>
      <div class="drop-sub">自动递归提取文件夹及子目录内的所有无损音频</div>
      <div class="file-formats">
        <span>FLAC</span><span>WAV</span><span>DSF</span><span>DFF</span><span>APE</span><span>MP3</span><span>M4A</span><span>AAC</span><span>ALAC</span><span>CUE</span>
      </div>
      <div class="select-buttons" onclick="event.stopPropagation()">
        <button class="btn-select" id="btnPickFiles">🎵 选择音频文件</button>
        <button class="btn-select" id="btnPickFolder">📁 选择音乐文件夹</button>
      </div>
      <input type="file" id="fileInput" multiple accept=".flac,.wav,.dsf,.dff,.ape,.mp3,.m4a,.aac,.ogg,.wma,.alac,.aiff,.cue,.iso,audio/*">
      <input type="file" id="folderInput" webkitdirectory directory multiple>
    </div>
    <div class="scan-tip" id="scanTip">⚡ 正在递归解析文件夹中的音频文件，请稍候...</div>
    <div class="actions">
      <button class="btn btn-primary" id="btnUpload" disabled>开始批量传输 (0)</button>
      <button class="btn btn-outline" id="btnClear" disabled>清空列表</button>
    </div>
    <div class="tip-banner">
      💡 提示：上传过程中请保持 {{PLATFORM}} 处于亮屏且 HiFi Player 应用在前台运行，避免系统锁屏休眠中断网络传输。
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
const folderInput = document.getElementById('folderInput');
const btnPickFiles = document.getElementById('btnPickFiles');
const btnPickFolder = document.getElementById('btnPickFolder');
const scanTip = document.getElementById('scanTip');
const btnUpload = document.getElementById('btnUpload');
const btnClear = document.getElementById('btnClear');
const queueList = document.getElementById('queueList');
const emptyTip = document.getElementById('emptyTip');
const queueCount = document.getElementById('queueCount');
const overallSpeed = document.getElementById('overallSpeed');

const AUDIO_EXTS = ['.flac', '.wav', '.dsf', '.dff', '.ape', '.mp3', '.m4a', '.aac', '.ogg', '.wma', '.alac', '.aiff', '.iso', '.cue'];

function isAudioFile(name) {
  if (!name) return false;
  const lower = name.toLowerCase();
  return AUDIO_EXTS.some(ext => lower.endsWith(ext));
}

let fileQueue = [];
let isUploading = false;

dropZone.addEventListener('click', () => fileInput.click());
btnPickFiles.addEventListener('click', (e) => { e.stopPropagation(); fileInput.click(); });
btnPickFolder.addEventListener('click', (e) => { e.stopPropagation(); folderInput.click(); });

dropZone.addEventListener('dragover', (e) => { e.preventDefault(); dropZone.classList.add('dragover'); });
dropZone.addEventListener('dragleave', () => dropZone.classList.remove('dragover'));

dropZone.addEventListener('drop', async (e) => {
  e.preventDefault();
  dropZone.classList.remove('dragover');

  const items = e.dataTransfer.items;
  if (items && items.length > 0) {
    scanTip.style.display = 'block';
    const collectedFiles = [];
    const promises = [];

    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (item.webkitGetAsEntry) {
        const entry = item.webkitGetAsEntry();
        if (entry) {
          promises.push(traverseEntry(entry, collectedFiles));
        }
      } else if (item.kind === 'file') {
        const f = item.getAsFile();
        if (f && f.size > 0 && isAudioFile(f.name)) {
          collectedFiles.push(f);
        }
      }
    }

    try {
      await Promise.all(promises);
    } catch (_) {}
    scanTip.style.display = 'none';

    if (collectedFiles.length > 0) {
      addFiles(collectedFiles);
    } else {
      alert('未在所选文件/文件夹中检测到支持的音频文件（支持 FLAC, WAV, DSD, APE, MP3 等）');
    }
    return;
  }

  if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
    const rawFiles = Array.from(e.dataTransfer.files).filter(f => f.size > 0 && isAudioFile(f.name));
    if (rawFiles.length > 0) {
      addFiles(rawFiles);
    } else {
      alert('所选文件为空或非支持的音频格式');
    }
  }
});

async function traverseEntry(entry, fileList) {
  if (!entry) return;
  if (entry.isFile) {
    return new Promise(resolve => {
      entry.file(f => {
        if (f && f.size > 0 && isAudioFile(f.name)) {
          if (entry.fullPath) {
            f.fullRelativePath = entry.fullPath.replace(/^\//, '');
          }
          fileList.push(f);
        }
        resolve();
      }, () => resolve());
    });
  } else if (entry.isDirectory) {
    return new Promise(resolve => {
      const dirReader = entry.createReader();
      const readBatch = () => {
        dirReader.readEntries(async entries => {
          if (!entries || entries.length === 0) {
            resolve();
          } else {
            const subPromises = entries.map(sub => traverseEntry(sub, fileList));
            await Promise.all(subPromises);
            readBatch();
          }
        }, () => resolve());
      };
      readBatch();
    });
  }
}

fileInput.addEventListener('change', () => {
  if (fileInput.files.length > 0) {
    const valid = Array.from(fileInput.files).filter(f => f.size > 0 && isAudioFile(f.name));
    addFiles(valid);
    fileInput.value = '';
  }
});

folderInput.addEventListener('change', () => {
  if (folderInput.files.length > 0) {
    const valid = Array.from(folderInput.files).filter(f => f.size > 0 && isAudioFile(f.name));
    if (valid.length > 0) {
      addFiles(valid);
    } else {
      alert('所选文件夹中未找到支持的音频文件');
    }
    folderInput.value = '';
  }
});

function formatBytes(bytes) {
  if (!bytes || bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function addFiles(files) {
  for (let file of files) {
    const key = file.fullRelativePath || file.webkitRelativePath || file.name;
    if (!fileQueue.some(item => (item.file.fullRelativePath || item.file.webkitRelativePath || item.file.name) === key && item.file.size === file.size)) {
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
  fileQueue.forEach((item) => {
    const div = document.createElement('div');
    div.className = 'queue-item';
    let pct = item.total > 0 ? Math.round((item.loaded / item.total) * 100) : 0;
    if (item.status === 'success') pct = 100;

    let statusText = '等待上传';
    let statusClass = 'file-status';
    if (item.status === 'uploading') {
      statusText = `上传中 ${pct}% · ${item.speed}`;
    } else if (item.status === 'success') {
      statusText = item.indexed === false ? '已保存，待重新扫描' : '已入库 ✓';
      statusClass = 'file-status status-success';
    } else if (item.status === 'error') {
      statusText = item.errorMsg ? `失败: ${item.errorMsg} ✗` : '上传失败 ✗';
      statusClass = 'file-status status-error';
    }

    const displayName = item.file.fullRelativePath || item.file.webkitRelativePath || item.file.name;
    div.innerHTML = `
      <div class="queue-top">
        <span class="file-name" title="${displayName}">${displayName}</span>
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

function uploadSingleFile(item) {
  return new Promise((resolve, reject) => {
    if (!item.file || item.file.size === 0) {
      reject(new Error('文件为空或无法读取'));
      return;
    }

    const uploadPath = item.file.fullRelativePath || item.file.webkitRelativePath || item.file.name;
    const xhr = new XMLHttpRequest();
    const encodedName = encodeURIComponent(uploadPath);
    xhr.open('POST', `/upload?filename=${encodedName}`, true);
    xhr.timeout = 600000; // 10分钟超时

    let startTime = Date.now();
    let lastLoaded = 0;

    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) {
        item.loaded = e.loaded;
        item.total = e.total;

        let now = Date.now();
        let elapsed = (now - startTime) / 1000;
        if (elapsed > 0.25) {
          let speedVal = ((e.loaded - lastLoaded) / elapsed / 1024 / 1024).toFixed(1);
          item.speed = `${speedVal} MB/s`;
          overallSpeed.textContent = `正在传输: ${item.file.name} · ${item.speed}`;
          startTime = now;
          lastLoaded = e.loaded;
          renderQueue();
        }
      }
    };

    xhr.onload = () => {
      if (xhr.status === 200) {
        try { item.indexed = JSON.parse(xhr.responseText).indexed; } catch (_) {}
        resolve();
      } else {
        let msg = `服务器错误 (HTTP ${xhr.status})`;
        try {
          const resp = JSON.parse(xhr.responseText);
          if (resp && resp.message) msg = resp.message;
        } catch (_) {}
        reject(new Error(msg));
      }
    };
    xhr.onerror = () => reject(new Error('网络断开，请确保 {{PLATFORM}} 处于亮屏且应用在前台'));
    xhr.ontimeout = () => reject(new Error('传输超时，请检查局域网连接'));
    xhr.send(item.file);
  });
}
</script>
</body>
</html>
''';
