package com.example.pwdpwdpwd

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
import androidx.core.app.NotificationCompat

/**
 * Keeps the process alive while TV Cast is serving.
 *
 * The cast is a plain Dart HTTP server living in a root Riverpod provider — no
 * native socket, no plugin. That works fine while the app is on screen, but a
 * lesson is exactly the situation where it won't be: the teacher locks the
 * tablet, or walks away and Android reclaims a backgrounded process, and the
 * TV silently falls back to "Oops, the teacher is connecting". A foreground
 * service is the only supported way to tell Android "this process is doing
 * something the user can see" — and the ongoing notification doubles as the
 * out-of-app reminder that a class is still watching.
 *
 * `dataSync` is the right foreground type here (we're serving bytes to another
 * device on the LAN). Note Android 15+ budgets `dataSync` at roughly 6 hours a
 * day, which is far beyond any single lesson.
 *
 * The notification is deliberately **informational** — tapping it opens the
 * app, where Stop lives behind its confirmation dialog. A "Stop" action in the
 * shade would have to signal Dart to shut the server down, and the Flutter
 * engine may be detached at that moment; a button that silently fails to stop
 * a cast is worse than no button.
 */
class CastForegroundService : Service() {

    companion object {
        const val ACTION_START = "com.example.pwdpwdpwd.cast.START"
        const val ACTION_UPDATE = "com.example.pwdpwdpwd.cast.UPDATE"
        const val ACTION_STOP = "com.example.pwdpwdpwd.cast.STOP"
        const val EXTRA_CODE = "code"
        const val EXTRA_DETAIL = "detail"

        private const val CHANNEL_ID = "tv_cast_session"
        private const val NOTIFICATION_ID = 4711
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val code = intent?.getStringExtra(EXTRA_CODE).orEmpty()
                val detail = intent?.getStringExtra(EXTRA_DETAIL).orEmpty()
                startForegroundCompat(buildNotification(code, detail))
            }
        }
        // NOT sticky: if Android does kill the process, the Dart server died
        // with it, so relaunching a bare service would show a notification for
        // a cast that no longer exists.
        return START_NOT_STICKY
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            @Suppress("DEPRECATION")
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun buildNotification(code: String, detail: String): Notification {
        ensureChannel()

        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            this,
            0,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val title = if (code.isEmpty()) {
            "Casting to TV"
        } else {
            "Casting to TV · code $code"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(detail.ifEmpty { "Tap to open the cast controls." })
            .setSmallIcon(R.drawable.ic_cast_notification)
            .setContentIntent(pending)
            .setOngoing(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            // Keep it quiet and off the lock screen: the code is a shared
            // secret for the cast, and a locked tablet on a desk shouldn't
            // display it to the room.
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "TV Cast session",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows while your lesson is being cast to a TV."
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_SECRET
        }
        manager.createNotificationChannel(channel)
    }
}
