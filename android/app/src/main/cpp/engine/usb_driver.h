#ifndef TANNHAUSER_USB_DRIVER_H
#define TANNHAUSER_USB_DRIVER_H

#include <cstdint>
#include <string>
#include <memory>
#include <atomic>
#include <thread>
#include <vector>
#include "ring_buffer.h"

#ifndef LIBUSB_CALL
#if defined(_WIN32)
#define LIBUSB_CALL __stdcall
#else
#define LIBUSB_CALL
#endif
#endif

// Forward declaration of libusb structs if libusb.h is not yet present
struct libusb_context;
struct libusb_device_handle;
struct libusb_transfer;

namespace tannhauser {

struct AudioFormat {
    int sampleRate = 44100;
    int channels = 2;
    int bitDepth = 16; // 16, 24, 32 bit
};

class UsbDriver {
public:
    UsbDriver();
    ~UsbDriver();

    bool setFileDescriptor(int fd);
    bool init();
    bool configureAudioStreaming(const AudioFormat& format);
    bool startStreaming(std::shared_ptr<RingBuffer> ringBuffer);
    void stopStreaming();
    void close();

    bool isConnected() const { return connected_.load(); }
    bool isStreaming() const { return streaming_.load(); }
    const AudioFormat& getCurrentFormat() const { return currentFormat_; }

    uint64_t getBytesTransferred() const { return bytesTransferred_.load(); }
    void resetBytesTransferred() { bytesTransferred_ = 0; }

private:
    bool findAudioStreamingEndpoint(int targetSampleRate, int channels, int bitDepth);
    void setSampleRateClock(int sampleRate);
    void eventThreadLoop();

    static void LIBUSB_CALL isoCallback(struct libusb_transfer* xfer);
    static void LIBUSB_CALL bulkCallback(struct libusb_transfer* xfer);

    int fd_;
    std::atomic<bool> connected_;
    std::atomic<bool> streaming_;
    std::atomic<int> inFlightTransfers_;
    std::atomic<uint64_t> bytesTransferred_;
    AudioFormat currentFormat_;
    
    std::shared_ptr<RingBuffer> ringBuffer_;
    
    libusb_context* usbContext_;
    libusb_device_handle* deviceHandle_;
    
    std::thread eventThread_;

    uint8_t audioInterfaceNumber_;
    uint8_t audioAltSetting_;
    uint8_t isocOutEndpoint_;
    uint16_t maxPacketSize_;
    uint8_t endpointType_; // LIBUSB_TRANSFER_TYPE_ISOCHRONOUS (1) or BULK (2)
    size_t packetSize_;

    std::vector<struct libusb_transfer*> activeTransfers_;
    std::vector<std::vector<uint8_t>> transferBuffers_;
};

} // namespace tannhauser

#endif // TANNHAUSER_USB_DRIVER_H
