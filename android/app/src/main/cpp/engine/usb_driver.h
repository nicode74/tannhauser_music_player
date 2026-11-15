#ifndef TANNHAUSER_USB_DRIVER_H
#define TANNHAUSER_USB_DRIVER_H

#include <cstdint>
#include <string>
#include <memory>
#include <atomic>
#include <thread>
#include "ring_buffer.h"

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

private:
    void eventThreadLoop();
    void isochronousTransferLoop();

    int fd_;
    std::atomic<bool> connected_;
    std::atomic<bool> streaming_;
    AudioFormat currentFormat_;
    
    std::shared_ptr<RingBuffer> ringBuffer_;
    
    libusb_context* usbContext_;
    libusb_device_handle* deviceHandle_;
    
    std::thread eventThread_;
    std::thread streamThread_;

    uint8_t audioInterfaceNumber_;
    uint8_t audioAltSetting_;
    uint8_t isocOutEndpoint_;
    uint16_t maxPacketSize_;
};

} // namespace tannhauser

#endif // TANNHAUSER_USB_DRIVER_H
