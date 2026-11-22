#include "usb_driver.h"
#include <chrono>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <algorithm>

#if __has_include(<android/log.h>)
#include <android/log.h>
#define LOG_TAG "Tannhauser_UsbDriver"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#include <cstdio>
#define LOG_TAG "Tannhauser_UsbDriver"
#define LOGI(...) printf(__VA_ARGS__)
#define LOGE(...) fprintf(stderr, __VA_ARGS__)
#endif

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
      inFlightTransfers_(0),
      bytesTransferred_(0),
      usbContext_(nullptr),
      deviceHandle_(nullptr),
      audioInterfaceNumber_(1),
      audioAltSetting_(1),
      isocOutEndpoint_(0x01),
      maxPacketSize_(1024),
      endpointType_(1), // 1 = LIBUSB_TRANSFER_TYPE_ISOCHRONOUS
      packetSize_(192) {}

UsbDriver::~UsbDriver() {
    close();
}

bool UsbDriver::setFileDescriptor(int fd) {
    LOGI("UsbDriver::setFileDescriptor - Setting USB File Descriptor: %d", fd);
    if (fd <= 0) {
        LOGE("UsbDriver::setFileDescriptor - Invalid USB file descriptor: %d", fd);
        return false;
    }
    // Bersihkan sesi aktif sebelum membungkus descriptor baru
    close();

    fd_ = fd;
    return init();
}

bool UsbDriver::init() {
#if HAS_LIBUSB_HEADER
    if (fd_ <= 0) {
        LOGE("UsbDriver::init - Cannot initialize libusb: No valid FD provided");
        return false;
    }

    // Duplikasi FD agar libusb dan Java UsbDeviceConnection memiliki
    // kernel file descriptor terpisah (mencegah double-close crash)
    int nativeFd = dup(fd_);
    if (nativeFd < 0) {
        LOGE("UsbDriver::init - Failed to duplicate USB file descriptor %d (errno: %d)", fd_, errno);
        return false;
    }

    // Krusial untuk Android: nonaktifkan penemuan otomatis (NO_DEVICE_DISCOVERY)
    // agar libusb tidak membuka Netlink uevent socket yang diblokir SELinux Android
    const struct libusb_init_option options[] = {
        { LIBUSB_OPTION_NO_DEVICE_DISCOVERY, { 0 } }
    };
    int res = libusb_init_context(&usbContext_, options, 1);
    if (res < 0) {
        LOGE("UsbDriver::init - Failed to initialize libusb context with NO_DEVICE_DISCOVERY: %s (trying fallback init)",
             libusb_strerror((libusb_error)res));
        res = libusb_init(&usbContext_);
        if (res < 0) {
            LOGE("UsbDriver::init - Fallback libusb_init also failed: %s", libusb_strerror((libusb_error)res));
            ::close(nativeFd);
            return false;
        }
    }

    // Bungkus Android USB file descriptor
    res = libusb_wrap_sys_device(usbContext_, (intptr_t)nativeFd, &deviceHandle_);
    if (res < 0 || !deviceHandle_) {
        LOGE("UsbDriver::init - Failed to wrap sys device from duplicated FD %d: %s", nativeFd, libusb_strerror((libusb_error)res));
        ::close(nativeFd);
        libusb_exit(usbContext_);
        usbContext_ = nullptr;
        return false;
    }

    // Otomatis lepaskan driver kernel ALSA bawaan jika memungkinkan
    libusb_set_auto_detach_kernel_driver(deviceHandle_, 1);

    connected_ = true;
    bytesTransferred_ = 0;
    LOGI("UsbDriver::init - libusb successfully wrapped USB FD %d (native duplicated FD %d)", fd_, nativeFd);
    return true;
#else
    LOGI("UsbDriver::init - libusb header not found during compilation. Storing FD: %d", fd_);
    connected_ = (fd_ > 0);
    return connected_;
#endif
}

