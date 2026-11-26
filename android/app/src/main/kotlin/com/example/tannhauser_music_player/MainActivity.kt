package com.example.tannhauser_music_player

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.tannhauser_music_player.bridge.NativeAudioBridge
import com.example.tannhauser_music_player.scanner.FileScanner
import com.example.tannhauser_music_player.service.AudioPlaybackService
import com.example.tannhauser_music_player.usb.UsbBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "Tannhauser_MainActivity"
        private const val COMMAND_CHANNEL = "com.example.tannhauser_music_player/audio"
        private const val USB_EVENT_CHANNEL = "com.example.tannhauser_music_player/usb_events"
        private const val SCAN_EVENT_CHANNEL = "com.example.tannhauser_music_player/scan_progress"
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    private var usbBridge: UsbBridge? = null
    private var usbEventSink: EventChannel.EventSink? = null
    private var scanEventSink: EventChannel.EventSink? = null
    private var fileScanner: FileScanner? = null
    private val backgroundExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var pausedByAudioFocus: Boolean = false
    private var audioFocusRequest: android.media.AudioFocusRequest? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var currentTrackTitle: String = "Tannhäuser Audio"
    private var currentTrackArtist: String = "Bit-Perfect Mode"
    private var commandMethodChannel: MethodChannel? = null
    private var currentVolume: Float = 0.75f

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
                    backgroundExecutor.execute {
                        usbBridge?.scanAndConnectUsbDac()
                    }
                }

                override fun onCancel(arguments: Any?) {
                    usbEventSink = null
                }
            }
        )

        // EventChannel for Filesystem Scan Progress Telemetry
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCAN_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    scanEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    scanEventSink = null
                }
            }
        )

        // MethodChannel for Playback & Control Commands (All JNI calls dispatched to background thread)
        val cmdChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMMAND_CHANNEL)
        commandMethodChannel = cmdChannel
        cmdChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppDocumentsPath" -> {
                    result.success(applicationContext.filesDir.absolutePath)
                }
                "checkAllFilesPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(android.os.Environment.isExternalStorageManager())
                    } else {
                        result.success(hasAudioPermission())
                    }
                }
                "requestAllFilesPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        if (android.os.Environment.isExternalStorageManager()) {
                            result.success(true)
                        } else {
                            try {
                                val intent = android.content.Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                                intent.data = android.net.Uri.parse("package:$packageName")
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                val intent = android.content.Intent(android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                startActivity(intent)
                                result.success(true)
                            }
                        }
                    } else {
                        if (hasAudioPermission()) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                getRequiredAudioPermissions(),
                                PERMISSION_REQUEST_CODE
                            )
                        }
                    }
                }
                "getStorageRoots" -> {
                    val roots = discoverStorageRoots().map { dir ->
                        val isPrimary = dir.absolutePath == android.os.Environment.getExternalStorageDirectory()?.absolutePath
                        mapOf(
                            "name" to if (isPrimary) "Internal Storage" else "SD Card (${dir.name})",
                            "path" to dir.absolutePath,
                            "isRemovable" to !isPrimary
                        )
                    }
                    result.success(roots)
                }
                "listSubdirectories" -> {
                    val targetPath = call.argument<String>("path")
                    if (targetPath.isNullOrEmpty()) {
                        result.success(emptyList<Map<String, Any>>())
                    } else {
                        ioExecutor.execute {
                            try {
                                val dir = File(targetPath)
                                val children = dir.listFiles()
                                    ?.filter { it.isDirectory && !it.name.startsWith(".") }
                                    ?.sortedBy { it.name.lowercase() }
                                    ?.map { sub ->
                                        val hasSub = sub.listFiles()?.any { it.isDirectory && !it.name.startsWith(".") } ?: false
                                        mapOf(
                                            "name" to sub.name,
                                            "path" to sub.absolutePath,
                                            "hasSubdirs" to hasSub
                                        )
                                    } ?: emptyList()
                                runOnUiThread { result.success(children) }
                            } catch (e: Exception) {
                                runOnUiThread { result.success(emptyList<Map<String, Any>>()) }
                            }
                        }
                    }
                }
                "startStorageScan" -> {
                    val customPaths = call.argument<List<String>>("customPaths")
                    val minDurationMs = (call.argument<Number>("minDurationMs") ?: 30000L).toLong()
                    val minSizeBytes = (call.argument<Number>("minSizeBytes") ?: (512L * 1024L)).toLong()
                    val excludedList = call.argument<List<String>>("excludedFolders") ?: emptyList()
                    val excludedSet = excludedList.toSet()
                    val additionalRoots = discoverStorageRoots()
                    val artworkCacheDir = File(applicationContext.cacheDir, "artwork")

                    ioExecutor.execute {
                        try {
                            val scanner = FileScanner()
                            fileScanner = scanner
                            val tracks = scanner.scan(
                                customPaths = customPaths,
                                minDurationMs = minDurationMs,
                                minSizeBytes = minSizeBytes,
                                excludedFolders = excludedSet,
                                additionalRoots = additionalRoots,
                                artworkCacheDir = artworkCacheDir
                            ) { currentDir, scannedCount, isDone ->
                                runOnUiThread {
                                    scanEventSink?.success(
                                        mapOf(
                                            "currentDir" to currentDir,
                                            "scannedCount" to scannedCount,
                                            "isDone" to isDone
                                        )
                                    )
                                }
                            }
                            runOnUiThread {
                                result.success(tracks)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Storage scan error: ${e.message}", e)
                            runOnUiThread {
                                result.error("SCAN_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "stopStorageScan" -> {
                    fileScanner?.cancel()
                    result.success(true)
                }
                "extractTrackArtwork" -> {
                    val filePath = call.argument<String>("filePath")
                    val album = call.argument<String>("album") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    if (filePath.isNullOrEmpty()) {
                        result.success("")
                    } else {
                        ioExecutor.execute {
                            try {
                                val trackFile = File(filePath)
                                val folderCover = FileScanner.findFolderCover(trackFile.parentFile)
                                val cacheDir = File(applicationContext.cacheDir, "artwork")
                                val artPath = FileScanner.resolveOrExtractArtwork(
                                    trackFile = trackFile,
                                    album = album,
                                    artist = artist,
                                    folderCoverPath = folderCover,
                                    artworkCacheDir = cacheDir
                                )
                                runOnUiThread { result.success(artPath) }
                            } catch (e: Exception) {
                                runOnUiThread { result.success("") }
                            }
                        }
                    }
                }
                "checkPermissions" -> {
                    result.success(hasAudioPermission())
                }
                "requestPermissions" -> {
                    if (hasAudioPermission()) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            getRequiredAudioPermissions(),
                            PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "scanAudioFiles" -> {
                    backgroundExecutor.execute {
                        try {
                            val audioList = queryAudioFiles()
                            runOnUiThread {
                                result.success(audioList)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error scanning audio files: ${e.message}", e)
                            runOnUiThread {
                                result.error("SCAN_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "scanUsb" -> {
                    backgroundExecutor.execute {
                        try {
                            usbBridge?.scanAndConnectUsbDac()
                            val connected = usbBridge?.isConnected ?: false
                            runOnUiThread {
                                result.success(connected)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("USB_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "loadFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    if (title != null) currentTrackTitle = title
                    if (artist != null) currentTrackArtist = artist

                    if (filePath == null) {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                    } else {
                        if (title == null) {
                            currentTrackTitle = File(filePath).nameWithoutExtension
                        }
                        backgroundExecutor.execute {
                            try {
                                Log.i(TAG, "Executing nativeLoadFile on background thread: $filePath")
                                val success = NativeAudioBridge.nativeLoadFile(filePath)
                                runOnUiThread {
                                    result.success(success)
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Exception during nativeLoadFile: ${e.message}", e)
                                runOnUiThread {
                                    result.error("LOAD_ERROR", e.message, null)
                                }
                            }
                        }
                    }
                }
                "play" -> {
                    requestAudioFocus()
                    backgroundExecutor.execute {
                        try {
                            val success = NativeAudioBridge.nativePlay()
                            if (success) {
                                runOnUiThread {
                                    AudioPlaybackService.startService(
                                        this@MainActivity,
                                        currentTrackTitle,
                                        currentTrackArtist,
                                        isPlaying = true
                                    )
                                }
                            }
                            runOnUiThread {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("PLAY_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "pause" -> {
                    backgroundExecutor.execute {
                        try {
                            val success = NativeAudioBridge.nativePause()
                            runOnUiThread {
                                AudioPlaybackService.updatePlayback(this@MainActivity, isPlaying = false)
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("PAUSE_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "resume" -> {
                    requestAudioFocus()
                    backgroundExecutor.execute {
                        try {
                            val success = NativeAudioBridge.nativeResume()
                            if (success) {
                                runOnUiThread {
                                    AudioPlaybackService.updatePlayback(this@MainActivity, isPlaying = true)
                                }
                            }
                            runOnUiThread {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("RESUME_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "stop" -> {
                    backgroundExecutor.execute {
                        try {
                            val success = NativeAudioBridge.nativeStop()
                            runOnUiThread {
                                AudioPlaybackService.stopService(this@MainActivity)
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("STOP_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "seek" -> {
                    val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                    backgroundExecutor.execute {
                        try {
                            val success = NativeAudioBridge.nativeSeek(positionMs)
                            runOnUiThread {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("SEEK_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "getPlaybackInfo" -> {
                    backgroundExecutor.execute {
                        try {
                            val info = mapOf(
                                "state" to NativeAudioBridge.nativeGetPlaybackState(),
                                "sampleRate" to NativeAudioBridge.nativeGetSampleRate(),
                                "channels" to NativeAudioBridge.nativeGetChannels(),
                                "bitDepth" to NativeAudioBridge.nativeGetBitDepth(),
                                "durationMs" to NativeAudioBridge.nativeGetDuration(),
                                "positionMs" to NativeAudioBridge.nativeGetPosition(),
                                "isUsbConnected" to (usbBridge?.isConnected ?: false)
                            )
                            runOnUiThread {
                                result.success(info)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("INFO_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "setPeqEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    backgroundExecutor.execute {
                        try {
                            val success = NativeAudioBridge.nativeSetPeqEnabled(enabled)
                            runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PEQ_ERROR", e.message, null) }
                        }
                    }
                }
                "setPeqPreamp" -> {
                    val preampDb = call.argument<Number>("preampDb")?.toDouble() ?: 0.0
                    backgroundExecutor.execute {
                        try {
                            val success = NativeAudioBridge.nativeSetPeqPreamp(preampDb)
                            runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PEQ_ERROR", e.message, null) }
                        }
                    }
                }
                "updatePeqBand" -> {
                    val index = call.argument<Int>("index") ?: 0
                    val type = call.argument<Int>("type") ?: 0
                    val fc = call.argument<Number>("fc")?.toDouble() ?: 1000.0
                    val gainDb = call.argument<Number>("gainDb")?.toDouble() ?: 0.0
                    val q = call.argument<Number>("q")?.toDouble() ?: 0.7071
                    val enabled = call.argument<Boolean>("enabled") ?: false

                    backgroundExecutor.execute {
                        try {
                            val success = NativeAudioBridge.nativeUpdatePeqBand(index, type, fc, gainDb, q, enabled)
                            runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PEQ_ERROR", e.message, null) }
                        }
                    }
                }
                "resetPeqStates" -> {
                    backgroundExecutor.execute {
                        try {
                            val success = NativeAudioBridge.nativeResetPeqStates()
                            runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("PEQ_ERROR", e.message, null) }
                        }
                    }
                }
                "setVolume" -> {
                    val volume = (call.argument<Number>("volume")?.toFloat() ?: 1.0f).coerceIn(0.0f, 1.0f)
                    currentVolume = volume
                    backgroundExecutor.execute {
                        try {
                            val success = NativeAudioBridge.nativeSetVolume(volume)
                            runOnUiThread { result.success(success) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("VOLUME_ERROR", e.message, null) }
                        }
                    }
                }
                "getVolume" -> {
                    backgroundExecutor.execute {
                        try {
                            val volume = NativeAudioBridge.nativeGetVolume()
                            currentVolume = volume
                            runOnUiThread { result.success(volume.toDouble()) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("VOLUME_ERROR", e.message, null) }
                        }
                    }
                }
                "setLauncherIcon" -> {
                    val paletteId = call.argument<String>("paletteId") ?: "eva_01"
                    backgroundExecutor.execute {
                        val ok = switchLauncherIcon(paletteId)
                        runOnUiThread { result.success(ok) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun switchLauncherIcon(paletteId: String): Boolean {
        val validIds = listOf(
            "eva_00_proto", "eva_00_blue", "eva_01", "eva_02", "eva_03",
            "eva_04", "eva_05", "eva_06", "eva_07", "eva_08",
            "eva_09", "eva_10", "eva_11", "eva_12", "eva_13"
        )
        val targetId = if (validIds.contains(paletteId)) paletteId else "eva_01"
        return try {
            val pm = applicationContext.packageManager
            val pkg = applicationContext.packageName
            for (id in validIds) {
                val component = android.content.ComponentName(pkg, "$pkg.Launcher_$id")
                val state = if (id == targetId) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                }
                pm.setComponentEnabledSetting(component, state, PackageManager.DONT_KILL_APP)
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to switch launcher icon: ${e.message}")
            false
        }
    }

    private fun discoverStorageRoots(): List<File> {
        val roots = LinkedHashSet<File>()
        val primary = android.os.Environment.getExternalStorageDirectory()
        if (primary != null && primary.exists() && primary.isDirectory) {
            roots.add(primary)
        }
        try {
            val extDirs = ContextCompat.getExternalFilesDirs(applicationContext, null)
            for (d in extDirs) {
                if (d != null) {
                    val rootPath = d.absolutePath.substringBefore("/Android/data")
                    val rootFile = File(rootPath)
                    if (rootFile.exists() && rootFile.isDirectory) {
                        roots.add(rootFile)
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error getting external files dirs: ${e.message}")
        }
        try {
            val sm = getSystemService(android.content.Context.STORAGE_SERVICE) as? android.os.storage.StorageManager
            sm?.storageVolumes?.forEach { vol ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    vol.directory?.let { dir ->
                        if (dir.exists() && dir.isDirectory) {
                            roots.add(dir)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error querying StorageManager: ${e.message}")
        }
        return roots.toList()
    }

    private fun getRequiredAudioPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(Manifest.permission.READ_MEDIA_AUDIO)
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
    }

    private fun hasAudioPermission(): Boolean {
        val perms = getRequiredAudioPermissions()
        return perms.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun queryAudioFiles(): List<Map<String, Any>> {
        val audioList = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA
        )

        val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"
        val cursor = contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            sortOrder
        )

        cursor?.use {
            val titleIndex = it.getColumnIndex(MediaStore.Audio.Media.TITLE)
            val artistIndex = it.getColumnIndex(MediaStore.Audio.Media.ARTIST)
            val albumIndex = it.getColumnIndex(MediaStore.Audio.Media.ALBUM)
            val durationIndex = it.getColumnIndex(MediaStore.Audio.Media.DURATION)
            val dataIndex = it.getColumnIndex(MediaStore.Audio.Media.DATA)

            val validExtensions = setOf("flac", "wav", "m4a", "alac", "mp3", "aac", "ogg")

            while (it.moveToNext()) {
                val path = if (dataIndex >= 0) it.getString(dataIndex) ?: "" else ""
                if (path.isEmpty()) continue

                val ext = path.substringAfterLast('.', "").lowercase()
                if (ext !in validExtensions) continue

                val file = File(path)
                if (!file.exists()) continue

                val title = if (titleIndex >= 0) it.getString(titleIndex) ?: file.nameWithoutExtension else file.nameWithoutExtension
                val artist = if (artistIndex >= 0) it.getString(artistIndex) ?: "Unknown Artist" else "Unknown Artist"
                val album = if (albumIndex >= 0) it.getString(albumIndex) ?: "Unknown Album" else "Unknown Album"
                val duration = if (durationIndex >= 0) it.getLong(durationIndex) else 0L

                audioList.add(
                    mapOf(
                        "path" to path,
                        "title" to title,
                        "artist" to if (artist == "<unknown>") "Unknown Artist" else artist,
                        "album" to if (album == "<unknown>") "Unknown Album" else album,
                        "duration" to duration,
                        "size" to file.length()
                    )
                )
            }
        }
        Log.i(TAG, "queryAudioFiles found ${audioList.size} audio tracks.")
        return audioList
    }

    override fun onKeyDown(keyCode: Int, event: android.view.KeyEvent?): Boolean {
        if (usbBridge?.isConnected == true) {
            when (keyCode) {
                android.view.KeyEvent.KEYCODE_VOLUME_UP -> {
                    val newVol = (currentVolume + 0.05f).coerceIn(0.0f, 1.0f)
                    currentVolume = newVol
                    backgroundExecutor.execute {
                        NativeAudioBridge.nativeSetVolume(newVol)
                    }
                    commandMethodChannel?.invokeMethod("onVolumeChanged", mapOf("volume" to newVol.toDouble()))
                    return true
                }
                android.view.KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    val newVol = (currentVolume - 0.05f).coerceIn(0.0f, 1.0f)
                    currentVolume = newVol
                    backgroundExecutor.execute {
                        NativeAudioBridge.nativeSetVolume(newVol)
                    }
                    commandMethodChannel?.invokeMethod("onVolumeChanged", mapOf("volume" to newVol.toDouble()))
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    private val audioFocusListener = android.media.AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                backgroundExecutor.execute {
                    if (NativeAudioBridge.nativeGetPlaybackState() == 1) {
                        pausedByAudioFocus = true
                        NativeAudioBridge.nativePause()
                        runOnUiThread {
                            AudioPlaybackService.updatePlayback(this@MainActivity, isPlaying = false)
                        }
                    }
                }
            }
            android.media.AudioManager.AUDIOFOCUS_LOSS -> {
                pausedByAudioFocus = false
                backgroundExecutor.execute {
                    if (NativeAudioBridge.nativeGetPlaybackState() == 1) {
                        NativeAudioBridge.nativePause()
                        runOnUiThread {
                            AudioPlaybackService.updatePlayback(this@MainActivity, isPlaying = false)
                        }
                    }
                }
            }
            android.media.AudioManager.AUDIOFOCUS_GAIN -> {
                if (pausedByAudioFocus) {
                    pausedByAudioFocus = false
                    backgroundExecutor.execute {
                        NativeAudioBridge.nativeResume()
                        runOnUiThread {
                            AudioPlaybackService.updatePlayback(this@MainActivity, isPlaying = true)
                        }
                    }
                }
            }
        }
    }

    private fun requestAudioFocus() {
        val am = getSystemService(android.content.Context.AUDIO_SERVICE) as? android.media.AudioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attrs = android.media.AudioAttributes.Builder()
                .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            val req = android.media.AudioFocusRequest.Builder(android.media.AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attrs)
                .setAcceptsDelayedFocusGain(true)
                .setWillPauseWhenDucked(false)
                .setOnAudioFocusChangeListener(audioFocusListener)
                .build()
            audioFocusRequest = req
            am.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(
                audioFocusListener,
                android.media.AudioManager.STREAM_MUSIC,
                android.media.AudioManager.AUDIOFOCUS_GAIN
            )
        }
    }

    private fun abandonAudioFocus() {
        val am = getSystemService(android.content.Context.AUDIO_SERVICE) as? android.media.AudioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(audioFocusListener)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        abandonAudioFocus()
        AudioPlaybackService.stopService(this)
        backgroundExecutor.shutdown()
        ioExecutor.shutdown()
        usbBridge?.unregister()
    }
}
