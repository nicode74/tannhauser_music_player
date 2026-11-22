package com.example.tannhauser_music_player.usb

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log
import com.example.tannhauser_music_player.bridge.NativeAudioBridge

class UsbBridge(
    private val context: Context,
    private val onUsbStateChanged: ((isConnected: Boolean, deviceName: String?) -> Unit)? = null
) {
    companion object {
        private const val TAG = "Tannhauser_UsbBridge"
        private const val ACTION_USB_PERMISSION = "com.example.tannhauser_music_player.USB_PERMISSION"
    }

    private val usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private var usbConnection: UsbDeviceConnection? = null
    private var currentDevice: UsbDevice? = null
    private var isRegistered = false

    // 1. Receiver khusus izin internal aplikasi (RECEIVER_NOT_EXPORTED)
    private val permissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_USB_PERMISSION) {
                synchronized(this@UsbBridge) {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }

                    if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        device?.let {
                            Log.i(TAG, "USB Permission granted for: ${it.deviceName}")
                            openDeviceAndPassFd(it)
                        }
                    } else {
                        Log.e(TAG, "USB Permission denied for: ${device?.deviceName}")
                        onUsbStateChanged?.invoke(false, null)
                    }
                }
            }
        }
    }

    // 2. Receiver khusus broadcast sistem Android (ATTACHED / DETACHED)
    private val usbDeviceReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    Log.i(TAG, "USB device attached event received.")
                    scanAndConnectUsbDac()
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    Log.i(TAG, "USB device detached event received.")
                    disconnect()
                }
            }
        }
    }

    fun register() {
        if (isRegistered) return

        // Daftarkan permission receiver privat
        val permFilter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(permissionReceiver, permFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(permissionReceiver, permFilter)
        }

        // Daftarkan system event receiver
        val sysFilter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            context.registerReceiver(usbDeviceReceiver, sysFilter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(usbDeviceReceiver, sysFilter)
        }

        isRegistered = true
    }

    fun unregister() {
        if (!isRegistered) return
        try {
            context.unregisterReceiver(permissionReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "Permission receiver unregister warning: ${e.message}")
        }
        try {
            context.unregisterReceiver(usbDeviceReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "Device receiver unregister warning: ${e.message}")
        }
        isRegistered = false
        disconnect()
    }

    fun scanAndConnectUsbDac() {
        val deviceList = usbManager.deviceList
        Log.i(TAG, "Scanning for USB devices... Found ${deviceList.size} device(s).")

        for (device in deviceList.values) {
            if (isAudioDevice(device)) {
                Log.i(TAG, "Found USB Audio Device: ${device.productName ?: device.deviceName} (VID: ${device.vendorId}, PID: ${device.productId})")
                requestPermissionOrConnect(device)
                return
            }
        }
        Log.w(TAG, "No USB Audio Class device found.")
    }

    private fun isAudioDevice(device: UsbDevice): Boolean {
        // Cek device class USB Audio (0x01 = USB_CLASS_AUDIO)
        if (device.deviceClass == UsbConstants.USB_CLASS_AUDIO) return true

        // Cek seluruh interface untuk USB Audio Class
        for (i in 0 until device.interfaceCount) {
            if (device.getInterface(i).interfaceClass == UsbConstants.USB_CLASS_AUDIO) {
                return true
            }
        }

        return false
    }

    private fun requestPermissionOrConnect(device: UsbDevice) {
        if (usbManager.hasPermission(device)) {
            Log.i(TAG, "Already has permission for device: ${device.deviceName}")
            openDeviceAndPassFd(device)
        } else {
            Log.i(TAG, "Requesting permission for device: ${device.deviceName}")
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
            // Explicit intent dengan setPackage agar mematuhi aturan keamanan Android 14+
            val explicitIntent = Intent(ACTION_USB_PERMISSION).apply {
                setPackage(context.packageName)
            }
            val permissionIntent = PendingIntent.getBroadcast(
                context, 0, explicitIntent, flags
            )
            usbManager.requestPermission(device, permissionIntent)
        }
    }

    private fun openDeviceAndPassFd(device: UsbDevice) {
        // Idempotent guard: hindari reconnect berulang jika device yang sama sudah aktif
        if (isConnected && currentDevice?.deviceId == device.deviceId) {
            Log.i(TAG, "Device ${device.deviceName} already connected and FD claimed. Skipping.")
            return
        }

        disconnect()

        val connection = usbManager.openDevice(device)
        if (connection == null) {
            Log.e(TAG, "Failed to open USB device connection: ${device.deviceName}")
            onUsbStateChanged?.invoke(false, null)
            return
        }

        usbConnection = connection
        currentDevice = device
        val fd = connection.fileDescriptor

        Log.i(TAG, "Successfully obtained USB File Descriptor (FD): $fd for ${device.productName ?: device.deviceName}")

        // JNI hand-off ke C++ libusb
        val success = NativeAudioBridge.nativeSetUsbFileDescriptor(fd)
        if (success) {
            Log.i(TAG, "JNI hand-off successful. C++ libusb now owns wrapped USB FD.")
            onUsbStateChanged?.invoke(true, device.productName ?: device.deviceName)
        } else {
            Log.e(TAG, "JNI hand-off failed in C++ libusb.")
            onUsbStateChanged?.invoke(false, null)
        }
    }

    fun disconnect() {
        usbConnection?.close()
        usbConnection = null
        currentDevice = null
        try {
            NativeAudioBridge.nativeResetUsbDevice()
        } catch (e: Exception) {
            Log.w(TAG, "Error resetting native USB device in C++: ${e.message}")
        }
        onUsbStateChanged?.invoke(false, null)
    }

    val isConnected: Boolean
        get() = usbConnection != null
}
