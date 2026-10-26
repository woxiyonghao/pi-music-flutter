#include "audio_engine/decoders/PcmRateDecoder.hpp"
#include <cassert>
#include <iostream>

using namespace audio_engine;
class Tone final : public IAudioDecoder {
public:
    explicit Tone(uint32_t rate, double frequency = 1000) : rate_(rate), frequency_(frequency) {}
    bool open(const std::string&) override { frame_ = 0; return true; }
    uint64_t readFrames(float* out, uint64_t count) override {
        count = std::min<uint64_t>(count, rate_ - frame_);
        for (uint64_t i = 0; i < count; ++i, ++frame_) {
            out[2*i] = float(std::sin(2 * std::numbers::pi * frequency_ * frame_ / rate_));
            out[2*i+1] = -out[2*i];
        }
        return count;
    }
    bool seek(double seconds) override { frame_ = std::min<uint64_t>(rate_, std::llround(seconds * rate_)); return true; }
    double getDuration() const override { return 1; }
    AudioFormatSpec getSpec() const override { return {rate_, 2, 32, SampleFormat::Float32}; }
    void close() override {}
private:
    uint32_t rate_; double frequency_; uint64_t frame_ = 0;
};
static void require(bool value) { if (!value) throw std::runtime_error("PCM conversion regression"); }
int main() {
    for (const auto [in, out] : {std::pair{44100u,96000u}, {96000u,44100u}, {352800u,48000u}}) {
        PcmRateDecoder converter(std::make_unique<Tone>(in), out);
        std::vector<float> data(2 * 997), all;
        while (const auto count = converter.readFrames(data.data(), 997)) all.insert(all.end(),data.begin(),data.begin()+2*count);
        require(std::abs(int64_t(all.size()/2)-out) <= 1);
        double error = 0;
        for (size_t frame = 1000; frame+1000 < all.size()/2; ++frame) {
            const double expected = std::sin(2*std::numbers::pi*1000*frame/out);
            error += std::pow(all[frame*2]-expected,2);
            require(std::abs(all[frame*2]+all[frame*2+1]) < 1e-6);
        }
        require(std::sqrt(error/(out-2000)) < 0.001);
        require(converter.seek(0.5));
        uint64_t remaining = 0;
        while (const auto count = converter.readFrames(data.data(), 997)) remaining += count;
        require(std::abs(int64_t(remaining)-out/2) <= 1);
    }
    PcmRateDecoder downsample(std::make_unique<Tone>(96000, 30000), 44100);
    std::vector<float> data(2*44100);
    require(downsample.readFrames(data.data(),44100)==44100);
    double energy = 0;
    for (size_t i=2000; i<42000; ++i) energy += data[2*i]*data[2*i];
    require(std::sqrt(energy/40000) < 0.001);
    std::cout << "PCM conversion duration, pitch, channel isolation, seek, EOF and anti-aliasing passed\n";
}
