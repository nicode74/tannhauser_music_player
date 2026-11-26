#ifndef TANNHAUSER_AUDIO_ENGINE_H
#define TANNHAUSER_AUDIO_ENGINE_H

#include <string>
#include <memory>
#include <atomic>
#include <thread>
#include <functional>
#include "audio_decoder.h"
#include "usb_driver.h"
#include "ring_buffer.h"
#include "peq_engine.h"

namespace tannhauser {

enum class PlaybackState {
    STOPPED,
    PLAYING,
    PAUSED
};

struct PlaybackInfo {
    PlaybackState state = PlaybackState::STOPPED;
    int64_t currentPositionMs = 0;
    int64_t totalDurationMs = 0;
    AudioFormat format;
};

using PositionCallback = std::function<void(int64_t currentMs, int64_t totalMs)>;
using StateCallback = std::function<void(PlaybackState state)>;

class AudioEngine {
public:
    static AudioEngine& getInstance();

    bool setUsbFileDescriptor(int fd);
    void resetUsbDevice();
    bool loadFile(const std::string& filePath);
    bool play();
    bool pause();
    bool resume();
    bool stop();
    bool seek(int64_t positionMs);

    // 64-Bit Parametric EQ Control
    void setPeqEnabled(bool enabled);
    bool isPeqEnabled() const;
    void setPeqPreamp(double preampDb);
    void updatePeqBand(int index, int type, double fc, double gainDb, double q, bool enabled);
    void resetPeqStates();

    // Master Digital Volume Control (0.0f - 1.0f)
    void setVolume(float volume);
    float getVolume() const { return masterVolume_.load(); }

    PlaybackState getState() const { return state_.load(); }
    PlaybackInfo getPlaybackInfo() const;

    void setPositionCallback(PositionCallback cb) { positionCallback_ = cb; }
    void setStateCallback(StateCallback cb) { stateCallback_ = cb; }

private:
    AudioEngine();
    ~AudioEngine();
    AudioEngine(const AudioEngine&) = delete;
    AudioEngine& operator=(const AudioEngine&) = delete;

    void decodeWorkerLoop();
    void applyVolume(uint8_t* data, size_t size, const AudioFormat& format, float volume);

    std::atomic<PlaybackState> state_;
    std::atomic<bool> isRunning_;
    std::atomic<float> masterVolume_{0.75f};
    mutable std::atomic<int64_t> currentPositionMs_;
    std::atomic<int64_t> seekBasePositionMs_;
    std::atomic<int64_t> totalDurationMs_;

    std::string currentFilePath_;
    
    std::unique_ptr<AudioDecoder> decoder_;
    std::unique_ptr<UsbDriver> usbDriver_;
    std::shared_ptr<RingBuffer> ringBuffer_;
    PeqEngine peqEngine_;

    std::thread decodeThread_;
    mutable std::recursive_mutex engineMutex_;
    mutable std::mutex decoderMutex_;

    PositionCallback positionCallback_;
    StateCallback stateCallback_;
};

} // namespace tannhauser

#endif // TANNHAUSER_AUDIO_ENGINE_H
