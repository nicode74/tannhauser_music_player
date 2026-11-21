#include "peq_engine.h"
#include <algorithm>
#include <cstring>

#if __has_include(<android/log.h>)
#include <android/log.h>
#define LOG_TAG "Tannhauser_PeqEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#include <cstdio>
#define LOG_TAG "Tannhauser_PeqEngine"
#define LOGI(...) printf(__VA_ARGS__)
#define LOGE(...) fprintf(stderr, __VA_ARGS__)
#endif

namespace tannhauser {

PeqEngine::PeqEngine() {
    // Inisialisasi default 10-band standar ISO
    const double defaultFreqs[MAX_PEQ_BANDS] = {
        31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0
    };

    for (int i = 0; i < MAX_PEQ_BANDS; ++i) {
        bandConfigs_[i].type = 0; // Peaking
        bandConfigs_[i].fc = defaultFreqs[i];
        bandConfigs_[i].gainDb = 0.0;
        bandConfigs_[i].q = 1.414;
        bandConfigs_[i].enabled = false;

        calculateCoefficients(bandConfigs_[i], 44100, coeffBuffers_[0][i]);
        calculateCoefficients(bandConfigs_[i], 44100, coeffBuffers_[1][i]);
    }
    resetStates();
}

void PeqEngine::setEnabled(bool enabled) {
    enabled_.store(enabled, std::memory_order_relaxed);
    LOGI("PeqEngine::setEnabled - PEQ active state set to %d", enabled ? 1 : 0);
}

void PeqEngine::setPreampDb(double preampDb) {
    preampDb_.store(preampDb, std::memory_order_relaxed);
    double linear = std::pow(10.0, preampDb / 20.0);
    preampLinear_.store(linear, std::memory_order_relaxed);
    LOGI("PeqEngine::setPreampDb - Pre-amp set to %.2f dB (linear: %.4f)", preampDb, linear);
}

void PeqEngine::updateBand(int index, int type, double fc, double gainDb, double q, bool enabled) {
    if (index < 0 || index >= MAX_PEQ_BANDS) {
        LOGE("PeqEngine::updateBand - Index %d out of bounds (0-%d)", index, MAX_PEQ_BANDS - 1);
        return;
    }

    std::lock_guard<std::mutex> lock(configMutex_);
    bandConfigs_[index] = {type, fc, gainDb, q, enabled};

    int activeIdx = activeBufferIndex_.load(std::memory_order_relaxed);
    int inactiveIdx = 1 - activeIdx;

    int sampleRate = currentSampleRate_.load(std::memory_order_relaxed);
    for (int i = 0; i < MAX_PEQ_BANDS; ++i) {
        calculateCoefficients(bandConfigs_[i], sampleRate, coeffBuffers_[inactiveIdx][i]);
    }

    activeBufferIndex_.store(inactiveIdx, std::memory_order_release);
    LOGI("PeqEngine::updateBand - Band %d updated (type=%d, fc=%.1f Hz, gain=%.1f dB, Q=%.2f, en=%d)",
         index, type, fc, gainDb, q, enabled ? 1 : 0);
}

void PeqEngine::setSampleRate(int sampleRate) {
    if (sampleRate <= 0) return;
    std::lock_guard<std::mutex> lock(configMutex_);
    currentSampleRate_.store(sampleRate, std::memory_order_relaxed);

    int activeIdx = activeBufferIndex_.load(std::memory_order_relaxed);
    int inactiveIdx = 1 - activeIdx;

    for (int i = 0; i < MAX_PEQ_BANDS; ++i) {
        calculateCoefficients(bandConfigs_[i], sampleRate, coeffBuffers_[inactiveIdx][i]);
    }

    activeBufferIndex_.store(inactiveIdx, std::memory_order_release);
    resetStates();
    LOGI("PeqEngine::setSampleRate - Recomputed coefficients for sample rate %d Hz", sampleRate);
}

void PeqEngine::resetStates() {
    for (int i = 0; i < MAX_PEQ_BANDS; ++i) {
        filterStates_[i].z1_L = 0.0;
        filterStates_[i].z2_L = 0.0;
        filterStates_[i].z1_R = 0.0;
        filterStates_[i].z2_R = 0.0;
    }
}

void PeqEngine::calculateCoefficients(const PeqBandConfig& config, int sampleRate, BiquadCoeffs& out) {
    if (!config.enabled || sampleRate <= 0) {
        out.b0 = 1.0;
        out.b1 = 0.0;
        out.b2 = 0.0;
        out.a1 = 0.0;
        out.a2 = 0.0;
        out.enabled = false;
        return;
    }

    constexpr double kPi = 3.14159265358979323846;
    double nyquist = sampleRate * 0.5;
    double fc = std::max(10.0, std::min(config.fc, nyquist * 0.999));
    double q = std::max(0.01, config.q);
    double w0 = 2.0 * kPi * (fc / sampleRate);
    double cosW0 = std::cos(w0);
    double sinW0 = std::sin(w0);
    double alpha = sinW0 / (2.0 * q);
    double A = std::pow(10.0, config.gainDb / 40.0);

    double b0 = 1.0, b1 = 0.0, b2 = 0.0;
    double a0 = 1.0, a1 = 0.0, a2 = 0.0;

    switch (static_cast<PeqFilterType>(config.type)) {
        case PeqFilterType::PEAKING: {
            b0 = 1.0 + alpha * A;
            b1 = -2.0 * cosW0;
            b2 = 1.0 - alpha * A;
            a0 = 1.0 + alpha / A;
            a1 = -2.0 * cosW0;
            a2 = 1.0 - alpha / A;
            break;
        }
        case PeqFilterType::LOW_SHELF: {
            double temp = (A + 1.0 / A) * (1.0 / q - 1.0) + 2.0;
            double alphaShelf = (sinW0 / 2.0) * std::sqrt(std::max(0.0, temp));
            double twoSqrtAAlpha = 2.0 * std::sqrt(A) * alphaShelf;

            b0 = A * ((A + 1.0) - (A - 1.0) * cosW0 + twoSqrtAAlpha);
            b1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosW0);
            b2 = A * ((A + 1.0) - (A - 1.0) * cosW0 - twoSqrtAAlpha);
            a0 = (A + 1.0) + (A - 1.0) * cosW0 + twoSqrtAAlpha;
            a1 = -2.0 * ((A - 1.0) + (A + 1.0) * cosW0);
            a2 = (A + 1.0) + (A - 1.0) * cosW0 - twoSqrtAAlpha;
            break;
        }
        case PeqFilterType::HIGH_SHELF: {
            double temp = (A + 1.0 / A) * (1.0 / q - 1.0) + 2.0;
            double alphaShelf = (sinW0 / 2.0) * std::sqrt(std::max(0.0, temp));
            double twoSqrtAAlpha = 2.0 * std::sqrt(A) * alphaShelf;

            b0 = A * ((A + 1.0) + (A - 1.0) * cosW0 + twoSqrtAAlpha);
            b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosW0);
            b2 = A * ((A + 1.0) - (A - 1.0) * cosW0 - twoSqrtAAlpha);
            a0 = (A + 1.0) - (A - 1.0) * cosW0 + twoSqrtAAlpha;
            a1 = 2.0 * ((A - 1.0) - (A + 1.0) * cosW0);
            a2 = (A + 1.0) - (A - 1.0) * cosW0 - twoSqrtAAlpha;
            break;
        }
        case PeqFilterType::LOW_PASS: {
            b0 = (1.0 - cosW0) / 2.0;
            b1 = 1.0 - cosW0;
            b2 = (1.0 - cosW0) / 2.0;
            a0 = 1.0 + alpha;
            a1 = -2.0 * cosW0;
            a2 = 1.0 - alpha;
            break;
        }
        case PeqFilterType::HIGH_PASS: {
            b0 = (1.0 + cosW0) / 2.0;
            b1 = -(1.0 + cosW0);
            b2 = (1.0 + cosW0) / 2.0;
            a0 = 1.0 + alpha;
            a1 = -2.0 * cosW0;
            a2 = 1.0 - alpha;
            break;
        }
    }

    if (std::abs(a0) > 1e-15) {
        out.b0 = b0 / a0;
        out.b1 = b1 / a0;
        out.b2 = b2 / a0;
        out.a1 = a1 / a0;
        out.a2 = a2 / a0;
        out.enabled = true;
    } else {
        out.b0 = 1.0;
        out.b1 = 0.0;
        out.b2 = 0.0;
        out.a1 = 0.0;
        out.a2 = 0.0;
        out.enabled = false;
    }
}

