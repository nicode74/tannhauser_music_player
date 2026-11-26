package com.example.tannhauser_music_player.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import com.example.tannhauser_music_player.MainActivity
import com.example.tannhauser_music_player.bridge.NativeAudioBridge
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class AudioPlaybackService : Service() {
    companion object {
        private const val TAG = "AudioPlaybackService"
        private const val CHANNEL_ID = "tannhauser_playback_channel"
        private const val NOTIFICATION_ID = 1001

        const val ACTION_START = "com.example.tannhauser_music_player.action.START"
        const val ACTION_PLAY = "com.example.tannhauser_music_player.action.PLAY"
        const val ACTION_PAUSE = "com.example.tannhauser_music_player.action.PAUSE"
        const val ACTION_STOP = "com.example.tannhauser_music_player.action.STOP"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_ARTIST = "extra_artist"
        const val EXTRA_IS_PLAYING = "extra_is_playing"

        @Volatile
        private var isServiceRunning: Boolean = false

        fun startService(context: Context, title: String, artist: String, isPlaying: Boolean) {
            isServiceRunning = true
            val intent = Intent(context, AudioPlaybackService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_ARTIST, artist)
                putExtra(EXTRA_IS_PLAYING, isPlaying)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun updatePlayback(context: Context, isPlaying: Boolean) {
            if (!isServiceRunning) return
            val intent = Intent(context, AudioPlaybackService::class.java).apply {
                action = if (isPlaying) ACTION_PLAY else ACTION_PAUSE
            }
            try {
                context.startService(intent)
            } catch (e: IllegalStateException) {
                Log.w(TAG, "Ignored updatePlayback while app is backgrounded: ${e.message}")
            }
        }

        fun stopService(context: Context) {
            if (!isServiceRunning) return
            isServiceRunning = false
            val intent = Intent(context, AudioPlaybackService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (e: IllegalStateException) {
                Log.w(TAG, "Ignored stopService while app is backgrounded: ${e.message}")
            }
        }
    }

    private var mediaSession: MediaSessionCompat? = null
    private val serviceExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var currentTitle: String = "Tannhäuser Audio"
    private var currentArtist: String = "Bit-Perfect Mode"
    private var isPlayingState: Boolean = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        setupMediaSession()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Tannhäuser Bit-Perfect Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Foreground playback notification for low-level USB audio"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun setupMediaSession() {
        mediaSession = MediaSessionCompat(this, "TannhauserSession").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    serviceExecutor.execute {
                        NativeAudioBridge.nativePlay()
                    }
                    updateNotification(true)
                }

                override fun onPause() {
                    serviceExecutor.execute {
                        NativeAudioBridge.nativePause()
                    }
                    updateNotification(false)
                }

                override fun onStop() {
                    serviceExecutor.execute {
                        NativeAudioBridge.nativeStop()
                    }
                    stopForegroundService()
                }

                override fun onSeekTo(pos: Long) {
                    serviceExecutor.execute {
                        NativeAudioBridge.nativeSeek(pos)
                    }
                }
            })
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        when (action) {
            ACTION_START -> {
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                currentArtist = intent.getStringExtra(EXTRA_ARTIST) ?: currentArtist
                isPlayingState = intent.getBooleanExtra(EXTRA_IS_PLAYING, true)
                startForegroundNotification()
            }
            ACTION_PLAY -> {
                isPlayingState = true
                updateNotification(true)
            }
            ACTION_PAUSE -> {
                isPlayingState = false
                updateNotification(false)
            }
            ACTION_STOP -> {
                stopForegroundService()
            }
        }
        return START_NOT_STICKY
    }

    private fun startForegroundNotification() {
        val notification = buildNotification(isPlayingState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(isPlaying: Boolean) {
        isPlayingState = isPlaying
        val playbackState = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        mediaSession?.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_STOP or
                    PlaybackStateCompat.ACTION_SEEK_TO
                )
                .setState(playbackState, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 1.0f)
                .build()
        )

        mediaSession?.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)
                .build()
        )

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(isPlaying))
    }

    private fun buildNotification(isPlaying: Boolean): Notification {
        val contentIntent = Intent(this, MainActivity::class.java).let { notificationIntent ->
            PendingIntent.getActivity(
                this, 0, notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val playPauseAction = if (isPlaying) {
            NotificationCompat.Action(
                android.R.drawable.ic_media_pause,
                "Pause",
                getPendingIntent(ACTION_PAUSE)
            )
        } else {
            NotificationCompat.Action(
                android.R.drawable.ic_media_play,
                "Play",
                getPendingIntent(ACTION_PLAY)
            )
        }

        val stopAction = NotificationCompat.Action(
            android.R.drawable.ic_menu_close_clear_cancel,
            "Stop",
            getPendingIntent(ACTION_STOP)
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(currentTitle)
            .setContentText(currentArtist)
            .setSubText("BIT-PERFECT DAC")
            .setContentIntent(contentIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(isPlaying)
            .addAction(playPauseAction)
            .addAction(stopAction)

        mediaSession?.let {
            builder.setStyle(
                MediaStyle()
                    .setMediaSession(it.sessionToken)
                    .setShowActionsInCompactView(0, 1)
            )
        }

        return builder.build()
    }

    private fun getPendingIntent(action: String): PendingIntent {
        val intent = Intent(this, AudioPlaybackService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(
            this,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun stopForegroundService() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        mediaSession?.release()
        mediaSession = null
        serviceExecutor.shutdown()
        super.onDestroy()
    }
}
