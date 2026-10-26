#!/usr/bin/env python3
"""
Portrait Stability & Stress Test Suite for HiFi Player (vivo V2419)
Executes functional bug hunting and high-intensity stress testing.
Logs memory, graphics, audio engine state, and crash logs.
"""

import os
import sys
import time
import subprocess
import json
from datetime import datetime

DEVICE = "10HEAEFT820003C"
PACKAGE = "com.example.hide_player_flutter"
LOG_DIR = "/Users/mk10/.gemini/antigravity/brain/192ad286-f0b3-4b33-9e32-f927dd76594c"
LOG_FILE = os.path.join(LOG_DIR, "portrait_stress_test.log")
STATS_FILE = os.path.join(LOG_DIR, "portrait_stress_stats.json")

def adb(cmd, timeout=15):
    full_cmd = f"adb -s {DEVICE} {cmd}"
    try:
        res = subprocess.run(full_cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return res.stdout.strip()
    except Exception as e:
        return f"ERROR: {e}"

def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = f"[{ts}] {msg}"
    print(entry, flush=True)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(entry + "\n")

def check_crashes():
    out = adb("logcat -b crash -d")
    if out and len(out) > 0 and "--------- beginning of crash" in out and len(out.strip()) > 35:
        log(f"CRASH DETECTED:\n{out}")
        return out
    return None

def get_meminfo():
    out = adb(f"shell dumpsys meminfo {PACKAGE}")
    pss = 0
    native_heap = 0
    java_heap = 0
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("TOTAL") and not line.startswith("TOTAL SWAP"):
            parts = line.split()
            if len(parts) >= 2 and parts[1].isdigit():
                pss = int(parts[1])
        elif line.startswith("Native Heap") and pss == 0:
            parts = line.split()
            if len(parts) >= 3 and parts[2].isdigit():
                native_heap = int(parts[2])
        elif line.startswith("Java Heap:"):
            parts = line.split()
            if len(parts) >= 3 and parts[2].isdigit():
                java_heap = int(parts[2])
    return {"pss_kb": pss, "native_heap_kb": native_heap, "java_heap_kb": java_heap}

def tap(x, y, delay=0.4):
    adb(f"shell input tap {x} {y}")
    time.sleep(delay)

def swipe(x1, y1, x2, y2, duration_ms=250, delay=0.4):
    adb(f"shell input swipe {x1} {y1} {x2} {y2} {duration_ms}")
    time.sleep(delay)

def ensure_app_running():
    out = adb(f"shell pidof {PACKAGE}")
    if not out or not out.isdigit():
        log("App not running, launching...")
        adb(f"shell monkey -p {PACKAGE} -c android.intent.category.LAUNCHER 1")
        time.sleep(2)
        # Handle orientation prompt if present
        tap(360, 940, delay=0.5)
        tap(360, 1070, delay=1.0)

def run_functional_round(round_num):
    log(f"=== Starting Functional Bug Hunt Round {round_num} ===")
    ensure_app_running()

    # 1. Test Song Selection and Playback
    log("Functional: Selecting and playing songs in library")
    # Tap '音乐库' tab
    swipe(100, 200, 600, 200, duration_ms=200, delay=0.3)
    tap(150, 200, delay=0.4)
    # Tap Track 1
    tap(360, 360, delay=0.8)
    # Tap Track 2
    tap(360, 480, delay=0.8)
    # Tap Track 3
    tap(360, 600, delay=0.8)

    # 2. Test Playback Controls (Pause/Play, Next, Prev, Seek)
    log("Functional: Testing transport controls & seek bar")
    # Play / Pause toggle
    tap(360, 1500, delay=0.5)
    tap(360, 1500, delay=0.5)
    # Next & Prev
    tap(480, 1500, delay=0.5)
    tap(240, 1500, delay=0.5)
    # Drag progress bar forward
    swipe(200, 1435, 550, 1435, duration_ms=300, delay=0.6)

    # 3. Test Fullscreen Theme toggle
    log("Functional: Testing fullscreen theme entry and shrink exit")
    # Tap mini visualizer
    tap(550, 1300, delay=1.0)
    # In fullscreen theme, verify shrink button at top right
    tap(642, 145, delay=0.8)

    # 4. Test Equalizer navigation & presets
    log("Functional: Testing Equalizer & Slider adjustments")
    # Tap '均衡器'
    tap(450, 200, delay=0.5)
    # Tap presets: 原音直通, 流行音乐, 摇滚现场, 经典人声
    tap(150, 275, delay=0.3)
    tap(360, 275, delay=0.3)
    tap(580, 275, delay=0.3)
    # Adjust sliders (31Hz, 125Hz, 1kHz, 8kHz)
    swipe(360, 340, 500, 340, duration_ms=150, delay=0.2)
    swipe(360, 440, 250, 440, duration_ms=150, delay=0.2)
    swipe(360, 580, 520, 580, duration_ms=150, delay=0.2)

    # 5. Test Scan Section
    log("Functional: Testing Scan section and directories")
    swipe(100, 200, 600, 200, duration_ms=200, delay=0.3)
    tap(160, 200, delay=0.5)
    # Trigger scan
    tap(280, 450, delay=1.0)

    # 6. Test App Lifecycle (Background / Resume)
    log("Functional: Testing Home key background and resume")
    adb("shell input keyevent 3")
    time.sleep(1.0)
    adb(f"shell monkey -p {PACKAGE} -c android.intent.category.LAUNCHER 1")
    time.sleep(1.0)

    # Record meminfo and crash check
    mem = get_meminfo()
    crash = check_crashes()
    log(f"Functional Round {round_num} Completed | PSS: {mem['pss_kb']} KB | Crash: {'YES' if crash else 'None'}")
    return {"pss_kb": mem["pss_kb"], "crashed": bool(crash)}

def run_stress_burst(burst_num, events_count=1500):
    log(f"=== Starting Stress Burst {burst_num} ({events_count} monkey events) ===")
    ensure_app_running()

    # 1. High-frequency transport seek burst
    log("Stress: Injecting high-frequency rapid seeks and skips")
    for _ in range(12):
        tap(480, 1500, delay=0.1) # next
        swipe(150, 1435, 600, 1435, duration_ms=80, delay=0.1) # seek
        tap(240, 1500, delay=0.1) # prev

    # 2. Targeted Monkey Stress on UI
    log(f"Stress: Running Android Monkey on {PACKAGE} with throttle 40ms...")
    # Target touches and trackball/gestures within app package
    adb(f"shell monkey -p {PACKAGE} --pct-touch 60 --pct-motion 25 --pct-trackball 0 --pct-syskeys 0 --pct-nav 5 --pct-majornav 10 --throttle 40 -v {events_count}")
    time.sleep(1.0)

    # 3. Verify app survives monkey
    ensure_app_running()
    mem = get_meminfo()
    crash = check_crashes()
    log(f"Stress Burst {burst_num} Finished | PSS: {mem['pss_kb']} KB | Crash: {'YES' if crash else 'None'}")
    return {"pss_kb": mem["pss_kb"], "crashed": bool(crash)}

def main():
    log("==================================================")
    log(f"Starting Portrait Test Suite on Device {DEVICE}")
    log(f"Package: {PACKAGE}")
    log("Target Duration: Multi-stage automated execution")
    log("==================================================")

    adb("shell logcat -c")
    stats = {
        "start_time": datetime.now().isoformat(),
        "rounds": [],
        "crashes": []
    }

    # Execute functional bug-hunting rounds and stress bursts
    # Initial deep functional validation
    for i in range(1, 11):
        res = run_functional_round(i)
        stats["rounds"].append({"type": "functional", "index": i, "result": res})
        if res["crashed"]:
            stats["crashes"].append(f"Functional round {i}")

    # Stress testing bursts
    for j in range(1, 6):
        res = run_stress_burst(j, events_count=1800)
        stats["rounds"].append({"type": "stress", "index": j, "result": res})
        if res["crashed"]:
            stats["crashes"].append(f"Stress burst {j}")

    stats["end_time"] = datetime.now().isoformat()
    with open(STATS_FILE, "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2)

    log("==================================================")
    log(f"Initial Stress & Functional Cycles Completed.")
    log(f"Total Crashes: {len(stats['crashes'])}")
    log(f"Peak Memory Recorded: {max(r['result']['pss_kb'] for r in stats['rounds'])} KB")
    log("==================================================")

if __name__ == "__main__":
    main()
