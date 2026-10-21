#include "audio_engine/RuntimeContext.hpp"
#include "hifi_audio_ffi.h"
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>

static void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

int main() {
    using namespace audio_engine;
    try {
        for (const auto* platform : {"iphone", "ipad", "mac", "pi", "android", "window", "linux"}) {
            RuntimeContext context;
            require(context.configure(platform, 0), "Valid platform rejected");
            require(context.platformName() == std::string(platform), "Platform was guessed or changed");
            require(context.configure(platform, 0), "Idempotent initialization failed");
            require(!context.configure("unknown", 0), "Invalid platform accepted");
            require(!context.configure(platform, 32), "Unknown policy accepted");
        }
        RuntimeContext context;
        require(context.configure("ipad", prefer_remote_io), "iPad initialization failed");
        require(!context.configure("iphone", prefer_remote_io), "Initialized identity changed");
        require(!context.updateHostOutput({0, 2, "id", "speaker", "BuiltIn"}), "Invalid rate accepted");
        require(!context.updateHostOutput({48000, 0, "id", "speaker", "BuiltIn"}), "Invalid channel count accepted");
        HostOutput output{48000, 2, "airpods-id", "AirPods Pro", "Bluetooth"};
        require(context.updateHostOutput(output), "Host output rejected");
        output.name = "Changed by caller";
        require(context.hostOutput().name == "AirPods Pro", "Host data was not copied");
        require(context.updateHostOutput({16000, 1, "airpods-id", "AirPods Pro", "Bluetooth"}), "Voice route rejected");
        require(context.hostOutput().channels == 1, "Route update was lost");

        require(hifi_audio_get_abi_version() == 2, "C ABI version mismatch");
        require(!hifi_audio_init(), "C ABI silently guessed its platform");
        require(!hifi_audio_init_for_platform(nullptr, 0), "Null platform accepted");
        require(!hifi_audio_init_for_platform("platfrom", 0), "Unknown platform accepted");
        require(hifi_audio_init_for_platform("mac", 0), "Explicit C ABI initialization failed");
        const std::string capabilities = hifi_audio_get_capabilities_json();
        require(capabilities.find("\"platform\":\"mac\"") != std::string::npos, "Injected platform missing");
        require(capabilities.find("\"session_owner\":\"host\"") != std::string::npos, "Host session ownership missing");
        require(!hifi_audio_update_host_output(0, 2, "id", "name", "BuiltIn"), "Invalid C ABI format accepted");
        std::cout << "Explicit platform, immutable initialization, host format, C ABI and capabilities: passed\n";
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return EXIT_FAILURE;
    }
}
