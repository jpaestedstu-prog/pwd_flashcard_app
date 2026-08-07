package com.example.pwdpwdpwd

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        /** Mirrors `TvCastKeepAlive._channel` on the Dart side. */
        private const val CAST_CHANNEL = "flashlearn/tv_cast_keepalive"
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
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
