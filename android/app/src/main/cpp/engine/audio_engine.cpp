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
      seekBasePositionMs_(0), totalDurationMs_(0),
      decoder_(std::make_unique<AudioDecoder>()),
      usbDriver_(std::make_unique<UsbDriver>()),
      ringBuffer_(std::make_shared<RingBuffer>(2 * 1024 * 1024)) {
} // 2 MB buffer

AudioEngine::~AudioEngine() { stop(); }

bool AudioEngine::setUsbFileDescriptor(int fd) {
  LOGI("AudioEngine::setUsbFileDescriptor - START: FD=%d", fd);
  std::lock_guard<std::recursive_mutex> lock(engineMutex_);
  bool res = usbDriver_->setFileDescriptor(fd);
  if (res && decoder_->isOpen()) {
    usbDriver_->configureAudioStreaming(decoder_->getFormat());
    LOGI("AudioEngine::setUsbFileDescriptor - Reconfigured audio streaming on new USB connection");
  }
  LOGI("AudioEngine::setUsbFileDescriptor - END: result=%d", res ? 1 : 0);
  return res;
}

void AudioEngine::resetUsbDevice() {
  LOGI("AudioEngine::resetUsbDevice - START");
  std::lock_guard<std::recursive_mutex> lock(engineMutex_);
  if (state_ == PlaybackState::PLAYING) {
    pause();
  }
  usbDriver_->close();
  LOGI("AudioEngine::resetUsbDevice - END: Closed USB driver cleanly");
}

bool AudioEngine::play() {
  LOGI("AudioEngine::play - START");
  std::lock_guard<std::recursive_mutex> lock(engineMutex_);
  if (state_ == PlaybackState::PLAYING) {
    LOGI("AudioEngine::play - Already playing");
    return true;
  }

  if (state_ == PlaybackState::PAUSED) {
    return resume();
  }

  if (!decoder_->isOpen()) {
    if (currentFilePath_.empty() || !decoder_->open(currentFilePath_)) {
      LOGE("AudioEngine::play - No valid file opened to play.");
      return false;
    }
  }

  // Pastikan DAC terkonfigurasi jika terhubung
  if (usbDriver_->isConnected()) {
    usbDriver_->configureAudioStreaming(decoder_->getFormat());
  }

  ringBuffer_->reset();
  isRunning_ = true;
  state_ = PlaybackState::PLAYING;

  // Mulai transmisi streaming USB bit-perfect
  usbDriver_->startStreaming(ringBuffer_);

  // Mulai thread decoding FFmpeg latar belakang
  if (decodeThread_.joinable()) {
    if (decodeThread_.get_id() != std::this_thread::get_id()) {
      isRunning_ = false;
      ringBuffer_->stop();
      decodeThread_.join();
    }
  }
  isRunning_ = true;
  ringBuffer_->reset();
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
  // Simpan posisi saat pause
  seekBasePositionMs_ = currentPositionMs_.load();
  usbDriver_->resetBytesTransferred();

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

  if (usbDriver_->isConnected() && !usbDriver_->isStreaming()) {
    usbDriver_->configureAudioStreaming(decoder_->getFormat());
    usbDriver_->startStreaming(ringBuffer_);
  }

  state_ = PlaybackState::PLAYING;
  usbDriver_->resetBytesTransferred();

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
    seekBasePositionMs_ = 0;
    LOGI("AudioEngine::loadFile - END (FAILED)");
    return false;
  }

  totalDurationMs_ = decoder_->getDurationMs();
  currentPositionMs_ = 0;
  seekBasePositionMs_ = 0;
  usbDriver_->resetBytesTransferred();

  // Sinkronisasi sample rate file audio ke PEQ Engine untuk rekalkulasi koefisien biquad
  const AudioFormat &format = decoder_->getFormat();
  peqEngine_.setSampleRate(format.sampleRate);

  // Konfigurasi DAC dengan format asli file audio jika DAC sudah terhubung
  if (usbDriver_->isConnected()) {
    usbDriver_->configureAudioStreaming(format);
    LOGI("AudioEngine::loadFile - USB DAC configured for bit-perfect %d Hz / %d bit.",
         format.sampleRate, format.bitDepth);
  } else {
    LOGI("AudioEngine::loadFile - USB DAC not connected yet. Will configure upon attachment.");
  }

  LOGI("AudioEngine::loadFile - SUCCESS: %d Hz, %d channels, %d bits, duration %lld ms",
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
    seekBasePositionMs_ = 0;
    usbDriver_->resetBytesTransferred();

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

  bool wasPlaying = (state_ == PlaybackState::PLAYING);

  ringBuffer_->clear();
  bool success = decoder_->seek(positionMs);
  if (success) {
    seekBasePositionMs_ = positionMs;
    usbDriver_->resetBytesTransferred();
    currentPositionMs_ = positionMs;
  }

  if (wasPlaying && !usbDriver_->isStreaming()) {
    usbDriver_->startStreaming(ringBuffer_);
  }

  LOGI("AudioEngine::seek - END: result=%d", success ? 1 : 0);
  return success;
}

