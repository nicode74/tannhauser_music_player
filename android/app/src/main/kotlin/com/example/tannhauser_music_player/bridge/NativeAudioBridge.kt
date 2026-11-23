package com.example.tannhauser_music_player.bridge

object NativeAudioBridge {
    init {
        // Urutan pemuatan library untuk mencegah UnsatisfiedLinkError:
        // 1. libusb1.0.so (independen dari FFmpeg)
        System.loadLibrary("usb1.0")

        // 2. FFmpeg libraries (urutan dependensi: libavutil -> libswresample -> libavcodec -> libavformat)
        System.loadLibrary("avutil")
        System.loadLibrary("swresample")
        System.loadLibrary("avcodec")
        System.loadLibrary("avformat")

        // 3. Engine C++ utama (tergantung pada libusb dan modul FFmpeg di atas)
        System.loadLibrary("native-audio-engine")
    }

    external fun nativeSetUsbFileDescriptor(fd: Int): Boolean
    external fun nativeResetUsbDevice(): Boolean
    external fun nativeLoadFile(filePath: String): Boolean
    external fun nativePlay(): Boolean
    external fun nativePause(): Boolean
    external fun nativeResume(): Boolean
    external fun nativeStop(): Boolean
    external fun nativeSeek(positionMs: Long): Boolean
    external fun nativeGetPlaybackState(): Int
    external fun nativeGetSampleRate(): Int
    external fun nativeGetChannels(): Int
    external fun nativeGetBitDepth(): Int
    external fun nativeGetDuration(): Long
    external fun nativeGetPosition(): Long

    // 64-Bit Parametric EQ NDK Methods
    external fun nativeSetPeqEnabled(enabled: Boolean): Boolean
    external fun nativeSetPeqPreamp(preampDb: Double): Boolean
    external fun nativeUpdatePeqBand(index: Int, type: Int, fc: Double, gainDb: Double, q: Double, enabled: Boolean): Boolean
    external fun nativeResetPeqStates(): Boolean

    // Master Digital Volume Control (0.0f - 1.0f)
    external fun nativeSetVolume(volume: Float): Boolean
    external fun nativeGetVolume(): Float

    // Fast Header Prober (FFmpeg without CodecContext allocation)
    external fun nativeProbeAudioFile(filePath: String): Map<String, Any>?
}
