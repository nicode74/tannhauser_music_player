#include "audio_engine.h"
#include <android/log.h>
#include <chrono>

#define LOG_TAG "Tannhauser_AudioEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace tannhauser {

AudioEngine& AudioEngine::getInstance() {
    static AudioEngine instance;
    return instance;
}

AudioEngine::AudioEngine()
    : state_(PlaybackState::STOPPED),
      isRunning_(false),
      currentPositionMs_(0),
      totalDurationMs_(0),
      decoder_(std::make_unique<AudioDecoder>()),
      usbDriver_(std::make_unique<UsbDriver>()),
      ringBuffer_(std::make_shared<RingBuffer>(2 * 1024 * 1024)) {} // 2 MB buffer

AudioEngine::~AudioEngine() {
    stop();
}

bool AudioEngine::setUsbFileDescriptor(int fd) {
    std::lock_guard<std::mutex> lock(engineMutex_);
    LOGI("AudioEngine: Received USB FD %d", fd);
    return usbDriver_->setFileDescriptor(fd);
}

bool AudioEngine::loadFile(const std::string& filePath) {
    std::lock_guard<std::mutex> lock(engineMutex_);
    stop();

    currentFilePath_ = filePath;
    if (!decoder_->open(filePath)) {
        LOGE("AudioEngine: Failed to open file: %s", filePath.c_str());
        return false;
    }

    totalDurationMs_ = decoder_->getDurationMs();
    currentPositionMs_ = 0;

    // Konfigurasi DAC dengan format asli file audio untuk bit-perfect streaming
    const AudioFormat& format = decoder_->getFormat();
    usbDriver_->configureAudioStreaming(format);

    LOGI("AudioEngine: File loaded. Ready to stream bit-perfect %d Hz / %d bit to USB DAC.",
         format.sampleRate, format.bitDepth);
    return true;
}

bool AudioEngine::play() {
    std::lock_guard<std::mutex> lock(engineMutex_);
    if (state_ == PlaybackState::PLAYING) return true;

    if (!decoder_->isOpen()) {
        if (currentFilePath_.empty() || !decoder_->open(currentFilePath_)) {
            LOGE("AudioEngine: No file loaded to play.");
            return false;
        }
    }

    ringBuffer_->reset();
    isRunning_ = true;
    state_ = PlaybackState::PLAYING;

    // Start direct USB streaming worker
    usbDriver_->startStreaming(ringBuffer_);

    // Start background decoding thread
    if (decodeThread_.joinable()) {
        decodeThread_.join();
    }
    decodeThread_ = std::thread(&AudioEngine::decodeWorkerLoop, this);

    if (stateCallback_) {
        stateCallback_(PlaybackState::PLAYING);
    }
    LOGI("AudioEngine: Playback started.");
    return true;
}

bool AudioEngine::pause() {
    std::lock_guard<std::mutex> lock(engineMutex_);
    if (state_ != PlaybackState::PLAYING) return true;

    state_ = PlaybackState::PAUSED;
    if (stateCallback_) {
        stateCallback_(PlaybackState::PAUSED);
    }
    LOGI("AudioEngine: Playback paused.");
    return true;
}

bool AudioEngine::resume() {
    std::lock_guard<std::mutex> lock(engineMutex_);
    if (state_ != PlaybackState::PAUSED) return true;

    state_ = PlaybackState::PLAYING;
    if (stateCallback_) {
        stateCallback_(PlaybackState::PLAYING);
    }
    LOGI("AudioEngine: Playback resumed.");
    return true;
}

bool AudioEngine::stop() {
    {
        std::lock_guard<std::mutex> lock(engineMutex_);
        if (state_ == PlaybackState::STOPPED) return true;

        state_ = PlaybackState::STOPPED;
        isRunning_ = false;
        ringBuffer_->stop();
        usbDriver_->stopStreaming();
    }

    if (decodeThread_.joinable()) {
        decodeThread_.join();
    }

    ringBuffer_->clear();
    currentPositionMs_ = 0;

    if (stateCallback_) {
        stateCallback_(PlaybackState::STOPPED);
    }
    LOGI("AudioEngine: Playback stopped.");
    return true;
}

bool AudioEngine::seek(int64_t positionMs) {
    std::lock_guard<std::mutex> lock(engineMutex_);
    LOGI("AudioEngine: Seeking to %lld ms", (long long)positionMs);
    
    ringBuffer_->clear();
    bool success = decoder_->seek(positionMs);
    if (success) {
        currentPositionMs_ = positionMs;
    }
    return success;
}

PlaybackInfo AudioEngine::getPlaybackInfo() const {
    std::lock_guard<std::mutex> lock(engineMutex_);
    PlaybackInfo info;
    info.state = state_.load();
    info.currentPositionMs = currentPositionMs_.load();
    info.totalDurationMs = totalDurationMs_.load();
    if (decoder_->isOpen()) {
        info.format = decoder_->getFormat();
    }
    return info;
}

void AudioEngine::decodeWorkerLoop() {
    LOGI("AudioEngine: Decode worker loop entered.");
    std::vector<uint8_t> pcmFrame;

    while (isRunning_ && state_ != PlaybackState::STOPPED) {
        if (state_ == PlaybackState::PAUSED) {
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
            continue;
        }

        if (!decoder_->decodeNextFrame(pcmFrame)) {
            LOGI("AudioEngine: End of stream reached or decoding stopped.");
            break;
        }

        if (!pcmFrame.empty()) {
            ringBuffer_->write(pcmFrame.data(), pcmFrame.size());
        }
    }
    LOGI("AudioEngine: Decode worker loop exited.");
}

} // namespace tannhauser
