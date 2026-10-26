#include "audio_engine/IphoneDsdDecoder.hpp"
#include "audio_engine/DsfParser.hpp"
#include "audio_engine/RuntimeContext.hpp"
#if defined(__APPLE__)
#include "audio_engine/decoders/CoreAudioPcmDecoder.hpp"
#endif
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>
#include <chrono>

using namespace audio_engine;
namespace {
constexpr double pi = 3.14159265358979323846;
void require(bool condition, const char* message) { if (!condition) throw std::runtime_error(message); }
void integer(std::vector<uint8_t>& bytes, uint64_t value, unsigned count, bool little) {
    for (unsigned i = 0; i < count; ++i) bytes.push_back(uint8_t(value >> (8 * (little ? i : count - 1 - i))));
}
void tag(std::vector<uint8_t>& bytes, const char* text) { bytes.insert(bytes.end(), text, text + 4); }
uint8_t reverse(uint8_t byte) {
    uint8_t result = 0;
    for (unsigned bit = 0; bit < 8; ++bit) result |= ((byte >> bit) & 1) << (7 - bit);
    return result;
}
using Streams = std::vector<std::vector<uint8_t>>;
Streams signal(unsigned rate, unsigned channels, double frequency, double seconds = 1) {
    const auto bits = uint64_t(rate * seconds);
    Streams result(channels, std::vector<uint8_t>((bits + 7) / 8));
    for (unsigned ch = 0; ch < channels; ++ch) {
        double first = 0, second = 0, output = 1;
        for (uint64_t bit = 0; bit < bits; ++bit) {
            const double input = .25 * std::sin(2 * pi * frequency * (ch + 1) * bit / rate);
            first += input - output;
            second += first - output;
            output = second >= 0 ? 1 : -1;
            if (output > 0) result[ch][bit / 8] |= 1 << (bit % 8);
        }
    }
    return result;
}
void write(const std::filesystem::path& path, const std::vector<uint8_t>& bytes) {
    std::ofstream file(path, std::ios::binary);
    file.write(reinterpret_cast<const char*>(bytes.data()), bytes.size());
    require(bool(file), "Fixture write failed");
}
void dsf(const std::filesystem::path& path, const Streams& streams, unsigned rate, bool lsb = true) {
    constexpr uint64_t block = 4096;
    const auto blocks = (streams.front().size() + block - 1) / block;
    const auto payload = blocks * block * streams.size();
    std::vector<uint8_t> data;
    tag(data,"DSD "); integer(data,28,8,true); integer(data,28+52+12+payload,8,true); integer(data,0,8,true);
    tag(data,"fmt "); integer(data,52,8,true); integer(data,1,4,true); integer(data,0,4,true);
    integer(data,streams.size() == 1 ? 1 : 2,4,true); integer(data,streams.size(),4,true);
    integer(data,rate,4,true); integer(data,lsb ? 1 : 8,4,true);
    integer(data,streams.front().size()*8,8,true); integer(data,block,4,true); integer(data,0,4,true);
    tag(data,"data"); integer(data,12+payload,8,true);
    for (size_t b = 0; b < blocks; ++b) for (const auto& stream : streams)
        for (size_t i = 0; i < block; ++i) {
            const auto pos = b * block + i;
            const auto value = pos < stream.size() ? stream[pos] : 0;
            data.push_back(lsb ? value : reverse(value));
        }
    write(path,data);
}
void chunk(std::vector<uint8_t>& target, const char* name, const std::vector<uint8_t>& payload) {
    tag(target,name); integer(target,payload.size(),8,false);
    target.insert(target.end(),payload.begin(),payload.end());
    if (payload.size() & 1) target.push_back(0);
}
void dff(const std::filesystem::path& path, const Streams& streams, unsigned rate) {
    std::vector<uint8_t> properties; tag(properties,"SND ");
    std::vector<uint8_t> clock; integer(clock,rate,4,false); chunk(properties,"FS  ",clock);
    std::vector<uint8_t> channels; integer(channels,streams.size(),2,false);
    for (size_t ch = 0; ch < streams.size(); ++ch) tag(channels,ch ? "SRGT" : "SLFT");
    chunk(properties,"CHNL",channels);
    std::vector<uint8_t> compression; tag(compression,"DSD "); compression.push_back(0);
    chunk(properties,"CMPR",compression); // odd-sized chunk exercises required even padding
    std::vector<uint8_t> body; tag(body,"DSD "); chunk(body,"PROP",properties);
    std::vector<uint8_t> samples;
    for (size_t i = 0; i < streams.front().size(); ++i)
        for (const auto& stream : streams) samples.push_back(reverse(stream[i]));
    chunk(body,"DSD ",samples);
    std::vector<uint8_t> data; tag(data,"FRM8"); integer(data,body.size(),8,false);
    data.insert(data.end(),body.begin(),body.end()); write(path,data);
}
std::vector<float> decode(IAudioDecoder& decoder, size_t request = 1024) {
    const auto channels = decoder.getSpec().channels;
    std::vector<float> result;
    std::vector<float> buffer(request * channels + 16, 123456);
    uint64_t count;
    while ((count = decoder.readFrames(buffer.data(),request))) {
        require(count <= request, "Decoder returned more than the requested frames");
        require(std::all_of(buffer.begin() + request * channels,buffer.end(),[](float x){ return x == 123456; }),
            "Decoder wrote beyond its declared channel/frame capacity");
        result.insert(result.end(),buffer.begin(),buffer.begin()+count*channels);
        require(result.size() < 4000000, "Decoder never reaches EOF");
    }
    require(decoder.readFrames(buffer.data(),request) == 0, "EOF is not stable");
    return result;
}
struct Stats { double rms_db, snr_db, amplitude; };
Stats stats(const std::vector<float>& data, unsigned channels, unsigned rate, double frequency) {
    const size_t first = rate / 10, last = rate * 9 / 10;
    require(data.size() / channels >= last, "Too few frames for audio-quality measurement");
    double ss=0,cs=0,power=0,mean=0;
    for (size_t i=first;i<last;++i) {
        const auto value = data[i*channels];
        const auto phase = 2*pi*frequency*i/rate;
        ss+=value*std::sin(phase); cs+=value*std::cos(phase); power+=value*value; mean+=value;
    }
    const double count=last-first;
    const double amplitude=2*std::hypot(ss,cs)/count;
    power/=count;mean/=count;
    const double residual=std::max(1e-30,power-amplitude*amplitude/2-mean*mean);
    return {10*std::log10(power),10*std::log10(amplitude*amplitude/2/residual),amplitude};
}
}
int main() {
    const auto directory = std::filesystem::temp_directory_path() /
        ("iphone-dsd-test-" + std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
    std::filesystem::create_directories(directory);
    try {
        constexpr unsigned rate=2822400;
        const auto stereo=signal(rate,2,1000);
        const auto lsbf=directory/"lsb.dsf", msbf=directory/"msb.dsf", interleaved=directory/"interleaved.dff";
        dsf(lsbf,stereo,rate);dsf(msbf,stereo,rate,false);dff(interleaved,stereo,rate);
        for (const auto* platform : {"iphone", "ipad", "mac", "pi", "android", "window", "linux"}) {
            RuntimeContext context;
            require(context.configure(platform,0),"Factory integration platform setup failed");
            auto selected=createDsdDecoderForClient(context.platformName());
            require(selected->open(lsbf.string()),"Playback DSD factory cannot open the source");
            require(dynamic_cast<IphoneDsdDecoder*>(selected.get())!=nullptr,
                "Playback DSD factory selected the wrong decoder for client");
            require(selected->getSpec().sample_rate==176400u,
                "Playback factory changed an accepted platform's DSD clock");
        }
        IphoneDsdDecoder decoder;
        require(decoder.open(lsbf.string()),"LSB DSF rejected");
        require(decoder.getSpec().sample_rate==176400 && decoder.getSpec().channels==2,"Wrong PCM specification");
        require(std::abs(decoder.getDuration()-1)<1e-12,"Wrong DSF duration");
        const auto expected=decode(decoder);
        require(expected.size()==176400*2,"DSF padded block leaked past the exact duration");
        require(decoder.open(msbf.string()),"MSB DSF rejected");
        require(decode(decoder)==expected,"DSF LSB/MSB bit order changes the decoded audio");
        require(decoder.open(interleaved.string()),"Uncompressed DFF rejected");
        require(decode(decoder,137)==expected,"DFF byte-interleaving/MSB order differs from DSF");
        for (const auto& path : {lsbf,interleaved}) {
            require(decoder.open(path.string()),"Reopen for seek failed");
            for (const uint64_t frame : {uint64_t(0),uint64_t(17),uint64_t(33000),uint64_t(176399)}) {
                require(decoder.seek(double(frame)/176400),"Seek failed");
                std::vector<float> buffer(128*2);
                const auto read=decoder.readFrames(buffer.data(),128);
                require(read==std::min<uint64_t>(128,176400-frame),"Seek returned the wrong frame count");
                for(size_t i=0;i<read*2;++i)
                    require(std::abs(buffer[i]-expected[frame*2+i])<1e-7,"Seek did not restore FIR history/sample position");
            }
            float eof_sample[2]{};
            require(decoder.seek(1) && decoder.readFrames(eof_sample,1)==0,"Seek to EOF emitted padding");
        }
        const auto mono=directory/"mono.dsf";dsf(mono,{stereo.front()},rate);
        require(decoder.open(mono.string()) && decoder.getSpec().channels==1,"Mono DSF rejected");
        const auto mono_pcm=decode(decoder,317);
        require(mono_pcm.size()==176400,"Mono frame count is wrong");
        for(size_t i=0;i<mono_pcm.size();++i)require(mono_pcm[i]==expected[2*i],"Mono channel stride is wrong");
        const auto mono_dff=directory/"mono.dff";dff(mono_dff,{stereo.front()},rate);
        require(decoder.open(mono_dff.string()) && decode(decoder,51)==mono_pcm,"Mono DFF decoding differs");
        const auto dsd128=directory/"dsd128.dsf";dsf(dsd128,signal(rate*2,1,1000,.1),rate*2);
        require(decoder.open(dsd128.string()) && decode(decoder).size()==17640,"DSD128 duration/decimation is wrong");

        for (const unsigned multiplier : {4u,8u}) {
            const auto high_rate=directory/("dsd"+std::to_string(multiplier*64)+".dsf");
            dsf(high_rate,signal(rate*multiplier,1,1000,.02),rate*multiplier);
            require(decoder.open(high_rate.string()) && decode(decoder).size()==3528,
                "DSD256/512 duration/decimation is wrong");
        }
        // Invalid metadata/truncated blocks must fail, rather than feeding
        // uninitialized bytes to the PCM filter or allocating unbounded buffers.
        const auto invalid=directory/"invalid.dsf";
        std::filesystem::copy_file(lsbf,invalid);
        {
            std::fstream file(invalid,std::ios::binary|std::ios::in|std::ios::out);
            file.seekp(60);const char unknown_order[4]={2,0,0,0};file.write(unknown_order,4);
        }
        require(!decoder.open(invalid.string()),"Invalid DSF bit order was accepted");
        std::filesystem::copy_file(lsbf,invalid,std::filesystem::copy_options::overwrite_existing);
        std::filesystem::resize_file(invalid,std::filesystem::file_size(invalid)-1);
        require(!decoder.open(invalid.string()),"Truncated DSF channel block was accepted");

        const auto quality=stats(expected,2,176400,1000);
        require(quality.snr_db>50 && std::abs(quality.amplitude-.25)<.001,"Audible tone response/noise regression");
        const auto ultrasound=directory/"ultrasound.dsf";dsf(ultrasound,signal(rate,1,100000),rate);
        require(decoder.open(ultrasound.string()),"Ultrasound test file rejected");
        const auto rejected=decode(decoder);
        require(stats(rejected,1,176400,76400).rms_db < -65,"Ultrasound aliased through DSD decimation");
#if defined(__APPLE__)
        auto source=std::make_unique<IphoneDsdDecoder>();require(source->open(lsbf.string()),"CoreAudio source open failed");
        auto output=source->getSpec();output.sample_rate=48000;
        CoreAudioPcmDecoder host(std::move(source),output);require(host.configure(),"iPhone host PCM conversion configuration failed");
        const auto host_pcm=decode(host);const auto host_quality=stats(host_pcm,2,48000,1000);
        require(host_quality.snr_db>60 && std::abs(host_quality.amplitude-.25)<.001,"48 kHz host output has audible DSD hiss");
        auto ultrasonic_source=std::make_unique<IphoneDsdDecoder>();require(ultrasonic_source->open(ultrasound.string()),"CoreAudio ultrasound source open failed");
        output.channels=1;
        CoreAudioPcmDecoder host_ultrasound(std::move(ultrasonic_source),output);
        require(host_ultrasound.configure(),"Host ultrasound converter configuration failed");
        const auto host_rejection=stats(decode(host_ultrasound),1,48000,4000);
        require(host_rejection.rms_db < -75,"DSD ultrasound leaks into the 48 kHz audible output");
        std::cout<<"48 kHz PCM SNR="<<host_quality.snr_db<<" dB; ultrasound RMS="<<host_rejection.rms_db<<" dBFS\n";
#endif
        // This is a separate decoder, not a global alteration to the accepted
        // Mac/Pi path: the original decoder retains its original output clock.
        DsfParser legacy;require(legacy.open(lsbf.string()),"Legacy parser no longer opens the same source");
        require(legacy.getSpec().sample_rate==44100,"Non-iPhone default DSD output changed");
        std::filesystem::remove_all(directory);
        std::cout<<"DSF/DFF, both DSF bit orders, mono, duration/EOF, seek, DSD128 and antialias checks passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr<<error.what()<<" (fixtures retained in "<<directory<<")\n";
        return 1;
    }
}
