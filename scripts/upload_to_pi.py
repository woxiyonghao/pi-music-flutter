#!/usr/bin/env python3
"""
Upload large audio files (WAV, DSD, CUE) to Pi via chunked streaming endpoint
with automatic resumption and weak-network retry.
"""
import sys
import os
import math
import json
import urllib.request
import urllib.parse
import time

os.environ['no_proxy'] = '*'
os.environ['NO_PROXY'] = '*'

HOST = sys.argv[1] if len(sys.argv) > 1 else "192.168.1.200"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
FILE_PATH = sys.argv[3] if len(sys.argv) > 3 else ""

if not FILE_PATH or not os.path.exists(FILE_PATH):
    print(f"Error: file '{FILE_PATH}' not found!")
    sys.exit(1)

CHUNK_SIZE = 512 * 1024  # 512 KB
filename = os.path.basename(FILE_PATH)
total_bytes = os.path.getsize(FILE_PATH)
total_chunks = max(1, math.ceil(total_bytes / CHUNK_SIZE))

encoded_name = urllib.parse.quote(filename)

# 1. 查询远端断点信息
start_byte = 0
try:
    status_url = f"http://{HOST}:{PORT}/upload_status?filename={encoded_name}&size={total_bytes}"
    req = urllib.request.Request(status_url)
    with urllib.request.urlopen(req, timeout=5) as resp:
        info = json.loads(resp.read().decode('utf-8'))
        if info.get('alreadyExists') or (info.get('exists') and info.get('finalBytes') == total_bytes):
            print(f"✨ 文件已存在且大小完全一致，自动跳过写入: {filename} ({total_bytes / 1024 / 1024:.1f} MB)！")
            sys.exit(0)
        if info.get('hasPartial') and info.get('partialBytes', 0) > 0:
            part_size = info['partialBytes']
            if part_size < total_bytes:
                start_byte = (part_size // CHUNK_SIZE) * CHUNK_SIZE
                print(f"🔄 检测到历史分片，从断点恢复: {start_byte / 1024 / 1024:.1f} MB ({start_byte}/{total_bytes} bytes)")
except Exception as e:
    print(f"  (断点查询略过: {e})")

start_chunk = start_byte // CHUNK_SIZE
print(f"🚀 开始流式分片上传: {filename} ({total_bytes / 1024 / 1024:.1f} MB, 分片 {start_chunk + 1}/{total_chunks})")

start_time = time.time()
uploaded_bytes = start_byte

with open(FILE_PATH, 'rb') as f:
    if start_byte > 0:
        f.seek(start_byte)

    for chunk_idx in range(start_chunk, total_chunks):
        offset = chunk_idx * CHUNK_SIZE
        chunk_data = f.read(CHUNK_SIZE)
        if not chunk_data:
            break

        url = (
            f"http://{HOST}:{PORT}/upload_chunk?"
            f"filename={encoded_name}&chunk={chunk_idx}&totalChunks={total_chunks}&totalBytes={total_bytes}"
            f"&offset={offset}&chunkSize={CHUNK_SIZE}"
        )
        
        success = False
        last_err = None
        for attempt in range(1, 6):
            try:
                req = urllib.request.Request(url, data=chunk_data, headers={'Content-Type': 'application/octet-stream'})
                with urllib.request.urlopen(req, timeout=45) as resp:
                    resp_data = resp.read()
                    success = True
                    break
            except Exception as e:
                last_err = e
                time.sleep(0.5 * attempt)
                
        if not success:
            print(f"\n❌ 分片 {chunk_idx + 1}/{total_chunks} 传输失败: {last_err}，已终止！")
            sys.exit(1)
            
        uploaded_bytes += len(chunk_data)
        pct = (uploaded_bytes / total_bytes) * 100
        elapsed = time.time() - start_time
        speed = ((uploaded_bytes - start_byte) / elapsed / 1024) if elapsed > 0 else 0
        speed_str = f"{speed / 1024:.2f} MB/s" if speed >= 1024 else f"{speed:.1f} KB/s"
        print(f"\r  进度: {pct:.1f}% ({uploaded_bytes / 1024 / 1024:.1f}/{total_bytes / 1024 / 1024:.1f} MB) | 速率: {speed_str} | 分片: {chunk_idx + 1}/{total_chunks}", end="", flush=True)

print(f"\n✅ 传输成功完成！耗时: {time.time() - start_time:.1f}s")
