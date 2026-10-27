#include "audio_engine/library/MusicLibrary.hpp"
#include "sqlite/sqlite3.h"
#include <filesystem>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <iomanip>

namespace audio_engine::library {
namespace { thread_local std::string open_error; }
std::string jsonString(const std::string& value) {
    std::ostringstream out; out << '"';
    for (unsigned char c : value) {
        switch (c) {
            case '"': out << "\\\""; break;
            case '\\': out << "\\\\"; break;
            case '\n': out << "\\n"; break;
            case '\r': out << "\\r"; break;
            case '\t': out << "\\t"; break;
            default:
                if (c < 32) out << "\\u00" << std::hex << std::setw(2) << std::setfill('0') << int(c) << std::dec;
                else out << char(c);
        }
    }
    return out.str() + '"';
}
void* openDatabase(const char* path) {
    sqlite3* db = nullptr;
    try {
        if (!path || !*path) throw std::runtime_error("Database path is empty");
        const auto parent = std::filesystem::path(path).parent_path();
        if (!parent.empty()) std::filesystem::create_directories(parent);
        if (sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nullptr) != SQLITE_OK)
            throw std::runtime_error(db ? sqlite3_errmsg(db) : "Cannot open database");
        sqlite3_busy_timeout(db, 5000);
        if (sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nullptr, nullptr, nullptr) != SQLITE_OK)
            throw std::runtime_error(sqlite3_errmsg(db));
        open_error.clear(); return db;
    } catch (const std::exception& error) {
        open_error = error.what(); if (db) sqlite3_close(db); return nullptr;
    }
}
void closeDatabase(void* handle) { if (handle) sqlite3_close_v2(static_cast<sqlite3*>(handle)); }
std::string queryJson(void* handle, const char* sql, const char* parameters) {
    auto* db = static_cast<sqlite3*>(handle);
    if (!db || !sql) return "{\"ok\":false,\"error\":" + jsonString(open_error.empty() ? "Database is closed" : open_error) + "}";
    try {
        std::string rows = "[]";
        const char* remaining = sql;
        while (*remaining) {
            sqlite3_stmt* raw = nullptr; const char* tail = nullptr;
            if (sqlite3_prepare_v2(db, remaining, -1, &raw, &tail) != SQLITE_OK) throw std::runtime_error(sqlite3_errmsg(db));
            std::unique_ptr<sqlite3_stmt, decltype(&sqlite3_finalize)> statement(raw, sqlite3_finalize);
            if (!tail || tail == remaining) break;
            remaining = tail;
            if (!raw) continue;
            const auto count = sqlite3_bind_parameter_count(raw);
            if (count) {
                sqlite3_stmt* params_raw = nullptr;
                if (sqlite3_prepare_v2(db, "SELECT type,value FROM json_each(?) ORDER BY CAST(key AS INTEGER)", -1, &params_raw, nullptr) != SQLITE_OK)
                    throw std::runtime_error(sqlite3_errmsg(db));
                std::unique_ptr<sqlite3_stmt, decltype(&sqlite3_finalize)> params(params_raw, sqlite3_finalize);
                sqlite3_bind_text(params_raw, 1, parameters ? parameters : "[]", -1, SQLITE_TRANSIENT);
                int index = 0, status;
                while ((status = sqlite3_step(params_raw)) == SQLITE_ROW) {
                    if (++index > count) throw std::runtime_error("Too many SQL parameters");
                    const std::string type = reinterpret_cast<const char*>(sqlite3_column_text(params_raw,0));
                    if (type == "null") sqlite3_bind_null(raw,index);
                    else if (type == "integer" || type == "true" || type == "false") sqlite3_bind_int64(raw,index,sqlite3_column_int64(params_raw,1));
                    else if (type == "real") sqlite3_bind_double(raw,index,sqlite3_column_double(params_raw,1));
                    else if (type == "text") sqlite3_bind_text(raw,index,reinterpret_cast<const char*>(sqlite3_column_text(params_raw,1)),sqlite3_column_bytes(params_raw,1),SQLITE_TRANSIENT);
                    else throw std::runtime_error("Unsupported SQL parameter type");
                }
                if (status != SQLITE_DONE || index != count) throw std::runtime_error("Invalid SQL parameters");
            }
            std::ostringstream result; result << '['; bool first = true; int status;
            while ((status = sqlite3_step(raw)) == SQLITE_ROW) {
                if (!first) result << ','; first = false; result << '{';
                for (int i = 0; i < sqlite3_column_count(raw); ++i) {
                    if (i) result << ','; result << jsonString(sqlite3_column_name(raw,i)) << ':';
                    switch (sqlite3_column_type(raw,i)) {
                        case SQLITE_NULL: result << "null"; break;
                        case SQLITE_INTEGER: result << sqlite3_column_int64(raw,i); break;
                        case SQLITE_FLOAT: result << std::setprecision(17) << sqlite3_column_double(raw,i); break;
                        case SQLITE_TEXT: result << jsonString(std::string(reinterpret_cast<const char*>(sqlite3_column_text(raw,i)),sqlite3_column_bytes(raw,i))); break;
                        default: throw std::runtime_error("Binary SQL results are not supported by the library bridge");
                    }
                }
                result << '}';
            }
            if (status != SQLITE_DONE) throw std::runtime_error(sqlite3_errmsg(db));
            result << ']'; rows = result.str();
        }
        return "{\"ok\":true,\"rows\":" + rows + "}";
    } catch (const std::exception& error) { return "{\"ok\":false,\"error\":" + jsonString(error.what()) + "}"; }
}
} // namespace audio_engine::library
