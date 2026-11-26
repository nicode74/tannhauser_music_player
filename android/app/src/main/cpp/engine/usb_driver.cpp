#include "usb_driver.h"
#include <chrono>
#include <unistd.h>
#include <sys/resource.h>
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
      audioControlInterfaceNumber_(0),
      audioInterfaceNumber_(1),
      audioAltSetting_(1),
      isocOutEndpoint_(0x01),
      maxPacketSize_(1024),
      endpointType_(1), // 1 = LIBUSB_TRANSFER_TYPE_ISOCHRONOUS
      epInterval_(1),
      isHighSpeedDevice_(true),
      hwSubslotSize_(2),
      hwBitResolution_(16),
      hwRequiresPadding_(false),
      packetSize_(192),
      packetsPerSecond_(8000),
      hwBytesPerFrame_(4),
      frameAccumulator_(0) {}

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

    // Deteksi kecepatan USB (Full-Speed 12Mbps vs High-Speed 480Mbps)
    libusb_device* dev = libusb_get_device(deviceHandle_);
    if (dev) {
        int speed = libusb_get_device_speed(dev);
        isHighSpeedDevice_ = (speed >= LIBUSB_SPEED_HIGH);
        LOGI("UsbDriver::init - USB Device Speed enum: %d (High-Speed: %d)", speed, isHighSpeedDevice_ ? 1 : 0);
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

bool UsbDriver::findAudioStreamingEndpoint(int /*targetSampleRate*/, int /*channels*/, int bitDepth) {
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
    int bestScore = -1;
    int targetBytes = (bitDepth >= 24) ? 4 : 2;
    LOGI("UsbDriver::findAudioStreamingEndpoint - Scanning %d interface(s) for target bitDepth=%d...",
         config->bNumInterfaces, bitDepth);

    for (int i = 0; i < config->bNumInterfaces; ++i) {
        const struct libusb_interface* iface = &config->interface[i];
        for (int a = 0; a < iface->num_altsetting; ++a) {
            const struct libusb_interface_descriptor* alt = &iface->altsetting[a];

            // USB Audio Class (0x01)
            if (alt->bInterfaceClass == 0x01) {
                // Audio Control Subclass (0x01)
                if (alt->bInterfaceSubClass == 0x01) {
                    audioControlInterfaceNumber_ = alt->bInterfaceNumber;
                    LOGI("UsbDriver: Found Audio Control Interface: %d", audioControlInterfaceNumber_);
                }
                // Audio Streaming Subclass (0x02)
                else if (alt->bInterfaceSubClass == 0x02 && alt->bNumEndpoints > 0) {
                    uint8_t candSubslot = (bitDepth > 16) ? 4 : 2;
                    uint8_t candBitRes = bitDepth > 0 ? bitDepth : 16;
                    uint8_t candChannels = 2;
                    if (alt->extra && alt->extra_length > 0) {
                        const uint8_t* p = alt->extra;
                        int remaining = alt->extra_length;
                        while (remaining >= 2) {
                            uint8_t len = p[0];
                            if (len < 2 || len > remaining) break;
                            uint8_t descType = p[1];
                            if (descType == 0x24 && len >= 6) { // CS_INTERFACE
                                uint8_t subtype = p[2];
                                if (subtype == 0x02) { // FORMAT_TYPE
                                    if (alt->bInterfaceProtocol == 0x20) { // UAC2
                                        candSubslot = p[4];
                                        candBitRes = p[5];
                                    } else { // UAC1
                                        candChannels = p[4];
                                        candSubslot = p[5];
                                        candBitRes = p[6];
                                    }
                                    break;
                                }
                            }
                            p += len;
                            remaining -= len;
                        }
                    }
                    if (candSubslot < 2 || candSubslot > 4) candSubslot = 2;

                    for (int ep = 0; ep < alt->bNumEndpoints; ++ep) {
                        const struct libusb_endpoint_descriptor* epDesc = &alt->endpoint[ep];
                        // Endpoint OUT: Host to DAC
                        if ((epDesc->bEndpointAddress & 0x80) == 0) {
                            uint8_t xferType = epDesc->bmAttributes & 0x03;
                            if (xferType == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS || xferType == LIBUSB_TRANSFER_TYPE_BULK) {
                                int score = 0;
                                if (candSubslot == targetBytes) score += 100;
                                else if (candSubslot > targetBytes) score += 50; // Upsizing preserves quality
                                else score += 10; // Downsizing fallback
                                if (xferType == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS) score += 20;
                                if (candBitRes >= bitDepth) score += 5;

                                if (!found || score > bestScore) {
                                    bestScore = score;
                                    audioInterfaceNumber_ = alt->bInterfaceNumber;
                                    audioAltSetting_ = alt->bAlternateSetting;
                                    isocOutEndpoint_ = epDesc->bEndpointAddress;
                                    maxPacketSize_ = epDesc->wMaxPacketSize & 0x07FF;
                                    if (maxPacketSize_ == 0) maxPacketSize_ = 1024;
                                    endpointType_ = xferType;
                                    epInterval_ = (epDesc->bInterval > 0) ? epDesc->bInterval : 1;
                                    hwSubslotSize_ = candSubslot;
                                    hwBitResolution_ = candBitRes;
                                    hwRequiresPadding_ = (hwSubslotSize_ != ((bitDepth > 0 ? bitDepth : 16) / 8));
                                    found = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (found) {
        LOGI("UsbDriver: Selected Best AltSetting: Iface=%d, Alt=%d, EP=0x%02X, MaxPkt=%d, bInterval=%d, Type=%s, hwSubslot=%d, hwBitRes=%d",
             audioInterfaceNumber_, audioAltSetting_, isocOutEndpoint_, maxPacketSize_,
             epInterval_, endpointType_ == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS ? "ISOCHRONOUS" : "BULK",
             hwSubslotSize_, hwBitResolution_);
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

    // 2. UAC2 Clock Source Control pada Audio Control Interface (CS_SAM_FREQ_CONTROL)
    uint8_t dataUAC2[4];
    dataUAC2[0] = static_cast<uint8_t>(sampleRate & 0xFF);
    dataUAC2[1] = static_cast<uint8_t>((sampleRate >> 8) & 0xFF);
    dataUAC2[2] = static_cast<uint8_t>((sampleRate >> 16) & 0xFF);
    dataUAC2[3] = static_cast<uint8_t>((sampleRate >> 24) & 0xFF);

    for (uint8_t csId : {0x01, 0x02, 0x04, 0x05, 0x10, 0x29}) {
        // Alamatkan ke Audio Control Interface (bukan Streaming Interface)
        for (uint8_t ctrlIface : {audioControlInterfaceNumber_, static_cast<uint8_t>(0)}) {
            int ret2 = libusb_control_transfer(
                deviceHandle_,
                LIBUSB_REQUEST_TYPE_CLASS | LIBUSB_RECIPIENT_INTERFACE, // 0x21
                0x01, // CUR / SET_CUR
                0x0100, // CS_SAM_FREQ_CONTROL
                (csId << 8) | ctrlIface,
                dataUAC2,
                4,
                200
            );
            if (ret2 >= 0) {
                LOGI("UsbDriver: Successfully set UAC2 sample rate to %d Hz on CS Entity 0x%02X, Interface %d",
                     sampleRate, csId, ctrlIface);
                return;
            }
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
    streamStartTime_ = std::chrono::steady_clock::now();

#if HAS_LIBUSB_HEADER
    if (!deviceHandle_ || !usbContext_) {
        LOGE("UsbDriver::startStreaming - No valid USB device handle or context!");
        streaming_ = false;
        return false;
    }

    // Format dan ukuran sampel audio
    int bytesPerSample = (currentFormat_.bitDepth > 0 ? currentFormat_.bitDepth : 16) / 8;
    int channels = currentFormat_.channels > 0 ? currentFormat_.channels : 2;
    int sampleRate = currentFormat_.sampleRate > 0 ? currentFormat_.sampleRate : 44100;

    int hwBytesPerSample = (hwSubslotSize_ > 0) ? hwSubslotSize_ : bytesPerSample;
    hwBytesPerFrame_ = channels * hwBytesPerSample;
    frameAccumulator_ = 0;

    // Perhitungan Laju Paket USB Presisi (Microframe Aware):
    // Full-Speed (12Mbps): 1000 frame/detik (1ms interval).
    // High-Speed (480Mbps): 8000 microframe/detik (125us interval jika bInterval=1).
    packetsPerSecond_ = 1000;
    if (isHighSpeedDevice_ && endpointType_ == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS) {
        int shift = (epInterval_ >= 1 && epInterval_ <= 6) ? (epInterval_ - 1) : 0;
        packetsPerSecond_ = 8000 >> shift;
    }
    if (packetsPerSecond_ <= 0) packetsPerSecond_ = 8000;

    // Hitung ukuran paket maksimum per microframe/frame (dengan +1 frame headroom untuk fractional rates seperti 44.1kHz)
    size_t minFramesPerPkt = static_cast<size_t>(sampleRate) / packetsPerSecond_;
    size_t maxFramesPerPkt = minFramesPerPkt + ((sampleRate % packetsPerSecond_ != 0) ? 1 : 0);
    if (maxFramesPerPkt == 0) maxFramesPerPkt = 1;
    size_t maxPktBytes = maxFramesPerPkt * hwBytesPerFrame_;
    if (maxPacketSize_ > 0 && maxPktBytes > maxPacketSize_) {
        maxPktBytes = (maxPacketSize_ / hwBytesPerFrame_) * hwBytesPerFrame_;
        if (maxPktBytes == 0) maxPktBytes = hwBytesPerFrame_;
    }
    packetSize_ = (minFramesPerPkt > 0 ? minFramesPerPkt : 1) * hwBytesPerFrame_;

    const int numTransfers = 8;
    const int packetsPerTransfer = (endpointType_ == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS) ? 16 : 1;
    size_t transferBufferSize = (endpointType_ == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS)
        ? (maxPktBytes * packetsPerTransfer)
        : (packetSize_ * 16);

    // Pre-allocate scratch buffer to avoid heap allocations inside real-time USB callbacks
    conversionScratch_.resize(transferBufferSize * 2);

    LOGI("UsbDriver::startStreaming - Pacing: HighSpeed=%d, pkts/sec=%d, basePkt=%zu, maxPkt=%zu, pkts/xfer=%d, xferBufSize=%zu, srcBits=%d, hwSubslot=%d",
         isHighSpeedDevice_ ? 1 : 0, packetsPerSecond_, packetSize_, maxPktBytes, packetsPerTransfer, transferBufferSize,
         currentFormat_.bitDepth, hwBytesPerSample);

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

            size_t exactBytes = prepareIsoPackets(xfer);
            fillTransferBuffer(transferBuffers_[t].data(), exactBytes);

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

            fillTransferBuffer(transferBuffers_[t].data(), transferBufferSize);

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
        if (driver->inFlightTransfers_.load() <= 0) {
            driver->streaming_ = false;
        }
        return;
    }

    if (!driver->streaming_.load()) {
        return;
    }

    // Hitung ukuran paket fraksional presisi dan isi ulang buffer secara non-blocking
    size_t exactBytes = driver->prepareIsoPackets(xfer);
    driver->fillTransferBuffer(reinterpret_cast<uint8_t*>(xfer->buffer), exactBytes);

    driver->inFlightTransfers_++;
    int res = libusb_submit_transfer(xfer);
    if (res < 0) {
        driver->inFlightTransfers_--;
        if (driver->streaming_.load()) {
            LOGE("UsbDriver::isoCallback - Resubmit failed: %s", libusb_strerror((libusb_error)res));
            if (driver->inFlightTransfers_.load() <= 0) {
                driver->streaming_ = false;
            }
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

    // Pacing rate limiting khusus untuk BULK transfer agar tidak melesat melebihi clock audio
    int sampleRate = driver->currentFormat_.sampleRate > 0 ? driver->currentFormat_.sampleRate : 44100;
    int bytesPerSec = sampleRate * driver->hwBytesPerFrame_;

    if (bytesPerSec > 0) {
        auto now = std::chrono::steady_clock::now();
        auto elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(now - driver->streamStartTime_).count();
        int64_t expectedBytes = (elapsedMs * bytesPerSec) / 1000;
        int64_t actual = driver->bytesTransferred_.load();
        if (actual > expectedBytes + static_cast<int64_t>(xfer->length * 2)) {
            std::this_thread::sleep_for(std::chrono::milliseconds(4));
        }
    }

    driver->fillTransferBuffer(reinterpret_cast<uint8_t*>(xfer->buffer), static_cast<size_t>(xfer->length));

    driver->inFlightTransfers_++;
    int res = libusb_submit_transfer(xfer);
    if (res < 0) {
        driver->inFlightTransfers_--;
        if (driver->streaming_.load()) {
            LOGE("UsbDriver::bulkCallback - Resubmit failed: %s", libusb_strerror((libusb_error)res));
        }
    }
}

size_t UsbDriver::prepareIsoPackets(struct libusb_transfer* xfer) {
    if (!xfer || xfer->num_iso_packets <= 0) return 0;

    int sampleRate = currentFormat_.sampleRate > 0 ? currentFormat_.sampleRate : 44100;
    int pps = packetsPerSecond_ > 0 ? packetsPerSecond_ : 8000;
    int bpf = hwBytesPerFrame_ > 0 ? hwBytesPerFrame_ : 4;
    uint32_t maxAligned = (maxPacketSize_ > 0) ? ((maxPacketSize_ / bpf) * bpf) : 1024;
    if (maxAligned == 0) maxAligned = bpf;

    size_t totalLen = 0;
    for (int i = 0; i < xfer->num_iso_packets; ++i) {
        frameAccumulator_ += static_cast<uint64_t>(sampleRate);
        uint32_t frames = static_cast<uint32_t>(frameAccumulator_ / pps);
        frameAccumulator_ %= static_cast<uint64_t>(pps);
        if (frames == 0) frames = 1;

        uint32_t pktLen = frames * static_cast<uint32_t>(bpf);
        if (pktLen > maxAligned) pktLen = maxAligned;

        xfer->iso_packet_desc[i].length = pktLen;
        totalLen += pktLen;
    }
    xfer->length = static_cast<int>(totalLen);
    return totalLen;
}

size_t UsbDriver::fillTransferBuffer(uint8_t* dest, size_t destSize) {
    if (!ringBuffer_ || !dest || destSize == 0) {
        if (dest && destSize > 0) std::memset(dest, 0, destSize);
        return 0;
    }

    int srcBytes = (currentFormat_.bitDepth > 0 ? currentFormat_.bitDepth : 16) / 8;
    if (srcBytes < 2 || srcBytes > 4) srcBytes = 2;
    int dstBytes = (hwSubslotSize_ >= 2 && hwSubslotSize_ <= 4) ? hwSubslotSize_ : srcBytes;

    if (srcBytes == dstBytes) {
        size_t readBytes = ringBuffer_->readAvailable(dest, destSize);
        if (readBytes < destSize) {
            std::memset(dest + readBytes, 0, destSize - readBytes);
        }
        return readBytes;
    }

    size_t numSamples = destSize / static_cast<size_t>(dstBytes);
    size_t sourceBytesNeeded = numSamples * static_cast<size_t>(srcBytes);
    if (conversionScratch_.size() < sourceBytesNeeded) {
        conversionScratch_.resize(sourceBytesNeeded);
    }
    size_t readBytes = ringBuffer_->readAvailable(conversionScratch_.data(), sourceBytesNeeded);
    size_t samplesRead = readBytes / static_cast<size_t>(srcBytes);

    for (size_t i = 0; i < samplesRead; ++i) {
        int32_t sample32 = 0;
        const uint8_t* s = conversionScratch_.data() + i * srcBytes;
        if (srcBytes == 2) {
            int16_t s16 = static_cast<int16_t>(s[0] | (s[1] << 8));
            sample32 = static_cast<int32_t>(s16) << 16;
        } else if (srcBytes == 3) {
            sample32 = static_cast<int32_t>(
                (static_cast<uint32_t>(s[0]) << 8) |
                (static_cast<uint32_t>(s[1]) << 16) |
                (static_cast<uint32_t>(static_cast<int8_t>(s[2])) << 24)
            );
        } else { // srcBytes == 4
            sample32 = static_cast<int32_t>(
                static_cast<uint32_t>(s[0]) |
                (static_cast<uint32_t>(s[1]) << 8) |
                (static_cast<uint32_t>(s[2]) << 16) |
                (static_cast<uint32_t>(s[3]) << 24)
            );
        }

        uint8_t* d = dest + i * dstBytes;
        if (dstBytes == 2) {
            int16_t out16 = static_cast<int16_t>(sample32 >> 16);
            d[0] = static_cast<uint8_t>(out16 & 0xFF);
            d[1] = static_cast<uint8_t>((out16 >> 8) & 0xFF);
        } else if (dstBytes == 3) {
            d[0] = static_cast<uint8_t>((sample32 >> 8) & 0xFF);
            d[1] = static_cast<uint8_t>((sample32 >> 16) & 0xFF);
            d[2] = static_cast<uint8_t>((sample32 >> 24) & 0xFF);
        } else { // dstBytes == 4
            d[0] = static_cast<uint8_t>(sample32 & 0xFF);
            d[1] = static_cast<uint8_t>((sample32 >> 8) & 0xFF);
            d[2] = static_cast<uint8_t>((sample32 >> 16) & 0xFF);
            d[3] = static_cast<uint8_t>((sample32 >> 24) & 0xFF);
        }
    }

    size_t writtenBytes = samplesRead * static_cast<size_t>(dstBytes);
    if (writtenBytes < destSize) {
        std::memset(dest + writtenBytes, 0, destSize - writtenBytes);
    }
    return writtenBytes;
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

    // 2. Tunggu event thread selesai (menguras seluruh in-flight callback)
    if (eventThread_.joinable()) {
        eventThread_.join();
    }

    // 3. Dealokasi transfer structs dengan aman
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
    setpriority(PRIO_PROCESS, 0, -16);
    LOGI("UsbDriver::eventThreadLoop - Entered (high priority)");
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
