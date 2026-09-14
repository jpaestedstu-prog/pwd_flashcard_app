package com.example.pwdpwdpwd

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Android's own scheduler for "My Day" reminders and routine locks.
 *
 * Replaces flutter_local_notifications for routine reminders on Android,
 * for three reasons found on the tablet:
 *
 *  * **Skipping a day.** The plugin rewrites the first date of any repeating
 *    schedule to "the next matching time from now", so a reminder cannot be
 *    started tomorrow. Here every alarm is a single exact alarm that re-arms
 *    itself when it fires, and at that moment it asks "is this step already
 *    done or excused today?" — so a skipped day costs nothing, and every day
 *    after it is untouched without the app ever being opened.
 *  * **An awake tablet.** Android turns a full-screen intent into a banner
 *    while the screen is in use. With "Display over other apps" granted, a
 *    locking step shows a brief overlay and brings FlashLearn to the front —
 *    the one exemption Android 15+ still allows (the app must have a visible
 *    overlay window when it starts the activity).
 *  * **Surviving the clock.** Alarms are re-armed after a reboot, an app
 *    update, or a change of time or time zone, and a delivery that arrives
 *    long after its time (the clock jumped forward) is skipped, not shown.
 *
 * Dart owns the plan (which steps, what text); this side owns when.
 */
object RoutineAlarms {
    private const val TAG = "RoutineAlarms"
    private const val PREFS = "flashlearn_routine_alarms"

    const val ACTION_FIRE = "com.example.pwdpwdpwd.ROUTINE_ALARM"
    const val ACTION_TAP = "com.example.pwdpwdpwd.ROUTINE_TAP"
    const val ACTION_LOCK = "com.example.pwdpwdpwd.ROUTINE_LOCK"
    const val EXTRA_ID = "routine_alarm_id"
    const val EXTRA_PAYLOAD = "routine_payload"
    const val EXTRA_LOCK = "routine_lock"
    const val EXTRA_PROFILE = "routine_profile"

    /** Mirrors `RoutineReminderScheduler`'s channel ids, so settings persist. */
    private const val CHANNEL = "routine_reminder"
    private const val CHANNEL_NAME = "Routine Reminders"
    private const val SILENT_CHANNEL = "routine_reminder_silent"
    private const val SILENT_CHANNEL_NAME = "Routine Reminders (vibrate only)"
    private const val CHANNEL_DESC =
        "Reminders for the steps of a daily routine set by a parent or teacher."
    const val HELP_CHANNEL = "routine_help"
    private const val HELP_CHANNEL_NAME = "Routine Help Alerts"

    /** Later than this after its time, a delivery is a clock jump, not a reminder. */
    private const val STALE_MS = 10 * 60 * 1000L

    /** Keeps a lock launch's PendingIntent apart from the tap's. */
    private const val LOCK_REQUEST_OFFSET = 1 shl 24

    data class Spec(
        val id: Int,
        val routineId: String,
        val stepId: String,
        val title: String,
        val body: String,
        val hour: Int,
        val minute: Int,
        /** ISO weekday, 1 = Monday … 7 = Sunday; 0 = every day. */
        val weekday: Int,
        val locks: Boolean,
    )

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ── plan ────────────────────────────────────────────────────────────────

    /** Replaces the whole schedule with [planJson] for [profileId]. */
    fun apply(ctx: Context, planJson: String, silent: Boolean, profileId: String) {
        cancelAll(ctx)
        prefs(ctx).edit()
            .putString("plan", planJson)
            .putBoolean("silent", silent)
            .putString("profile", profileId)
            .apply()
        val now = System.currentTimeMillis()
        for (spec in load(ctx)) arm(ctx, spec, now)
        Log.i(TAG, "scheduled ${load(ctx).size} routine alarms for $profileId")
    }

    fun cancelAll(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        val nm = ctx.getSystemService(NotificationManager::class.java)
        val edit = prefs(ctx).edit()
        for (spec in load(ctx)) {
            am.cancel(firePending(ctx, spec.id))
            nm.cancel(spec.id)
            edit.remove("due_${spec.id}")
        }
        edit.remove("plan").apply()
    }

    /** Re-arms every alarm from the stored plan — boot, update, clock change. */
    fun rearmAll(ctx: Context) {
        val now = System.currentTimeMillis()
        val specs = load(ctx)
        for (spec in specs) arm(ctx, spec, now)
        Log.i(TAG, "re-armed ${specs.size} routine alarms")
    }

