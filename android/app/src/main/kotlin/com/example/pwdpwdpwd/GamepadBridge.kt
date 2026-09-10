package com.example.pwdpwdpwd

import android.content.Context
import android.content.pm.ApplicationInfo
import android.hardware.input.InputManager
import android.os.Handler
import android.os.Looper
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Turns a physical Bluetooth game controller into one uniform event stream for
 * Dart.
 *
 * ## Why this has to exist at all
 * Flutter forwards **key** events to Dart, but not `MotionEvent`s from
 * `SOURCE_JOYSTICK`. On the X3 (`GamePadPlus V3`, vendor 1949 product 0402)
 * the controls that matter most arrive as motion, not keys:
 *
 * ```
 * KEY  (event8): BTN_GAMEPAD BTN_EAST BTN_NORTH BTN_WEST BTN_TL BTN_TR
 *                BTN_TL2 BTN_TR2 BTN_SELECT BTN_START BTN_MODE
 *                BTN_THUMBL BTN_THUMBR
 * ABS  (event8): ABS_X ABS_Y ABS_Z ABS_RZ ABS_GAS ABS_BRAKE
 *                ABS_HAT0X ABS_HAT0Y      <- the D-pad!
 * ```
 *
 * So without this bridge the D-pad, both thumbsticks and both analogue
 * triggers would be **completely invisible to the app** — ten of the sixteen
 * controls. This class reads them natively and converts each axis into
 * discrete press/release pairs, so Dart sees one flat stream of named buttons
 * and never has to know which controls were keys and which were axes.
 *
 * ## Two HID interfaces, one device
 * The X3 also exposes a *Consumer Control* interface (`KEY_UP`/`KEY_LEFT`/...,
 * `KEY_ENTER`, `KEY_BACK`), which Android merges into the same `InputDevice`.
 * A single D-pad press can therefore be reported **twice** — once as a hat
 * axis, once as an arrow key. Both are forwarded; collapsing the duplicate is
 * `GamepadDebouncer`'s job on the Dart side, where it is unit-testable.
 */
