#include "audio_engine/decoders/AlsaCaptureDecoder.hpp"
#include <algorithm>
#include <cerrno>
#include <iostream>

namespace audio_engine {

AlsaCaptureDecoder::~AlsaCaptureDecoder() {
    close();
}

bool AlsaCaptureDecoder::open(const std::string& device_name) {
    close();
#if !defined(HIFI_HAS_ALSA)
    (void)device_name;
    return false;
#else
    const std::string target = device_name.empty() ? "plughw:CARD=PhonoraLoop,DEV=1,SUBDEV=0" : device_name;
    int err = snd_pcm_open(&pcm_, target.c_str(), SND_PCM_STREAM_CAPTURE, 0);
    if (err < 0) {
        std::cerr << "[AlsaCaptureDecoder] snd_pcm_open(" << target << ") failed: "
                  << snd_strerror(err) << std::endl;
        pcm_ = nullptr;
        return false;
    }

    unsigned int rate = 44100;
    snd_pcm_uframes_t period = 512;
    snd_pcm_uframes_t buffer_frames = 4096;

    snd_pcm_hw_params_t* hw = nullptr;
    snd_pcm_hw_params_alloca(&hw);
    if ((err = snd_pcm_hw_params_any(pcm_, hw)) < 0 ||
        (err = snd_pcm_hw_params_set_access(pcm_, hw, SND_PCM_ACCESS_RW_INTERLEAVED)) < 0 ||
        (err = snd_pcm_hw_params_set_format(pcm_, hw, SND_PCM_FORMAT_S32_LE)) < 0 ||
        (err = snd_pcm_hw_params_set_channels(pcm_, hw, 2)) < 0 ||
        (err = snd_pcm_hw_params_set_rate_near(pcm_, hw, &rate, nullptr)) < 0 ||
        (err = snd_pcm_hw_params_set_period_size_near(pcm_, hw, &period, nullptr)) < 0 ||
        (err = snd_pcm_hw_params_set_buffer_size_near(pcm_, hw, &buffer_frames)) < 0 ||
        (err = snd_pcm_hw_params(pcm_, hw)) < 0) {
        std::cerr << "[AlsaCaptureDecoder] hw_params failed: " << snd_strerror(err) << std::endl;
        snd_pcm_close(pcm_);
        pcm_ = nullptr;
        return false;
    }

    if ((err = snd_pcm_prepare(pcm_)) < 0 || (err = snd_pcm_start(pcm_)) < 0) {
        std::cerr << "[AlsaCaptureDecoder] snd_pcm_prepare/start failed: " << snd_strerror(err) << std::endl;
        snd_pcm_close(pcm_);
        pcm_ = nullptr;
        return false;
    }

    spec_ = AudioFormatSpec{rate, 2, 32, SampleFormat::Float32};
    closed_.store(false, std::memory_order_release);
    std::cout << "[AlsaCaptureDecoder] Opened capture " << target << " @ " << rate << " Hz" << std::endl;
    return true;
#endif
}

uint64_t AlsaCaptureDecoder::readFrames(float* buffer, uint64_t max_frames) {
#if !defined(HIFI_HAS_ALSA)
    (void)buffer;
    (void)max_frames;
    return 0;
#else
    if (closed_.load(std::memory_order_acquire) || !pcm_ || !buffer || max_frames == 0) {
        return 0;
    }

    if (snd_pcm_state(pcm_) == SND_PCM_STATE_PREPARED) {
        snd_pcm_start(pcm_);
    }

    // Bounded wait so stop()/close() never blocks decode_thread_join.
    int ready = snd_pcm_wait(pcm_, 40);
    if (ready == 0 || closed_.load(std::memory_order_acquire)) {
        return 0;
    }
    if (ready < 0) {
        if (ready == -EPIPE || ready == -ESTRPIPE) {
            snd_pcm_recover(pcm_, ready, 1);
            snd_pcm_start(pcm_);
        }
        return 0;
    }

    const size_t wanted = static_cast<size_t>(std::min<uint64_t>(max_frames, 2048));
    raw_buf_.resize(wanted * 2);
    snd_pcm_sframes_t got = snd_pcm_readi(pcm_, raw_buf_.data(), wanted);
    if (got < 0) {
        if (got == -EPIPE || got == -ESTRPIPE) {
            snd_pcm_recover(pcm_, static_cast<int>(got), 1);
            snd_pcm_start(pcm_);
        }
        return 0;
    }

    constexpr float kScale = 1.0f / 2147483648.0f;
    const size_t total_samples = static_cast<size_t>(got) * 2;
    for (size_t i = 0; i < total_samples; ++i) {
        buffer[i] = static_cast<float>(raw_buf_[i]) * kScale;
    }
    return static_cast<uint64_t>(got);
#endif
}

bool AlsaCaptureDecoder::seek(double /*target_seconds*/) {
    return false;
}

void AlsaCaptureDecoder::close() {
    closed_.store(true, std::memory_order_release);
#if defined(HIFI_HAS_ALSA)
    if (pcm_) {
        snd_pcm_drop(pcm_);
        snd_pcm_close(pcm_);
        pcm_ = nullptr;
    }
    raw_buf_.clear();
#endif
}

} // namespace audio_engine
