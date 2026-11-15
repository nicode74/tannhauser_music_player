#include "usb_driver.h"
#include <android/log.h>
#include <chrono>

#define LOG_TAG "Tannhauser_UsbDriver"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#if __has_include(<libusb/libusb.h>)
#include <libusb/libusb.h>
#define HAS_LIBUSB_HEADER 1
#elif __has_include("libusb.h")
#include "libusb.h"
#define HAS_LIBUSB_HEADER 1
#else
#define HAS_LIBUSB_HEADER 0
#endif

namespace tannhauser {

UsbDriver::UsbDriver()
    : fd_(-1),
      connected_(false),
      streaming_(false),
      usbContext_(nullptr),
      deviceHandle_(nullptr),
      audioInterfaceNumber_(1),
      audioAltSetting_(1),
      isocOutEndpoint_(0x01),
      maxPacketSize_(1024) {}

UsbDriver::~UsbDriver() {
    close();
}

bool UsbDriver::setFileDescriptor(int fd) {
    LOGI("Setting USB File Descriptor: %d", fd);
    if (fd <= 0) {
        LOGE("Invalid USB file descriptor: %d", fd);
        return false;
    }
    fd_ = fd;
    return init();
}

bool UsbDriver::init() {
#if HAS_LIBUSB_HEADER
    if (fd_ <= 0) {
        LOGE("Cannot initialize libusb: No valid FD provided");
        return false;
    }

    int res = libusb_init(&usbContext_);
    if (res < 0) {
        LOGE("Failed to initialize libusb: %s", libusb_strerror((libusb_error)res));
        return false;
    }

    // Wrap Android USB file descriptor
    res = libusb_wrap_sys_device(usbContext_, (intptr_t)fd_, &deviceHandle_);
    if (res < 0 || !deviceHandle_) {
        LOGE("Failed to wrap sys device from FD %d: %s", fd_, libusb_strerror((libusb_error)res));
        libusb_exit(usbContext_);
        usbContext_ = nullptr;
        return false;
    }

    connected_ = true;
    LOGI("libusb successfully wrapped USB FD %d", fd_);
    return true;
#else
    LOGI("libusb header not found during compilation. Storing FD: %d", fd_);
    connected_ = (fd_ > 0);
    return connected_;
#endif
}

bool UsbDriver::configureAudioStreaming(const AudioFormat& format) {
    currentFormat_ = format;
    LOGI("Configuring USB Audio Class 2.0 streaming: Rate=%d Hz, Channels=%d, Bits=%d",
         format.sampleRate, format.channels, format.bitDepth);

#if HAS_LIBUSB_HEADER
    if (!deviceHandle_) {
        LOGE("Cannot configure streaming: Device handle is null");
        return false;
    }

    // Klaim interface audio streaming UAC2
    int res = libusb_claim_interface(deviceHandle_, audioInterfaceNumber_);
    if (res < 0) {
        LOGE("Failed to claim audio interface %d: %s", audioInterfaceNumber_, libusb_strerror((libusb_error)res));
        return false;
    }

    // Set Alternate Setting untuk mengaktifkan isochronous audio endpoint
    res = libusb_set_interface_alt_setting(deviceHandle_, audioInterfaceNumber_, audioAltSetting_);
    if (res < 0) {
        LOGE("Failed to set alternate setting %d: %s", audioAltSetting_, libusb_strerror((libusb_error)res));
        return false;
    }
#endif

    return true;
}

bool UsbDriver::startStreaming(std::shared_ptr<RingBuffer> ringBuffer) {
    if (streaming_) {
        LOGI("Streaming is already active.");
        return true;
    }

    ringBuffer_ = ringBuffer;
    streaming_ = true;

    streamThread_ = std::thread(&UsbDriver::isochronousTransferLoop, this);
    LOGI("USB audio streaming thread started.");
    return true;
}

void UsbDriver::stopStreaming() {
    if (!streaming_) return;

    LOGI("Stopping USB streaming...");
    streaming_ = false;

    if (streamThread_.joinable()) {
        streamThread_.join();
    }

#if HAS_LIBUSB_HEADER
    if (deviceHandle_) {
        // Kembalikan ke Alt Setting 0 (idle/bandwidth 0)
        libusb_set_interface_alt_setting(deviceHandle_, audioInterfaceNumber_, 0);
        libusb_release_interface(deviceHandle_, audioInterfaceNumber_);
    }
#endif

    LOGI("USB streaming stopped successfully.");
}

void UsbDriver::close() {
    stopStreaming();

#if HAS_LIBUSB_HEADER
    if (deviceHandle_) {
        libusb_close(deviceHandle_);
        deviceHandle_ = nullptr;
    }
    if (usbContext_) {
        libusb_exit(usbContext_);
        usbContext_ = nullptr;
    }
#endif

    connected_ = false;
    fd_ = -1;
    LOGI("USB Driver closed.");
}

void UsbDriver::isochronousTransferLoop() {
    LOGI("Entering USB Isochronous Transfer Loop");
    std::vector<uint8_t> pcmChunk(maxPacketSize_);

    while (streaming_) {
        if (!ringBuffer_) {
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
            continue;
        }

        size_t bytesRead = ringBuffer_->read(pcmChunk.data(), pcmChunk.size());
        if (bytesRead == 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
            continue;
        }

#if HAS_LIBUSB_HEADER
        // Transmisi ke isochronous / bulk endpoint USB DAC
        // Pada implementasi penuh, libusb_fill_iso_transfer & libusb_submit_transfer dijalankan secara asinkron
#endif
    }
    LOGI("Exiting USB Isochronous Transfer Loop");
}

} // namespace tannhauser
