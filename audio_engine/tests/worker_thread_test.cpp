#include "audio_engine/WorkerThread.hpp"
#include <atomic>
#include <chrono>
#include <stdexcept>
#include <utility>

int main() {
    using namespace audio_engine;
    std::atomic<int> finished{0};
    auto run = [&](StopToken token) {
        while (!token.stop_requested()) std::this_thread::sleep_for(std::chrono::milliseconds(1));
        ++finished;
    };
    {
        WorkerThread first(run);
        WorkerThread second(std::move(first));
        if (first.joinable() || !second.joinable()) throw std::runtime_error("Move lost thread ownership");
        second = WorkerThread(run); // must stop and join previous worker before replacing it
        if (finished != 1) throw std::runtime_error("Replacement leaked the old worker");
        if (!second.request_stop() || second.request_stop()) throw std::runtime_error("Cancellation not idempotent");
        second.join();
    }
    if (finished != 2) throw std::runtime_error("Cancellation did not reach replacement worker");
    { WorkerThread worker(run); }
    if (finished != 3) throw std::runtime_error("Destructor did not stop and join");
}
