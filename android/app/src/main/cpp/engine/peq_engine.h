#ifndef TANNHAUSER_PEQ_ENGINE_H
#define TANNHAUSER_PEQ_ENGINE_H

#include <cstdint>
#include <cstddef>
#include <atomic>
#include <mutex>
#include <cmath>
#include "usb_driver.h" // For AudioFormat

namespace tannhauser {

constexpr int MAX_PEQ_BANDS = 10;

enum class PeqFilterType {
    PEAKING = 0,
    LOW_SHELF = 1,
    HIGH_SHELF = 2,
    LOW_PASS = 3,
    HIGH_PASS = 4
};

struct BiquadCoeffs {
    double b0 = 1.0;
    double b1 = 0.0;
    double b2 = 0.0;
    double a1 = 0.0;
    double a2 = 0.0;
    bool enabled = false;
};

struct BiquadState {
    double z1_L = 0.0;
    double z2_L = 0.0;
    double z1_R = 0.0;
    double z2_R = 0.0;
};

struct PeqBandConfig {
    int type = 0;        // 0: PK, 1: LS, 2: HS, 3: LP, 4: HP
    double fc = 1000.0;  // Center frequency in Hz
    double gainDb = 0.0; // Gain in dB
    double q = 0.7071;   // Quality factor
    bool enabled = false;
};

class PeqEngine {
public:
    PeqEngine();
    ~PeqEngine() = default;

    void setEnabled(bool enabled);
    bool isEnabled() const { return enabled_.load(std::memory_order_relaxed); }

    void setPreampDb(double preampDb);
    double getPreampDb() const { return preampDb_.load(std::memory_order_relaxed); }

    void updateBand(int index, int type, double fc, double gainDb, double q, bool enabled);
    void setSampleRate(int sampleRate);
    void resetStates();

    // Process interleaved PCM in-place using Transposed Direct Form II cascade
    // Supports 16-bit, 24-bit, and 32-bit integer PCM formats.
    void process(uint8_t* pcmData, size_t sizeBytes, const AudioFormat& format);

private:
    void calculateCoefficients(const PeqBandConfig& config, int sampleRate, BiquadCoeffs& outCoeffs);
    void clearStatesInternal();

    std::atomic<bool> enabled_{false};
    std::atomic<bool> resetPending_{false};
    std::atomic<double> preampDb_{0.0};
    std::atomic<double> preampLinear_{1.0};
    std::atomic<int> currentSampleRate_{44100};

    // Double-buffered coefficient table for lock-free audio thread reads
    BiquadCoeffs coeffBuffers_[2][MAX_PEQ_BANDS];
    std::atomic<int> activeBufferIndex_{0};

    // Filter delay states per band (accessed strictly by the audio decoding thread)
    BiquadState filterStates_[MAX_PEQ_BANDS];

    // Band configurations (guarded by configMutex_ during JNI configuration updates)
    PeqBandConfig bandConfigs_[MAX_PEQ_BANDS];
    std::mutex configMutex_;

    // TPDF Dither fast PRNG state
    uint32_t prngState_{0x12345678};
    inline double generateTpdfDither() {
        prngState_ ^= prngState_ << 13;
        prngState_ ^= prngState_ >> 17;
        prngState_ ^= prngState_ << 5;
        uint32_t r1 = prngState_;
        prngState_ ^= prngState_ << 13;
        prngState_ ^= prngState_ >> 17;
        prngState_ ^= prngState_ << 5;
        uint32_t r2 = prngState_;
        return ((double)r1 - (double)r2) / 4294967296.0;
    }
};

} // namespace tannhauser

#endif // TANNHAUSER_PEQ_ENGINE_H
