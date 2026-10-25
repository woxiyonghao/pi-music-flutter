#pragma once

#include "audio_engine/IAudioDecoder.hpp"
#include <array>
#include <fstream>
#include <memory>
#include <string_view>
#include <vector>

namespace audio_engine {

// iPhone PCM path only. The legacy DsfParser remains unchanged for other clients.
// Low-pass the 1-bit stream BEFORE decimation. A byte lookup table avoids doing
// a multiply per DSD bit; CoreAudio then converts 176.4 kHz PCM to the host rate.
class IphoneDsdDecoder final : public IAudioDecoder {
public:
    bool open(const std::string& path) override;
    uint64_t readFrames(float* output, uint64_t frames) override;
    bool seek(double seconds) override;
    double getDuration() const override;
    AudioFormatSpec getSpec() const override { return spec_; }
    void close() override;

private:
    bool parseDsf(uint64_t file_size);
    bool parseDff(uint64_t file_size);
    bool configureFilter();
    bool readByte(std::array<uint8_t, 2>& bytes);
    void pushByte(const std::array<uint8_t, 2>& bytes);
    bool positionAtFrame(uint64_t frame);

    std::ifstream file_;
    AudioFormatSpec spec_;
    bool dff_ = false;
    bool lsb_first_ = true;
    uint32_t source_rate_ = 0;
    uint32_t source_channels_ = 0;
    uint32_t block_size_ = 4096;
    uint32_t ratio_ = 0;
    uint64_t samples_ = 0;
    uint64_t data_offset_ = 0;
    uint64_t data_size_ = 0;
    uint64_t total_frames_ = 0;
    uint64_t frame_ = 0;
    uint64_t byte_cursor_ = 0;
    uint64_t loaded_block_ = UINT64_MAX;
    size_t loaded_bytes_per_channel_ = 0;
    std::vector<uint8_t> input_block_;
    std::array<std::vector<uint8_t>, 2> history_;
    std::vector<std::array<float, 256>> coefficients_;
    size_t history_position_ = 0;
};

// Shared by the playback factory and its hardware-independent integration test.
std::unique_ptr<IAudioDecoder> createDsdDecoderForClient(std::string_view platform);
} // namespace audio_engine