bool UsbDriver::findAudioStreamingEndpoint(int /*targetSampleRate*/, int /*channels*/, int /*bitDepth*/) {
#if HAS_LIBUSB_HEADER
    if (!deviceHandle_) return false;

    libusb_device* dev = libusb_get_device(deviceHandle_);
    if (!dev) return false;

    struct libusb_config_descriptor* config = nullptr;
    int ret = libusb_get_active_config_descriptor(dev, &config);
    if (ret < 0 || !config) {
        ret = libusb_get_config_descriptor(dev, 0, &config);
        if (ret < 0 || !config) {
            LOGE("UsbDriver::findAudioStreamingEndpoint - Failed to get config descriptor: %s",
                 libusb_strerror((libusb_error)ret));
            return false;
        }
    }

    bool found = false;
    LOGI("UsbDriver::findAudioStreamingEndpoint - Scanning %d interface(s) for UAC Audio Streaming...",
         config->bNumInterfaces);

    for (int i = 0; i < config->bNumInterfaces; ++i) {
        const struct libusb_interface* iface = &config->interface[i];
        for (int a = 0; a < iface->num_altsetting; ++a) {
            const struct libusb_interface_descriptor* alt = &iface->altsetting[a];

            // USB Audio Class (0x01), Audio Streaming Subclass (0x02)
            if (alt->bInterfaceClass == 0x01 && alt->bInterfaceSubClass == 0x02) {
                // Cari alternate setting operasional yang memiliki endpoint (alt 0 umumnya bandwidth 0)
                if (alt->bNumEndpoints > 0) {
                    for (int ep = 0; ep < alt->bNumEndpoints; ++ep) {
                        const struct libusb_endpoint_descriptor* epDesc = &alt->endpoint[ep];
                        // Endpoint OUT: Host to DAC
                        if ((epDesc->bEndpointAddress & 0x80) == 0) {
                            uint8_t xferType = epDesc->bmAttributes & 0x03;
                            if (xferType == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS || xferType == LIBUSB_TRANSFER_TYPE_BULK) {
                                audioInterfaceNumber_ = alt->bInterfaceNumber;
                                audioAltSetting_ = alt->bAlternateSetting;
                                isocOutEndpoint_ = epDesc->bEndpointAddress;
                                maxPacketSize_ = epDesc->wMaxPacketSize & 0x07FF;
                                if (maxPacketSize_ == 0) maxPacketSize_ = 1024;
                                endpointType_ = xferType;
                                found = true;

                                LOGI("UsbDriver: Found Audio Streaming Interface %d, AltSetting %d, Endpoint 0x%02X, MaxPacket %d, Type=%s",
                                     audioInterfaceNumber_, audioAltSetting_, isocOutEndpoint_, maxPacketSize_,
                                     xferType == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS ? "ISOCHRONOUS" : "BULK");
                                break;
                            }
                        }
                    }
                }
            }
            if (found) break;
        }
        if (found) break;
    }

    libusb_free_config_descriptor(config);
    return found;
#else
    return false;
#endif
}

void UsbDriver::setSampleRateClock(int sampleRate) {
#if HAS_LIBUSB_HEADER
    if (!deviceHandle_) return;

    // 1. UAC1 Sampling Frequency Control pada Endpoint OUT
    uint8_t dataUAC1[3];
    dataUAC1[0] = static_cast<uint8_t>(sampleRate & 0xFF);
    dataUAC1[1] = static_cast<uint8_t>((sampleRate >> 8) & 0xFF);
    dataUAC1[2] = static_cast<uint8_t>((sampleRate >> 16) & 0xFF);
    int ret1 = libusb_control_transfer(
        deviceHandle_,
        LIBUSB_REQUEST_TYPE_CLASS | LIBUSB_RECIPIENT_ENDPOINT, // 0x22
        0x01, // SET_CUR
        0x0100, // SAMPLING_FREQ_CONTROL
        isocOutEndpoint_,
        dataUAC1,
        3,
        250 // timeout ms
    );
    if (ret1 >= 0) {
        LOGI("UsbDriver: Successfully set UAC1 sample rate to %d Hz on EP 0x%02X", sampleRate, isocOutEndpoint_);
        return;
    }

    // 2. UAC2 Clock Source Control pada Interface (CS_SAM_FREQ_CONTROL)
    uint8_t dataUAC2[4];
    dataUAC2[0] = static_cast<uint8_t>(sampleRate & 0xFF);
    dataUAC2[1] = static_cast<uint8_t>((sampleRate >> 8) & 0xFF);
    dataUAC2[2] = static_cast<uint8_t>((sampleRate >> 16) & 0xFF);
    dataUAC2[3] = static_cast<uint8_t>((sampleRate >> 24) & 0xFF);

    for (uint8_t csId : {0x01, 0x02, 0x04, 0x05, 0x10, 0x29}) {
        int ret2 = libusb_control_transfer(
            deviceHandle_,
            LIBUSB_REQUEST_TYPE_CLASS | LIBUSB_RECIPIENT_INTERFACE, // 0x21
            0x01, // CUR
            0x0100, // CS_SAM_FREQ_CONTROL
            (csId << 8) | audioInterfaceNumber_,
            dataUAC2,
            4,
            200
        );
        if (ret2 >= 0) {
            LOGI("UsbDriver: Successfully set UAC2 sample rate to %d Hz on CS Entity 0x%02X", sampleRate, csId);
            return;
        }
    }
    LOGI("UsbDriver: Clock rate request finished (DAC hardware clock may auto-lock to incoming stream rate).");
#endif
}