PlaybackInfo AudioEngine::getPlaybackInfo() const {
  std::lock_guard<std::recursive_mutex> lock(engineMutex_);
  PlaybackInfo info;
  info.state = state_.load();
  info.totalDurationMs = totalDurationMs_.load();
  if (decoder_->isOpen()) {
    info.format = decoder_->getFormat();
  }

  // Kalkulasi realtime posisi berbasis akumulasi byte PCM yang terkirim ke hardware
  if (state_ == PlaybackState::PLAYING && usbDriver_->isStreaming()) {
    const AudioFormat &fmt = info.format;
    int hwSubslot = usbDriver_->getHwSubslotSize();
    int bytesPerSample = (hwSubslot > 0) ? hwSubslot : ((fmt.bitDepth > 0 ? fmt.bitDepth : 16) / 8);
    int channels = fmt.channels > 0 ? fmt.channels : 2;
    int sampleRate = fmt.sampleRate > 0 ? fmt.sampleRate : 44100;
    int bytesPerSec = sampleRate * channels * bytesPerSample;

    if (bytesPerSec > 0) {
      uint64_t transferred = usbDriver_->getBytesTransferred();
      int64_t elapsedMs = (transferred * 1000) / bytesPerSec;
      int64_t computed = seekBasePositionMs_.load() + elapsedMs;
      if (totalDurationMs_ > 0 && computed > totalDurationMs_) {
        computed = totalDurationMs_.load();
      }
      currentPositionMs_ = computed;
    }
  }

  info.currentPositionMs = currentPositionMs_.load();
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
      // Tunggu hingga sisa data di buffer habis dikonsumsi oleh DAC
      while (isRunning_ && state_ == PlaybackState::PLAYING && ringBuffer_->availableRead() > 0) {
        std::this_thread::sleep_for(std::chrono::milliseconds(40));
      }
      if (isRunning_ && state_ == PlaybackState::PLAYING) {
        state_ = PlaybackState::STOPPED;
        if (stateCallback_) {
          stateCallback_(PlaybackState::STOPPED);
        }
      }
      break;
    }

    if (!pcmFrame.empty()) {
      if (peqEngine_.isEnabled()) {
        peqEngine_.process(pcmFrame.data(), pcmFrame.size(),
                           decoder_->getFormat());
      }
      float vol = masterVolume_.load();
      if (vol < 0.999f) {
        applyVolume(pcmFrame.data(), pcmFrame.size(), decoder_->getFormat(), vol);
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

void AudioEngine::setVolume(float volume) {
  if (volume < 0.0f) volume = 0.0f;
  if (volume > 1.0f) volume = 1.0f;
  masterVolume_.store(volume);
  LOGI("AudioEngine::setVolume - Volume updated to %.2f", volume);
}

void AudioEngine::applyVolume(uint8_t* data, size_t size, const AudioFormat& format, float volume) {
  if (volume >= 0.999f || data == nullptr || size == 0) {
    return; // 100% bit-perfect bypass
  }
  if (volume <= 0.0001f) {
    std::memset(data, 0, size);
    return;
  }

  if (format.bitDepth == 16) {
    int16_t* samples = reinterpret_cast<int16_t*>(data);
    size_t count = size / sizeof(int16_t);
    for (size_t i = 0; i < count; ++i) {
      float s = samples[i] * volume;
      if (s > 32767.0f) s = 32767.0f;
      else if (s < -32768.0f) s = -32768.0f;
      samples[i] = static_cast<int16_t>(s);
    }
  } else if (format.bitDepth == 32) {
    int32_t* samples = reinterpret_cast<int32_t*>(data);
    size_t count = size / sizeof(int32_t);
    for (size_t i = 0; i < count; ++i) {
      double s = static_cast<double>(samples[i]) * volume;
      if (s > 2147483647.0) s = 2147483647.0;
      else if (s < -2147483648.0) s = -2147483648.0;
      samples[i] = static_cast<int32_t>(s);
    }
  } else if (format.bitDepth == 24) {
    for (size_t i = 0; i + 2 < size; i += 3) {
      int32_t sample = (int32_t)((uint32_t)data[i] | ((uint32_t)data[i+1] << 8) | ((uint32_t)(int8_t)data[i+2] << 16));
      double s = sample * volume;
      if (s > 8388607.0) s = 8388607.0;
      else if (s < -8388608.0) s = -8388608.0;
      int32_t outSample = static_cast<int32_t>(s);
      data[i] = outSample & 0xFF;
      data[i+1] = (outSample >> 8) & 0xFF;
      data[i+2] = (outSample >> 16) & 0xFF;
    }
  }
}

void AudioEngine::resetPeqStates() { peqEngine_.resetStates(); }

} // namespace tannhauser
