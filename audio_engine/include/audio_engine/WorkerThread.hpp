#pragma once
#include <atomic>
#include <memory>
#include <thread>
#include <utility>

namespace audio_engine {
// Cooperative cancellation without experimental libc++ stop_token (Android NDK).
class StopToken {
public:
    explicit StopToken(std::shared_ptr<std::atomic<bool>> stopped) : stopped_(std::move(stopped)) {}
    bool stop_requested() const { return stopped_ && stopped_->load(std::memory_order_acquire); }
private:
    std::shared_ptr<std::atomic<bool>> stopped_;
};

class WorkerThread {
public:
    WorkerThread() = default;
    template<class Function>
    explicit WorkerThread(Function function)
        : stopped_(std::make_shared<std::atomic<bool>>(false)),
          thread_([function = std::move(function), token = StopToken(stopped_)]() mutable { function(token); }) {}
    WorkerThread(const WorkerThread&) = delete;
    WorkerThread& operator=(const WorkerThread&) = delete;
    WorkerThread(WorkerThread&&) noexcept = default;
    WorkerThread& operator=(WorkerThread&& other) noexcept {
        if (this != &other) {
            finish();
            stopped_ = std::move(other.stopped_);
            thread_ = std::move(other.thread_);
        }
        return *this;
    }
    ~WorkerThread() { finish(); }
    bool request_stop() {
        return stopped_ && !stopped_->exchange(true, std::memory_order_acq_rel);
    }
    bool joinable() const { return thread_.joinable(); }
    void join() { thread_.join(); }
private:
    void finish() {
        request_stop();
        if (thread_.joinable()) thread_.join();
    }
    std::shared_ptr<std::atomic<bool>> stopped_;
    std::thread thread_;
};
}
