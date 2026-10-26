#pragma once

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <string_view>

namespace audio_engine {

enum class ClientPlatform { unknown, iphone, ipad, mac, pi, android, window, linux_desktop };
enum OutputPolicy : uint32_t {
    exclude_display_outputs = 1,
    synchronize_system_output = 2,
    prefer_remote_io = 4,
    prefer_external_output = 8,
};

struct AndroidOutputPreferences {
    int32_t device_id = 0; // 0 follows Android's media route
    uint32_t sample_rate = 0; // 0 follows the source
    bool exclusive = true; // preference; the stream reports the actual mode
    bool operator==(const AndroidOutputPreferences&) const = default;
};

struct HostOutput {
    uint32_t sample_rate = 0;
    uint32_t channels = 0;
    std::string id;
    std::string name;
    std::string transport;
};

// Host-neutral input contract. No Flutter, UIKit, JNI, or application callbacks.
class RuntimeContext {
public:
    bool configure(std::string_view platform, uint32_t policies) {
        ClientPlatform value = ClientPlatform::unknown;
        for (auto candidate : {ClientPlatform::iphone, ClientPlatform::ipad, ClientPlatform::mac,
                               ClientPlatform::pi, ClientPlatform::android, ClientPlatform::window,
                               ClientPlatform::linux_desktop})
            if (platform == platformName(candidate)) value = candidate;
        if (value == ClientPlatform::unknown || (policies & ~uint32_t(15))) return false;
        std::lock_guard lock(mutex_);
        if (platform_.load() != ClientPlatform::unknown)
            return platform_.load() == value && policies_.load() == policies;
        policies_.store(policies);
        platform_.store(value);
        return true;
    }

    static const char* platformName(ClientPlatform value) {
        switch (value) {
            case ClientPlatform::iphone: return "iphone";
            case ClientPlatform::ipad: return "ipad";
            case ClientPlatform::mac: return "mac";
            case ClientPlatform::pi: return "pi";
            case ClientPlatform::android: return "android";
            case ClientPlatform::window: return "window";
            case ClientPlatform::linux_desktop: return "linux";
            default: return "unknown";
        }
    }
    const char* platformName() const { return platformName(platform_.load()); }
    bool configured() const { return platform_.load() != ClientPlatform::unknown; }
    bool policy(OutputPolicy policy) const { return (policies_.load() & policy) != 0; }

    bool updateHostOutput(HostOutput output) {
        if ((output.sample_rate != 0 && (output.sample_rate < 8000 || output.sample_rate > 768000)) ||
            output.channels == 0 || output.channels > 8 ||
            output.id.empty() || output.name.empty()) return false;
        std::lock_guard lock(mutex_);
        host_output_ = std::move(output);
        return true;
    }
    bool setAndroidOutputPreferences(AndroidOutputPreferences preferences) {
        if (preferences.device_id < 0 || (preferences.sample_rate != 0 &&
            (preferences.sample_rate < 8000 || preferences.sample_rate > 768000))) return false;
        std::lock_guard lock(mutex_);
        android_output_ = preferences;
        return true;
    }
    AndroidOutputPreferences androidOutputPreferences() const {
        std::lock_guard lock(mutex_);
        return android_output_;
    }
    HostOutput hostOutput() const {
        std::lock_guard lock(mutex_);
        return host_output_;
    }

private:
    mutable std::mutex mutex_;
    std::atomic<ClientPlatform> platform_{ClientPlatform::unknown};
    std::atomic<uint32_t> policies_{0};
    HostOutput host_output_;
    AndroidOutputPreferences android_output_;
};

inline RuntimeContext& runtimeContext() {
    static RuntimeContext context;
    return context;
}

} // namespace audio_engine
