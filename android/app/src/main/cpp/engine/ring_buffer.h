#ifndef TANNHAUSER_RING_BUFFER_H
#define TANNHAUSER_RING_BUFFER_H

#include <vector>
#include <mutex>
#include <condition_variable>
#include <cstdint>
#include <algorithm>

namespace tannhauser {

class RingBuffer {
public:
    explicit RingBuffer(size_t capacity = 1024 * 1024) // Default 1 MB buffer
        : buffer_(capacity), capacity_(capacity), head_(0), tail_(0), size_(0), stopped_(false) {}

    size_t write(const uint8_t* data, size_t count) {
        std::unique_lock<std::mutex> lock(mutex_);
        if (stopped_ || count == 0) return 0;

        size_t bytesWritten = 0;
        while (bytesWritten < count && !stopped_) {
            size_t available = capacity_ - size_;
            if (available == 0) {
                // Buffer penuh, tunggu sampai konsumen membaca
                cv_not_full_.wait(lock, [this]() { return (capacity_ - size_) > 0 || stopped_; });
                if (stopped_) break;
                available = capacity_ - size_;
            }

            size_t toWrite = std::min(count - bytesWritten, available);
            size_t firstPart = std::min(toWrite, capacity_ - head_);
            std::copy(data + bytesWritten, data + bytesWritten + firstPart, buffer_.data() + head_);
            
            size_t secondPart = toWrite - firstPart;
            if (secondPart > 0) {
                std::copy(data + bytesWritten + firstPart, data + bytesWritten + toWrite, buffer_.data());
            }

            head_ = (head_ + toWrite) % capacity_;
            size_ += toWrite;
            bytesWritten += toWrite;

            cv_not_empty_.notify_one();
        }
        return bytesWritten;
    }

    size_t read(uint8_t* destination, size_t count) {
        std::unique_lock<std::mutex> lock(mutex_);
        if (count == 0) return 0;

        while (size_ == 0 && !stopped_) {
            // Buffer kosong, tunggu produsen menulis data
            cv_not_empty_.wait(lock, [this]() { return size_ > 0 || stopped_; });
        }

        if (size_ == 0 && stopped_) {
            return 0;
        }

        size_t toRead = std::min(count, size_);
        size_t firstPart = std::min(toRead, capacity_ - tail_);
        std::copy(buffer_.data() + tail_, buffer_.data() + tail_ + firstPart, destination);

        size_t secondPart = toRead - firstPart;
        if (secondPart > 0) {
            std::copy(buffer_.data(), buffer_.data() + secondPart, destination + firstPart);
        }

        tail_ = (tail_ + toRead) % capacity_;
        size_ -= toRead;

        cv_not_full_.notify_one();
        return toRead;
    }

    // Non-blocking read khusus untuk thread USB isochronous callback agar event pump tidak pernah deadlock
    size_t readAvailable(uint8_t* destination, size_t count) {
        std::unique_lock<std::mutex> lock(mutex_);
        if (count == 0 || size_ == 0 || stopped_) return 0;

        size_t toRead = std::min(count, size_);
        size_t firstPart = std::min(toRead, capacity_ - tail_);
        std::copy(buffer_.data() + tail_, buffer_.data() + tail_ + firstPart, destination);

        size_t secondPart = toRead - firstPart;
        if (secondPart > 0) {
            std::copy(buffer_.data(), buffer_.data() + secondPart, destination + firstPart);
        }

        tail_ = (tail_ + toRead) % capacity_;
        size_ -= toRead;

        cv_not_full_.notify_one();
        return toRead;
    }

    void clear() {
        std::lock_guard<std::mutex> lock(mutex_);
        head_ = 0;
        tail_ = 0;
        size_ = 0;
        cv_not_full_.notify_all();
    }

    void stop() {
        std::lock_guard<std::mutex> lock(mutex_);
        stopped_ = true;
        cv_not_empty_.notify_all();
        cv_not_full_.notify_all();
    }

    void reset() {
        std::lock_guard<std::mutex> lock(mutex_);
        head_ = 0;
        tail_ = 0;
        size_ = 0;
        stopped_ = false;
    }

    size_t availableRead() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return size_;
    }

private:
    std::vector<uint8_t> buffer_;
    size_t capacity_;
    size_t head_;
    size_t tail_;
    size_t size_;
    bool stopped_;
    mutable std::mutex mutex_;
    std::condition_variable cv_not_empty_;
    std::condition_variable cv_not_full_;
};

} // namespace tannhauser

#endif // TANNHAUSER_RING_BUFFER_H
