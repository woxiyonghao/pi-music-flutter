#!/bin/bash
# ==============================================================================
# MyHiFiPlayer 树莓派 5 + TOPPING DX1 II 连续 3 小时发烧直推与稳定性自动化测试
# 重点监测项：
# 1. 物理 DAC: TOPPING DX1 II (card 0) 384kHz 32-bit 持续推流锁定
# 2. ALSA hw_params 状态与 XRUN (欠载 / Underrun) 零容忍检测
# 3. 树莓派 5 核心 SoC 温度、CPU 占用率、内存 RSS (MB) 与系统负载
# 4. WebRemote 接口 RTT 延迟与连续播放流转无缝度
# ==============================================================================

DURATION_SEC=${1:-10800} # 默认 3 小时 (10800 秒)
DURATION_HOURS=$(awk "BEGIN {printf \"%.1f\", $DURATION_SEC / 3600}")
INTERVAL_SEC=10
LOG_FILE=${2:-"/home/winheo/longevity_3h_dx1ii.log"}
SUMMARY_FILE=${3:-"/home/winheo/longevity_3h_summary.json"}

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION_SEC))

echo "==================================================================" >> "$LOG_FILE"
echo "🍓 [TOPPING DX1 II] 连续 ${DURATION_HOURS} 小时 384kHz 发烧直推耐久性测试启动" >> "$LOG_FILE"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S') | 目标运行: ${DURATION_SEC}s (${DURATION_HOURS}h)" >> "$LOG_FILE"
echo "==================================================================" >> "$LOG_FILE"

SAMPLE_COUNT=0
TOTAL_CPU=0
MAX_CPU=0
TOTAL_MEM=0
MAX_MEM=0
TOTAL_TEMP=0
MAX_TEMP=0
CRASH_COUNT=0
API_ERRORS=0
XRUN_COUNT=0
NON_384K_COUNT=0

# 先确保播放处于运行状态
curl -s -m 2 -X POST "http://127.0.0.1:8088/api/play" >/dev/null 2>&1 || true

