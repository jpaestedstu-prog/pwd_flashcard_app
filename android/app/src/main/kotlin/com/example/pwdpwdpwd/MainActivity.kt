package com.example.pwdpwdpwd

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
