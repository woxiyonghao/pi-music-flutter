#!/usr/bin/env python3
"""
生成标准规范的 Xcursor 纯透明鼠标光标文件。
支持 1, 16, 24, 32, 48, 64 等所有标称尺寸 (Nominal Sizes)。
无论 Cage / wlroots / GDK 请求任何尺寸，均返回 1x1 透明像素，彻底杜绝回退到默认黑白箭头。
"""

import struct
import sys
import os

def generate_multi_size_transparent_xcursor(sizes=(1, 16, 24, 32, 48, 64, 96, 128)):
    # 1. 准备单像素透明 ARGB (0x00000000)
    width = 1
    height = 1
    xhot = 0
    yhot = 0
    delay = 0
    chunk_header_len = 36
    chunk_type = 0xfffd0002  # Image chunk
    chunk_version = 1
    
    pixel_data = struct.pack("<I", 0x00000000)
    
    # 2. 构建各个尺寸的 Image Chunk
    chunks = []
    for s in sizes:
        image_header = struct.pack(
            "<IIIIIIIII",
            chunk_header_len,
            chunk_type,
            s,  # nominal size
            chunk_version,
            width,
            height,
            xhot,
            yhot,
            delay
        )
        chunks.append(image_header + pixel_data)
        
    # 3. 构建 Header 与 ToC
    file_header_len = 16
    toc_entry_size = 12
    ntoc = len(sizes)
    total_header_size = file_header_len + (toc_entry_size * ntoc)
    
    magic = b"Xcur"
    file_version = 0x00010000
    
    file_header = struct.pack("<4sIII", magic, total_header_size, file_version, ntoc)
    
    toc_entries = []
    current_pos = total_header_size
    for i, s in enumerate(sizes):
        toc_entries.append(struct.pack("<III", chunk_type, s, current_pos))
        current_pos += len(chunks[i])
        
    data = file_header + b"".join(toc_entries) + b"".join(chunks)
    return data

def main():
    target_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/transparent_cursors"
    os.makedirs(target_dir, exist_ok=True)
    
    cursor_data = generate_multi_size_transparent_xcursor()
    
    # 所有主流 X11 / Wayland / wlroots / GTK 常用光标名称
    cursor_names = [
        "default", "arrow", "left_ptr", "top_left_arrow", "right_ptr",
        "pointer", "hand", "hand1", "hand2", "grab", "grabbing",
        "cross", "crosshair", "tcross",
        "text", "xterm", "ibeam",
        "wait", "watch", "progress",
        "help", "question_arrow",
        "move", "size_all", "all-scroll",
        "n-resize", "s-resize", "w-resize", "e-resize",
        "nw-resize", "ne-resize", "sw-resize", "se-resize",
        "col-resize", "row-resize",
        "not-allowed", "no-drop", "circle", "dnd-none",
        "dnd-move", "dnd-copy", "dnd-link",
        "blank", "none", "invisible"
    ]
    
    for name in cursor_names:
        filepath = os.path.join(target_dir, name)
        with open(filepath, "wb") as f:
            f.write(cursor_data)
            
    # 创建 index.theme 与 cursor.theme
    index_theme = """[Icon Theme]
Name=blank
Comment=Fully transparent invisible cursor theme
Inherits=core
"""
    with open(os.path.join(target_dir, "..", "index.theme"), "w") as f:
        f.write(index_theme)
    with open(os.path.join(target_dir, "..", "cursor.theme"), "w") as f:
        f.write(index_theme)
        
    print(f"✅ 成功生成全尺寸纯透明光标主题包: {len(cursor_names)} 个符号至 {target_dir}")

if __name__ == "__main__":
    main()
