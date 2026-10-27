#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace audio_engine::library {
struct Metadata { uint32_t sample_rate = 0; int bit_depth = 0; double duration = 0; };
struct Track {
    int64_t id = 0;
    std::string title, artist, album, path, cue_path;
    int format = 0, sample_rate = 0, bit_depth = 0, duration = 0, number = 0;
    double start = 0, end = 0;
    bool cue = false;
};
struct ScanResult { size_t count = 0; std::vector<std::string> warnings; };
// Scan flags: bit 0 retains records outside a partial scan; bit 1 scans a
// filesystem root, including hidden directories, except virtual kernel trees.
ScanResult scan(const std::string& database, const std::vector<std::string>& roots,
                const std::string& documents, uint32_t flags);
Metadata metadata(const std::string& file);
std::vector<Track> load(const std::string& database);
std::string jsonString(const std::string& value);
std::string metadataJson(const std::string& file);
std::string scanJson(const char* database, const char* const* roots, uint32_t count,
                     const char* documents, uint32_t flags);
// All database connections used by the host also live in this engine. Opaque
// handles keep transactions intact across statements; JSON parameters are bound.
void* openDatabase(const char* path);
void closeDatabase(void* handle);
std::string queryJson(void* handle, const char* sql, const char* parameters);
} // namespace audio_engine::library
