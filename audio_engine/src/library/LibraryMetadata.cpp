#include "audio_engine/library/MusicLibrary.hpp"
#include "audio_engine/decoders/WavDecoder.hpp"
#include "audio_engine/decoders/FlacDecoder.hpp"
#include "audio_engine/decoders/Mp3Decoder.hpp"
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <functional>
#include <sstream>
#include <iomanip>

namespace audio_engine::library {
namespace {
using Bytes = std::vector<unsigned char>;
uint64_t number(const Bytes& b, size_t at, size_t n, bool little = false) {
    if (at > b.size() || n > b.size()-at) return 0;
    uint64_t value = 0;
    for (size_t i = 0; i < n; ++i) value = (value << 8) | b[at+(little?n-1-i:i)];
    return value;
}
std::string tag(const Bytes& bytes, size_t at=0) {
    return at+4<=bytes.size() ? std::string(bytes.begin()+at,bytes.begin()+at+4) : "";
}
struct Reader {
    std::ifstream stream; uint64_t size;
    explicit Reader(const std::string& path) : stream(path,std::ios::binary), size(std::filesystem::file_size(path)) {}
    Bytes read(uint64_t at, size_t count) {
        if (at > size || count > size-at) return {};
        Bytes result(count); stream.clear();stream.seekg(at);stream.read(reinterpret_cast<char*>(result.data()),count);
        if (size_t(stream.gcount()) != count) return {}; return result;
    }
};
}
Metadata metadata(const std::string& path) {
    try {
        Reader file(path); const auto header=file.read(0,std::min<uint64_t>(file.size,32));
        Metadata m;
        if (tag(header)=="RIFF" && tag(header,8)=="WAVE") {
            uint32_t byte_rate=0;
            for (uint64_t at=12; at+8<=file.size;) {
                const auto h=file.read(at,8);const auto length=number(h,4,4,true);const auto pos=at+8;
                if (tag(h)=="fmt " && length>=16) {
                    const auto b=file.read(pos,std::min<uint64_t>({length,40,file.size-pos}));
                    m.sample_rate=number(b,4,4,true);byte_rate=number(b,8,4,true);m.bit_depth=number(b,14,2,true);
                    if (number(b,0,2,true)==0xfffe && b.size()>=20 && number(b,18,2,true))m.bit_depth=number(b,18,2,true);
                } else if (tag(h)=="data" && byte_rate) {m.duration=double(std::min(length,file.size-pos))/byte_rate;return m;}
                if(length>file.size-pos)break;at=pos+length+(length&1);
            }
        } else if (tag(header)=="fLaC") {
            const auto b=file.read(8,34);
            const auto packed=number(b,10,8);m.sample_rate=packed>>44;m.bit_depth=((packed>>36)&31)+1;
            if(m.sample_rate)m.duration=double(packed&0xfffffffffull)/m.sample_rate;return m;
        }
        uint64_t offset=0;
        if (header.size()>=10 && std::string(header.begin(),header.begin()+3)=="ID3")
            offset=10+((header[6]&127)<<21)+((header[7]&127)<<14)+((header[8]&127)<<7)+(header[9]&127);
        const auto magic=file.read(offset,16);
        if(tag(magic)=="DSD ") {
            uint32_t channels=0;uint64_t samples=0,data=0;
            for(uint64_t at=offset+28;at+12<=file.size;) {
                const auto h=file.read(at,12);const auto size=number(h,4,8,true);if(size<12)break;
                if(tag(h)=="fmt ") {
                    const auto b=file.read(at+12,40);channels=number(b,12,4,true);m.sample_rate=number(b,16,4,true);m.bit_depth=1;samples=number(b,24,8,true);
                } else if(tag(h)=="data") {data=size-12;break;}
                if(size>file.size-at)break;at+=size;
            }
            if(!samples&&channels)samples=data*8/channels;
            if(m.sample_rate)m.duration=double(samples)/m.sample_rate;return m;
        }
        if(tag(magic)=="FRM8"&&tag(magic,12)=="DSD ") {
            uint32_t channels=0;uint64_t data=0;
            for(uint64_t at=offset+16;at+12<=file.size;) {
                const auto h=file.read(at,12);const auto size=number(h,4,8);const auto pos=at+12;
                if(tag(h)=="PROP"&&tag(file.read(pos,4))=="SND ") {
                    const auto end=pos+std::min(size,file.size-pos);
                    for(uint64_t sub=pos+4;sub+12<=end;) {
                        const auto sh=file.read(sub,12);const auto n=number(sh,4,8);
                        if(tag(sh)=="FS  ")m.sample_rate=number(file.read(sub+12,4),0,4);
                        if(tag(sh)=="CHNL")channels=number(file.read(sub+12,2),0,2);
                        if(n>end-sub-12)break;sub+=12+n+(n&1);
                    }
                } else if(tag(h)=="DSD ")data=size;
                if(size>file.size-pos)break;at=pos+size+(size&1);
            }
            m.bit_depth=1;if(channels&&m.sample_rate)m.duration=double(data)*8/channels/m.sample_rate;return m;
        }
        if(tag(header)=="FORM"&&(tag(header,8)=="AIFF"||tag(header,8)=="AIFC")) {
            for(uint64_t at=12;at+8<=file.size;) {
                const auto h=file.read(at,8);const auto n=number(h,4,4);const auto pos=at+8;
                if(tag(h)=="COMM"&&n>=18) {
                    const auto b=file.read(pos,18);const auto exponent=number(b,8,2)&0x7fff;
                    const double rate=exponent==0x7fff?0:std::ldexp(double(number(b,10,8)),int(exponent)-16383-63);
                    m.sample_rate=std::isfinite(rate)&&rate>0&&rate<100000000?std::lround(rate):0;m.bit_depth=number(b,6,2);
                    if(m.sample_rate)m.duration=double(number(b,2,4))/m.sample_rate;return m;
                }
                if(n>file.size-pos)break;at=pos+n+(n&1);
            }
        }
        // MP4 atoms are bounded; do not read media payloads or whole files.
        if(tag(header,4)=="ftyp"||tag(header,4)=="moov"||tag(header,4)=="mdat") {
            double movie_duration=0;
            std::function<void(uint64_t,uint64_t,int)> boxes = [&](uint64_t begin,uint64_t end,int depth) {
                if(depth>8)return;
                for(uint64_t at=begin;at+8<=end;) {
                    const auto h=file.read(at,8);auto size=number(h,0,4);uint64_t hs=8;
                    if(size==1){size=number(file.read(at+8,8),0,8);hs=16;}if(!size)size=end-at;
                    if(size<hs||size>end-at)break;const auto pos=at+hs;const auto type=tag(h,4);
                    if(type=="moov"||type=="trak"||type=="mdia"||type=="minf"||type=="stbl")boxes(pos,at+size,depth+1);
                    else if(type=="mdhd"||type=="mvhd") {
                        const auto b=file.read(pos,std::min<uint64_t>(size-hs,32));
                        const bool v1=!b.empty()&&b[0]==1;const auto scale=number(b,v1?20:12,4);const auto duration=number(b,v1?24:16,v1?8:4);
                        if(scale){if(type=="mdhd")m.duration=double(duration)/scale;else movie_duration=double(duration)/scale;}
                    } else if(type=="stsd"&&size-hs>=44) {
                        const auto b=file.read(pos,44);const auto codec=tag(b,12);
                        if(codec=="mp4a"||codec=="alac"||codec=="lpcm") {m.bit_depth=number(b,34,2);m.sample_rate=number(b,40,4)>>16;}
                    }
                    at+=size;
                }
            };
            boxes(0,file.size,0);if(!m.duration)m.duration=movie_duration;return m;
        }
        const auto ext=std::filesystem::path(path).extension().string();
        if(ext==".mp3"||ext==".MP3") {
            if(header.size()>5&&(header[5]&0x10))offset+=10;
            if(offset<file.size) {
                const auto b=file.read(offset,std::min<uint64_t>(65536,file.size-offset));
                static constexpr int rates[3][3]={{44100,48000,32000},{22050,24000,16000},{11025,12000,8000}};
                static constexpr int br1[]={0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,0};
                static constexpr int br2[]={0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0};
                for(size_t i=0;i+4<=b.size();++i) {
                    if(b[i]!=255||(b[i+1]&0xe0)!=0xe0)continue;
                    const auto version=(b[i+1]>>3)&3,layer=(b[i+1]>>1)&3,bitrate=(b[i+2]>>4)&15,rate=(b[i+2]>>2)&3;
                    if(version==1||layer!=1||bitrate==0||bitrate==15||rate==3)continue;
                    m.sample_rate=rates[version==3?0:version==2?1:2][rate];m.bit_depth=16;
                    const int samples=version==3?1152:576;const bool mono=(b[i+3]>>6)==3;
                    const auto xing=i+4+((b[i+1]&1)?0:2)+(version==3?(mono?17:32):(mono?9:17));
                    if((tag(b,xing)=="Xing"||tag(b,xing)=="Info")&&(number(b,xing+4,4)&1))m.duration=double(number(b,xing+8,4))*samples/m.sample_rate;
                    if(!m.duration&&tag(b,i+36)=="VBRI")m.duration=double(number(b,i+50,4))*samples/m.sample_rate;
                    if(!m.duration)m.duration=double(file.size-offset-i)*8/((version==3?br1[bitrate]:br2[bitrate])*1000);
                    return m;
                }
            }
        }
        if(ext==".mp3"||ext==".MP3") {Mp3Decoder decoder;if(decoder.open(path)){const auto spec=decoder.getSpec();return {spec.sample_rate,spec.bit_depth,decoder.getDuration()};}}
        return m;
    } catch (...) {return {};}
}
std::string metadataJson(const std::string& path) {
    const auto m=metadata(path);std::ostringstream out;
    out<<"{\"sampleRate\":"<<m.sample_rate<<",\"bitDepth\":"<<m.bit_depth<<",\"durationSeconds\":"<<std::setprecision(17)<<m.duration<<'}';return out.str();
}
} // namespace audio_engine::library