bool UsbDriver::configureAudioStreaming(const AudioFormat& format) {
    currentFormat_ = format;
    LOGI("UsbDriver::configureAudioStreaming - START: Rate=%d Hz, Channels=%d, Bits=%d",
         format.sampleRate, format.channels, format.bitDepth);

#if HAS_LIBUSB_HEADER
    if (!connected_ || !deviceHandle_) {
        LOGI("UsbDriver::configureAudioStreaming - DAC not connected or deviceHandle is null.");
        return false;
    }

    // 1. Temukan Audio Streaming Interface dan Endpoint yang tepat secara dinamis
    if (!findAudioStreamingEndpoint(format.sampleRate, format.channels, format.bitDepth)) {
        LOGE("UsbDriver::configureAudioStreaming - No suitable audio streaming interface found.");
        return false;
    }

    // 2. Detach kernel driver jika masih terikat
    if (libusb_kernel_driver_active(deviceHandle_, audioInterfaceNumber_) == 1) {
        int detachRes = libusb_detach_kernel_driver(deviceHandle_, audioInterfaceNumber_);
        LOGI("UsbDriver: Detached kernel driver from interface %d (res=%d)", audioInterfaceNumber_, detachRes);
    }

    // 3. Klaim interface audio streaming UAC
    int res = libusb_claim_interface(deviceHandle_, audioInterfaceNumber_);
    if (res < 0) {
        LOGE("UsbDriver::configureAudioStreaming - Failed to claim audio interface %d: %s",
             audioInterfaceNumber_, libusb_strerror((libusb_error)res));
        return false;
    }

    // 4. Set Alternate Setting untuk mengaktifkan audio endpoint
    res = libusb_set_interface_alt_setting(deviceHandle_, audioInterfaceNumber_, audioAltSetting_);
    if (res < 0) {
        LOGE("UsbDriver::configureAudioStreaming - Failed to set alternate setting %d: %s",
             audioAltSetting_, libusb_strerror((libusb_error)res));
        return false;
    }

    // 5. Konfigurasi Clock Sample Rate pada DAC
    setSampleRateClock(format.sampleRate);
#endif

    LOGI("UsbDriver::configureAudioStreaming - END: Configured successfully.");
    return true;
}