class GamepadBridge(
    messenger: BinaryMessenger,
    private val context: Context,
) : EventChannel.StreamHandler, InputManager.InputDeviceListener {

    companion object {
        private const val EVENT_CHANNEL = "flashlearn/gamepad/events"
        private const val METHOD_CHANNEL = "flashlearn/gamepad"

        /**
         * A stick must be pushed this far to count as a direction, and must
         * fall back below [AXIS_RELEASE] before it can fire again.
         *
         * Deliberately far wider than the hardware's own flat zone (0.118 on
         * this pad). A learner with a motor impairment rests their thumb on the
         * stick; at the hardware dead zone that resting weight walks the cursor
         * across the screen on its own. The gap between the two values is
         * hysteresis — without it a stick held near the boundary chatters.
         */
        private const val AXIS_PRESS = 0.6f
        private const val AXIS_RELEASE = 0.4f

        /** Hat switches are digital (-1 / 0 / 1), so they need no hysteresis. */
        private const val HAT_PRESS = 0.5f

        /** Analogue triggers rest at 0 and are pulled toward 1. */
        private const val TRIGGER_PRESS = 0.55f
        private const val TRIGGER_RELEASE = 0.35f
    }

    /**
     * Whether to trace raw hardware events to logcat.
     *
     * Read from the application info rather than `BuildConfig`, which AGP 8 no
     * longer generates unless the feature is switched on for the whole project
     * — not a build-wide change worth making for one log line.
     */
    private val debugLogging: Boolean =
        (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private val inputManager: InputManager? =
        context.getSystemService(Context.INPUT_SERVICE) as? InputManager

    /**
     * Whether key events should be **consumed** rather than passed on to
     * Flutter's own focus traversal.
     *
     * Starts false and is switched on by Dart only once gamepad control is
     * actually enabled for the signed-in profile. That ordering matters: if the
     * Dart side never initialises (a build with the feature off, an early
     * crash), the controller keeps behaving like a stock Android game
     * controller instead of going dead.
     */
    private var captureEnabled = false

    /**
     * Last direction reported per (device, axis): -1, 0 or 1. This is what
     * turns a continuous axis into edges — a press when it leaves 0, a release
     * when it returns.
     */
    private val axisState = HashMap<String, Int>()

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL).apply {
        setMethodCallHandler { call, result ->
            when (call.method) {
                "setCaptureEnabled" -> {
                    captureEnabled = call.argument<Boolean>("enabled") ?: false
                    if (!captureEnabled) axisState.clear()
                    result.success(true)
                }
                "devices" -> result.success(connectedGamepads())
                else -> result.notImplemented()
            }
        }
    }

    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL).apply {
        setStreamHandler(this@GamepadBridge)
    }

    // -- EventChannel.StreamHandler ------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        inputManager?.registerInputDeviceListener(this, handler)
        // Report what is already paired, so a controller connected *before* the
        // app launched is not invisible until the learner re-pairs it.
        connectedGamepads().forEach { device ->
            emitConnection(device["id"] as Int, device["name"] as String, true)
        }
    }

    override fun onCancel(arguments: Any?) {
        inputManager?.unregisterInputDeviceListener(this)
        sink = null
        axisState.clear()
    }

    fun dispose() {
        inputManager?.unregisterInputDeviceListener(this)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        sink = null
    }

    // -- InputManager.InputDeviceListener ------------------------------------

    override fun onInputDeviceAdded(deviceId: Int) {
        val device = InputDevice.getDevice(deviceId) ?: return
        if (!isGamepad(device)) return
        emitConnection(deviceId, device.name ?: "Gamepad", true)
    }

    override fun onInputDeviceRemoved(deviceId: Int) {
        // The device is already gone, so its sources can no longer be checked;
        // Dart tracks which ids it was told about and ignores the rest.
        clearAxesFor(deviceId)
        emitConnection(deviceId, "", false)
    }

    override fun onInputDeviceChanged(deviceId: Int) {
        // A controller waking from sleep re-reports its capabilities. Any axis
        // state from before the nap is meaningless now.
        clearAxesFor(deviceId)
    }

    // -- Event entry points, called from MainActivity -------------------------

    /**
     * @return true when the event was handled and must not reach Flutter.
     */
    fun handleKeyEvent(event: KeyEvent): Boolean {
        if (!captureEnabled || sink == null) return false

        // A real, resolvable controller is the everyday path. The source-only
        // fallback covers the case where Android cannot resolve the device —
        // which happens in the moments around a Bluetooth disconnect, and would
        // otherwise drop presses the learner did make.
        val realDevice = isGamepad(event.device)
        if (!realDevice && !hasGamepadSource(event.source)) return false

        // BACK and ESCAPE are the one pair that must come from a *resolved*
        // controller. The system back gesture and the tablet's own keys also
        // produce KEYCODE_BACK, and swallowing those would trap the learner in
        // whatever screen they are on with no way out but the controller.
        val keyCode = event.keyCode
        if ((keyCode == KeyEvent.KEYCODE_BACK ||
                keyCode == KeyEvent.KEYCODE_ESCAPE) && !realDevice
        ) {
            return false
        }

        val button = buttonForKeyCode(keyCode) ?: return false

        // Raw hardware trace. The Dart side only ever sees what survives the
        // filtering below, so this is the only place that can answer "what did
        // the pad actually send?" — which is exactly the question when a held
        // button behaves oddly, because holding is the one gesture that cannot
        // be injected by tooling and has to be tested by hand.
        // `adb logcat -s GamepadRaw`
        if (debugLogging) {
            android.util.Log.d(
                "GamepadRaw",
                "key=$button action=${event.action} repeat=${event.repeatCount} " +
                    "dev=${event.deviceId} src=0x${Integer.toHexString(event.source)}",
            )
        }

        when (event.action) {
            KeyEvent.ACTION_DOWN -> {
                // Android repeats a held key ~20x/second. One press should be
                // one move, so repeats are swallowed here rather than
                // travelling to Dart just to be filtered again.
                if (event.repeatCount > 0) return true
                emitButton(button, true, event.deviceId)
            }
            KeyEvent.ACTION_UP -> emitButton(button, false, event.deviceId)
            else -> return false
        }
        // Consumed: Flutter's own focus traversal must not also react, or every
        // press would move twice.
        return true
    }

    /**
     * @return true when the motion was a joystick axis this bridge owns.
     */
    fun handleMotionEvent(event: MotionEvent): Boolean {
        if (!captureEnabled || sink == null) return false
        if (event.action != MotionEvent.ACTION_MOVE) return false
        // Joystick-class motion comes only from controllers — touch, stylus and
        // mouse all carry different source classes — so this is the whole gate.
        // Checked on the *event* rather than a resolved `InputDevice`, which is
        // momentarily null around a Bluetooth disconnect and would otherwise
        // drop the stick movements a learner is making right then.
        if ((event.source and InputDevice.SOURCE_CLASS_JOYSTICK) !=
            InputDevice.SOURCE_CLASS_JOYSTICK
        ) {
            return false
        }

        if (debugLogging) {
            android.util.Log.d(
                "GamepadRaw",
                "motion dev=${event.deviceId} src=0x${Integer.toHexString(event.source)} " +
                    "x=${event.getAxisValue(MotionEvent.AXIS_X)} " +
                    "y=${event.getAxisValue(MotionEvent.AXIS_Y)} " +
                    "z=${event.getAxisValue(MotionEvent.AXIS_Z)} " +
                    "rz=${event.getAxisValue(MotionEvent.AXIS_RZ)} " +
                    "hx=${event.getAxisValue(MotionEvent.AXIS_HAT_X)} " +
                    "hy=${event.getAxisValue(MotionEvent.AXIS_HAT_Y)}",
            )
        }

        // A joystick MotionEvent can batch several samples. Replaying the
        // history first means a quick flick-and-release inside one batch is
        // still seen as a press, instead of being averaged away to nothing.
        val deviceId = event.deviceId
        for (h in 0 until event.historySize) {
            processAxes(event, deviceId, h)
        }
        processAxes(event, deviceId, -1)
        return true
    }

    private fun processAxes(event: MotionEvent, deviceId: Int, pos: Int) {
        fun axis(a: Int): Float =
            if (pos < 0) {
                event.getAxisValue(a)
            } else {
                event.getHistoricalAxisValue(a, pos)
            }

        // D-pad. The X3 reports it here rather than as key events.
        bipolar(
            deviceId, "hatX", axis(MotionEvent.AXIS_HAT_X),
            HAT_PRESS, HAT_PRESS, "dpadLeft", "dpadRight",
        )
        bipolar(
            deviceId, "hatY", axis(MotionEvent.AXIS_HAT_Y),
            HAT_PRESS, HAT_PRESS, "dpadUp", "dpadDown",
        )

        // Left thumbstick.
        bipolar(
            deviceId, "lx", axis(MotionEvent.AXIS_X),
            AXIS_PRESS, AXIS_RELEASE, "leftStickLeft", "leftStickRight",
        )
        bipolar(
            deviceId, "ly", axis(MotionEvent.AXIS_Y),
            AXIS_PRESS, AXIS_RELEASE, "leftStickUp", "leftStickDown",
        )

        // Right thumbstick — Z / RZ on this pad, the usual Android convention.
        bipolar(
            deviceId, "rx", axis(MotionEvent.AXIS_Z),
            AXIS_PRESS, AXIS_RELEASE, "rightStickLeft", "rightStickRight",
        )
        bipolar(
            deviceId, "ry", axis(MotionEvent.AXIS_RZ),
            AXIS_PRESS, AXIS_RELEASE, "rightStickUp", "rightStickDown",
        )

        // Analogue triggers. This pad declares LTRIGGER *and* BRAKE (and
        // RTRIGGER *and* GAS) for the same physical trigger — a documented
        // Android quirk — so take whichever reads higher and emit once.
        unipolar(
            deviceId, "l2",
            maxOf(axis(MotionEvent.AXIS_LTRIGGER), axis(MotionEvent.AXIS_BRAKE)),
            "l2",
        )
        unipolar(
            deviceId, "r2",
            maxOf(axis(MotionEvent.AXIS_RTRIGGER), axis(MotionEvent.AXIS_GAS)),
            "r2",
        )
    }

    /**
     * An axis that swings both ways (a stick or a hat): negative fires
     * [negative], positive fires [positive], and returning to centre releases
     * whichever was held.
     */
    private fun bipolar(
        deviceId: Int,
        key: String,
        value: Float,
        press: Float,
        release: Float,
        negative: String,
        positive: String,
    ) {
        val stateKey = "$deviceId/$key"
        val previous = axisState[stateKey] ?: 0
        val next = when {
            value <= -press -> -1
            value >= press -> 1
            // Hysteresis: only fall back to centre once well inside the dead
            // zone, so a stick resting on the threshold does not chatter.
            kotlin.math.abs(value) < release -> 0
            else -> previous
        }
        if (next == previous) return
        axisState[stateKey] = next
        if (debugLogging) {
            android.util.Log.d(
                "GamepadRaw",
                "axis=$key value=$value $previous -> $next",
            )
        }
        // A direct flip (left straight to right, which a fast wrist does)
        // releases the old direction before pressing the new one, so Dart's
        // held-button bookkeeping stays balanced.
        if (previous != 0) {
            emitButton(if (previous < 0) negative else positive, false, deviceId)
        }
        if (next != 0) {
            emitButton(if (next < 0) negative else positive, true, deviceId)
        }
    }

    /** A trigger: rests at 0, pulled toward 1. */
    private fun unipolar(
        deviceId: Int,
        key: String,
        value: Float,
        button: String,
    ) {
        val stateKey = "$deviceId/$key"
        val previous = axisState[stateKey] ?: 0
        val next = when {
            value >= TRIGGER_PRESS -> 1
            value < TRIGGER_RELEASE -> 0
            else -> previous
        }
        if (next == previous) return
        axisState[stateKey] = next
        if (debugLogging) {
            android.util.Log.d(
                "GamepadRaw",
                "axis=$key value=$value -> $button ${if (next == 1) "down" else "up"}",
            )
        }
        emitButton(button, next == 1, deviceId)
    }

    private fun clearAxesFor(deviceId: Int) {
        axisState.keys.filter { it.startsWith("$deviceId/") }
            .toList()
            .forEach { axisState.remove(it) }
    }

    // -- Emission ------------------------------------------------------------

    private fun emitButton(button: String, pressed: Boolean, deviceId: Int) {
        post(
            mapOf(
                "type" to "button",
                "button" to button,
                "pressed" to pressed,
                "deviceId" to deviceId,
            )
        )
    }

    private fun emitConnection(deviceId: Int, name: String, connected: Boolean) {
        post(
            mapOf(
                "type" to "connection",
                "deviceId" to deviceId,
                "name" to name,
                "connected" to connected,
            )
        )
    }

    private fun post(payload: Map<String, Any?>) {
        // Input callbacks already run on the main thread, but InputManager
        // callbacks are only guaranteed to run on the handler's thread — and an
        // EventSink must never be touched from anywhere else.
        if (Looper.myLooper() == Looper.getMainLooper()) {
            sink?.success(payload)
        } else {
            handler.post { sink?.success(payload) }
        }
    }

    // -- Device identification -----------------------------------------------

    private fun connectedGamepads(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        for (id in InputDevice.getDeviceIds()) {
            val device = InputDevice.getDevice(id) ?: continue
            if (!isGamepad(device)) continue
            out.add(
                mapOf(
                    "id" to id,
                    "name" to (device.name ?: "Gamepad"),
                    "descriptor" to (device.descriptor ?: ""),
                )
            )
        }
        return out
    }

    /**
     * A real controller, as opposed to the touchscreen or the on-screen
     * keyboard.
     *
     * The `DPAD`-only branch requires [InputDevice.isExternal] on purpose: the
     * built-in `gpio-keys` device (volume rocker, power) also carries a DPAD
     * source, and swallowing those would break the tablet's own hardware keys.
     */
    /**
     * Whether a source bitmask carries controller bits.
     *
     * Deliberately does **not** accept `SOURCE_DPAD` on its own: the tablet's
     * built-in `gpio-keys` device (volume rocker, power) reports a DPAD source
     * too, and consuming those would break the hardware keys for everyone.
     */
    private fun hasGamepadSource(sources: Int): Boolean {
        val gamepad =
            (sources and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
        val joystick =
            (sources and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
        return gamepad || joystick
    }

    private fun isGamepad(device: InputDevice?): Boolean {
        if (device == null) return false
        if (device.isVirtual) return false
        val s = device.sources
        val gamepad =
            (s and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
        val joystick =
            (s and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
        val dpad = (s and InputDevice.SOURCE_DPAD) == InputDevice.SOURCE_DPAD
        return gamepad || joystick || (dpad && device.isExternal)
    }

    private fun buttonForKeyCode(keyCode: Int): String? = when (keyCode) {
        // D-pad, when the pad sends it as keys rather than a hat.
        KeyEvent.KEYCODE_DPAD_LEFT -> "dpadLeft"
        KeyEvent.KEYCODE_DPAD_UP -> "dpadUp"
        KeyEvent.KEYCODE_DPAD_RIGHT -> "dpadRight"
        KeyEvent.KEYCODE_DPAD_DOWN -> "dpadDown"

        // Face buttons.
        KeyEvent.KEYCODE_BUTTON_A -> "a"
        KeyEvent.KEYCODE_BUTTON_B -> "b"
        KeyEvent.KEYCODE_BUTTON_X -> "x"
        KeyEvent.KEYCODE_BUTTON_Y -> "y"

        // Shoulders. L2/R2 also arrive as axes on this pad; the Dart debouncer
        // collapses whichever pair of reports lands first.
        KeyEvent.KEYCODE_BUTTON_L1 -> "l1"
        KeyEvent.KEYCODE_BUTTON_R1 -> "r1"
        KeyEvent.KEYCODE_BUTTON_L2 -> "l2"
        KeyEvent.KEYCODE_BUTTON_R2 -> "r2"

        KeyEvent.KEYCODE_BUTTON_SELECT -> "select"
        KeyEvent.KEYCODE_BUTTON_START -> "start"
        KeyEvent.KEYCODE_BUTTON_THUMBL -> "leftStickClick"
        KeyEvent.KEYCODE_BUTTON_THUMBR -> "rightStickClick"
        KeyEvent.KEYCODE_BUTTON_MODE -> "mode"

        // The Consumer Control interface's equivalents. Mapped to the same
        // logical roles so the pad works in either of its HID modes.
        KeyEvent.KEYCODE_ENTER,
        KeyEvent.KEYCODE_NUMPAD_ENTER,
        KeyEvent.KEYCODE_DPAD_CENTER,
        -> "r1"

        KeyEvent.KEYCODE_BACK,
        KeyEvent.KEYCODE_ESCAPE,
        -> "l1"

        else -> null
    }
}
