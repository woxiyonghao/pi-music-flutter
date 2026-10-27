#include "audio_engine/library/MusicLibrary.hpp"
#include "hifi_audio_ffi.h"
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <thread>
#include <cmath>
#include <chrono>
using namespace audio_engine::library;
namespace fs=std::filesystem;
static void require(bool ok,const std::string& message){if(!ok)throw std::runtime_error(message);}
static void put(const fs::path& p,const std::string& s){fs::create_directories(p.parent_path());std::ofstream(p,std::ios::binary)<<s;}
static void le(std::ofstream& f,uint64_t n,int bytes){for(int i=0;i<bytes;++i)f.put(char(n>>(8*i)));}
static void wav(const fs::path& path,double seconds=8.4){fs::create_directories(path.parent_path());std::ofstream f(path,std::ios::binary);const auto samples=uint32_t(std::lround(seconds*44100));f<<"RIFF";le(f,36+samples*4,4);f<<"WAVEfmt ";le(f,16,4);le(f,1,2);le(f,2,2);le(f,44100,4);le(f,176400,4);le(f,4,2);le(f,16,2);f<<"data";le(f,samples*4,4);std::string zero(4096,'\0');uint64_t remaining=samples*4;while(remaining){const auto n=std::min<uint64_t>(remaining,zero.size());f.write(zero.data(),n);remaining-=n;}}
static const std::string cue="PERFORMER \"艺术家\"\nTITLE \"整轨专辑\"\nFILE \"disc 1\\\\CDImage.WAV\" WAVE\n TRACK 01 AUDIO\n TITLE \"第一首\"\n INDEX 01 00:00:00\n TRACK 02 AUDIO\n TITLE \"第二首\"\n INDEX 01 00:02:01\n TRACK 03 AUDIO\n TITLE \"第三首\"\n INDEX 01 00:05:37\n";
static std::string utf16(const std::u16string& s){std::string result="\xff\xfe";for(auto c:s){result+=char(c&255);result+=char(c>>8);}return result;}
static void sql(void* db,const std::string& statement,const std::string& args="[]"){
 const auto r=std::string(hifi_library_db_query_json(db,statement.c_str(),args.c_str()));require(r.find("\"ok\":true")!=r.npos,"SQL failed: "+r);
}
int main(){
 const auto root=fs::temp_directory_path()/("hifi-library-cpp-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
 try{
  const auto music=root/"Documents";const auto db=(root/"library.db").string();wav(music/"Disc 1"/"CDImage.wav");put(music/"album.cue",cue);
  require(scan(db,{music.string()},music.string(),0).count==3,"CUE was not split in C++");
  auto tracks=load(db);require(tracks[0].title=="第一首"&&tracks[1].title=="第二首"&&tracks[2].album=="整轨专辑","UTF-8 CUE metadata lost");
  require(std::abs(tracks[1].start-(2+1/75.0))<1e-10&&std::abs(tracks[1].end-(5+37/75.0))<1e-10,"CUE CD frame timing lost");
  require(std::abs(tracks[2].end-8.4)<1e-10&&tracks[2].duration==3,"Last CUE boundary did not use exact WAV duration");
  const auto ids=std::vector<int64_t>{tracks[0].id,tracks[1].id,tracks[2].id};
  auto* handle=hifi_library_db_open(db.c_str());require(handle,"Native database open failed");
  sql(handle,"INSERT INTO playlists(id,name) VALUES(7,?)","[\"试听'歌单\"]");sql(handle,"INSERT INTO playlist_tracks VALUES(7,?,0)","["+std::to_string(tracks[1].id)+"]");
  sql(handle,"INSERT INTO app_settings VALUES('custom','keep')");hifi_library_db_close(handle);
  scan(db,{music.string()},music.string(),0);tracks=load(db);require(tracks[1].id==ids[1],"Rescan changed stable CUE ID");
  handle=hifi_library_db_open(db.c_str());const auto members=std::string(hifi_library_db_query_json(handle,"SELECT track_id FROM playlist_tracks","[]"));require(members.find(std::to_string(ids[1]))!=members.npos,"Rescan deleted playlist membership");
  sql(handle,"BEGIN IMMEDIATE");sql(handle,"UPDATE app_settings SET value=? WHERE key=?","[\"transaction\",\"custom\"]");sql(handle,"ROLLBACK");
  require(std::string(hifi_library_db_query_json(handle,"SELECT value FROM app_settings WHERE key='custom'","[]")).find("keep")!=std::string::npos,"C ABI transaction did not survive across calls");
  sql(handle,"CREATE TRIGGER reject_new BEFORE INSERT ON scanned_tracks WHEN NEW.title='reject' BEGIN SELECT RAISE(ABORT,'test rollback'); END");hifi_library_db_close(handle);
  wav(music/"reject.wav",1);bool rejected=false;try{scan(db,{music.string()},"",0);}catch(...){rejected=true;}require(rejected&&load(db).size()==3,"Failed scan did not roll back atomically");
  fs::remove(music/"reject.wav");handle=hifi_library_db_open(db.c_str());sql(handle,"DROP TRIGGER reject_new");hifi_library_db_close(handle);
  // A Finder container UUID change keeps the old IDs and playlists.
  const auto moved=root/"new-container"/"Documents";fs::create_directories(moved.parent_path());fs::rename(music,moved);
  scan(db,{moved.string()},moved.string(),0);tracks=load(db);require(tracks[1].id==ids[1]&&tracks[1].path.find("new-container")!=tracks[1].path.npos,"iOS Documents rebasing lost ID");
  // UTF-16 and GB18030 share exactly the same parser and clock calculations.
  put(moved/"album.cue",utf16(u"TITLE \"UTF16 专辑\"\nFILE \"Disc 1/CDImage.wav\" WAVE\nTRACK 01 AUDIO\nTITLE \"中文😀\"\nINDEX 01 00:00:00\n"));
  scan(db,{moved.string()},moved.string(),0);require(load(db).front().title=="中文😀","UTF-16 surrogate pair lost");
  const unsigned char gbk[]={0x54,0x49,0x54,0x4c,0x45,0x20,0x22,0xd6,0xd0,0xce,0xc4,0x22,0x0a};
  std::string gb(reinterpret_cast<const char*>(gbk),sizeof(gbk));gb+="FILE \"Disc 1/CDImage.wav\" WAVE\nTRACK 01 AUDIO\nTITLE \"";gb.append("\xb5\xda\xd2\xbb\xca\xd7",6);gb+="\"\nINDEX 01 00:00:00\n";put(moved/"album.cue",gb);
  scan(db,{moved.string()},moved.string(),0);require(load(db).front().title=="第一首"&&load(db).front().album=="中文","GBK decode failed");
  const auto public_music=root/"public"/"Music";wav(public_music/"public.wav",1);
  scan(db,{moved.string(),public_music.string()},moved.string(),0);require(load(db).size()==2,"Private/public music roots not combined");
  wav(moved/"wifi.wav",1);scan(db,{moved.string()},moved.string(),1);require(load(db).size()==3,"WiFi partial scan deleted public songs");
  auto old=load(db);const auto high=old.back().id;fs::remove(moved/"wifi.wav");scan(db,{moved.string(),public_music.string()},moved.string(),0);wav(moved/"new.wav",1);scan(db,{moved.string(),public_music.string()},moved.string(),0);
  bool increasing=false;for(const auto& t:load(db))if(t.title=="new")increasing=t.id>high;require(increasing,"Deleted IDs were reused");
  const auto global=root/"pi-root";wav(global/"opt"/"albums"/"global.wav",1);wav(global/".hidden"/"hidden.wav",1);wav(global/"proc"/"fake.wav",1);
  fs::create_directory_symlink(global/"opt",global/"linked");fs::create_directory_symlink(global,global/"opt"/"loop");
  const auto pi=(root/"pi.db").string();require(scan(pi,{global.string()},"",2).count==2,"Global Pi scan missed arbitrary/hidden songs or followed virtual tree/symlink loop");
  const auto restricted=global/"restricted";wav(restricted/"keep.wav",1);scan(pi,{global.string()},"",2);
  fs::permissions(restricted,fs::perms::none);const auto unreadable=scan(pi,{global.string()},"",2);fs::permissions(restricted,fs::perms::owner_all);
  require(unreadable.count==3&&!unreadable.warnings.empty(),"Unreadable directory erased old songs");
  const auto legacy=(root/"legacy.db").string();handle=hifi_library_db_open(legacy.c_str());
  sql(handle,"CREATE TABLE scanned_tracks(id INTEGER PRIMARY KEY,title TEXT,artist TEXT,album TEXT,file_path TEXT UNIQUE,format INTEGER,sample_rate INTEGER,bit_depth INTEGER,duration_sec INTEGER)");
  hifi_library_db_close(handle);
  require(scan(legacy,{moved.string()},moved.string(),0).count==2,"Legacy path-unique schema was not migrated by the engine");
  const auto report=std::string(hifi_library_scan_json(pi.c_str(),nullptr,0,"",0));require(report.find("\"ok\":false")!=report.npos,"Invalid C ABI scan accepted");
  std::cout<<"Shared native library: CUE UTF-8/UTF-16/GBK, frame precision, final WAV duration, stable IDs, playlists, SQL binding/transactions, rollback, Documents relocation, private/public WiFi preservation, monotonic IDs, global/hidden/symlink/permissions and C ABI errors passed\n";
  fs::remove_all(root);return 0;
 }catch(const std::exception& e){std::cerr<<e.what()<<"\nFixture: "<<root<<'\n';return 1;}
}