bool UsbDriver::startStreaming(std::shared_ptr<RingBuffer> ringBuffer) {
    if (streaming_) {
        LOGI("UsbDriver::startStreaming - Streaming is already active.");
        return true;
    }

    ringBuffer_ = ringBuffer;
    streaming_ = true;
    bytesTransferred_ = 0;

#if HAS_LIBUSB_HEADER
    if (!deviceHandle_ || !usbContext_) {
        LOGE("UsbDriver::startStreaming - No valid USB device handle or context!");
        streaming_ = false;
        return false;
    }

    // Hitung ukuran paket isochronous (1ms frame)
    // bytesPerSample: 16-bit = 2, 24-bit/32-bit = 4
    int bytesPerSample = (currentFormat_.bitDepth > 0 ? currentFormat_.bitDepth : 16) / 8;
    int channels = currentFormat_.channels > 0 ? currentFormat_.channels : 2;
    int sampleRate = currentFormat_.sampleRate > 0 ? currentFormat_.sampleRate : 44100;

    size_t calculatedPacket = (sampleRate / 1000) * channels * bytesPerSample;
    if (calculatedPacket == 0) calculatedPacket = 192;
    if (maxPacketSize_ > 0 && calculatedPacket > maxPacketSize_) {
        calculatedPacket = maxPacketSize_;
    }
    packetSize_ = calculatedPacket;

    const int numTransfers = 4;
    const int packetsPerTransfer = (endpointType_ == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS) ? 8 : 1;
    size_t transferBufferSize = (endpointType_ == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS)
        ? (packetSize_ * packetsPerTransfer)
        : (packetSize_ * 8);

    LOGI("UsbDriver::startStreaming - Starting %d transfers, packetsPerTransfer=%d, packetSize=%zu, bufferSize=%zu",
         numTransfers, packetsPerTransfer, packetSize_, transferBufferSize);

    // Jalankan dedicated background USB event loop
    eventThread_ = std::thread(&UsbDriver::eventThreadLoop, this);

    activeTransfers_.assign(numTransfers, nullptr);
    transferBuffers_.resize(numTransfers);

    for (int t = 0; t < numTransfers; ++t) {
        transferBuffers_[t].assign(transferBufferSize, 0);

        if (endpointType_ == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS) {
            struct libusb_transfer* xfer = libusb_alloc_transfer(packetsPerTransfer);
            if (!xfer) {
                LOGE("UsbDriver: Failed to allocate iso transfer %d", t);
                continue;
            }

            // Baca data awal dari ringBuffer (non-blocking)
            if (ringBuffer_) {
                size_t readBytes = ringBuffer_->readAvailable(transferBuffers_[t].data(), transferBufferSize);
                if (readBytes < transferBufferSize) {
                    std::memset(transferBuffers_[t].data() + readBytes, 0, transferBufferSize - readBytes);
                }
            }

            libusb_fill_iso_transfer(
                xfer,
                deviceHandle_,
                isocOutEndpoint_,
                transferBuffers_[t].data(),
                static_cast<int>(transferBufferSize),
                packetsPerTransfer,
                &UsbDriver::isoCallback,
                this,
                1000
            );

            libusb_set_iso_packet_lengths(xfer, static_cast<unsigned int>(packetSize_));

            activeTransfers_[t] = xfer;
            inFlightTransfers_++;
            int subRes = libusb_submit_transfer(xfer);
            if (subRes < 0) {
                inFlightTransfers_--;
                LOGE("UsbDriver: Failed to submit initial iso transfer %d: %s", t, libusb_strerror((libusb_error)subRes));
            }
        } else {
            // BULK endpoint
            struct libusb_transfer* xfer = libusb_alloc_transfer(0);
            if (!xfer) continue;

            if (ringBuffer_) {
                size_t readBytes = ringBuffer_->readAvailable(transferBuffers_[t].data(), transferBufferSize);
                if (readBytes < transferBufferSize) {
                    std::memset(transferBuffers_[t].data() + readBytes, 0, transferBufferSize - readBytes);
                }
            }

            libusb_fill_bulk_transfer(
                xfer,
                deviceHandle_,
                isocOutEndpoint_,
                transferBuffers_[t].data(),
                static_cast<int>(transferBufferSize),
                &UsbDriver::bulkCallback,
                this,
                1000
            );

            activeTransfers_[t] = xfer;
            inFlightTransfers_++;
            int subRes = libusb_submit_transfer(xfer);
            if (subRes < 0) {
                inFlightTransfers_--;
                LOGE("UsbDriver: Failed to submit initial bulk transfer %d: %s", t, libusb_strerror((libusb_error)subRes));
            }
        }
    }

    LOGI("UsbDriver::startStreaming - USB audio streaming engine started successfully.");
    return true;
#else
    LOGI("UsbDriver::startStreaming (Mock)");
    return true;
#endif
}

