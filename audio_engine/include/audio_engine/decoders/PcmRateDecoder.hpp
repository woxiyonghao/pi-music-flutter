#pragma once

#include "audio_engine/IAudioDecoder.hpp"
#include <algorithm>
#include <cmath>
#include <memory>
#include <numbers>
#include <vector>

namespace audio_engine {

// Streaming windowed-sinc conversion on the decoder thread. The real-time
// callback only consumes already-converted PCM. Keeps time and CUE boundaries
// in seconds when AAudio's stream rate differs from the source.
class PcmRateDecoder final : public IAudioDecoder {
public:
    PcmRateDecoder(std::unique_ptr<IAudioDecoder> source, uint32_t output_rate)
        : source_(std::move(source)), spec_(source_->getSpec()), input_rate_(spec_.sample_rate) {
        spec_.sample_rate = output_rate;
        spec_.bit_depth = 32;
        spec_.format = SampleFormat::Float32;
        const double cutoff = std::min(1.0, double(output_rate) / input_rate_) * 0.94;
        radius_ = std::min(512, int(std::ceil(32 / cutoff)));
        kernels_.resize(phases_ * radius_ * 2);
        for (int phase = 0; phase < phases_; ++phase) {
            double sum = 0;
            for (int tap = 0; tap < radius_ * 2; ++tap) {
                const double x = tap - radius_ + 1 - double(phase) / phases_;
                const double z = x * cutoff;
                const double sinc = std::abs(z) < 1e-12 ? 1 : std::sin(std::numbers::pi * z) / (std::numbers::pi * z);
                const double window = std::abs(x) >= radius_ ? 0 :
                    0.42 + 0.5 * std::cos(std::numbers::pi * x / radius_) + 0.08 * std::cos(2 * std::numbers::pi * x / radius_);
                const double weight = cutoff * sinc * window;
                kernels_[phase * radius_ * 2 + tap] = float(weight);
                sum += weight;
            }
            for (int tap = 0; tap < radius_ * 2; ++tap) kernels_[phase * radius_ * 2 + tap] /= float(sum);
        }
        scratch_.resize(4096 * spec_.channels);
    }

    bool open(const std::string& path) override { reset(); return source_->open(path); }
    uint64_t readFrames(float* output, uint64_t max_frames) override {
        if (!output || !spec_.sample_rate || !input_rate_) return 0;
        uint64_t produced = 0;
        while (produced < max_frames) {
            const double position = double(output_frames_) * input_rate_ / spec_.sample_rate;
            const auto center = static_cast<int64_t>(std::floor(position));
            while (!eof_ && input_frames_ <= center + radius_) {
                const auto count = source_->readFrames(scratch_.data(), 4096);
                if (!count) { eof_ = true; break; }
                input_.insert(input_.end(), scratch_.begin(), scratch_.begin() + count * spec_.channels);
                input_frames_ += count;
            }
            if (eof_ && position >= input_frames_) break;
            const int phase = std::min(phases_ - 1, int((position - center) * phases_));
            const auto* kernel = kernels_.data() + phase * radius_ * 2;
            for (uint32_t channel = 0; channel < spec_.channels; ++channel) {
                double sample = 0;
                for (int tap = 0; tap < radius_ * 2; ++tap) {
                    const auto frame = center + tap - radius_ + 1;
                    if (frame >= base_frame_ && frame < input_frames_)
                        sample += input_[(frame - base_frame_) * spec_.channels + channel] * kernel[tap];
                }
                output[produced * spec_.channels + channel] = float(sample);
            }
            ++output_frames_;
            ++produced;
            const auto discard = center - radius_ - base_frame_;
            if (discard >= 4096) {
                input_.erase(input_.begin(), input_.begin() + discard * spec_.channels);
                base_frame_ += discard;
            }
        }
        return produced;
    }
    bool seek(double seconds) override {
        if (!source_->seek(seconds)) return false;
        reset();
        return true;
    }
    double getDuration() const override { return source_->getDuration(); }
    AudioFormatSpec getSpec() const override { return spec_; }
    void close() override { source_->close(); reset(); }
private:
    void reset() { input_.clear(); output_frames_ = 0; input_frames_ = base_frame_ = 0; eof_ = false; }
    static constexpr int phases_ = 1024;
    std::unique_ptr<IAudioDecoder> source_;
    AudioFormatSpec spec_;
    uint32_t input_rate_;
    int radius_;
    std::vector<float> kernels_, input_, scratch_;
    uint64_t output_frames_ = 0;
    int64_t input_frames_ = 0, base_frame_ = 0;
    bool eof_ = false;
};
} // namespace audio_engine
