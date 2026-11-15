package com.example.tannhauser_music_player.bridge

object NativeAudioBridge {
    init {
        System.loadLibrary("native-audio-engine")
    }

    external fun nativeSetUsbFileDescriptor(fd: Int): Boolean
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
}