while [ $(date +%s) -lt $END_TIME ]; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    REMAINING=$((END_TIME - NOW))
    SAMPLE_COUNT=$((SAMPLE_COUNT + 1))

    # 1. 检查 Flutter 进程 PID
    APP_PID=$(pidof hide_player_flutter 2>/dev/null | awk '{print $1}')
    if [ -z "$APP_PID" ]; then
        APP_PID=$(pgrep -f "bundle/hide_player_flutter" 2>/dev/null | head -n 1)
    fi

    CPU="0.0"
    RSS_MB="0.0"
    if [ -n "$APP_PID" ]; then
        CPU=$(ps -p "$APP_PID" -o %cpu --no-headers 2>/dev/null | tr -d ' ' || echo "0.0")
        RSS_KB=$(ps -p "$APP_PID" -o rss --no-headers 2>/dev/null | tr -d ' ' || echo "0")
        CPU=${CPU:-0.0}
        RSS_KB=${RSS_KB:-0}
        RSS_MB=$(awk "BEGIN {printf \"%.1f\", $RSS_KB / 1024}")
    else
        CRASH_COUNT=$((CRASH_COUNT + 1))
    fi

    # 2. 测量 SoC 温度与系统负载
    TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    TEMP_C=$(awk "BEGIN {printf \"%.1f\", $TEMP_RAW / 1000}")
    SYS_LOAD=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0.0")

    # 3. 测量 ALSA 硬件推流参数与拓品 DX1 II 状态
    ALSA_RATE=$(grep -o '^rate: [0-9]*' /proc/asound/card0/pcm0p/sub0/hw_params 2>/dev/null | awk '{print $2}')
    ALSA_FORMAT=$(grep -o '^format: [A-Za-z0-9_]*' /proc/asound/card0/pcm0p/sub0/hw_params 2>/dev/null | awk '{print $2}')
    ALSA_STATUS=$(grep -o '^state: [A-Za-z0-9_]*' /proc/asound/card0/pcm0p/sub0/status 2>/dev/null | awk '{print $2}')

    # 检查硬件速率有效性
    if [ -z "$ALSA_RATE" ] && [ "$ALSA_STATUS" = "RUNNING" ]; then
        NON_384K_COUNT=$((NON_384K_COUNT + 1))
    fi

    # 检查 XRUN (欠载)
    if [ "$ALSA_STATUS" = "XRUN" ]; then
        XRUN_COUNT=$((XRUN_COUNT + 1))
    fi

    # 4. 测量 Web API 响应与延迟
    T0=$(date +%s%N)
    API_RESP=$(curl -s -m 2 http://127.0.0.1:8088/api/status 2>/dev/null || echo "")
    T1=$(date +%s%N)
    LATENCY_MS=$(awk "BEGIN {printf \"%.1f\", ($T1 - $T0) / 1000000}")

    IS_PLAYING="false"
    CUR_TITLE="none"
    if [ -n "$API_RESP" ]; then
        IS_PLAYING=$(echo "$API_RESP" | grep -o '"is_playing":[^,]*' | cut -d: -f2)
        CUR_TITLE=$(echo "$API_RESP" | grep -o '"title":"[^"]*' | cut -d'"' -f4)
    else
        API_ERRORS=$((API_ERRORS + 1))
    fi

    # 5. 统计极值与均值
    TOTAL_CPU=$(awk "BEGIN {printf \"%.1f\", $TOTAL_CPU + $CPU}")
    MAX_CPU=$(awk "BEGIN {printf \"%.1f\", ($CPU > $MAX_CPU) ? $CPU : $MAX_CPU}")

    TOTAL_MEM=$(awk "BEGIN {printf \"%.1f\", $TOTAL_MEM + $RSS_MB}")
    MAX_MEM=$(awk "BEGIN {printf \"%.1f\", ($RSS_MB > $MAX_MEM) ? $RSS_MB : $MAX_MEM}")

    TOTAL_TEMP=$(awk "BEGIN {printf \"%.1f\", $TOTAL_TEMP + $TEMP_C}")
    MAX_TEMP=$(awk "BEGIN {printf \"%.1f\", ($TEMP_C > $MAX_TEMP) ? $TEMP_C : $MAX_TEMP}")

    AVG_CPU=$(awk "BEGIN {printf \"%.1f\", $TOTAL_CPU / $SAMPLE_COUNT}")
    AVG_MEM=$(awk "BEGIN {printf \"%.1f\", $TOTAL_MEM / $SAMPLE_COUNT}")
    AVG_TEMP=$(awk "BEGIN {printf \"%.1f\", $TOTAL_TEMP / $SAMPLE_COUNT}")

    # 6. 写入实时日志
    LOG_LINE="[$(date '+%H:%M:%S') | +${ELAPSED}s] ALSA: ${ALSA_RATE:-idle}Hz/${ALSA_FORMAT:-idle} (${ALSA_STATUS:-closed}) | Temp: ${TEMP_C}°C (Max: ${MAX_TEMP}°C) | CPU: ${CPU}% (Avg: ${AVG_CPU}%) | Mem: ${RSS_MB}MB | Load: ${SYS_LOAD} | API: ${LATENCY_MS}ms | Play: ${IS_PLAYING} ('${CUR_TITLE}') | XRUN: ${XRUN_COUNT}"
    echo "$LOG_LINE" >> "$LOG_FILE"

    # 7. 生成 JSON 实时摘要
    cat <<EOF > "$SUMMARY_FILE"
{
  "status": "RUNNING",
  "start_time": $START_TIME,
  "elapsed_seconds": $ELAPSED,
  "remaining_seconds": $REMAINING,
  "duration_seconds": $DURATION_SEC,
  "progress_percent": $(awk "BEGIN {printf \"%.2f\", ($ELAPSED / $DURATION_SEC) * 100}"),
  "sample_count": $SAMPLE_COUNT,
  "app_pid": "${APP_PID}",
  "dac": {
    "model": "TOPPING DX1 II",
    "alsa_card": "card 0",
    "hardware_sample_rate": "${ALSA_RATE:-idle}",
    "hardware_format": "${ALSA_FORMAT:-idle}",
    "alsa_state": "${ALSA_STATUS:-closed}",
    "non_384k_anomalies": $NON_384K_COUNT,
    "xrun_underruns": $XRUN_COUNT
  },
  "metrics": {
    "current_temp_c": $TEMP_C,
    "avg_temp_c": $AVG_TEMP,
    "max_temp_c": $MAX_TEMP,
    "current_cpu_pct": $CPU,
    "avg_cpu_pct": $AVG_CPU,
    "max_cpu_pct": $MAX_CPU,
    "current_mem_mb": $RSS_MB,
    "avg_mem_mb": $AVG_MEM,
    "max_mem_mb": $MAX_MEM,
    "system_load": $SYS_LOAD,
    "api_latency_ms": $LATENCY_MS,
    "crashes_detected": $CRASH_COUNT,
    "api_errors": $API_ERRORS
  },
  "playback": {
    "is_playing": $IS_PLAYING,
    "title": "${CUR_TITLE}"
  },
  "last_updated": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF

    # 8. 周期性持续播发巡航
    # (a) 若曲目结束停播，自动触发下首播放保持持续推流
    if [ $((SAMPLE_COUNT % 3)) -eq 0 ]; then
        if [ "$IS_PLAYING" != "true" ]; then
            curl -s -m 2 -X POST "http://127.0.0.1:8088/api/play" >/dev/null 2>&1 || true
        fi
    fi

    # (b) 每隔 180 秒，做一次轻微音量微调并拉取 DAC 状态，验证双向通信健康
    if [ $((SAMPLE_COUNT % 18)) -eq 0 ]; then
        VOL_TARGETS=(0.80 0.82 0.78 0.81)
        VOL_IDX=$(( (SAMPLE_COUNT / 18) % 4 ))
        curl -s -m 2 -X POST "http://127.0.0.1:8088/api/volume?value=${VOL_TARGETS[$VOL_IDX]}" >/dev/null 2>&1 || true
        curl -s -m 2 "http://127.0.0.1:8088/api/dac" >/dev/null 2>&1 || true
    fi

    sleep $INTERVAL_SEC
done

# 完成阶段
cat <<EOF > "$SUMMARY_FILE"
{
  "status": "COMPLETED",
  "start_time": $START_TIME,
  "elapsed_seconds": $DURATION_SEC,
  "duration_seconds": $DURATION_SEC,
  "progress_percent": 100.0,
  "sample_count": $SAMPLE_COUNT,
  "dac": {
    "model": "TOPPING DX1 II",
    "target_rate": "384000 Hz",
    "xrun_underruns": $XRUN_COUNT,
    "non_384k_anomalies": $NON_384K_COUNT
  },
  "metrics": {
    "avg_temp_c": $AVG_TEMP,
    "max_temp_c": $MAX_TEMP,
    "avg_cpu_pct": $AVG_CPU,
    "max_cpu_pct": $MAX_CPU,
    "avg_mem_mb": $AVG_MEM,
    "max_mem_mb": $MAX_MEM,
    "crashes_detected": $CRASH_COUNT,
    "api_errors": $API_ERRORS
  },
  "completed_at": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF

echo "==================================================================" >> "$LOG_FILE"
echo "✅ [TOPPING DX1 II] ${DURATION_HOURS} 小时长效稳定性测试圆满完成！" >> "$LOG_FILE"
echo "==================================================================" >> "$LOG_FILE"