    /**
     * Today's settled steps (done, excused or approved). Their alarms still
     * fire, re-arm, and then stay quiet; any reminder already in the shade
     * for them is cleared.
     */
    fun setSettled(ctx: Context, day: String, stepIds: List<String>) {
        prefs(ctx).edit()
            .putString("settled_day", day)
            .putString("settled_ids", JSONArray(stepIds).toString())
            .apply()
        val nm = ctx.getSystemService(NotificationManager::class.java)
        for (spec in load(ctx)) if (stepIds.contains(spec.stepId)) nm.cancel(spec.id)
    }

    fun load(ctx: Context): List<Spec> {
        val raw = prefs(ctx).getString("plan", null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                Spec(
                    id = o.getInt("id"),
                    routineId = o.getString("routineId"),
                    stepId = o.getString("stepId"),
                    title = o.getString("title"),
                    body = o.getString("body"),
                    hour = o.getInt("hour"),
                    minute = o.getInt("minute"),
                    weekday = o.optInt("weekday", 0),
                    locks = o.optBoolean("locks", false),
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "unreadable plan: $e")
            emptyList()
        }
    }

    fun find(ctx: Context, id: Int): Spec? = load(ctx).firstOrNull { it.id == id }

    // ── time ────────────────────────────────────────────────────────────────

    /** ISO weekday of [cal]: Monday = 1 … Sunday = 7. */
    fun isoWeekday(cal: Calendar): Int = ((cal.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1

    /** The first local occurrence of [spec] strictly after [afterMillis]. */
    fun nextFire(spec: Spec, afterMillis: Long): Long {
        val cal = Calendar.getInstance().apply {
            timeInMillis = afterMillis
            set(Calendar.HOUR_OF_DAY, spec.hour)
            set(Calendar.MINUTE, spec.minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        var guard = 0
        while (cal.timeInMillis <= afterMillis ||
            (spec.weekday != 0 && isoWeekday(cal) != spec.weekday)
        ) {
            cal.add(Calendar.DAY_OF_MONTH, 1)
            // Re-set the wall time: a daylight-saving day must not slide it.
            cal.set(Calendar.HOUR_OF_DAY, spec.hour)
            cal.set(Calendar.MINUTE, spec.minute)
            if (++guard > 8) break
        }
        return cal.timeInMillis
    }

    fun dayStamp(millis: Long): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(millis))

    fun isSettledToday(ctx: Context, stepId: String, now: Long): Boolean {
        val p = prefs(ctx)
        if (p.getString("settled_day", null) != dayStamp(now)) return false
        return try {
            val arr = JSONArray(p.getString("settled_ids", "[]"))
            (0 until arr.length()).any { arr.getString(it) == stepId }
        } catch (e: Exception) {
            false
        }
    }

    // ── alarms ──────────────────────────────────────────────────────────────

    private fun firePending(ctx: Context, id: Int): PendingIntent =
        PendingIntent.getBroadcast(
            ctx,
            id,
            Intent(ctx, RoutineAlarmReceiver::class.java)
                .setAction(ACTION_FIRE)
                .putExtra(EXTRA_ID, id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun arm(ctx: Context, spec: Spec, afterMillis: Long) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        val at = nextFire(spec, afterMillis)
        val pending = firePending(ctx, spec.id)
        val exact = android.os.Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        try {
            if (exact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            }
            prefs(ctx).edit().putLong("due_${spec.id}", at).apply()
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            prefs(ctx).edit().putLong("due_${spec.id}", at).apply()
        }
    }

    fun dueOf(ctx: Context, id: Int): Long = prefs(ctx).getLong("due_$id", 0L)

    /** Called by the receiver when [spec]'s alarm goes off. */
    fun onFire(ctx: Context, spec: Spec, receiver: BroadcastReceiver.PendingResult?) {
        val now = System.currentTimeMillis()
        val due = dueOf(ctx, spec.id)
        // Tomorrow's (or next week's) first, whatever happens below.
        arm(ctx, spec, maxOf(now, due) + 60_000L)

        val stale = due != 0L && now - due > STALE_MS
        val settled = isSettledToday(ctx, spec.stepId, now)
        Log.i(TAG, "fire ${spec.stepId} stale=$stale settled=$settled locks=${spec.locks}")
        if (stale || settled) {
            receiver?.finish()
            return
        }
        post(ctx, spec)
        if (spec.locks) {
            takeOverIfAwake(ctx, spec, receiver)
        } else {
            receiver?.finish()
        }
    }

    // ── notification ────────────────────────────────────────────────────────

    fun ensureChannels(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = CHANNEL_DESC },
            )
        }
        if (nm.getNotificationChannel(SILENT_CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    SILENT_CHANNEL,
                    SILENT_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = CHANNEL_DESC
                    setSound(null, null)
                    enableVibration(true)
                },
            )
        }
        if (nm.getNotificationChannel(HELP_CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(
                    HELP_CHANNEL,
                    HELP_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "When a learner has waited too long on a routine step."
                },
            )
        }
    }

