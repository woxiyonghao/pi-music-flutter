#pragma once

#include "audio_engine/IAudioDecoder.hpp"
#include <atomic>
#include <cstdint>
#include <string>
#include <vector>

#if defined(HIFI_HAS_ALSA)
#include <alsa/asoundlib.h>
#endif

namespace audio_engine {

/**
 * @brief Live ALSA capture decoder (e.g. from snd-aloop) feeding external
 * Bluetooth / AirPlay audio streams through AudioEngine EQ & spectrum DSP.
 */
class AlsaCaptureDecoder final : public IAudioDecoder {
public:
    AlsaCaptureDecoder() = default;
    ~AlsaCaptureDecoder() override;

    bool open(const std::string& device_name) override;
    uint64_t readFrames(float* buffer, uint64_t max_frames) override;
    bool seek(double target_seconds) override;
    double getDuration() const override { return 0.0; }
    AudioFormatSpec getSpec() const override { return spec_; }
    void close() override;

private:
    AudioFormatSpec spec_{44100, 2, 32, SampleFormat::Float32};
    std::atomic<bool> closed_{true};
#if defined(HIFI_HAS_ALSA)
    snd_pcm_t* pcm_ = nullptr;
    std::vector<int32_t> raw_buf_;
#endif
};

} // namespace audio_engine
