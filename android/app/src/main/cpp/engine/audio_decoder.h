#ifndef TANNHAUSER_AUDIO_DECODER_H
#define TANNHAUSER_AUDIO_DECODER_H

#include <string>
#include <vector>
#include <cstdint>
#include <memory>
#include "usb_driver.h"

// Forward declaration FFmpeg structs
struct AVFormatContext;
struct AVCodecContext;
struct AVFrame;
struct AVPacket;

namespace tannhauser {

class AudioDecoder {
public:
    AudioDecoder();
    ~AudioDecoder();

    bool open(const std::string& filePath);
    bool decodeNextFrame(std::vector<uint8_t>& pcmOut);
    bool seek(int64_t timestampMs);
    void close();

    bool isOpen() const { return isOpen_; }
    const AudioFormat& getFormat() const { return format_; }
    int64_t getDurationMs() const { return durationMs_; }

private:
    bool isOpen_;
    int audioStreamIndex_;
    int64_t durationMs_;
    AudioFormat format_;

    AVFormatContext* formatContext_;
    AVCodecContext* codecContext_;
    AVFrame* frame_;
    AVPacket* packet_;
};

} // namespace tannhauser

#endif // TANNHAUSER_AUDIO_DECODER_H
