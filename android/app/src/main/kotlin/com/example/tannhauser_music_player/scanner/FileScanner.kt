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

        val COVER_FILENAMES = setOf(
            "cover.jpg", "cover.jpeg", "cover.png",
            "folder.jpg", "folder.jpeg", "folder.png",
            "front.jpg", "front.png", "album.jpg", "album.png",
            "artwork.jpg", "artwork.png"
        )

        fun findFolderCover(dir: File?): String? {
            if (dir == null || !dir.isDirectory) return null
            val files = try { dir.listFiles() } catch (_: Exception) { null } ?: return null
            for (f in files) {
                if (f.isFile && COVER_FILENAMES.contains(f.name.lowercase(Locale.ROOT))) {
                    return f.absolutePath
                }
            }
            return null
        }

        fun resolveOrExtractArtwork(
            trackFile: File,
            album: String,
            artist: String,
            folderCoverPath: String?,
            artworkCacheDir: File?
        ): String {
            if (artworkCacheDir != null) {
                if (!artworkCacheDir.exists()) artworkCacheDir.mkdirs()
                val keySource = if (album.isNotBlank() && album != "Unknown Album") {
                    "${artist}_$album"
                } else {
                    trackFile.absolutePath
                }
                val digest = java.security.MessageDigest.getInstance("SHA-256")
                    .digest(keySource.toByteArray(Charsets.UTF_8))
                val hexKey = digest.take(8).joinToString("") { "%02x".format(it) }
                val cacheFile = File(artworkCacheDir, "art_$hexKey.img")
                if (cacheFile.exists() && cacheFile.length() > 0) {
                    return cacheFile.absolutePath
                }
                if (NativeAudioBridge.nativeExtractArtwork(trackFile.absolutePath, cacheFile.absolutePath)) {
                    if (cacheFile.exists() && cacheFile.length() > 0) {
                        return cacheFile.absolutePath
                    }
                }
            }
            return folderCoverPath ?: ""
        }
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
        artworkCacheDir: File? = null,
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
        val visitedDirs = HashSet<String>()
        for (root in rootDirs) {
            dirQueue.add(root)
        }

        var scannedCount = 0

        while (dirQueue.isNotEmpty() && !isCancelled.get()) {
            val currentDir = dirQueue.removeFirst()
            val canonical = try {
                currentDir.canonicalPath
            } catch (e: Exception) {
                currentDir.absolutePath
            }
            if (!visitedDirs.add(canonical)) {
                continue // Break cyclic symlinks / duplicate mount points
            }
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

            val folderCoverPath = findFolderCover(currentDir)

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
                                    val artworkPath = resolveOrExtractArtwork(
                                        trackFile = file,
                                        album = album,
                                        artist = artist,
                                        folderCoverPath = folderCoverPath,
                                        artworkCacheDir = artworkCacheDir
                                    )

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
                                        "codec" to codec,
                                        "artworkPath" to artworkPath
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
