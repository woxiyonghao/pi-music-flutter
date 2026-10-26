#include "hifi_audio_ffi.h"
#include "audio_engine/AudioEngine.hpp"
#include "audio_engine/RuntimeContext.hpp"
#include <cstring>
#include <algorithm>
#include <sstream>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

extern "C" {

uint32_t hifi_audio_get_abi_version() { return 2; }

bool hifi_audio_init_for_platform(const char* platform, uint32_t policies) {
    if (!platform || !audio_engine::runtimeContext().configure(platform, policies)) return false;
    return audio_engine::AudioEngine::getInstance().init();
}

bool hifi_audio_update_host_output(uint32_t rate, uint32_t channels,
        const char* id, const char* name, const char* transport) {
    if (!id || !name || !transport || !audio_engine::runtimeContext().configured()) return false;
    if (!audio_engine::runtimeContext().updateHostOutput({rate, channels, id, name, transport})) return false;
#if !defined(__ANDROID__)
    audio_engine::AudioEngine::getInstance().notifyOutputDeviceChanged();
#endif
    return true;
}

void hifi_audio_set_hardware_buffer_frames(uint32_t frames) {
    if (frames >= 64 && frames <= 16384)
        audio_engine::AudioEngine::getInstance().setHardwareBufferSize(frames);
}

const char* hifi_audio_get_capabilities_json() {
    static thread_local std::string result;
#if defined(__ANDROID__)
    const char* backend = "aaudio";
    constexpr bool enumerate = false, select = false, host_format = true;
#elif defined(__APPLE__) && TARGET_OS_IPHONE
    const char* backend = "coreaudio-ios";
    constexpr bool enumerate = true, select = false, host_format = true;
#elif defined(__APPLE__)
    const char* backend = "coreaudio-macos";
    constexpr bool enumerate = true, select = true, host_format = false;
#else
    const char* backend = "sdl";
    constexpr bool enumerate = false, select = false, host_format = false;
#endif
    std::ostringstream out;
    out << "{\"abi_version\":2,\"platform\":\"" << audio_engine::runtimeContext().platformName()
        << "\",\"backend\":\"" << backend << "\",\"decode\":true,\"pcm_conversion\":true,"
        << "\"equalizer\":true,\"software_volume\":true,\"device_enumeration\":" << (enumerate ? "true" : "false")
        << ",\"output_selection\":" << (select ? "true" : "false")
        << ",\"host_output_format\":" << (host_format ? "true" : "false")
        << ",\"session_owner\":\"host\",\"hardware_capabilities_source\":\"connected_device\"}";
    result = out.str();
    return result.c_str();
}

bool hifi_audio_init() {
    if (!audio_engine::runtimeContext().configured()) return false;
    return audio_engine::AudioEngine::getInstance().init();
}

bool hifi_audio_open_and_play(const char* filepath) {
    if (!filepath || !audio_engine::runtimeContext().configured()) return false;
    return audio_engine::AudioEngine::getInstance().openAndPlay(filepath);
}

bool hifi_audio_open_and_play_section(const char* filepath, double start_sec, double end_sec) {
    if (!filepath || !audio_engine::runtimeContext().configured()) return false;
    return audio_engine::AudioEngine::getInstance().openAndPlaySection(filepath, start_sec, end_sec);
}

void hifi_audio_play() {
    audio_engine::AudioEngine::getInstance().play();
}

void hifi_audio_pause() {
    audio_engine::AudioEngine::getInstance().pause();
}

void hifi_audio_toggle() {
    audio_engine::AudioEngine::getInstance().togglePlayPause();
}

void hifi_audio_stop() {
    audio_engine::AudioEngine::getInstance().stop();
}

void hifi_audio_seek(double target_seconds) {
    audio_engine::AudioEngine::getInstance().seek(target_seconds);
}

bool hifi_audio_is_playing() {
    return audio_engine::AudioEngine::getInstance().isPlaying();
}

bool hifi_audio_is_paused() {
    return audio_engine::AudioEngine::getInstance().isPaused();
}

bool hifi_audio_is_idle() {
    return audio_engine::AudioEngine::getInstance().isIdle();
}

bool hifi_audio_has_playback_completed() {
    return audio_engine::AudioEngine::getInstance().hasPlaybackCompleted();
}

double hifi_audio_get_current_time() {
    return audio_engine::AudioEngine::getInstance().getCurrentTimeSec();
}

double hifi_audio_get_duration() {
    return audio_engine::AudioEngine::getInstance().getDurationSec();
}

float hifi_audio_get_progress() {
    return audio_engine::AudioEngine::getInstance().getProgress();
}

void hifi_audio_set_volume(float volume) {
    audio_engine::AudioEngine::getInstance().setVolume(volume);
}

float hifi_audio_get_volume() {
    return audio_engine::AudioEngine::getInstance().getVolume();
}

void hifi_audio_set_muted(bool muted) {
    audio_engine::AudioEngine::getInstance().setMuted(muted);
}

bool hifi_audio_is_muted() {
    return audio_engine::AudioEngine::getInstance().isMuted();
}

bool hifi_audio_is_bit_perfect() {
    return audio_engine::AudioEngine::getInstance().isBitPerfectDirect();
}

void hifi_audio_set_eq_enabled(bool enabled) {
    audio_engine::AudioEngine::getInstance().setEqEnabled(enabled);
}

bool hifi_audio_is_eq_enabled() {
    return audio_engine::AudioEngine::getInstance().isEqEnabled();
}

void hifi_audio_set_eq_bands(const float* gains_10) {
    if (!gains_10) return;
    std::array<float, 10> bands{};
    for (size_t i = 0; i < 10; ++i) {
        bands[i] = gains_10[i];
    }
    audio_engine::AudioEngine::getInstance().setEqBands(bands);
}

void hifi_audio_get_eq_bands(float* out_gains_10) {
    if (!out_gains_10) return;
    auto bands = audio_engine::AudioEngine::getInstance().getEqBands();
    for (size_t i = 0; i < 10; ++i) {
        out_gains_10[i] = bands[i];
    }
}

void hifi_audio_get_spectrum_levels(float* out_levels_12) {
    if (!out_levels_12) return;
    audio_engine::AudioEngine::getInstance().getSpectrumLevels(out_levels_12, 12);
}

uint32_t hifi_audio_get_sample_rate() {
    return audio_engine::AudioEngine::getInstance().getActiveHardwareSampleRate();
}

void hifi_audio_get_device_name(char* out_buf, int max_len) {
    if (!out_buf || max_len <= 0) return;
    std::string name = audio_engine::AudioEngine::getInstance().getActiveHardwareDeviceName();
    strncpy(out_buf, name.c_str(), max_len - 1);
    out_buf[max_len - 1] = '\0';
}

static HifiEofCallback g_eof_callback = nullptr;

void hifi_audio_set_eof_callback(HifiEofCallback callback) {
    g_eof_callback = callback;
    if (g_eof_callback) {
        audio_engine::AudioEngine::getInstance().setEofCallback([]() {
            if (g_eof_callback) {
                g_eof_callback();
            }
        });
    } else {
        audio_engine::AudioEngine::getInstance().setEofCallback(nullptr);
    }
}

static thread_local std::string g_devices_json_cache;

const char* hifi_audio_get_connected_devices_json() {
    g_devices_json_cache = audio_engine::AudioEngine::getInstance().getConnectedDevicesJson();
    return g_devices_json_cache.c_str();
}

bool hifi_audio_configure_android_output(int32_t id, uint32_t rate, bool exclusive) {
    if (!audio_engine::runtimeContext().configured()) return false;
    return audio_engine::AudioEngine::getInstance().configureAndroidOutput(id, rate, exclusive);
}

const char* hifi_audio_get_android_output_state_json() {
    static thread_local std::string state;
    state = audio_engine::AudioEngine::getInstance().getAndroidOutputStateJson();
    return state.c_str();
}

bool hifi_audio_select_output_device(const char* device_id) {
    if (!device_id) return false;
    return audio_engine::AudioEngine::getInstance().selectOutputDevice(device_id);
}

void hifi_audio_set_external_device_mock(bool enable) {
    audio_engine::AudioEngine::getInstance().setExternalDeviceMock(enable);
}

bool hifi_audio_is_external_device_mock() {
    return audio_engine::AudioEngine::getInstance().isExternalDeviceMock();
}

const char* hifi_audio_get_diagnostics_json() {
    static thread_local std::string diagnostics;
    diagnostics = audio_engine::AudioEngine::getInstance().getDiagnosticsJson();
    return diagnostics.c_str();
}

} // extern "C"
