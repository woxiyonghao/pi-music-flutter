package com.winheo.hide_player_flutter

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
import android.os.PowerManager

/**
 * Keeps the audio engine process in FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK state
 * and holds a PARTIAL_WAKE_LOCK while music is playing so OEM ROMs (Vivo/Oppo)
 * do not mark the UID idle, revoke AudioFocus, or freeze the process after screen lock.
 */
class PlaybackForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            releaseWakeLock()
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }
        acquireWakeLock(applicationContext)
        startForegroundWithNotification()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        releaseWakeLock()
        stopForegroundCompat()
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    private fun startForegroundWithNotification() {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager != null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "HiFi 后台音频播放",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "保持锁屏与后台状态下高保真音频连续输出"
                    setShowBadge(false)
                    enableVibration(false)
                    setSound(null, null)
                }
                manager.createNotificationChannel(channel)
            }

            val launchIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val contentIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }

            val iconRes = R.drawable.ic_stat_playback
            val notification = builder
                .setContentTitle("PhonoraMusic")
                .setContentText("正在后台高保真播放音频")
                .setSmallIcon(iconRes)
                .setContentIntent(contentIntent)
                .setOngoing(true)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            // Ignore foreground start restrictions on restricted background transitions;
            // the partial WakeLock still protects the audio/decode threads.
        }
    }

    private fun stopForegroundCompat() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {}
    }

    companion object {
        private const val CHANNEL_ID = "hifi_playback_channel"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_START = "com.winheo.hide_player_flutter.action.START_PLAYBACK"
        private const val ACTION_STOP = "com.winheo.hide_player_flutter.action.STOP_PLAYBACK"
        private const val WAKE_LOCK_TAG = "hide_player_flutter:AudioPlaybackWakeLock"

        @Volatile
        private var wakeLock: PowerManager.WakeLock? = null

        @Synchronized
        private fun acquireWakeLock(context: Context) {
            try {
                val lock = wakeLock ?: run {
                    val pm = context.applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
                    pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG)?.apply {
                        setReferenceCounted(false)
                    }
                }.also { wakeLock = it }
                if (lock != null && !lock.isHeld) {
                    lock.acquire()
                }
            } catch (_: Exception) {}
        }

        @Synchronized
        private fun releaseWakeLock() {
            try {
                val lock = wakeLock
                if (lock != null && lock.isHeld) {
                    lock.release()
                }
            } catch (_: Exception) {}
        }

        fun setPlaybackActive(context: Context, active: Boolean) {
            val appContext = context.applicationContext
            if (active) {
                acquireWakeLock(appContext)
                try {
                    val intent = Intent(appContext, PlaybackForegroundService::class.java).apply {
                        action = ACTION_START
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        appContext.startForegroundService(intent)
                    } else {
                        appContext.startService(intent)
                    }
                } catch (_: Exception) {}
            } else {
                releaseWakeLock()
                try {
                    val intent = Intent(appContext, PlaybackForegroundService::class.java)
                    appContext.stopService(intent)
                } catch (_: Exception) {}
            }
        }
    }
}
