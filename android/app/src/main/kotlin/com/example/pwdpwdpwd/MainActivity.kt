package com.example.pwdpwdpwd

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
