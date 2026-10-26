#include "audio_engine/IphoneDsdDecoder.hpp"
#include "audio_engine/DsfParser.hpp"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <limits>

namespace audio_engine {
namespace {
bool readBytes(std::ifstream& file, void* value, size_t size) {
    return bool(file.read(static_cast<char*>(value), static_cast<std::streamsize>(size)));
}
uint64_t integer(std::ifstream& file, size_t count, bool little) {
    uint8_t bytes[8]{};
    if (!readBytes(file, bytes, count)) return 0;
    uint64_t value = 0;
    for (size_t i = 0; i < count; ++i)
        value |= uint64_t(bytes[i]) << (8 * (little ? i : count - 1 - i));
    return value;
}
bool jump(std::ifstream& file, uint64_t offset) {
    file.clear();
    return bool(file.seekg(static_cast<std::streamoff>(offset)));
}
uint8_t reverse(uint8_t value) {
    value = ((value & 0x55) << 1) | ((value >> 1) & 0x55);
    value = ((value & 0x33) << 2) | ((value >> 2) & 0x33);
    return uint8_t((value << 4) | (value >> 4));
}
double bessel0(double x) {
    double sum = 1, term = 1;
    for (unsigned k = 1; k < 64; ++k) {
        term *= x * x / (4.0 * k * k);
        sum += term;
        if (term < sum * 1e-16) break;
    }
    return sum;
}
constexpr double pi = 3.1415926535897932384626433832795;
constexpr uint32_t pcm_rate = 176400;
} // namespace

bool IphoneDsdDecoder::open(const std::string& path) {
    close();
    file_.open(path, std::ios::binary | std::ios::ate);
    if (!file_) return false;
    const auto end = file_.tellg();
    if (end < 28) { close(); return false; }
    const auto size = static_cast<uint64_t>(end);
    jump(file_, 0);
    char magic[4]{};
    if (!readBytes(file_, magic, 4)) { close(); return false; }
    const bool parsed = std::memcmp(magic, "DSD ", 4) == 0 ? parseDsf(size)
        : std::memcmp(magic, "FRM8", 4) == 0 && parseDff(size);
    // Common DSD64 … DSD512 rates; reject unknown clocks rather than truncate
    // the sample rate or silently change the speed of the recording.
    if (!parsed || source_rate_ < 2822400 || source_rate_ > 22579200 ||
        source_rate_ % pcm_rate != 0 || source_channels_ < 1 ||
        source_channels_ > 8 || samples_ == 0) { close(); return false; }
    ratio_ = source_rate_ / pcm_rate;
    if ((ratio_ & (ratio_ - 1)) != 0) { close(); return false; }
    spec_.sample_rate = pcm_rate;
    spec_.channels = std::min(source_channels_, 2u);
    spec_.bit_depth = 32;
    spec_.format = SampleFormat::Float32;
    total_frames_ = samples_ / ratio_;
    if (!total_frames_ || !configureFilter() || !positionAtFrame(0)) {
        close(); return false;
    }
    return true;
}

bool IphoneDsdDecoder::parseDsf(uint64_t file_size) {
    dff_ = false;
    const auto header_size = integer(file_, 8, true);
    if (header_size != 28 || !jump(file_, 28)) return false;
    bool format_found = false;
    while (file_ && uint64_t(file_.tellg()) <= file_size - 12) {
        char id[4]{};
        if (!readBytes(file_, id, 4)) return false;
        const auto size = integer(file_, 8, true);
        const auto payload = uint64_t(file_.tellg());
        if (size < 12 || size - 12 > file_size - payload) return false;
        if (std::memcmp(id, "fmt ", 4) == 0) {
            if (size < 52) return false;
            const auto version = integer(file_, 4, true);
            const auto format = integer(file_, 4, true);
            integer(file_, 4, true); // channel layout (first L/R channels retained)
            source_channels_ = uint32_t(integer(file_, 4, true));
            source_rate_ = uint32_t(integer(file_, 4, true));
            const auto order = integer(file_, 4, true);
            samples_ = integer(file_, 8, true);
            block_size_ = uint32_t(integer(file_, 4, true));
            if (version != 1 || format != 0 || (order != 1 && order != 8) ||
                !block_size_ || block_size_ > 1048576 || block_size_ % 8) return false;
            lsb_first_ = order == 1;
            format_found = true;
        } else if (std::memcmp(id, "data", 4) == 0) {
            if (!format_found || !source_channels_) return false;
            data_offset_ = payload;
            data_size_ = size - 12;
            const auto bytes = samples_ / 8 + (samples_ % 8 != 0);
            const auto blocks = bytes / block_size_ + (bytes % block_size_ != 0);
            if (blocks > std::numeric_limits<uint64_t>::max() / block_size_ / source_channels_)
                return false;
            return blocks * block_size_ * source_channels_ <= data_size_;
        }
        if (!jump(file_, payload + size - 12)) return false;
    }
    return false;
}

bool IphoneDsdDecoder::parseDff(uint64_t file_size) {
    dff_ = true;
    lsb_first_ = false;
    const auto form_size = integer(file_, 8, false);
    char form[4]{};
    if (form_size < 4 || form_size > file_size - 12 ||
        !readBytes(file_, form, 4) || std::memcmp(form, "DSD ", 4)) return false;
    const auto form_end = form_size + 12;
    while (file_ && uint64_t(file_.tellg()) <= form_end - 12) {
        char id[4]{};
        if (!readBytes(file_, id, 4)) return false;
        const auto size = integer(file_, 8, false);
        const auto payload = uint64_t(file_.tellg());
        if (size > form_end - payload) return false;
        if (std::memcmp(id, "PROP", 4) == 0) {
            char type[4]{};
            if (size < 4 || !readBytes(file_, type, 4) || std::memcmp(type, "SND ", 4)) return false;
            const auto prop_end = payload + size;
            while (file_ && uint64_t(file_.tellg()) + 12 <= prop_end) {
                char sub_id[4]{};
                if (!readBytes(file_, sub_id, 4)) return false;
                const auto sub_size = integer(file_, 8, false);
                const auto sub_payload = uint64_t(file_.tellg());
                if (sub_size > prop_end - sub_payload) return false;
                if (std::memcmp(sub_id, "FS  ", 4) == 0) {
                    if (sub_size < 4) return false;
                    source_rate_ = uint32_t(integer(file_, 4, false));
                } else if (std::memcmp(sub_id, "CHNL", 4) == 0) {
                    if (sub_size < 2) return false;
                    source_channels_ = uint32_t(integer(file_, 2, false));
                } else if (std::memcmp(sub_id, "CMPR", 4) == 0) {
                    char compression[4]{};
                    if (sub_size < 4 || !readBytes(file_, compression, 4) ||
                        std::memcmp(compression, "DSD ", 4)) return false;
                }
                if (!jump(file_, sub_payload + sub_size + (sub_size & 1))) return false;
            }
        } else if (std::memcmp(id, "DSD ", 4) == 0) {
            if (!source_rate_ || !source_channels_ || size % source_channels_) return false;
            data_offset_ = payload;
            data_size_ = size;
            samples_ = (size / source_channels_) * 8;
            return true;
        } else if (std::memcmp(id, "DST ", 4) == 0) {
            return false; // Compressed DST requires a real DST decoder.
        }
        if (!jump(file_, payload + size + (size & 1))) return false;
    }
    return false;
}

bool IphoneDsdDecoder::configureFilter() {
    // Kaiser-windowed sinc: 40 kHz cutoff, >100 dB stop-band rejection before
    // 176.4 kHz decimation. Keep the whole audible band flat; the existing
    // CoreAudio converter supplies the final host-rate antialias filter.
    const size_t taps = size_t(ratio_) * 32 + 1;
    const double middle = (taps - 1) / 2.0;
    const double cutoff = 40000.0 / source_rate_;
    const double beta = 10.2, denominator = bessel0(beta);
    std::vector<double> filter(taps);
    double sum = 0;
    for (size_t i = 0; i < taps; ++i) {
        const double position = (double(i) - middle) / middle;
        const double sinc = i == size_t(middle) ? 2 * cutoff
            : std::sin(2 * pi * cutoff * (double(i) - middle)) / (pi * (double(i) - middle));
        filter[i] = sinc * bessel0(beta * std::sqrt(std::max(0.0, 1 - position * position))) / denominator;
        sum += filter[i];
    }
    const auto groups = (taps + 7) / 8;
    coefficients_.resize(groups);
    for (size_t group = 0; group < groups; ++group)
        for (unsigned byte = 0; byte < 256; ++byte) {
            double value = 0;
            for (unsigned bit = 0; bit < 8; ++bit) {
                const auto tap = group * 8 + bit;
                if (tap < taps) value += filter[tap] / sum * ((byte & (1u << bit)) ? 1 : -1);
            }
            coefficients_[group][byte] = float(value);
        }
    for (auto& history : history_) history.assign(groups, 0xAA);
    input_block_.resize(size_t(block_size_) * source_channels_);
    return true;
}

bool IphoneDsdDecoder::readByte(std::array<uint8_t, 2>& bytes) {
    const auto byte_count = samples_ / 8 + (samples_ % 8 != 0);
    if (byte_cursor_ >= byte_count) return false;
    const auto block = byte_cursor_ / block_size_;
    const auto within = size_t(byte_cursor_ % block_size_);
    if (block != loaded_block_) {
        const auto offset = data_offset_ + block * block_size_ * source_channels_;
        loaded_bytes_per_channel_ = size_t(std::min<uint64_t>(block_size_, byte_count - block * block_size_));
        const auto bytes_to_read = dff_ ? loaded_bytes_per_channel_ * source_channels_
            : size_t(block_size_) * source_channels_;
        if (!jump(file_, offset) || !readBytes(file_, input_block_.data(), bytes_to_read)) return false;
        loaded_block_ = block;
    }
    if (within >= loaded_bytes_per_channel_) return false;
    for (unsigned ch = 0; ch < spec_.channels; ++ch) {
        auto value = input_block_[dff_ ? within * source_channels_ + ch : ch * block_size_ + within];
        bytes[ch] = lsb_first_ ? reverse(value) : value;
    }
    ++byte_cursor_;
    return true;
}

void IphoneDsdDecoder::pushByte(const std::array<uint8_t, 2>& bytes) {
    for (unsigned ch = 0; ch < spec_.channels; ++ch) history_[ch][history_position_] = bytes[ch];
    history_position_ = (history_position_ + 1) % coefficients_.size();
}

uint64_t IphoneDsdDecoder::readFrames(float* output, uint64_t requested) {
    if (!file_.is_open() || !output) return 0;
    const auto available = std::min(requested, total_frames_ - frame_);
    uint64_t decoded = 0;
    std::array<uint8_t, 2> bytes{};
    for (; decoded < available; ++decoded) {
        for (unsigned byte = 0; byte < ratio_ / 8; ++byte) {
            if (!readByte(bytes)) { frame_ = total_frames_; return decoded; }
            pushByte(bytes);
        }
        for (unsigned ch = 0; ch < spec_.channels; ++ch) {
            double value = 0;
            auto position = history_position_;
            for (size_t group = 0; group < coefficients_.size(); ++group) {
                position = position ? position - 1 : coefficients_.size() - 1;
                value += coefficients_[group][history_[ch][position]];
            }
            output[decoded * spec_.channels + ch] = float(value);
        }
    }
    frame_ += decoded;
    return decoded;
}

bool IphoneDsdDecoder::positionAtFrame(uint64_t frame) {
    frame_ = std::min(frame, total_frames_);
    const auto target_byte = frame_ * ratio_ / 8;
    const auto history_bytes = coefficients_.size();
    byte_cursor_ = target_byte > history_bytes ? target_byte - history_bytes : 0;
    loaded_block_ = UINT64_MAX;
    history_position_ = 0;
    for (auto& history : history_) std::fill(history.begin(), history.end(), 0xAA);
    std::array<uint8_t, 2> bytes{};
    while (byte_cursor_ < target_byte) {
        if (!readByte(bytes)) return false;
        pushByte(bytes);
    }
    return true;
}

bool IphoneDsdDecoder::seek(double seconds) {
    if (!file_.is_open() || !std::isfinite(seconds)) return false;
    seconds = std::clamp(seconds, 0.0, getDuration());
    return positionAtFrame(uint64_t(seconds * spec_.sample_rate + 1e-7));
}
double IphoneDsdDecoder::getDuration() const {
    return source_rate_ ? double(samples_) / source_rate_ : 0;
}
void IphoneDsdDecoder::close() {
    if (file_.is_open()) file_.close();
    file_.clear();
    source_rate_ = source_channels_ = ratio_ = 0;
    samples_ = data_offset_ = data_size_ = total_frames_ = frame_ = byte_cursor_ = 0;
    loaded_block_ = UINT64_MAX;
    block_size_ = 4096;
    input_block_.clear();
    coefficients_.clear();
    for (auto& history : history_) history.clear();
    spec_ = {};
}

std::unique_ptr<IAudioDecoder> createDsdDecoderForClient(std::string_view platform) {
    return std::make_unique<IphoneDsdDecoder>();
}
} // namespace audio_engine
