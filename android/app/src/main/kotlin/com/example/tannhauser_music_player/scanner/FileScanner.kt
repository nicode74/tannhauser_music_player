package com.example.tannhauser_music_player.scanner

import android.os.Environment
import android.util.Log
import com.example.tannhauser_music_player.bridge.NativeAudioBridge
import java.io.File
import java.util.ArrayDeque
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

class FileScanner {
    companion object {
        private const val TAG = "Tannhauser_FileScanner"

        val SUPPORTED_EXTENSIONS = setOf(
            "flac", "wav", "alac", "dsf", "dff", "ape", "wv", "m4a", "ogg", "mp3", "aac", "aiff"
        )

        val JUNK_DIRECTORIES = setOf(
            "android", "dcim", "pictures", "movies", "whatsapp", "telegram",
            "recordings", "notifications", "ringtones", "alarms", "miui", "tencent",
            "coloros", "lost.dir", "cache"
        )
    }

    private val isCancelled = AtomicBoolean(false)

    fun cancel() {
        isCancelled.set(true)
    }

    fun scan(
        customPaths: List<String>? = null,
        minDurationMs: Long = 30000L,
        minSizeBytes: Long = 512L * 1024L,
        excludedFolders: Set<String> = emptySet(),
        additionalRoots: List<File> = emptyList(),
        onProgress: (currentDir: String, scannedCount: Int, isDone: Boolean) -> Unit
    ): List<Map<String, Any>> {
        isCancelled.set(false)
        val tracks = ArrayList<Map<String, Any>>()
        val rootDirs = ArrayList<File>()

        if (!customPaths.isNullOrEmpty()) {
            for (p in customPaths) {
                val f = File(p)
                if (f.exists() && f.isDirectory) {
                    rootDirs.add(f)
                }
            }
        } else {
            // 1. Primary internal storage
            val primary = Environment.getExternalStorageDirectory()
            if (primary != null && primary.exists()) {
                rootDirs.add(primary)
            }

            // 2. Storage roots discovered via Android framework (SD Cards, USB OTG)
            for (root in additionalRoots) {
                if (root.exists() && root.isDirectory && !rootDirs.contains(root)) {
                    rootDirs.add(root)
                }
            }

            // 3. Fallback scan on standard Android mount points
            for (mountPoint in listOf("/storage", "/mnt/media_rw", "/mnt")) {
                val dir = File(mountPoint)
                if (dir.exists() && dir.isDirectory) {
                    dir.listFiles()?.forEach { file ->
                        val name = file.name.lowercase(Locale.ROOT)
                        if (file.isDirectory && name != "emulated" && name != "self" && name != "knox") {
                            if (!rootDirs.contains(file)) {
                                rootDirs.add(file)
                            }
                        }
                    }
                }
            }
        }

        Log.i(TAG, "Starting filesystem scan across ${rootDirs.size} root directories")
        val dirQueue = ArrayDeque<File>()
        for (root in rootDirs) {
            dirQueue.add(root)
        }

        var scannedCount = 0

        while (dirQueue.isNotEmpty() && !isCancelled.get()) {
            val currentDir = dirQueue.removeFirst()
            val dirPath = currentDir.absolutePath
            val dirNameLower = currentDir.name.lowercase(Locale.ROOT)

            // Skip hidden or system/junk directories
            if (currentDir.name.startsWith(".") && currentDir.name != ".") {
                continue
            }
            if (JUNK_DIRECTORIES.contains(dirNameLower)) {
                continue
            }

            // Check if explicitly excluded by user
            if (isPathExcluded(dirPath, excludedFolders)) {
                continue
            }

            val files = try {
                currentDir.listFiles()
            } catch (e: Exception) {
                Log.w(TAG, "Cannot list files in $dirPath: ${e.message}")
                null
            } ?: continue

            // Directory Marker Bypass: If folder contains .nomedia or .tannhauser_ignore, skip entire folder
            val hasIgnoreFile = files.any { f ->
                f.isFile && (f.name.equals(".nomedia", ignoreCase = true) || f.name.equals(".tannhauser_ignore", ignoreCase = true))
            }
            if (hasIgnoreFile) {
                continue
            }

            for (file in files) {
                if (isCancelled.get()) break

                if (file.isDirectory) {
                    dirQueue.add(file)
                } else if (file.isFile) {
                    val ext = file.extension.lowercase(Locale.ROOT)
                    if (SUPPORTED_EXTENSIONS.contains(ext) && file.length() >= minSizeBytes) {
                        try {
                            val probe = NativeAudioBridge.nativeProbeAudioFile(file.absolutePath)
                            if (probe != null) {
                                val dur = (probe["durationMs"] as? Number)?.toLong() ?: 0L
                                // Audiophile filter: minimum duration (>= 30s by default), no upper cap
                                if (dur >= minDurationMs) {
                                    val title = (probe["title"] as? String)?.takeIf { it.isNotBlank() }
                                        ?: file.nameWithoutExtension
                                    val artist = (probe["artist"] as? String)?.takeIf { it.isNotBlank() }
                                        ?: "Unknown Artist"
                                    val album = (probe["album"] as? String)?.takeIf { it.isNotBlank() }
                                        ?: currentDir.name
                                    val trackNumber = (probe["trackNumber"] as? Number)?.toInt() ?: 0
                                    val sampleRate = (probe["sampleRate"] as? Number)?.toInt() ?: 44100
                                    val bitDepth = (probe["bitDepth"] as? Number)?.toInt() ?: 16
                                    val bitRate = (probe["bitRate"] as? Number)?.toLong() ?: 0L
                                    val codec = (probe["codec"] as? String) ?: ext.uppercase(Locale.ROOT)

                                    val trackMap = mapOf<String, Any>(
                                        "path" to file.absolutePath,
                                        "title" to title,
                                        "artist" to artist,
                                        "album" to album,
                                        "duration" to dur,
                                        "size" to file.length(),
                                        "trackNumber" to trackNumber,
                                        "sampleRate" to sampleRate,
                                        "bitDepth" to bitDepth,
                                        "bitRate" to bitRate,
                                        "codec" to codec
                                    )
                                    tracks.add(trackMap)
                                    scannedCount++

                                    if (scannedCount % 15 == 0) {
                                        onProgress(currentDir.absolutePath, scannedCount, false)
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Failed to probe file ${file.absolutePath}: ${e.message}")
                        }
                    }
                }
            }
        }

        onProgress("", tracks.size, true)
        Log.i(TAG, "Filesystem scan completed. Total tracks indexed: ${tracks.size}")
        return tracks
    }

    private fun isPathExcluded(dirPath: String, excludedFolders: Set<String>): Boolean {
        for (excluded in excludedFolders) {
            if (dirPath == excluded || dirPath.startsWith("$excluded/")) {
                return true
            }
        }
        return false
    }
}
