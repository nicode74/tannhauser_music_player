package com.example.tannhauser_music_player

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.example.tannhauser_music_player.bridge.NativeAudioBridge
import com.example.tannhauser_music_player.usb.UsbBridge

class MainActivity : FlutterActivity() {
    private val COMMAND_CHANNEL = "com.example.tannhauser_music_player/audio"
    private val USB_EVENT_CHANNEL = "com.example.tannhauser_music_player/usb_events"

    private var usbBridge: UsbBridge? = null
    private var usbEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup USB Bridge
        usbBridge = UsbBridge(this) { isConnected, deviceName ->
            runOnUiThread {
                usbEventSink?.success(
                    mapOf(
                        "connected" to isConnected,
                        "deviceName" to deviceName
                    )
                )
            }
        }
        usbBridge?.register()

        // EventChannel for USB Attach/Detach & Permission
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, USB_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    usbEventSink = events
                    // Send initial status
                    usbBridge?.scanAndConnectUsbDac()
                }

                override fun onCancel(arguments: Any?) {
                    usbEventSink = null
                }
            }
        )

        // MethodChannel for Playback & Control Commands
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMMAND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanUsb" -> {
                    usbBridge?.scanAndConnectUsbDac()
                    result.success(usbBridge?.isConnected ?: false)
                }
                "loadFile" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val success = NativeAudioBridge.nativeLoadFile(filePath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                    }
                }
                "play" -> {
                    result.success(NativeAudioBridge.nativePlay())
                }
                "pause" -> {
                    result.success(NativeAudioBridge.nativePause())
                }
                "resume" -> {
                    result.success(NativeAudioBridge.nativeResume())
                }
                "stop" -> {
                    result.success(NativeAudioBridge.nativeStop())
                }
                "seek" -> {
                    val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                    result.success(NativeAudioBridge.nativeSeek(positionMs))
                }
                "getPlaybackInfo" -> {
                    val info = mapOf(
                        "state" to NativeAudioBridge.nativeGetPlaybackState(),
                        "sampleRate" to NativeAudioBridge.nativeGetSampleRate(),
                        "channels" to NativeAudioBridge.nativeGetChannels(),
                        "bitDepth" to NativeAudioBridge.nativeGetBitDepth(),
                        "durationMs" to NativeAudioBridge.nativeGetDuration(),
                        "positionMs" to NativeAudioBridge.nativeGetPosition(),
                        "isUsbConnected" to (usbBridge?.isConnected ?: false)
                    )
                    result.success(info)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        usbBridge?.unregister()
    }
}
