package com.example.pwdpwdpwd

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        /** Mirrors `TvCastKeepAlive._channel` on the Dart side. */
        private const val CAST_CHANNEL = "flashlearn/tv_cast_keepalive"

        /** Mirrors `DeviceTimezone._channel` on the Dart side. */
        private const val TIMEZONE_CHANNEL = "flashlearn/device_timezone"

        /** Mirrors `RoutineNativeAlarms._channel` on the Dart side. */
        private const val ROUTINE_CHANNEL = "flashlearn/routine_alarms"

        /**
         * True while FlashLearn is the app in front. [RoutineAlarms] reads it
         * so it never throws an overlay over the app's own lock, which already
         * appears by itself when the app is open.
         */
        @Volatile
        var isInForeground = false
    }

    /**
     * Bluetooth game-controller support. Null until the engine is configured,
     * and inert until Dart enables capture — see [GamepadBridge].
     */
    private var gamepadBridge: GamepadBridge? = null

    /** The routine channel, once the engine exists. */
    private var routineChannel: MethodChannel? = null

    /**
     * A routine notification tap or lock launch that arrived before Dart was
     * listening (a cold start). Dart collects it with `takeLaunch`.
     */
    private var pendingRoutineLaunch: Map<String, Any>? = null

    /**
     * Bridges the TV Cast keep-alive service to Dart.
     *
     * Dart owns the cast lifecycle (the HTTP server is a Riverpod provider), so
     * it is the only thing that knows when a cast starts, changes, or ends —
     * hence a channel rather than the service watching anything itself. Every
     * call is best-effort: if starting the service fails (OEM restrictions, a
     * denied notification permission), the cast still works exactly as it did
     * before, just without the process guarantee.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        gamepadBridge = GamepadBridge(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
        )

        // The device's IANA time zone ("Asia/Manila"). Dart's `DateTime` knows
        // only the current offset, and the `timezone` package defaults its
        // local zone to UTC — which scheduled every reminder, check-in and
        // alarm eight hours late on a Philippine device.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TIMEZONE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getLocalTimezone") {
                    result.success(java.util.TimeZone.getDefault().id)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAST_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start", "update" -> {
                        val intent = Intent(this, CastForegroundService::class.java).apply {
                            action = if (call.method == "start") {
                                CastForegroundService.ACTION_START
                            } else {
                                CastForegroundService.ACTION_UPDATE
                            }
                            putExtra(
                                CastForegroundService.EXTRA_CODE,
                                call.argument<String>("code") ?: "",
                            )
                            putExtra(
                                CastForegroundService.EXTRA_DETAIL,
                                call.argument<String>("detail") ?: "",
                            )
                        }
                        try {
                            startForegroundService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            // e.g. an OEM background-start restriction. The cast
                            // itself is unaffected, so this is not an error the
                            // teacher needs to see.
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        val intent = Intent(this, CastForegroundService::class.java).apply {
                            action = CastForegroundService.ACTION_STOP
                        }
                        try {
                            startService(intent)
                        } catch (e: Exception) {
                            // Already gone (process was reclaimed) — nothing to do.
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // "My Day" reminders and locks — see [RoutineAlarms].
        routineChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ROUTINE_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "apply" -> {
                        RoutineAlarms.apply(
                            applicationContext,
                            call.argument<String>("plan") ?: "[]",
                            call.argument<Boolean>("silent") ?: false,
                            call.argument<String>("profile") ?: "",
                        )
                        result.success(true)
                    }
                    "cancelAll" -> {
                        RoutineAlarms.cancelAll(applicationContext)
                        result.success(true)
                    }
                    "setSettled" -> {
                        RoutineAlarms.setSettled(
                            applicationContext,
                            call.argument<String>("day") ?: "",
                            call.argument<List<String>>("ids") ?: emptyList(),
                        )
                        result.success(true)
                    }
                    "canDrawOverlays" ->
                        result.success(RoutineAlarms.canDrawOverlays(applicationContext))
                    "openOverlaySettings" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "setShowWhenLocked" -> {
                        applyShowWhenLocked(call.argument<Boolean>("on") ?: false)
                        result.success(true)
                    }
                    "takeLaunch" -> {
                        result.success(pendingRoutineLaunch)
                        pendingRoutineLaunch = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /**
     * Picks up a routine notification tap or lock launch. On a cold start Dart
     * is not listening yet, so it is kept for `takeLaunch`; while running it is
     * delivered straight away.
     */
    private fun captureRoutineLaunch(intent: Intent?, running: Boolean) {
        val payload = intent?.getStringExtra(RoutineAlarms.EXTRA_PAYLOAD) ?: return
        val lock = intent.getBooleanExtra(RoutineAlarms.EXTRA_LOCK, false)
        val launch = mapOf(
            "payload" to payload,
            "lock" to lock,
            "profile" to (intent.getStringExtra(RoutineAlarms.EXTRA_PROFILE) ?: ""),
        )
        // Consumed once: a rotation or a return from Settings must not replay it.
        intent.removeExtra(RoutineAlarms.EXTRA_PAYLOAD)
        // A lock opened by the alarm must be visible over the tablet's own lock
        // screen. Dart turns this off again as soon as the routine lock closes.
        if (lock) applyShowWhenLocked(true)
        val channel = routineChannel
        if (running && channel != null) {
            channel.invokeMethod("onLaunch", launch)
        } else {
            pendingRoutineLaunch = launch
        }
    }

    private fun applyShowWhenLocked(on: Boolean) {
        setShowWhenLocked(on)
        setTurnScreenOn(on)
    }

    /**
     * Gamepad key presses are offered to [GamepadBridge] before Flutter sees
     * them.
     *
     * Taking them here rather than inside Flutter is what stops a single press
     * acting twice: Flutter maps D-pad keys onto its own focus traversal, so if
     * both layers ran, one press would move the app's cursor *and* shift
     * Flutter's focus. The bridge consumes only events it recognises from a
     * real external controller and only while Dart has enabled capture — the
     * tablet's own volume and power keys, and every touch interaction, are
     * untouched.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (gamepadBridge?.handleKeyEvent(event) == true) return true
        return super.dispatchKeyEvent(event)
    }

    /**
     * The half of the controller Flutter cannot see at all: the D-pad hat, both
     * thumbsticks and the analogue triggers arrive as `SOURCE_JOYSTICK` motion,
     * which the Flutter embedding never forwards to Dart.
     */
    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (gamepadBridge?.handleMotionEvent(event) == true) return true
        return super.dispatchGenericMotionEvent(event)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        gamepadBridge?.dispose()
        gamepadBridge = null
        routineChannel?.setMethodCallHandler(null)
        routineChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureRoutineLaunch(intent, running = true)
    }

    override fun onResume() {
        super.onResume()
        isInForeground = true
    }

    override fun onPause() {
        isInForeground = false
        super.onPause()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureRoutineLaunch(intent, running = false)
        // The routine and "needs help" channels must exist before the first
        // push arrives, which can be long before any routine alarm fires.
        RoutineAlarms.ensureChannels(applicationContext)
        // Keep the display awake while the app is in the foreground. Learners
        // using Gaze Control / voice commands never touch the screen, so the
        // normal touch-based screen timeout would blank the display mid-use —
        // and aggressive OEM power managers (e.g. Honor) then freeze the whole
        // process, killing the camera and microphone loops. Foreground-only:
        // the flag has no effect once the app is backgrounded.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        // Request the highest available display refresh rate (120 Hz on
        // Honor Pad X8a NDL-W09). On Android 14 the preferred mode is
        // respected by the compositor when the window is in the foreground.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            }
            display?.let { d ->
                val modes = d.supportedModes
                val best = modes.maxByOrNull { it.refreshRate }
                best?.let { mode ->
                    val params: WindowManager.LayoutParams = window.attributes
                    params.preferredDisplayModeId = mode.modeId
                    window.attributes = params
                }
            }
        }
    }
}
