#include "audio_decoder.h"
#include <android/log.h>

#define LOG_TAG "Tannhauser_AudioDecoder"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#if __has_include(<libavformat/avformat.h>)
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/opt.h>
}
#define HAS_FFMPEG_HEADERS 1
#else
#define HAS_FFMPEG_HEADERS 0
#endif

namespace tannhauser {

AudioDecoder::AudioDecoder()
    : isOpen_(false),
      audioStreamIndex_(-1),
      durationMs_(0),
      formatContext_(nullptr),
      codecContext_(nullptr),
      frame_(nullptr),
      packet_(nullptr) {}

AudioDecoder::~AudioDecoder() {
    close();
}

bool AudioDecoder::open(const std::string& filePath) {
    LOGI("AudioDecoder::open - START: %s", filePath.c_str());
    close();

    if (filePath.empty()) {
        LOGE("AudioDecoder::open - File path is empty!");
        return false;
    }

#if HAS_FFMPEG_HEADERS
    int ret = avformat_open_input(&formatContext_, filePath.c_str(), nullptr, nullptr);
    if (ret < 0) {
        char errBuf[128];
        av_strerror(ret, errBuf, sizeof(errBuf));
        LOGE("AudioDecoder::open - avformat_open_input failed (%d: %s): %s", ret, errBuf, filePath.c_str());
        close();
        LOGI("AudioDecoder::open - END (FAILED)");
        return false;
    }

    ret = avformat_find_stream_info(formatContext_, nullptr);
    if (ret < 0) {
        LOGE("AudioDecoder::open - avformat_find_stream_info failed.");
        close();
        LOGI("AudioDecoder::open - END (FAILED)");
        return false;
    }

    const AVCodec* decoder = nullptr;
    audioStreamIndex_ = av_find_best_stream(formatContext_, AVMEDIA_TYPE_AUDIO, -1, -1, &decoder, 0);
    if (audioStreamIndex_ < 0 || !decoder) {
        LOGE("AudioDecoder::open - No suitable audio decoder found in stream.");
        close();
        LOGI("AudioDecoder::open - END (FAILED)");
        return false;
    }

    AVStream* stream = formatContext_->streams[audioStreamIndex_];
    codecContext_ = avcodec_alloc_context3(decoder);
    if (!codecContext_) {
        LOGE("AudioDecoder::open - Failed to allocate codec context.");
        close();
        LOGI("AudioDecoder::open - END (FAILED)");
        return false;
    }

    if (avcodec_parameters_to_context(codecContext_, stream->codecpar) < 0) {
        LOGE("AudioDecoder::open - Failed to copy codec parameters to context.");
        close();
        LOGI("AudioDecoder::open - END (FAILED)");
        return false;
    }

    if (avcodec_open2(codecContext_, decoder, nullptr) < 0) {
        LOGE("AudioDecoder::open - Failed to open audio codec.");
        close();
        LOGI("AudioDecoder::open - END (FAILED)");
        return false;
    }

    frame_ = av_frame_alloc();
    packet_ = av_packet_alloc();

    format_.sampleRate = codecContext_->sample_rate;
    format_.channels = codecContext_->ch_layout.nb_channels;
    format_.bitDepth = av_get_bytes_per_sample(codecContext_->sample_fmt) * 8;
    if (stream->duration != AV_NOPTS_VALUE) {
        durationMs_ = (stream->duration * av_q2d(stream->time_base)) * 1000;
    } else if (formatContext_->duration != AV_NOPTS_VALUE) {
        durationMs_ = formatContext_->duration / (AV_TIME_BASE / 1000);
    }

    LOGI("AudioDecoder::open - SUCCESS: %d Hz, %d channels, %d bits, duration %lld ms",
         format_.sampleRate, format_.channels, format_.bitDepth, (long long)durationMs_);
    isOpen_ = true;
    LOGI("AudioDecoder::open - END (SUCCESS)");
    return true;
#else
    LOGI("AudioDecoder::open - FFmpeg headers not yet present during compilation. Mocking file open.");
    isOpen_ = true;
    format_.sampleRate = 44100;
    format_.channels = 2;
    format_.bitDepth = 16;
    durationMs_ = 180000;
    LOGI("AudioDecoder::open - END (MOCK)");
    return true;
#endif
}

bool AudioDecoder::decodeNextFrame(std::vector<uint8_t>& pcmOut) {
    if (!isOpen_) return false;

#if HAS_FFMPEG_HEADERS
    while (av_read_frame(formatContext_, packet_) >= 0) {
        if (packet_->stream_index == audioStreamIndex_) {
            int ret = avcodec_send_packet(codecContext_, packet_);
            av_packet_unref(packet_);

            if (ret < 0) {
                LOGE("Error sending packet to decoder.");
                return false;
            }

            ret = avcodec_receive_frame(codecContext_, frame_);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                continue;
            } else if (ret < 0) {
                LOGE("Error decoding audio frame.");
                return false;
            }

            // Extract raw PCM bytes from frame_
            int bytesPerSample = av_get_bytes_per_sample(codecContext_->sample_fmt);
            int dataSize = frame_->nb_samples * format_.channels * bytesPerSample;
            pcmOut.resize(dataSize);

            // Perhatikan: jika planar, data ada di frame_->extended_data[channel]
            if (av_sample_fmt_is_planar(codecContext_->sample_fmt)) {
                // Interleave planar samples
                uint8_t* outPtr = pcmOut.data();
                for (int s = 0; s < frame_->nb_samples; ++s) {
                    for (int ch = 0; ch < format_.channels; ++ch) {
                        memcpy(outPtr, frame_->extended_data[ch] + s * bytesPerSample, bytesPerSample);
                        outPtr += bytesPerSample;
                    }
                }
            } else {
                memcpy(pcmOut.data(), frame_->data[0], dataSize);
            }

            return true;
        }
        av_packet_unref(packet_);
    }
    return false;
#else
    // Mock decode frame
    pcmOut.resize(4096, 0);
    return true;
#endif
}

bool AudioDecoder::seek(int64_t timestampMs) {
    if (!isOpen_) return false;

#if HAS_FFMPEG_HEADERS
    if (formatContext_ && audioStreamIndex_ >= 0) {
        AVStream* stream = formatContext_->streams[audioStreamIndex_];
        int64_t targetTimestamp = (timestampMs / 1000.0) / av_q2d(stream->time_base);
        int res = av_seek_frame(formatContext_, audioStreamIndex_, targetTimestamp, AVSEEK_FLAG_BACKWARD);
        if (res >= 0) {
            avcodec_flush_buffers(codecContext_);
            return true;
        }
    }
    return false;
#else
    LOGI("Mock seek to: %lld ms", (long long)timestampMs);
    return true;
#endif
}

void AudioDecoder::close() {
    if (!isOpen_) return;

#if HAS_FFMPEG_HEADERS
    if (frame_) {
        av_frame_free(&frame_);
        frame_ = nullptr;
    }
    if (packet_) {
        av_packet_free(&packet_);
        packet_ = nullptr;
    }
    if (codecContext_) {
        avcodec_free_context(&codecContext_);
        codecContext_ = nullptr;
    }
    if (formatContext_) {
        avformat_close_input(&formatContext_);
        formatContext_ = nullptr;
    }
#endif

    isOpen_ = false;
    audioStreamIndex_ = -1;
    durationMs_ = 0;
    LOGI("Audio decoder closed.");
}

} // namespace tannhauser