void PeqEngine::process(uint8_t* pcmData, size_t sizeBytes, const AudioFormat& format) {
    if (!enabled_.load(std::memory_order_relaxed) || sizeBytes == 0 || !pcmData) {
        return;
    }

    int bytesPerSample = format.bitDepth / 8;
    if (bytesPerSample <= 0) bytesPerSample = 2; // Default 16-bit
    int channels = format.channels;
    if (channels <= 0) channels = 2;

    size_t frameSizeBytes = bytesPerSample * channels;
    size_t numFrames = sizeBytes / frameSizeBytes;
    if (numFrames == 0) return;

    const BiquadCoeffs* coeffs = coeffBuffers_[activeBufferIndex_.load(std::memory_order_acquire)];
    double preamp = preampLinear_.load(std::memory_order_relaxed);

    if (bytesPerSample == 2) {
        // 16-bit signed integer PCM
        int16_t* samples = reinterpret_cast<int16_t*>(pcmData);

        for (size_t f = 0; f < numFrames; ++f) {
            double x_L = static_cast<double>(samples[f * channels]) / 32768.0 * preamp;
            double x_R = (channels > 1) ? (static_cast<double>(samples[f * channels + 1]) / 32768.0 * preamp) : x_L;

            for (int i = 0; i < MAX_PEQ_BANDS; ++i) {
                const auto& c = coeffs[i];
                if (!c.enabled) continue;

                auto& s = filterStates_[i];

                double y_L = c.b0 * x_L + s.z1_L;
                s.z1_L = c.b1 * x_L - c.a1 * y_L + s.z2_L;
                s.z2_L = c.b2 * x_L - c.a2 * y_L;
                x_L = y_L;

                double y_R = c.b0 * x_R + s.z1_R;
                s.z1_R = c.b1 * x_R - c.a1 * y_R + s.z2_R;
                s.z2_R = c.b2 * x_R - c.a2 * y_R;
                x_R = y_R;
            }

            // TPDF Dither & Quantization
            double ditherL = generateTpdfDither() / 32768.0;
            double ditherR = generateTpdfDither() / 32768.0;

            int32_t outL = static_cast<int32_t>(std::round((x_L + ditherL) * 32767.0));
            int32_t outR = static_cast<int32_t>(std::round((x_R + ditherR) * 32767.0));

            samples[f * channels] = static_cast<int16_t>(std::clamp(outL, -32768, 32767));
            if (channels > 1) {
                samples[f * channels + 1] = static_cast<int16_t>(std::clamp(outR, -32768, 32767));
            }
        }
    } else if (bytesPerSample == 3) {
        // 24-bit packed signed integer PCM (3 bytes per sample, LE)
        uint8_t* ptr = pcmData;

        for (size_t f = 0; f < numFrames; ++f) {
            // Read 24-bit Left
            int32_t rawL = (ptr[0]) | (ptr[1] << 8) | (ptr[2] << 16);
            if (rawL & 0x800000) rawL |= 0xFF000000; // Sign extend
            double x_L = static_cast<double>(rawL) / 8388608.0 * preamp;

            double x_R = x_L;
            if (channels > 1) {
                int32_t rawR = (ptr[3]) | (ptr[4] << 8) | (ptr[5] << 16);
                if (rawR & 0x800000) rawR |= 0xFF000000;
                x_R = static_cast<double>(rawR) / 8388608.0 * preamp;
            }

            for (int i = 0; i < MAX_PEQ_BANDS; ++i) {
                const auto& c = coeffs[i];
                if (!c.enabled) continue;

                auto& s = filterStates_[i];

                double y_L = c.b0 * x_L + s.z1_L;
                s.z1_L = c.b1 * x_L - c.a1 * y_L + s.z2_L;
                s.z2_L = c.b2 * x_L - c.a2 * y_L;
                x_L = y_L;

                double y_R = c.b0 * x_R + s.z1_R;
                s.z1_R = c.b1 * x_R - c.a1 * y_R + s.z2_R;
                s.z2_R = c.b2 * x_R - c.a2 * y_R;
                x_R = y_R;
            }

            double ditherL = generateTpdfDither() / 8388608.0;
            double ditherR = generateTpdfDither() / 8388608.0;

            int32_t outL = static_cast<int32_t>(std::round((x_L + ditherL) * 8388607.0));
            int32_t outR = static_cast<int32_t>(std::round((x_R + ditherR) * 8388607.0));

            outL = std::clamp(outL, -8388608, 8388607);
            outR = std::clamp(outR, -8388608, 8388607);

            ptr[0] = static_cast<uint8_t>(outL & 0xFF);
            ptr[1] = static_cast<uint8_t>((outL >> 8) & 0xFF);
            ptr[2] = static_cast<uint8_t>((outL >> 16) & 0xFF);

            if (channels > 1) {
                ptr[3] = static_cast<uint8_t>(outR & 0xFF);
                ptr[4] = static_cast<uint8_t>((outR >> 8) & 0xFF);
                ptr[5] = static_cast<uint8_t>((outR >> 16) & 0xFF);
            }
            ptr += frameSizeBytes;
        }
    } else if (bytesPerSample == 4) {
        // 32-bit signed integer PCM
        int32_t* samples = reinterpret_cast<int32_t*>(pcmData);

        for (size_t f = 0; f < numFrames; ++f) {
            double x_L = static_cast<double>(samples[f * channels]) / 2147483648.0 * preamp;
            double x_R = (channels > 1) ? (static_cast<double>(samples[f * channels + 1]) / 2147483648.0 * preamp) : x_L;

            for (int i = 0; i < MAX_PEQ_BANDS; ++i) {
                const auto& c = coeffs[i];
                if (!c.enabled) continue;

                auto& s = filterStates_[i];

                double y_L = c.b0 * x_L + s.z1_L;
                s.z1_L = c.b1 * x_L - c.a1 * y_L + s.z2_L;
                s.z2_L = c.b2 * x_L - c.a2 * y_L;
                x_L = y_L;

                double y_R = c.b0 * x_R + s.z1_R;
                s.z1_R = c.b1 * x_R - c.a1 * y_R + s.z2_R;
                s.z2_R = c.b2 * x_R - c.a2 * y_R;
                x_R = y_R;
            }

            int64_t outL = static_cast<int64_t>(std::round(x_L * 2147483647.0));
            int64_t outR = static_cast<int64_t>(std::round(x_R * 2147483647.0));

            samples[f * channels] = static_cast<int32_t>(std::clamp<int64_t>(outL, -2147483648LL, 2147483647LL));
            if (channels > 1) {
                samples[f * channels + 1] = static_cast<int32_t>(std::clamp<int64_t>(outR, -2147483648LL, 2147483647LL));
            }
        }
    }
}

} // namespace tannhauser