void LIBUSB_CALL UsbDriver::isoCallback(struct libusb_transfer* xfer) {
    auto* driver = static_cast<UsbDriver*>(xfer->user_data);
    if (!driver) return;

    driver->inFlightTransfers_--;

    if (xfer->status == LIBUSB_TRANSFER_COMPLETED) {
        int successfulBytes = 0;
        for (int i = 0; i < xfer->num_iso_packets; ++i) {
            if (xfer->iso_packet_desc[i].status == LIBUSB_TRANSFER_COMPLETED) {
                successfulBytes += xfer->iso_packet_desc[i].actual_length;
            }
        }
        driver->bytesTransferred_ += successfulBytes;
    } else if (xfer->status == LIBUSB_TRANSFER_CANCELLED || xfer->status == LIBUSB_TRANSFER_NO_DEVICE) {
        return;
    }

    if (!driver->streaming_.load()) {
        return;
    }

    // Isi ulang buffer dari ring buffer secara non-blocking
    if (driver->ringBuffer_) {
        size_t totalSize = static_cast<size_t>(xfer->length);
        size_t bytesRead = driver->ringBuffer_->readAvailable(xfer->buffer, totalSize);
        if (bytesRead < totalSize) {
            std::memset(xfer->buffer + bytesRead, 0, totalSize - bytesRead);
        }
    }

    libusb_set_iso_packet_lengths(xfer, static_cast<unsigned int>(driver->packetSize_));

    driver->inFlightTransfers_++;
    int res = libusb_submit_transfer(xfer);
    if (res < 0) {
        driver->inFlightTransfers_--;
        if (driver->streaming_.load()) {
            LOGE("UsbDriver::isoCallback - Resubmit failed: %s", libusb_strerror((libusb_error)res));
        }
    }
}

void LIBUSB_CALL UsbDriver::bulkCallback(struct libusb_transfer* xfer) {
    auto* driver = static_cast<UsbDriver*>(xfer->user_data);
    if (!driver) return;

    driver->inFlightTransfers_--;

    if (xfer->status == LIBUSB_TRANSFER_COMPLETED) {
        driver->bytesTransferred_ += xfer->actual_length;
    } else if (xfer->status == LIBUSB_TRANSFER_CANCELLED || xfer->status == LIBUSB_TRANSFER_NO_DEVICE) {
        return;
    }

    if (!driver->streaming_.load()) {
        return;
    }

    if (driver->ringBuffer_) {
        size_t totalSize = static_cast<size_t>(xfer->length);
        size_t bytesRead = driver->ringBuffer_->readAvailable(xfer->buffer, totalSize);
        if (bytesRead < totalSize) {
            std::memset(xfer->buffer + bytesRead, 0, totalSize - bytesRead);
        }
    }

    driver->inFlightTransfers_++;
    int res = libusb_submit_transfer(xfer);
    if (res < 0) {
        driver->inFlightTransfers_--;
        if (driver->streaming_.load()) {
            LOGE("UsbDriver::bulkCallback - Resubmit failed: %s", libusb_strerror((libusb_error)res));
        }
    }
}

void UsbDriver::stopStreaming() {
    if (!streaming_) return;

    LOGI("UsbDriver::stopStreaming - Stopping USB streaming...");
    streaming_ = false;

#if HAS_LIBUSB_HEADER
    // 1. Batalkan semua transfer aktif
    for (auto* xfer : activeTransfers_) {
        if (xfer) {
            libusb_cancel_transfer(xfer);
        }
    }

    // 2. Tunggu event thread selesai
    if (eventThread_.joinable()) {
        eventThread_.join();
    }

    // 3. Dealokasi transfer structs
    for (auto*& xfer : activeTransfers_) {
        if (xfer) {
            libusb_free_transfer(xfer);
            xfer = nullptr;
        }
    }
    activeTransfers_.clear();
    transferBuffers_.clear();

    // 4. Kembalikan ke Alt Setting 0 (idle) dan release interface
    if (deviceHandle_) {
        libusb_set_interface_alt_setting(deviceHandle_, audioInterfaceNumber_, 0);
        libusb_release_interface(deviceHandle_, audioInterfaceNumber_);
    }
#endif

    LOGI("UsbDriver::stopStreaming - Stopped successfully.");
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
    bytesTransferred_ = 0;
    LOGI("UsbDriver::close - USB Driver closed cleanly.");
}

void UsbDriver::eventThreadLoop() {
    LOGI("UsbDriver::eventThreadLoop - Entered");
#if HAS_LIBUSB_HEADER
    while (streaming_.load() || inFlightTransfers_.load() > 0) {
        struct timeval tv;
        tv.tv_sec = 0;
        tv.tv_usec = 10000; // 10ms
        int res = libusb_handle_events_timeout_completed(usbContext_, &tv, nullptr);
        if (res < 0 && res != LIBUSB_ERROR_INTERRUPTED) {
            LOGE("UsbDriver::eventThreadLoop - libusb_handle_events error: %s",
                 libusb_strerror((libusb_error)res));
        }
    }
#endif
    LOGI("UsbDriver::eventThreadLoop - Exited cleanly (all in-flight transfers drained).");
}

} // namespace tannhauser
