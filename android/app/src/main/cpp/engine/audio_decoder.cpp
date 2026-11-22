#include "audio_decoder.h"
#include <android/log.h>
#include <cstdlib>
#include <cstring>
#include <algorithm>

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
    bool isFloat = (codecContext_->sample_fmt == AV_SAMPLE_FMT_FLT ||
                    codecContext_->sample_fmt == AV_SAMPLE_FMT_FLTP ||
                    codecContext_->sample_fmt == AV_SAMPLE_FMT_DBL ||
                    codecContext_->sample_fmt == AV_SAMPLE_FMT_DBLP);
    if (isFloat) {
        format_.bitDepth = 16; // Standard 16-bit integer PCM conversion for DAC compatibility
    } else {
        format_.bitDepth = av_get_bytes_per_sample(codecContext_->sample_fmt) * 8;
        if (format_.bitDepth <= 0) format_.bitDepth = 16;
    }
    if (stream->duration != AV_NOPTS_VALUE) {
        durationMs_ = (stream->duration * av_q2d(stream->time_base)) * 1000;
    } else if (formatContext_->duration != AV_NOPTS_VALUE) {
        durationMs_ = formatContext_->duration / (AV_TIME_BASE / 1000);
    }

    LOGI("AudioDecoder::open - SUCCESS: %d Hz, %d channels, %d bits, duration %lld ms (codec format: %s)",
         format_.sampleRate, format_.channels, format_.bitDepth, (long long)durationMs_,
         av_get_sample_fmt_name(codecContext_->sample_fmt));
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

            bool isFloatPlanar = (codecContext_->sample_fmt == AV_SAMPLE_FMT_FLTP);
            bool isFloatPacked = (codecContext_->sample_fmt == AV_SAMPLE_FMT_FLT);
            bool isDoublePlanar = (codecContext_->sample_fmt == AV_SAMPLE_FMT_DBLP);
            bool isDoublePacked = (codecContext_->sample_fmt == AV_SAMPLE_FMT_DBL);

            if (isFloatPlanar) {
                // Konversi 32-bit float planar (mis. MP3/AAC) ke 16-bit signed integer interleaved PCM
                pcmOut.resize(frame_->nb_samples * format_.channels * sizeof(int16_t));
                int16_t* outPtr = reinterpret_cast<int16_t*>(pcmOut.data());
                for (int s = 0; s < frame_->nb_samples; ++s) {
                    for (int ch = 0; ch < format_.channels; ++ch) {
                        float val = *reinterpret_cast<float*>(frame_->extended_data[ch] + s * sizeof(float));
                        val = std::max(-1.0f, std::min(1.0f, val));
                        *outPtr++ = static_cast<int16_t>(val * 32767.0f);
                    }
                }
            } else if (isFloatPacked) {
                // Konversi 32-bit float packed ke 16-bit signed integer interleaved PCM
                pcmOut.resize(frame_->nb_samples * format_.channels * sizeof(int16_t));
                int16_t* outPtr = reinterpret_cast<int16_t*>(pcmOut.data());
                const float* inPtr = reinterpret_cast<const float*>(frame_->data[0]);
                for (int i = 0; i < frame_->nb_samples * format_.channels; ++i) {
                    float val = std::max(-1.0f, std::min(1.0f, inPtr[i]));
                    outPtr[i] = static_cast<int16_t>(val * 32767.0f);
                }
            } else if (isDoublePlanar) {
                pcmOut.resize(frame_->nb_samples * format_.channels * sizeof(int16_t));
                int16_t* outPtr = reinterpret_cast<int16_t*>(pcmOut.data());
                for (int s = 0; s < frame_->nb_samples; ++s) {
                    for (int ch = 0; ch < format_.channels; ++ch) {
                        double val = *reinterpret_cast<double*>(frame_->extended_data[ch] + s * sizeof(double));
                        val = std::max(-1.0, std::min(1.0, val));
                        *outPtr++ = static_cast<int16_t>(val * 32767.0);
                    }
                }
            } else if (isDoublePacked) {
                pcmOut.resize(frame_->nb_samples * format_.channels * sizeof(int16_t));
                int16_t* outPtr = reinterpret_cast<int16_t*>(pcmOut.data());
                const double* inPtr = reinterpret_cast<const double*>(frame_->data[0]);
                for (int i = 0; i < frame_->nb_samples * format_.channels; ++i) {
                    double val = std::max(-1.0, std::min(1.0, inPtr[i]));
                    outPtr[i] = static_cast<int16_t>(val * 32767.0);
                }
            } else {
                // Integer PCM asli (16-bit, 24-bit, 32-bit integer)
                int bytesPerSample = av_get_bytes_per_sample(codecContext_->sample_fmt);
                int dataSize = frame_->nb_samples * format_.channels * bytesPerSample;
                pcmOut.resize(dataSize);

                if (av_sample_fmt_is_planar(codecContext_->sample_fmt)) {
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

AudioProbeResult AudioDecoder::probeAudioFile(const std::string& filePath) {
    AudioProbeResult res;
    if (filePath.empty()) return res;

#if HAS_FFMPEG_HEADERS
    AVFormatContext* fmtCtx = nullptr;
    int ret = avformat_open_input(&fmtCtx, filePath.c_str(), nullptr, nullptr);
    if (ret < 0) {
        return res;
    }

    ret = avformat_find_stream_info(fmtCtx, nullptr);
    if (ret < 0) {
        avformat_close_input(&fmtCtx);
        return res;
    }

    // Extract tags from container metadata
    AVDictionaryEntry* tag = nullptr;
    tag = av_dict_get(fmtCtx->metadata, "title", nullptr, 0);
    if (tag && tag->value) res.title = tag->value;

    tag = av_dict_get(fmtCtx->metadata, "artist", nullptr, 0);
    if (tag && tag->value) res.artist = tag->value;

    tag = av_dict_get(fmtCtx->metadata, "album", nullptr, 0);
    if (tag && tag->value) res.album = tag->value;

    tag = av_dict_get(fmtCtx->metadata, "track", nullptr, 0);
    if (tag && tag->value) {
        res.trackNumber = atoi(tag->value);
    }

    int audioStreamIdx = av_find_best_stream(fmtCtx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (audioStreamIdx >= 0) {
        AVStream* stream = fmtCtx->streams[audioStreamIdx];
        AVCodecParameters* codecpar = stream->codecpar;

        res.sampleRate = codecpar->sample_rate;
        res.channels = codecpar->ch_layout.nb_channels;

        // Bit depth resolution
        int bits = codecpar->bits_per_raw_sample;
        if (bits <= 0) {
            bits = av_get_bytes_per_sample(static_cast<AVSampleFormat>(codecpar->format)) * 8;
        }
        res.bitDepth = bits > 0 ? bits : 16;
        res.bitRate = codecpar->bit_rate > 0 ? codecpar->bit_rate : fmtCtx->bit_rate;

        // Codec short name
        const AVCodec* c = avcodec_find_decoder(codecpar->codec_id);
        if (c && c->name) {
            res.codecName = c->name;
        }

        // Secondary tag check from stream metadata if container tags were empty
        if (res.title.empty()) {
            tag = av_dict_get(stream->metadata, "title", nullptr, 0);
            if (tag && tag->value) res.title = tag->value;
        }
        if (res.artist.empty()) {
            tag = av_dict_get(stream->metadata, "artist", nullptr, 0);
            if (tag && tag->value) res.artist = tag->value;
        }
        if (res.album.empty()) {
            tag = av_dict_get(stream->metadata, "album", nullptr, 0);
            if (tag && tag->value) res.album = tag->value;
        }
        if (res.trackNumber == 0) {
            tag = av_dict_get(stream->metadata, "track", nullptr, 0);
            if (tag && tag->value) res.trackNumber = atoi(tag->value);
        }

        // Duration calculation
        if (stream->duration != AV_NOPTS_VALUE) {
            res.durationMs = static_cast<int64_t>((stream->duration * av_q2d(stream->time_base)) * 1000.0);
        } else if (fmtCtx->duration != AV_NOPTS_VALUE) {
            res.durationMs = fmtCtx->duration / (AV_TIME_BASE / 1000);
        }
    }

    avformat_close_input(&fmtCtx);
    res.success = true;
    return res;
#else
    res.success = true;
    res.sampleRate = 44100;
    res.channels = 2;
    res.bitDepth = 16;
    res.durationMs = 180000;
    res.codecName = "flac";
    return res;
#endif
}

} // namespace tannhauser
