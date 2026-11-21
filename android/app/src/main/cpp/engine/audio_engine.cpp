#include "audio_engine.h"
#include <chrono>

#if __has_include(<android/log.h>)
#include <android/log.h>
#define LOG_TAG "Tannhauser_AudioEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#include <cstdio>
#define LOG_TAG "Tannhauser_AudioEngine"
#define LOGI(...) printf(__VA_ARGS__)
#define LOGE(...) fprintf(stderr, __VA_ARGS__)
#endif

namespace tannhauser {

AudioEngine &AudioEngine::getInstance() {
  static AudioEngine instance;
  return instance;
}

AudioEngine::AudioEngine()
    : state_(PlaybackState::STOPPED), isRunning_(false), currentPositionMs_(0),
      totalDurationMs_(0), decoder_(std::make_unique<AudioDecoder>()),
      usbDriver_(std::make_unique<UsbDriver>()),
      ringBuffer_(std::make_shared<RingBuffer>(2 * 1024 * 1024)) {
} // 2 MB buffer

AudioEngine::~AudioEngine() { stop(); }

bool AudioEngine::setUsbFileDescriptor(int fd) {
  LOGI("AudioEngine::setUsbFileDescriptor - START: FD=%d", fd);
  std::lock_guard<std::recursive_mutex> lock(engineMutex_);
  bool res = usbDriver_->setFileDescriptor(fd);
  LOGI("AudioEngine::setUsbFileDescriptor - END: result=%d", res ? 1 : 0);
  return res;
}

bool AudioEngine::play() {
  LOGI("AudioEngine::play - START");
  std::lock_guard<std::recursive_mutex> lock(engineMutex_);
  if (state_ == PlaybackState::PLAYING) {
    LOGI("AudioEngine::play - Already playing");
    return true;
  }

  if (!decoder_->isOpen()) {
    if (currentFilePath_.empty() || !decoder_->open(currentFilePath_)) {
      LOGE("AudioEngine::play - No valid file opened to play.");
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
    if (decodeThread_.get_id() != std::this_thread::get_id()) {
      decodeThread_.join();
    }
  }
  decodeThread_ = std::thread(&AudioEngine::decodeWorkerLoop, this);

  if (stateCallback_) {
    stateCallback_(PlaybackState::PLAYING);
  }
  LOGI("AudioEngine::play - END: Playback started successfully.");
  return true;
}

bool AudioEngine::pause() {
  LOGI("AudioEngine::pause - START");
  std::lock_guard<std::recursive_mutex> lock(engineMutex_);
  if (state_ != PlaybackState::PLAYING) {
    LOGI("AudioEngine::pause - Not playing, nothing to pause");
    return true;
  }

  state_ = PlaybackState::PAUSED;
  if (stateCallback_) {
    stateCallback_(PlaybackState::PAUSED);
  }
  LOGI("AudioEngine::pause - END: Playback paused.");
  return true;
}

bool AudioEngine::resume() {
  LOGI("AudioEngine::resume - START");
  std::lock_guard<std::recursive_mutex> lock(engineMutex_);
  if (state_ != PlaybackState::PAUSED) {
    LOGI("AudioEngine::resume - Not paused, cannot resume");
    return true;
  }

  state_ = PlaybackState::PLAYING;
  if (stateCallback_) {
    stateCallback_(PlaybackState::PLAYING);
  }
  LOGI("AudioEngine::resume - END: Playback resumed.");
  return true;
}

bool AudioEngine::loadFile(const std::string &filePath) {
  LOGI("AudioEngine::loadFile - START: %s", filePath.c_str());

  if (filePath.empty()) {
    LOGE("AudioEngine::loadFile - File path is empty!");
    return false;
  }

  // Stop playback yang sedang berjalan terlebih dahulu
  stop();

  std::lock_guard<std::recursive_mutex> lock(engineMutex_);

  currentFilePath_ = filePath;
  if (!decoder_->open(filePath)) {
    LOGE("AudioEngine::loadFile - Decoder failed to open file: %s",
         filePath.c_str());
    currentFilePath_.clear();
    totalDurationMs_ = 0;
    currentPositionMs_ = 0;
    LOGI("AudioEngine::loadFile - END (FAILED)");
    return false;
  }

  totalDurationMs_ = decoder_->getDurationMs();
  currentPositionMs_ = 0;

  // Sinkronisasi sample rate file audio ke PEQ Engine untuk rekalkulasi
  // koefisien biquad
  const AudioFormat &format = decoder_->getFormat();
  peqEngine_.setSampleRate(format.sampleRate);

  // Konfigurasi DAC dengan format asli file audio jika DAC sudah terhubung.
  // Hindari blocking libusb jika DAC belum dicolok.
  if (usbDriver_->isConnected()) {
    usbDriver_->configureAudioStreaming(format);
    LOGI("AudioEngine::loadFile - USB DAC configured for bit-perfect %d Hz / "
         "%d bit.",
         format.sampleRate, format.bitDepth);
  } else {
    LOGI("AudioEngine::loadFile - USB DAC not connected yet. Skipping USB "
         "configuration until DAC is plugged in.");
  }

  LOGI("AudioEngine::loadFile - SUCCESS: %d Hz, %d channels, %d bits, duration "
       "%lld ms",
       format.sampleRate, format.channels, format.bitDepth,
       (long long)totalDurationMs_);
  LOGI("AudioEngine::loadFile - END (SUCCESS)");
  return true;
}

bool AudioEngine::stop() {
  LOGI("AudioEngine::stop - START");
  {
    std::lock_guard<std::recursive_mutex> lock(engineMutex_);
    if (state_ == PlaybackState::STOPPED) {
      LOGI("AudioEngine::stop - Already stopped");
      return true;
    }

    state_ = PlaybackState::STOPPED;
    isRunning_ = false;
    ringBuffer_->stop();
    usbDriver_->stopStreaming();
  }

  // Join decodeThread di luar lock untuk menghindari deadlock
  if (decodeThread_.joinable()) {
    if (decodeThread_.get_id() != std::this_thread::get_id()) {
      decodeThread_.join();
    }
  }

  {
    std::lock_guard<std::recursive_mutex> lock(engineMutex_);
    ringBuffer_->clear();
    currentPositionMs_ = 0;

    if (stateCallback_) {
      stateCallback_(PlaybackState::STOPPED);
    }
  }

  LOGI("AudioEngine::stop - END");
  return true;
}

bool AudioEngine::seek(int64_t positionMs) {
  LOGI("AudioEngine::seek - START: %lld ms", (long long)positionMs);
  std::lock_guard<std::recursive_mutex> lock(engineMutex_);

  ringBuffer_->clear();
  bool success = decoder_->seek(positionMs);
  if (success) {
    currentPositionMs_ = positionMs;
  }
  LOGI("AudioEngine::seek - END: result=%d", success ? 1 : 0);
  return success;
}

PlaybackInfo AudioEngine::getPlaybackInfo() const {
  std::lock_guard<std::recursive_mutex> lock(engineMutex_);
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
      if (peqEngine_.isEnabled()) {
        peqEngine_.process(pcmFrame.data(), pcmFrame.size(),
                           decoder_->getFormat());
      }
      ringBuffer_->write(pcmFrame.data(), pcmFrame.size());
    }
  }
  LOGI("AudioEngine: Decode worker loop exited.");
}

void AudioEngine::setPeqEnabled(bool enabled) {
  peqEngine_.setEnabled(enabled);
}

bool AudioEngine::isPeqEnabled() const { return peqEngine_.isEnabled(); }

void AudioEngine::setPeqPreamp(double preampDb) {
  peqEngine_.setPreampDb(preampDb);
}

void AudioEngine::updatePeqBand(int index, int type, double fc, double gainDb,
                                double q, bool enabled) {
  peqEngine_.updateBand(index, type, fc, gainDb, q, enabled);
}

void AudioEngine::resetPeqStates() { peqEngine_.resetStates(); }

} // namespace tannhauser
