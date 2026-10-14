#include "hifi_audio_ffi.h"
#include "audio_engine/AudioEngine.hpp"
#include <cstring>
#include <algorithm>

extern "C" {

bool hifi_audio_init() {
    return audio_engine::AudioEngine::getInstance().init();
}

bool hifi_audio_open_and_play(const char* filepath) {
    if (!filepath) return false;
    return audio_engine::AudioEngine::getInstance().openAndPlay(filepath);
}

bool hifi_audio_open_and_play_section(const char* filepath, double start_sec, double end_sec) {
    if (!filepath) return false;
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

} // extern "C"
