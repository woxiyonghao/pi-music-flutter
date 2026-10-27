#include "audio_engine/library/MusicLibrary.hpp"
#include "sqlite/sqlite3.h"
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <map>
#include <memory>
#include <mutex>
#include <set>
#include <sstream>
#include <stdexcept>
#include <cstring>

namespace audio_engine::library {
namespace {
namespace fs=std::filesystem;
#include "Gb18030Tables.inc"
std::mutex scan_mutex;
using Statement=std::unique_ptr<sqlite3_stmt,decltype(&sqlite3_finalize)>;
Statement prepare(sqlite3* db,const char* sql) {
    sqlite3_stmt* s=nullptr;if(sqlite3_prepare_v2(db,sql,-1,&s,nullptr)!=SQLITE_OK)throw std::runtime_error(sqlite3_errmsg(db));return {s,sqlite3_finalize};
}
void execute(sqlite3* db,const std::string& sql) {
    if(sqlite3_exec(db,sql.c_str(),nullptr,nullptr,nullptr)!=SQLITE_OK)throw std::runtime_error(sqlite3_errmsg(db));
}
void schema(sqlite3* db) {
    execute(db,R"(
      CREATE TABLE IF NOT EXISTS app_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS scanned_tracks(id INTEGER PRIMARY KEY,title TEXT NOT NULL,artist TEXT NOT NULL,album TEXT NOT NULL,
        file_path TEXT NOT NULL,format INTEGER NOT NULL,sample_rate INTEGER NOT NULL,bit_depth INTEGER NOT NULL,duration_sec INTEGER NOT NULL,
        start_time_sec REAL DEFAULT 0,end_time_sec REAL DEFAULT 0,cue_path TEXT DEFAULT '',track_number INTEGER DEFAULT 0,is_cue_track INTEGER DEFAULT 0);
      CREATE TABLE IF NOT EXISTS playlists(id INTEGER PRIMARY KEY,name TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS playlist_tracks(playlist_id INTEGER NOT NULL,track_id INTEGER NOT NULL,sort_order INTEGER DEFAULT 0,
        PRIMARY KEY(playlist_id,track_id));
      CREATE TABLE IF NOT EXISTS dac_dx1ii_settings(key TEXT PRIMARY KEY,value TEXT NOT NULL);
    )");
    auto s=prepare(db,"PRAGMA table_info(scanned_tracks)");std::set<std::string> columns;
    while(sqlite3_step(s.get())==SQLITE_ROW)columns.insert(reinterpret_cast<const char*>(sqlite3_column_text(s.get(),1)));
    for(const auto& [key,type]:std::map<std::string,std::string>{{"start_time_sec","REAL DEFAULT 0"},{"end_time_sec","REAL DEFAULT 0"},
        {"cue_path","TEXT DEFAULT ''"},{"track_number","INTEGER DEFAULT 0"},{"is_cue_track","INTEGER DEFAULT 0"}})
        if(!columns.count(key))execute(db,"ALTER TABLE scanned_tracks ADD COLUMN "+key+" "+type);

    auto table=prepare(db,"SELECT sql FROM sqlite_master WHERE type='table' AND name='scanned_tracks'");
    if(sqlite3_step(table.get())==SQLITE_ROW) {
        const std::string ddl=reinterpret_cast<const char*>(sqlite3_column_text(table.get(),0));
        if(ddl.find("file_path TEXT UNIQUE")!=ddl.npos || ddl.find("UNIQUE(file_path)")!=ddl.npos) {
            table.reset();s.reset();execute(db,"BEGIN IMMEDIATE");
            try {
                execute(db,R"(CREATE TABLE _hifi_scan_migration(id INTEGER PRIMARY KEY,title TEXT NOT NULL,artist TEXT NOT NULL,album TEXT NOT NULL,
                    file_path TEXT NOT NULL,format INTEGER NOT NULL,sample_rate INTEGER NOT NULL,bit_depth INTEGER NOT NULL,duration_sec INTEGER NOT NULL,
                    start_time_sec REAL DEFAULT 0,end_time_sec REAL DEFAULT 0,cue_path TEXT DEFAULT '',track_number INTEGER DEFAULT 0,is_cue_track INTEGER DEFAULT 0);
                    INSERT INTO _hifi_scan_migration SELECT id,title,artist,album,file_path,format,sample_rate,bit_depth,duration_sec,start_time_sec,end_time_sec,cue_path,track_number,is_cue_track FROM scanned_tracks;
                    DROP TABLE scanned_tracks; ALTER TABLE _hifi_scan_migration RENAME TO scanned_tracks; COMMIT;)");
            } catch(...) {sqlite3_exec(db,"ROLLBACK",nullptr,nullptr,nullptr);throw;}
        }
    }
}
std::string text(sqlite3_stmt* s,int column) {const auto* value=sqlite3_column_text(s,column);return value?reinterpret_cast<const char*>(value):"";}
std::vector<Track> readTracks(sqlite3* db) {
    auto s=prepare(db,"SELECT id,title,artist,album,file_path,format,sample_rate,bit_depth,duration_sec,start_time_sec,end_time_sec,cue_path,track_number,is_cue_track FROM scanned_tracks ORDER BY id");
    std::vector<Track> tracks;int status;
    while((status=sqlite3_step(s.get()))==SQLITE_ROW) {
        Track t;t.id=sqlite3_column_int64(s.get(),0);t.title=text(s.get(),1);t.artist=text(s.get(),2);t.album=text(s.get(),3);t.path=text(s.get(),4);
        t.format=sqlite3_column_int(s.get(),5);t.sample_rate=sqlite3_column_int(s.get(),6);t.bit_depth=sqlite3_column_int(s.get(),7);t.duration=sqlite3_column_int(s.get(),8);
        t.start=sqlite3_column_double(s.get(),9);t.end=sqlite3_column_double(s.get(),10);t.cue_path=text(s.get(),11);t.number=sqlite3_column_int(s.get(),12);t.cue=sqlite3_column_int(s.get(),13)!=0;tracks.push_back(t);
    }
    if(status!=SQLITE_DONE)throw std::runtime_error(sqlite3_errmsg(db));return tracks;
}
std::string trim(std::string s) {const auto a=s.find_first_not_of(" \t\r\n");return a==s.npos?"":s.substr(a,s.find_last_not_of(" \t\r\n")-a+1);}
std::string lower(std::string s) {for(auto& c:s)if(c>='A'&&c<='Z')c+='a'-'A';return s;}
std::string quoted(std::string s) {s=trim(s);if(s.size()&& (s[0]=='"'||s[0]=='\'')){const auto end=s.find(s[0],1);return s.substr(1,end==s.npos?s.size()-1:end-1);}return s;}
bool audioFile(const fs::path& file) {
    static const std::set<std::string> extensions={".flac",".wav",".mp3",".dsf",".dff",".alac",".m4a",".aac",".aiff",".aif",".caf",".ape",".ogg",".opus",".wma"};
    return extensions.count(lower(file.extension().string()));
}
int audioFormat(const fs::path& path) {
    const auto e=lower(path.extension().string());if(e==".flac")return 1;if(e==".wav")return 2;if(e==".dsf")return 3;if(e==".dff")return 4;
    if(e==".alac"||e==".m4a"||e==".aac"||e==".aiff"||e==".aif"||e==".caf")return 5;if(e==".mp3")return 6;return 0;
}
std::string canonicalPath(const fs::path& path) {std::error_code ec;auto result=fs::weakly_canonical(path,ec);return (ec?fs::absolute(path).lexically_normal():result).string();}
bool within(const std::string& path,const std::string& directory) {
    const auto relative=fs::path(path).lexically_relative(directory);
    return !relative.empty() && *relative.begin()!="..";
}
void appendUtf8(std::string& out,uint32_t cp) {
    if(cp<0x80)out+=char(cp);
    else if(cp<0x800){out+=char(0xc0|(cp>>6));out+=char(0x80|(cp&63));}
    else if(cp<0x10000){out+=char(0xe0|(cp>>12));out+=char(0x80|((cp>>6)&63));out+=char(0x80|(cp&63));}
    else {out+=char(0xf0|(cp>>18));out+=char(0x80|((cp>>12)&63));out+=char(0x80|((cp>>6)&63));out+=char(0x80|(cp&63));}
}
bool validUtf8(const std::string& s) {
    for(size_t i=0;i<s.size();) {
        const auto c=uint8_t(s[i++]);if(c<128)continue;
        int n;uint32_t cp,min;if(c>=0xc2&&c<=0xdf){n=1;cp=c&31;min=0x80;}else if(c>=0xe0&&c<=0xef){n=2;cp=c&15;min=0x800;}else if(c>=0xf0&&c<=0xf4){n=3;cp=c&7;min=0x10000;}else return false;
        if(size_t(n)>s.size()-i)return false;
        while(n--){const auto b=uint8_t(s[i++]);if((b&0xc0)!=0x80)return false;cp=(cp<<6)|(b&63);}
        if(cp<min||cp>0x10ffff||(cp>=0xd800&&cp<=0xdfff))return false;
    }return true;
}
std::string decodeCue(const std::string& bytes) {
    const auto* b=reinterpret_cast<const uint8_t*>(bytes.data());std::string out;
    if(bytes.size()>=2&&((b[0]==0xff&&b[1]==0xfe)||(b[0]==0xfe&&b[1]==0xff))) {
        const bool le=b[0]==0xff;
        auto unit=[&](size_t i){return uint32_t(le?b[i]|(b[i+1]<<8):(b[i]<<8)|b[i+1]);};
        for(size_t i=2;i+1<bytes.size();i+=2){uint32_t cp=unit(i);if(cp>=0xd800&&cp<=0xdbff&&i+3<bytes.size()) {const auto low=unit(i+2);if(low>=0xdc00&&low<=0xdfff){cp=0x10000+((cp-0xd800)<<10)+(low-0xdc00);i+=2;}}if(cp>=0xd800&&cp<=0xdfff)cp=0xfffd;appendUtf8(out,cp);}return out;
    }
    if(bytes.size()>=3&&b[0]==0xef&&b[1]==0xbb&&b[2]==0xbf)return decodeCue(bytes.substr(3));
    if(validUtf8(bytes))return bytes;
    for(size_t i=0;i<bytes.size();) {
        const auto first=b[i++];if(first<128){out+=char(first);continue;}
        uint32_t cp=first==0x80?0x20ac:first;
        if(first>=0x81&&first<=0xfe&&i<bytes.size()) {
            const auto second=b[i];
            if(second>=0x30&&second<=0x39&&i+2<bytes.size()&&b[i+1]>=0x81&&b[i+1]<=0xfe&&b[i+2]>=0x30&&b[i+2]<=0x39) {
                const uint32_t index=(((first-0x81)*10+second-0x30)*126+b[i+1]-0x81)*10+b[i+2]-0x30;
                cp=0xfffd;for(const auto& range:gbFourByte)if(index>=range.first&&index<=range.last){cp=range.unicode+index-range.first;break;}i+=3;
            } else if((second>=0x40&&second<=0x7e)||(second>=0x80&&second<=0xfe)) {
                cp=gbTwoByte[(first-0x81)*190+(second<0x7f?second-0x40:second-0x41)];++i;
            }
        }
        appendUtf8(out,cp);
    }return out;
}
struct CueTrack {int number=0;std::string title,performer,reference;double start=-1;};
struct CueSheet {std::string title,performer;std::vector<CueTrack> tracks;std::set<std::string> references;};
CueSheet parseCue(const fs::path& path) {
    if(fs::file_size(path)>16*1024*1024)throw std::runtime_error("CUE exceeds 16 MiB");
    std::ifstream file(path,std::ios::binary);if(!file)throw std::runtime_error("Cannot read CUE");
    const std::string bytes((std::istreambuf_iterator<char>(file)),{});std::istringstream input(decodeCue(bytes));
    CueSheet sheet;std::string line,reference;CueTrack* track=nullptr;
    while(std::getline(input,line)) {
        line=trim(line);const auto split=line.find_first_of(" \t");if(split==line.npos)continue;
        const auto command=lower(line.substr(0,split));auto value=trim(line.substr(split+1));
        if(command=="file") {
            if(!value.empty()&&(value[0]=='"'||value[0]=='\''))reference=quoted(value);
            else {const auto last=value.find_last_of(" \t");reference=last==value.npos?value:trim(value.substr(0,last));}
            std::replace(reference.begin(),reference.end(),'\\','/');
            if(!reference.empty()&&(reference[0]=='/'||(reference.size()>2&&reference[1]==':')))reference=fs::path(reference).filename().string();
            sheet.references.insert(reference);track=nullptr;
        } else if(command=="track") {
            int number=0;std::string type;std::istringstream tokens(value);tokens>>number>>type;
            if(number>0&&lower(type)=="audio"){sheet.tracks.push_back({number,"","",reference,-1});track=&sheet.tracks.back();}else track=nullptr;
        } else if(command=="title") {if(track)track->title=quoted(value);else if(sheet.title.empty())sheet.title=quoted(value);}
        else if(command=="performer") {if(track)track->performer=quoted(value);else if(sheet.performer.empty())sheet.performer=quoted(value);}
        else if(command=="index"&&track) {
            int index=-1;std::string stamp;std::istringstream tokens(value);tokens>>index>>stamp;
            if(index==1){int mm=0,ss=0,ff=0;const auto n=std::sscanf(stamp.c_str(),"%d:%d:%d",&mm,&ss,&ff);if(n>=2&&mm>=0&&ss>=0&&ss<60&&ff>=0&&ff<75)track->start=mm*60.0+ss+ff/75.0;}
        }
    }
    sheet.tracks.erase(std::remove_if(sheet.tracks.begin(),sheet.tracks.end(),[](const auto& t){return t.start<0||t.reference.empty();}),sheet.tracks.end());
    if(sheet.title.empty())sheet.title=path.stem().string();return sheet;
}
std::string resolveAudio(const fs::path& cue,const std::string& reference,const std::vector<fs::path>& audio,bool single_ref) {
    const auto direct=cue.parent_path()/fs::path(reference);
    for(const auto& candidate:audio) {
        std::error_code ec;
        if(candidate==direct||fs::equivalent(candidate,direct,ec))return candidate.string();
    }
    // Resolve components case-insensitively for CUE files authored on Windows.
    fs::path folded=cue.parent_path();bool found=true;
    for(const auto& component:fs::path(reference)) {
        if(component==".."||component=="."){folded/=component;continue;}
        std::error_code ec;bool matched=false;
        for(fs::directory_iterator it(folded,ec),end;!ec&&it!=end;it.increment(ec))
            if(lower(it->path().filename().string())==lower(component.string())){folded=it->path();matched=true;break;}
        if(!matched){found=false;break;}
    }
    if(found){const auto key=canonicalPath(folded);for(const auto& candidate:audio)if(candidate.string()==key)return key;}
    std::vector<fs::path> siblings;
    for(const auto& file:audio)if(file.parent_path()==cue.parent_path())siblings.push_back(file);
    const auto ref_stem=lower(fs::path(reference).stem().string());
    for(const auto& file:siblings)if(lower(file.stem().string())==ref_stem)return file.string();
    if(single_ref) {
        for(const auto& file:siblings)if(lower(file.stem().string())==lower(cue.stem().string()))return file.string();
        if(siblings.size()==1)return siblings.front().string();
    }
    return "";
}
std::string rebase(const std::string& path,const std::string& documents) {
    if(documents.empty())return path;const auto marker=path.find("/Documents/");
    if(marker!=path.npos)return canonicalPath(fs::path(documents)/path.substr(marker+11));
    if(path.ends_with("/Documents"))return documents;return path;
}
std::string identity(const Track& track) {
    return std::string(track.cue?"cue:":"audio:")+track.path+(track.cue?":"+std::to_string(track.number)+":"+std::to_string(std::llround(track.start*75)):"");
}
Track ordinary(const fs::path& path,const Metadata& m) {
    Track t;t.path=path.string();t.title=path.stem().string();t.artist="未知艺术家";t.album=path.parent_path().filename().string();
    if(t.album.empty()||t.album=="Documents"||t.album=="Music"||t.album=="pimusic"||t.album=="Download"||t.album=="app_flutter")t.album="默认专辑";
    const auto dash=t.title.find(" - ");
    if(dash!=t.title.npos){const auto first=trim(t.title.substr(0,dash));const auto last=trim(t.title.substr(dash+3));t.title=last;
        if(!first.empty()){t.artist=first;}}
    t.format=audioFormat(path);t.sample_rate=m.sample_rate;t.bit_depth=m.bit_depth;t.duration=std::lround(m.duration);return t;
}
} // namespace

std::vector<Track> load(const std::string& database) {
    std::unique_ptr<void,decltype(&closeDatabase)> db(openDatabase(database.c_str()),closeDatabase);
    if(!db)throw std::runtime_error("Cannot open library database");schema(static_cast<sqlite3*>(db.get()));return readTracks(static_cast<sqlite3*>(db.get()));
}
ScanResult scan(const std::string& database,const std::vector<std::string>& requested,const std::string& documents,uint32_t flags) {
    std::lock_guard lock(scan_mutex);
    if(requested.empty())throw std::runtime_error("No scan roots supplied");
    ScanResult result;std::vector<fs::path> roots,pending,audio,cues;std::vector<std::string> failed;
    for(const auto& root:requested){std::error_code ec;if(fs::is_directory(root,ec))roots.push_back(canonicalPath(root));else throw std::runtime_error("Scan root is missing or unreadable: "+root);}
    pending=roots;std::set<std::string> visited_dirs,visited_files;
    while(!pending.empty()) {
        const auto directory=pending.back();pending.pop_back();std::error_code ec;const auto key=fs::canonical(directory,ec);
        if(ec){failed.push_back(directory.string());continue;}
        if(flags&2) {
            bool virtual_tree=false;
            for(const auto& root:roots)for(const auto& pseudo:{"proc","sys","dev"})
                if(key==root/pseudo||within(key.string(),(root/pseudo).string()))virtual_tree=true;
            if(virtual_tree)continue;
        }
        if(!(flags&2)&&std::none_of(roots.begin(),roots.end(),[&](const auto& root){return within(key.string(),root.string());}))continue;
        if(!visited_dirs.insert(key.string()).second)continue;
        fs::directory_iterator it(key,ec),end;if(ec){failed.push_back(key.string());continue;}
        while(it!=end) {
            const auto entry=it->path();const auto name=entry.filename().string();const auto type=it->status(ec);
            if(ec){failed.push_back(entry.string());ec.clear();}
            else if(fs::is_directory(type)) {
                bool skip=false;
                if(flags&2)for(const auto& root:roots)for(const auto& pseudo:{"proc","sys","dev"})if(entry==root/pseudo)skip=true;
                if(!skip)pending.push_back(entry);
            } else if(fs::is_regular_file(type)&&(audioFile(entry)||lower(entry.extension().string())==".cue")) {
                const auto physical=fs::canonical(entry,ec);
                if(!ec&&((flags&2)||std::any_of(roots.begin(),roots.end(),[&](const auto& root){return within(physical.string(),root.string());}))&&visited_files.insert(physical.string()).second)(lower(entry.extension().string())==".cue"?cues:audio).push_back(physical);
            }
            it.increment(ec);if(ec){failed.push_back(key.string());break;}
        }
    }
    std::sort(audio.begin(),audio.end());std::sort(cues.begin(),cues.end());
    result.warnings=failed;std::map<std::string,Metadata> cache;
    auto meta=[&](const std::string& path){auto it=cache.find(path);if(it!=cache.end())return it->second;return cache[path]=metadata(path);};
    std::vector<Track> tracks;std::set<std::string> split_audio,added;
    for(const auto& cue:cues) {
        try {
            const auto sheet=parseCue(cue);std::vector<std::string> resolved;
            for(const auto& raw:sheet.tracks)resolved.push_back(resolveAudio(cue,raw.reference,audio,sheet.references.size()<=1));
            for(size_t i=0;i<sheet.tracks.size();++i) {
                const auto& raw=sheet.tracks[i];if(resolved[i].empty()){result.warnings.push_back("Unresolved CUE audio: "+cue.string()+": "+raw.reference);continue;}
                const auto m=meta(resolved[i]);double end=m.duration;
                for(size_t next=i+1;next<sheet.tracks.size();++next)if(resolved[next]==resolved[i]){end=sheet.tracks[next].start;break;}
                if(end>0&&end<=raw.start){result.warnings.push_back("Invalid CUE boundary: "+cue.string());continue;}
                Track t=ordinary(resolved[i],m);t.cue=true;t.number=raw.number;t.start=raw.start;t.end=end;t.cue_path=cue.string();
                t.title=raw.title.empty()?"音轨 "+std::to_string(raw.number):raw.title;t.artist=raw.performer.empty()?sheet.performer:raw.performer;
                if(t.artist.empty())t.artist="未知艺术家";t.album=sheet.title;t.duration=end>raw.start?std::lround(end-raw.start):0;
                if(added.insert(identity(t)).second){split_audio.insert(t.path);tracks.push_back(t);}
            }
        }catch(const std::exception& error){result.warnings.push_back(cue.string()+": "+error.what());}
    }
    for(const auto& file:audio)if(!split_audio.count(file.string())){auto t=ordinary(file,meta(file.string()));if(added.insert(identity(t)).second)tracks.push_back(t);}
    std::unique_ptr<void,decltype(&closeDatabase)> connection(openDatabase(database.c_str()),closeDatabase);
    if(!connection)throw std::runtime_error("Cannot open library database");auto* db=static_cast<sqlite3*>(connection.get());schema(db);
    execute(db,"BEGIN IMMEDIATE");
    try {
        auto old=readTracks(db);std::map<std::string,int64_t> ids;int64_t next_id=1;
        auto setting=prepare(db,"SELECT CAST(value AS INTEGER) FROM app_settings WHERE key='library_next_track_id'");
        if(sqlite3_step(setting.get())==SQLITE_ROW)next_id=std::max<int64_t>(1,sqlite3_column_int64(setting.get(),0));
        setting.reset();
        for(auto& t:old){next_id=std::max(next_id,t.id+1);t.path=canonicalPath(rebase(t.path,documents));if(!t.cue_path.empty())t.cue_path=canonicalPath(rebase(t.cue_path,documents));ids[identity(t)]=t.id;}
        for(auto& t:tracks){const auto found=ids.find(identity(t));t.id=found==ids.end()?next_id++:found->second;}
        for(const auto& t:old) {
            const bool outside=std::none_of(roots.begin(),roots.end(),[&](const auto& root){return within(t.path,root.string());});
            const bool unreadable=std::any_of(failed.begin(),failed.end(),[&](const auto& root){return t.path==root||within(t.path,root);});
            if(((flags&1)&&outside)||unreadable)if(added.insert(identity(t)).second)tracks.push_back(t);
        }
        execute(db,"DELETE FROM scanned_tracks");
        auto insert=prepare(db,"INSERT INTO scanned_tracks(id,title,artist,album,file_path,format,sample_rate,bit_depth,duration_sec,start_time_sec,end_time_sec,cue_path,track_number,is_cue_track) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
        for(const auto& t:tracks) {
            auto* s=insert.get();sqlite3_bind_int64(s,1,t.id);
            for(const auto& [index,value]:std::vector<std::pair<int,std::string>>{{2,t.title},{3,t.artist},{4,t.album},{5,t.path},{12,t.cue_path}})sqlite3_bind_text(s,index,value.c_str(),-1,SQLITE_TRANSIENT);
            sqlite3_bind_int(s,6,t.format);sqlite3_bind_int(s,7,t.sample_rate);sqlite3_bind_int(s,8,t.bit_depth);sqlite3_bind_int(s,9,t.duration);
            sqlite3_bind_double(s,10,t.start);sqlite3_bind_double(s,11,t.end);sqlite3_bind_int(s,13,t.number);sqlite3_bind_int(s,14,t.cue?1:0);
            if(sqlite3_step(s)!=SQLITE_DONE)throw std::runtime_error(sqlite3_errmsg(db));sqlite3_reset(s);sqlite3_clear_bindings(s);
        }
        execute(db,"DELETE FROM playlist_tracks WHERE track_id NOT IN(SELECT id FROM scanned_tracks)");
        execute(db,"INSERT OR REPLACE INTO app_settings(key,value) VALUES('library_next_track_id','"+std::to_string(next_id)+"')");
        execute(db,"COMMIT");result.count=tracks.size();return result;
    }catch(...){sqlite3_exec(db,"ROLLBACK",nullptr,nullptr,nullptr);throw;}
}
std::string scanJson(const char* database,const char* const* roots,uint32_t count,const char* documents,uint32_t flags) {
    try {
        if(!database||!roots||count==0||count>1024||(flags&~uint32_t(3)))throw std::runtime_error("Invalid library scan arguments");
        std::vector<std::string> directories;for(uint32_t i=0;i<count;++i){if(!roots[i]||!*roots[i])throw std::runtime_error("Empty scan root");directories.emplace_back(roots[i]);}
        const auto result=scan(database,directories,documents?documents:"",flags);std::ostringstream out;
        out<<"{\"ok\":true,\"trackCount\":"<<result.count<<",\"warnings\":[";
        for(size_t i=0;i<result.warnings.size();++i){if(i)out<<',';out<<jsonString(result.warnings[i]);}out<<"]}";return out.str();
    }catch(const std::exception& error){return "{\"ok\":false,\"error\":"+jsonString(error.what())+"}";}
}
} // namespace audio_engine::library