    fun launchIntent(ctx: Context, spec: Spec, lock: Boolean): Intent =
        Intent(ctx, MainActivity::class.java).apply {
            action = if (lock) ACTION_LOCK else ACTION_TAP
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_PAYLOAD, "${spec.routineId}|${spec.stepId}")
            putExtra(EXTRA_LOCK, lock)
            putExtra(EXTRA_PROFILE, prefs(ctx).getString("profile", "") ?: "")
        }

    private fun post(ctx: Context, spec: Spec) {
        ensureChannels(ctx)
        val silent = prefs(ctx).getBoolean("silent", false)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val tap = PendingIntent.getActivity(ctx, spec.id, launchIntent(ctx, spec, false), flags)
        val builder = Notification.Builder(ctx, if (silent) SILENT_CHANNEL else CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(spec.title)
            .setContentText(spec.body)
            .setStyle(Notification.BigTextStyle().bigText(spec.body))
            .setAutoCancel(true)
            .setContentIntent(tap)
        if (spec.locks) {
            val lock = PendingIntent.getActivity(
                ctx,
                spec.id + LOCK_REQUEST_OFFSET,
                launchIntent(ctx, spec, true),
                flags,
            )
            builder.setCategory(Notification.CATEGORY_ALARM).setFullScreenIntent(lock, true)
        }
        try {
            ctx.getSystemService(NotificationManager::class.java).notify(spec.id, builder.build())
        } catch (e: SecurityException) {
            Log.w(TAG, "notifications not allowed: $e")
        }
    }

    // ── awake tablet ────────────────────────────────────────────────────────

    fun canDrawOverlays(ctx: Context): Boolean = Settings.canDrawOverlays(ctx)

    /**
     * Brings the lock to the front of an awake tablet.
     *
     * Only when the screen is on (a sleeping one is the full-screen intent's
     * job), FlashLearn is not already in front (its own lock appears there by
     * itself), and the educator has granted "Display over other apps".
     */
    private fun takeOverIfAwake(
        ctx: Context,
        spec: Spec,
        receiver: BroadcastReceiver.PendingResult?,
    ) {
        val app = ctx.applicationContext
        val interactive = app.getSystemService(PowerManager::class.java).isInteractive
        if (!interactive || MainActivity.isInForeground || !canDrawOverlays(app)) {
            Log.i(TAG, "no takeover: interactive=$interactive foreground=${MainActivity.isInForeground} overlay=${canDrawOverlays(app)}")
            receiver?.finish()
            return
        }
        val wm = app.getSystemService(WindowManager::class.java)
        val banner = TextView(app).apply {
            text = spec.title
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#E61B5E20"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            gravity = Gravity.CENTER
            val pad = (16 * resources.displayMetrics.density).toInt()
            setPadding(pad, pad, pad, pad)
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP }
        try {
            wm.addView(banner, params)
        } catch (e: Exception) {
            Log.w(TAG, "overlay refused: $e")
            receiver?.finish()
            return
        }
        val main = Handler(Looper.getMainLooper())
        // Start the activity once the overlay is actually on screen — Android
        // 15+ checks for a *visible* overlay window at that moment.
        main.postDelayed({
            try {
                app.startActivity(launchIntent(app, spec, true))
                Log.i(TAG, "lock brought to front for ${spec.stepId}")
            } catch (e: Exception) {
                Log.w(TAG, "could not start lock: $e")
            }
            main.postDelayed({
                try {
                    wm.removeView(banner)
                } catch (_: Exception) {
                }
                receiver?.finish()
            }, 2500L)
        }, 400L)
    }
}

/** Posts a routine reminder (or skips a settled one) and re-arms it. */
class RoutineAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != RoutineAlarms.ACTION_FIRE) return
        val id = intent.getIntExtra(RoutineAlarms.EXTRA_ID, -1)
        val spec = RoutineAlarms.find(context, id) ?: return
        RoutineAlarms.onFire(context, spec, goAsync())
    }
}

/** Re-arms routine alarms after a reboot, an update or a clock change. */
class RoutineAlarmRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        RoutineAlarms.rearmAll(context)
    }
}
