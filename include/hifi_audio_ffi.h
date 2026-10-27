#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
    #define HIFI_EXPORT __declspec(dllexport)
#else
    #define HIFI_EXPORT __attribute__((visibility("default")))
#endif

/**
 * @brief HiFi 发烧音频核心 C-API 导出接口 (供 Flutter dart:ffi 绑定调用)
 */

enum HifiOutputPolicy {
    HIFI_EXCLUDE_DISPLAY_OUTPUTS = 1,
    HIFI_SYNCHRONIZE_SYSTEM_OUTPUT = 2,
    HIFI_PREFER_REMOTE_IO = 4,
    HIFI_PREFER_EXTERNAL_OUTPUT = 8
};

// 1. 引擎生命周期
// ABI 2: host configures its own audio session, then injects platform and policy.
HIFI_EXPORT uint32_t hifi_audio_get_abi_version();
HIFI_EXPORT bool hifi_audio_init_for_platform(const char* platform, uint32_t output_policies);
HIFI_EXPORT const char* hifi_audio_get_capabilities_json();
HIFI_EXPORT bool hifi_audio_update_host_output(uint32_t sample_rate, uint32_t channels,
    const char* device_id, const char* device_name, const char* transport);
HIFI_EXPORT void hifi_audio_set_hardware_buffer_frames(uint32_t frames);
HIFI_EXPORT bool hifi_audio_init();

// 2. 播放与曲目控制
HIFI_EXPORT bool hifi_audio_open_and_play(const char* filepath);
HIFI_EXPORT bool hifi_audio_open_and_play_section(const char* filepath, double start_sec, double end_sec);
HIFI_EXPORT void hifi_audio_play();
HIFI_EXPORT void hifi_audio_pause();
HIFI_EXPORT void hifi_audio_toggle();
HIFI_EXPORT void hifi_audio_stop();
HIFI_EXPORT void hifi_audio_seek(double target_seconds);

// 3. 状态查询
HIFI_EXPORT bool hifi_audio_is_playing();
HIFI_EXPORT bool hifi_audio_is_paused();
HIFI_EXPORT bool hifi_audio_is_idle();
HIFI_EXPORT bool hifi_audio_has_playback_completed();
HIFI_EXPORT double hifi_audio_get_current_time();
HIFI_EXPORT double hifi_audio_get_duration();
HIFI_EXPORT float hifi_audio_get_progress();

// 4. 音量与 Bit-Perfect 源码输出控制 (0.0f ~ 1.0f)
HIFI_EXPORT void hifi_audio_set_volume(float volume);
HIFI_EXPORT float hifi_audio_get_volume();
HIFI_EXPORT void hifi_audio_set_muted(bool muted);
HIFI_EXPORT bool hifi_audio_is_muted();
HIFI_EXPORT bool hifi_audio_is_bit_perfect();

// 5. 10段图形均衡器控制 (RBJ Audio EQ 二阶 IIR 滤波)
HIFI_EXPORT void hifi_audio_set_eq_enabled(bool enabled);
HIFI_EXPORT bool hifi_audio_is_eq_enabled();
HIFI_EXPORT void hifi_audio_set_eq_bands(const float* gains_10);
HIFI_EXPORT void hifi_audio_get_eq_bands(float* out_gains_10);

// 6. 实时动效与表头渲染核心 (60fps 刷新 12 频段振幅数据与 VU 表头阻尼计算)
HIFI_EXPORT void hifi_audio_get_spectrum_levels(float* out_levels_12);

// 7. 硬件声卡状态
HIFI_EXPORT uint32_t hifi_audio_get_sample_rate();
HIFI_EXPORT void hifi_audio_get_device_name(char* out_buf, int max_len);

// 8. 播放完毕 (EOF) 回调函数类型与注册
typedef void (*HifiEofCallback)();
HIFI_EXPORT void hifi_audio_set_eof_callback(HifiEofCallback callback);

// 9. 动态 DAC 外设与芯片画像识别 (返回 JSON 字符串数组)
HIFI_EXPORT const char* hifi_audio_get_connected_devices_json();
HIFI_EXPORT bool hifi_audio_select_output_device(const char* device_id);
// Android: preferences reopen the AAudio stream, preserving playback position.
// State reports negotiated application stream format, not USB hardware encoding.
HIFI_EXPORT bool hifi_audio_configure_android_output(int32_t device_id, uint32_t sample_rate, bool exclusive);
HIFI_EXPORT const char* hifi_audio_get_android_output_state_json();
HIFI_EXPORT void hifi_audio_set_external_device_mock(bool enable);
HIFI_EXPORT bool hifi_audio_is_external_device_mock();
HIFI_EXPORT const char* hifi_audio_get_diagnostics_json();

// 10. Shared library/database core; independent of audio-session initialization.
HIFI_EXPORT const char* hifi_library_scan_json(const char* database, const char* const* roots,
    uint32_t root_count, const char* documents_root, uint32_t flags);
HIFI_EXPORT const char* hifi_library_metadata_json(const char* file);
HIFI_EXPORT void* hifi_library_db_open(const char* database);
HIFI_EXPORT void hifi_library_db_close(void* database);
HIFI_EXPORT const char* hifi_library_db_query_json(void* database, const char* sql, const char* parameters_json);

#ifdef __cplusplus
}
#endif
