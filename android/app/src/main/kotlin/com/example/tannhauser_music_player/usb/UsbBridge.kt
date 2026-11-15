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

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
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
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    Log.i(TAG, "USB device attached.")
                    scanAndConnectUsbDac()
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    Log.i(TAG, "USB device detached.")
                    disconnect()
                }
            }
        }
    }

    fun register() {
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(usbReceiver, filter)
        }
    }

    fun unregister() {
        try {
            context.unregisterReceiver(usbReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "Receiver not registered or already unregistered: ${e.message}")
        }
        disconnect()
    }

    fun scanAndConnectUsbDac() {
        val deviceList = usbManager.deviceList
        Log.i(TAG, "Scanning for USB devices... Found ${deviceList.size} device(s).")

        for (device in deviceList.values) {
            if (isAudioDevice(device)) {
                Log.i(TAG, "Found USB Audio Device: ${device.productName ?: device.deviceName} (Vendor: ${device.vendorId}, Product: ${device.productId})")
                requestPermissionOrConnect(device)
                return
            }
        }
        Log.w(TAG, "No USB Audio Class device found.")
    }

    private fun isAudioDevice(device: UsbDevice): Boolean {
        // Cek device class atau interface class untuk USB Audio (0x01 = USB_CLASS_AUDIO)
        if (device.deviceClass == UsbConstants.USB_CLASS_AUDIO) return true
        for (i in 0 until device.interfaceCount) {
            if (device.getInterface(i).interfaceClass == UsbConstants.USB_CLASS_AUDIO) {
                return true
            }
        }
        // Fallback: periksa vendor ID / product ID DAC jika class interface di-hide oleh vendor
        return true
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
            val permissionIntent = PendingIntent.getBroadcast(
                context, 0, Intent(ACTION_USB_PERMISSION), flags
            )
            usbManager.requestPermission(device, permissionIntent)
        }
    }

    private fun openDeviceAndPassFd(device: UsbDevice) {
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
            Log.i(TAG, "JNI hand-off successful. C++ libusb now owns the USB FD.")
            onUsbStateChanged?.invoke(true, device.productName ?: device.deviceName)
        } else {
            Log.e(TAG, "JNI hand-off failed.")
            onUsbStateChanged?.invoke(false, null)
        }
    }

    fun disconnect() {
        usbConnection?.close()
        usbConnection = null
        currentDevice = null
        onUsbStateChanged?.invoke(false, null)
    }

    val isConnected: Boolean
        get() = usbConnection != null
}
