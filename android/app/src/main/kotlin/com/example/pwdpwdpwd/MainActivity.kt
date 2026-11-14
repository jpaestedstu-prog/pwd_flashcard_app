package com.example.pwdpwdpwd

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioManager
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.util.Log
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        /** Mirrors `TvCastKeepAlive._channel` on the Dart side. */
        private const val CAST_CHANNEL = "flashlearn/tv_cast_keepalive"

        /** Mirrors `TvCastSpeech._channel` on the Dart side. */
        private const val CAST_SPEECH_CHANNEL = "flashlearn/cast_speech"

        /** Mirrors `DeviceTimezone._channel` on the Dart side. */
        private const val TIMEZONE_CHANNEL = "flashlearn/device_timezone"

        /**
         * While a learner drives the app with a switch, the window stays out of
         * the system keyboard's reach. Android hands hardware keys to the
         * keyboard BEFORE the app whenever a text field has an input
         * connection, and the keyboard swallows Space/Enter — the keys switch
         * interfaces send — to type into the field. With the flag the keys
         * reach the app (and no system keyboard rises over the gaze one).
         */
        private const val IME_CHANNEL = "flashlearn/ime"

        /** Mirrors `RoutineNativeAlarms._channel` on the Dart side. */
        private const val ROUTINE_CHANNEL = "flashlearn/routine_alarms"

        /** Mirrors `DeviceSound._channel` on the Dart side. */
        private const val AUDIO_CHANNEL = "flashlearn/audio"

        /** Mirrors `DeviceVideoSupport._channel` on the Dart side. */
        private const val MEDIA_CHANNEL = "flashlearn/media"

        /** Mirrors `ScreenAwake._channel` on the Dart side. */
        private const val SCREEN_CHANNEL = "flashlearn/screen"

        /**
         * True while FlashLearn is the app in front. [RoutineAlarms] reads it
         * so it never throws an overlay over the app's own lock, which already
         * appears by itself when the app is open.
         */
        @Volatile
        var isInForeground = false

        /**
         * How long a lock launch may take to reach the routine lock before
         * "show over the lock screen" is taken back. A cold start from a
         * sleeping tablet reached the lock in about 12 s on the emulator.
         */
        private const val LOCK_SCREEN_GRACE_MS = 45_000L
    }

    /**
     * Bluetooth game-controller support. Null until the engine is configured,
     * and inert until Dart enables capture — see [GamepadBridge].
     */
    private var gamepadBridge: GamepadBridge? = null

    /** A switch learner is active (see IME_CHANNEL). */
    private var switchKeysToApp = false

    /** The TV Cast's own speech engine, started on its first request. */
    private var castSpeech: CastSpeech? = null

    /**
     * Gives the Flutter view Android-level focus if it lost it.
     *
     * In touch mode Android treats the arrows, the D-pad, Space and Enter as
     * navigation keys: when nothing in the window holds focus, the FIRST such
     * key is spent giving focus (ViewRootImpl leaving touch mode) and never
     * reaches the app — only its release does. And since Android 9 nothing
     * holds focus when the window opens in touch mode. So after anyone had
     * touched the screen, the first press of a switch interface, a keyboard's
     * arrows, a TV remote or a controller that sends its D-pad as keys simply
     * vanished (found on the tablet: one of four D-pad presses on the profile
     * list, every time the screen had been touched first). With the view
     * focused the key goes through.
     */
    private fun focusFlutterView() {
        val root = window?.decorView ?: return
        fun find(v: android.view.View): android.view.View? {
            if (v is io.flutter.embedding.android.FlutterView) return v
            if (v is android.view.ViewGroup) {
                for (i in 0 until v.childCount) {
                    find(v.getChildAt(i))?.let { return it }
                }
            }
            return null
        }
        val view = find(root) ?: return
        if (!view.hasFocus()) view.requestFocus()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // For everyone, not only a switch learner: see [focusFlutterView].
        if (hasFocus) window?.decorView?.post { focusFlutterView() }
    }

    /** The routine channel, once the engine exists. */
    private var routineChannel: MethodChannel? = null

    /**
     * A routine notification tap or lock launch that arrived before Dart was
     * listening (a cold start). Dart collects it with `takeLaunch`.
     */
    private var pendingRoutineLaunch: Map<String, Any>? = null

    /**
     * Takes "show over the lock screen" back when a lock launch never reaches
     * the routine lock. Found on the emulator with a PIN set: the step was
     * already done, the launch ended on My Day, and FlashLearn stayed usable in
     * front of the PIN screen. Only the routine lock confirming itself on
     * screen (or closing) cancels it.
     */
    private val lockScreenWatchdog = Handler(Looper.getMainLooper())
    private val lockScreenTakeBack = Runnable {
        Log.i("RoutineAlarms", "no routine lock appeared; taking the lock screen back")
        applyShowWhenLocked(false)
    }

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
        // Whether the display stays on: while the learner steers hands-free
        // (Gaze Control's head tracking or voice commands, which make no
        // touches or key presses), else the device's own screen timeout.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "keepOn") {
                    val on = call.arguments as? Boolean ?: true
                    runOnUiThread {
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TIMEZONE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getLocalTimezone") {
                    result.success(java.util.TimeZone.getDefault().id)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IME_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBypass" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        switchKeysToApp = on
                        runOnUiThread {
                            if (on) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
                                focusFlutterView()
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)
                            }
                        }
                        result.success(true)
                    }
                    "focus" -> {
                        runOnUiThread { focusFlutterView() }
                        result.success(true)
                    }
                    else -> result.notImplemented()
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
                            putExtra(
                                CastForegroundService.EXTRA_TITLE,
                                call.argument<String>("title") ?: "",
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

        // The TV Cast's spoken words as audio files the TV plays through its
        // own speakers — see `TvCastSpeech` on the Dart side and CastSpeech.
        val speech = CastSpeech(applicationContext)
        castSpeech = speech
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAST_SPEECH_CHANNEL)
            .setMethodCallHandler { call, result -> speech.onMethodCall(call, result) }

        // The media sound the app's speech plays on, for the "your device
        // sound is off" note — see `DeviceSound` on the Dart side.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
            .setMethodCallHandler { call, result ->
                val audio = getSystemService(AudioManager::class.java)
                val stream = AudioManager.STREAM_MUSIC
                when {
                    // "No Filipino voice on this device": the speech engine's
                    // own "install voice data" screen, where a Filipino voice
                    // is added (TalkBack then has it too), or else the
                    // device's text-to-speech settings. Only on a tap.
                    call.method == "openVoiceSettings" -> {
                        val opened = listOf(
                            Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA),
                            Intent("com.android.settings.TTS_SETTINGS"),
                        ).any { intent ->
                            try {
                                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                                true
                            } catch (e: ActivityNotFoundException) {
                                false
                            } catch (e: SecurityException) {
                                false
                            }
                        }
                        Log.i("DeviceSound", "open voice settings: $opened")
                        result.success(opened)
                    }
                    // TalkBack's own words ("Button", "In list") follow
                    // TalkBack's language, not the app's. Android 13 and up
                    // has a language per app: its screen for TalkBack, or else
                    // the device's languages. Only on a tap.
                    call.method == "openTalkBackLanguage" -> {
                        // Android's page for one app's language opens and closes at
                        // once for an app that does not declare its languages, and
                        // TalkBack does not (the Honor, 4 Nov): the tablet's own
                        // languages are then the way.
                        val talkBackId = "com.google.android.marvin.talkback"
                        val talkBack = Uri.parse("package:$talkBackId")
                        val hasOwnLanguagePage = Build.VERSION.SDK_INT >= 33 && try {
                            val config = android.app.LocaleConfig(
                                createPackageContext(talkBackId, 0),
                            )
                            config.status == android.app.LocaleConfig.STATUS_SUCCESS &&
                                config.supportedLocales?.isEmpty == false
                        } catch (e: Exception) {
                            false
                        }
                        val candidates = buildList {
                            if (hasOwnLanguagePage) {
                                add(Intent("android.settings.APP_LOCALE_SETTINGS", talkBack))
                            }
                            add(Intent(Settings.ACTION_LOCALE_SETTINGS))
                        }
                        val opened = candidates.any { intent ->
                            try {
                                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                                true
                            } catch (e: ActivityNotFoundException) {
                                false
                            } catch (e: SecurityException) {
                                false
                            }
                        }
                        Log.i("DeviceSound", "open TalkBack language: $opened")
                        result.success(opened)
                    }
                    audio == null -> result.success(null)
                    call.method == "mediaVolume" -> {
                        val level = audio.getStreamVolume(stream)
                        val muted = audio.isStreamMute(stream)
                        Log.i("DeviceSound", "media volume $level, muted $muted")
                        result.success(
                            mapOf(
                                "level" to level,
                                "max" to audio.getStreamMaxVolume(stream),
                                "muted" to muted,
                            ),
                        )
                    }
                    // Only ever on the learner's tap: a third of the way up,
                    // a step at a time as the volume keys do (on the Honor
                    // tablet a direct setStreamVolume reported success and
                    // left the speaker silent), then the system's own volume
                    // panel, so the change is seen and can be set by hand.
                    call.method == "turnUp" -> try {
                        val max = audio.getStreamMaxVolume(stream)
                        val target = maxOf(1, max / 3)
                        val before = audio.getStreamVolume(stream)
                        if (audio.isStreamMute(stream)) {
                            audio.adjustStreamVolume(stream, AudioManager.ADJUST_UNMUTE, 0)
                        }
                        repeat((target - before).coerceIn(0, max)) {
                            audio.adjustStreamVolume(stream, AudioManager.ADJUST_RAISE, 0)
                        }
                        audio.adjustStreamVolume(
                            stream,
                            AudioManager.ADJUST_SAME,
                            AudioManager.FLAG_SHOW_UI,
                        )
                        val after = audio.getStreamVolume(stream)
                        Log.i("DeviceSound", "turn up: $before -> $after (target $target of $max)")
                        result.success(after > 0)
                    } catch (e: SecurityException) {
                        // Do Not Disturb may refuse a volume change.
                        result.success(false)
                    }
                    else -> result.notImplemented()
                }
            }

        // What this device can play, for the choice between an FSL sign's
        // original (1080p, 60 frames a second) and its light copy — see
        // `FslClipQuality` on the Dart side.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "videoCapabilities" -> {
                        val activity = getSystemService(ActivityManager::class.java)
                        val fullHd60 = decodesFullHd60()
                        val lowRam = activity?.isLowRamDevice ?: false
                        Log.i("DeviceVideo", "1080p60 decoder $fullHd60, low RAM $lowRam")
                        result.success(mapOf("fullHd60" to fullHd60, "lowRam" to lowRam))
                    }
                    "networkMetered" -> {
                        val connectivity = getSystemService(ConnectivityManager::class.java)
                        result.success(connectivity?.isActiveNetworkMetered)
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
                        // The routine lock is on screen (on) or has closed
                        // (off) — either way the watchdog's job is done.
                        lockScreenWatchdog.removeCallbacks(lockScreenTakeBack)
                        // True when FlashLearn went behind a locked tablet, so
                        // Dart knows not to build Home until it comes back.
                        result.success(
                            applyShowWhenLocked(call.argument<Boolean>("on") ?: false),
                        )
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
    /**
     * Whether a hardware H.264 decoder is rated for 1920x1080 at 60 frames a
     * second: by its declared performance points where it has them, else by
     * its size-and-rate limits. Budget phones whose decoders stop at 1080p30
     * froze on the original sign clips or never started them.
     */
    private fun decodesFullHd60(): Boolean = try {
        val wanted = MediaCodecInfo.VideoCapabilities.PerformancePoint(1920, 1080, 60)
        MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.any { info ->
            if (info.isEncoder || !info.isHardwareAccelerated) return@any false
            val type = info.supportedTypes.firstOrNull {
                it.equals(MediaFormat.MIMETYPE_VIDEO_AVC, ignoreCase = true)
            } ?: return@any false
            val video = info.getCapabilitiesForType(type).videoCapabilities
                ?: return@any false
            val points = video.supportedPerformancePoints
            if (!points.isNullOrEmpty()) {
                points.any { it.covers(wanted) }
            } else {
                video.areSizeAndRateSupported(1920, 1080, 60.0)
            }
        }
    } catch (e: Exception) {
        Log.w("DeviceVideo", "could not read the video decoders", e)
        false
    }

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
        // screen — but only if the routine lock actually appears. If the launch
        // ends anywhere else, the watchdog takes it back.
        if (lock) {
            applyShowWhenLocked(true)
            lockScreenWatchdog.removeCallbacks(lockScreenTakeBack)
            lockScreenWatchdog.postDelayed(lockScreenTakeBack, LOCK_SCREEN_GRACE_MS)
        }
        val channel = routineChannel
        if (running && channel != null) {
            channel.invokeMethod("onLaunch", launch)
        } else {
            pendingRoutineLaunch = launch
        }
    }

    /**
     * Shows FlashLearn over the tablet's own lock screen, or takes that back.
     *
     * Taking it back is not enough on its own: an activity that is *already*
     * in front of the lock screen stays there after the flag is cleared (found
     * on the emulator with a PIN set — a lock launch that ended on My Day left
     * the whole app usable over the PIN screen). So when the device is still
     * locked, the task also moves to the back and the lock screen covers it.
     * While the device is unlocked the flag is simply cleared; nothing moves.
     *
     * Returns whether the task moved behind the lock screen.
     */
    private fun applyShowWhenLocked(on: Boolean): Boolean {
        setShowWhenLocked(on)
        setTurnScreenOn(on)
        val locked = getSystemService(KeyguardManager::class.java)?.isKeyguardLocked ?: false
        Log.i("RoutineAlarms", "showWhenLocked=$on keyguardLocked=$locked")
        if (!on && locked) {
            moveTaskToBack(true)
            Log.i("RoutineAlarms", "moved behind the lock screen")
            return true
        }
        return false
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

    override fun onDestroy() {
        lockScreenWatchdog.removeCallbacks(lockScreenTakeBack)
        super.onDestroy()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        gamepadBridge?.dispose()
        gamepadBridge = null
        routineChannel?.setMethodCallHandler(null)
        routineChannel = null
        castSpeech?.release()
        castSpeech = null
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

    /**
     * TalkBack started every slider twice: "4 words per day, 4 words per day,
     * Daily Mission Size, slider". Right after telling TalkBack that a slider
     * has its focus, Flutter's engine sends a "selected" event as well ("SeekBars
     * only announce themselves after this event", for the TalkBack of years
     * ago), and today's TalkBack speaks for each, the second cutting the first
     * short (read in its log, 4 Nov).
     *
     * Only that echo is dropped: sent in the same breath as the focus event,
     * with no words of its own. The "selected" that says a slider's new value
     * comes later and on its own, and goes through. And only on the TalkBack
     * this was checked on: an older one may need it, and stutters no worse
     * than it did.
     */
    private fun quietSliderEcho() {
        val content = findViewById<ViewGroup>(android.R.id.content) ?: return
        val checkedTalkBack by lazy {
            try {
                val version = packageManager
                    .getPackageInfo("com.google.android.marvin.talkback", 0)
                    .versionName
                (version?.substringBefore('.')?.toIntOrNull() ?: 0) >= 17
            } catch (_: Exception) {
                false
            }
        }
        val main = Handler(Looper.getMainLooper())
        var focusJustSent = false
        content.accessibilityDelegate = object : View.AccessibilityDelegate() {
            override fun onRequestSendAccessibilityEvent(
                host: ViewGroup,
                child: View,
                event: AccessibilityEvent,
            ): Boolean {
                when (event.eventType) {
                    AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED -> {
                        focusJustSent = true
                        main.post { focusJustSent = false }
                    }
                    AccessibilityEvent.TYPE_VIEW_SELECTED ->
                        if (focusJustSent && event.text.isEmpty() && checkedTalkBack) {
                            return false
                        }
                }
                return super.onRequestSendAccessibilityEvent(host, child, event)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        quietSliderEcho()
        captureRoutineLaunch(intent, running = false)
        // The routine and "needs help" channels must exist before the first
        // push arrives, which can be long before any routine alarm fires.
        RoutineAlarms.ensureChannels(applicationContext)
        // Keep the display awake until the app knows who is using it. Learners
        // using Gaze Control / voice commands never touch the screen, so the
        // normal touch-based screen timeout would blank the display mid-use —
        // and aggressive OEM power managers (e.g. Honor) then freeze the whole
        // process, killing the camera and microphone loops. The app then lets
        // go of it for everyone else (SCREEN_CHANNEL, `ScreenAwake`): kept on
        // for every learner, a tablet left open on a desk never slept.
        // Foreground-only: the flag has no effect once the app is backgrounded.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        // Request the highest available display refresh rate (120 Hz on
        // Honor Pad X8a NDL-W09). On Android 14 the preferred mode is
        // respected by the compositor when the window is in the foreground.
        // (minSdk 29 always has display modes.) Only modes at the current
        // resolution: on a screen whose fastest mode is a lower resolution, the
        // fastest of all would have blurred the app to get there.
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }
        display?.let { d ->
            val current = d.mode
            val best = d.supportedModes
                .filter {
                    it.physicalWidth == current.physicalWidth &&
                        it.physicalHeight == current.physicalHeight
                }
                .maxByOrNull { it.refreshRate }
            best?.let { mode ->
                val params: WindowManager.LayoutParams = window.attributes
                params.preferredDisplayModeId = mode.modeId
                window.attributes = params
            }
        }
    }
}
