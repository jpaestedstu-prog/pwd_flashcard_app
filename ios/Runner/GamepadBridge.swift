import Flutter
import GameController
import UIKit

/// The iPhone/iPad half of the game-controller bridge: the same two channels
/// and the same wire format as android/.../GamepadBridge.kt, so the Dart side
/// (GamepadService, GamepadDebouncer, the navigation layer) is shared as is.
///
/// Built on Apple's GameController framework, which is part of iOS: any
/// controller iOS itself supports works — Xbox, PlayStation, MFi, Switch Pro
/// and most "Xbox mode" Bluetooth pads — once it is paired in iOS Settings →
/// Bluetooth. No paid service or entitlement is involved.
///
///   * method channel `flashlearn/gamepad`: `devices` → `[{id, name,
///     descriptor}]`; `setCaptureEnabled({enabled})`.
///   * event channel `flashlearn/gamepad/events`:
///     `{type: "button", button, pressed, deviceId}` and
///     `{type: "connection", deviceId, name, connected}`.
///
/// Like Android, presses are only sent while Dart has switched gamepad
/// control on (`setCaptureEnabled`), and sticks, the D-pad and the analogue
/// triggers become discrete presses with the same thresholds: a learner with
/// a motor impairment rests a thumb on the stick, and at the hardware's own
/// dead zone that resting weight would walk the highlight across the screen.
final class GamepadBridge: NSObject, FlutterStreamHandler {
  private static let eventChannelName = "flashlearn/gamepad/events"
  private static let methodChannelName = "flashlearn/gamepad"

  /// Sticks: pushed this far to count, and back inside [axisRelease] before
  /// they can fire again (hysteresis, so a stick on the line cannot chatter).
  private static let axisPress: Float = 0.6
  private static let axisRelease: Float = 0.4
  /// The D-pad is digital; no hysteresis needed.
  private static let hatPress: Float = 0.5
  /// Analogue triggers rest at 0 and are pulled toward 1.
  private static let triggerPress: Float = 0.55
  private static let triggerRelease: Float = 0.35

  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var sink: FlutterEventSink?
  private var captureEnabled = false
  private var observers: [NSObjectProtocol] = []

  /// A small, stable number per connected controller (Dart's `deviceId`).
  private var ids: [ObjectIdentifier: Int] = [:]
  private var nextId = 1

  /// Last direction per (device, axis): -1, 0 or 1 — what turns a continuous
  /// value into a press when it leaves 0 and a release when it returns.
  private var axisState: [String: Int] = [:]

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: GamepadBridge.methodChannelName, binaryMessenger: messenger)
    eventChannel = FlutterEventChannel(
      name: GamepadBridge.eventChannelName, binaryMessenger: messenger)
    super.init()
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "setCaptureEnabled":
        let args = call.arguments as? [String: Any]
        self.captureEnabled = (args?["enabled"] as? Bool) ?? false
        if !self.captureEnabled { self.axisState.removeAll() }
        result(true)
      case "devices":
        result(self.connectedGamepads())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    eventChannel.setStreamHandler(self)
  }

  // MARK: - FlutterStreamHandler

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) {
        [weak self] note in
        if let controller = note.object as? GCController { self?.attach(controller) }
      })
    observers.append(
      center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) {
        [weak self] note in
        if let controller = note.object as? GCController { self?.detach(controller) }
      })
    // A controller paired before the app opened must not stay invisible
    // until it reconnects.
    for controller in GCController.controllers() { attach(controller) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    observers.removeAll()
    for controller in GCController.controllers() {
      controller.extendedGamepad?.valueChangedHandler = nil
      unbind(controller)
    }
    sink = nil
    axisState.removeAll()
    return nil
  }

  // MARK: - Controllers

  private func isGamepad(_ controller: GCController) -> Bool {
    controller.extendedGamepad != nil
  }

  private func id(for controller: GCController) -> Int {
    let key = ObjectIdentifier(controller)
    if let id = ids[key] { return id }
    let id = nextId
    nextId += 1
    ids[key] = id
    return id
  }

  private func name(of controller: GCController) -> String {
    controller.vendorName ?? "Game controller"
  }

  private func connectedGamepads() -> [[String: Any]] {
    GCController.controllers().filter(isGamepad).map { controller in
      [
        "id": id(for: controller),
        "name": name(of: controller),
        "descriptor": controller.productCategory,
      ]
    }
  }

  private func attach(_ controller: GCController) {
    guard let pad = controller.extendedGamepad else { return }
    let device = id(for: controller)
    bind(pad, device: device)
    emitConnection(device, name: name(of: controller), connected: true)
  }

  private func detach(_ controller: GCController) {
    let key = ObjectIdentifier(controller)
    guard let device = ids[key] else { return }
    unbind(controller)
    clearAxes(for: device)
    ids.removeValue(forKey: key)
    emitConnection(device, name: "", connected: false)
  }

  private func bind(_ pad: GCExtendedGamepad, device: Int) {
    func button(_ input: GCControllerButtonInput?, _ name: String) {
      input?.pressedChangedHandler = { [weak self] _, _, pressed in
        self?.emitButton(name, pressed: pressed, deviceId: device)
      }
    }
    // Positional, as on the wire: A bottom, B right, X left, Y top.
    button(pad.buttonA, "a")
    button(pad.buttonB, "b")
    button(pad.buttonX, "x")
    button(pad.buttonY, "y")
    button(pad.leftShoulder, "l1")
    button(pad.rightShoulder, "r1")
    button(pad.buttonOptions, "select")
    button(pad.buttonMenu, "start")
    button(pad.leftThumbstickButton, "leftStickClick")
    button(pad.rightThumbstickButton, "rightStickClick")
    button(pad.buttonHome, "mode")

    pad.leftTrigger.valueChangedHandler = { [weak self] _, value, _ in
      self?.unipolar(device, key: "l2", value: value, button: "l2")
    }
    pad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
      self?.unipolar(device, key: "r2", value: value, button: "r2")
    }
    // GameController's y grows upward; on the wire (as on Android) "up" is
    // the negative side, so y is negated.
    pad.dpad.valueChangedHandler = { [weak self] _, x, y in
      self?.bipolar(device, key: "hatX", value: x, press: GamepadBridge.hatPress,
                    release: GamepadBridge.hatPress, negative: "dpadLeft", positive: "dpadRight")
      self?.bipolar(device, key: "hatY", value: -y, press: GamepadBridge.hatPress,
                    release: GamepadBridge.hatPress, negative: "dpadUp", positive: "dpadDown")
    }
    pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
      self?.bipolar(device, key: "lx", value: x, press: GamepadBridge.axisPress,
                    release: GamepadBridge.axisRelease,
                    negative: "leftStickLeft", positive: "leftStickRight")
      self?.bipolar(device, key: "ly", value: -y, press: GamepadBridge.axisPress,
                    release: GamepadBridge.axisRelease,
                    negative: "leftStickUp", positive: "leftStickDown")
    }
    pad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
      self?.bipolar(device, key: "rx", value: x, press: GamepadBridge.axisPress,
                    release: GamepadBridge.axisRelease,
                    negative: "rightStickLeft", positive: "rightStickRight")
      self?.bipolar(device, key: "ry", value: -y, press: GamepadBridge.axisPress,
                    release: GamepadBridge.axisRelease,
                    negative: "rightStickUp", positive: "rightStickDown")
    }
  }

  private func unbind(_ controller: GCController) {
    guard let pad = controller.extendedGamepad else { return }
    for input in [
      pad.buttonA, pad.buttonB, pad.buttonX, pad.buttonY, pad.leftShoulder,
      pad.rightShoulder, pad.buttonMenu,
    ] {
      input.pressedChangedHandler = nil
    }
    pad.buttonOptions?.pressedChangedHandler = nil
    pad.leftThumbstickButton?.pressedChangedHandler = nil
    pad.rightThumbstickButton?.pressedChangedHandler = nil
    pad.buttonHome?.pressedChangedHandler = nil
    pad.leftTrigger.valueChangedHandler = nil
    pad.rightTrigger.valueChangedHandler = nil
    pad.dpad.valueChangedHandler = nil
    pad.leftThumbstick.valueChangedHandler = nil
    pad.rightThumbstick.valueChangedHandler = nil
  }

  // MARK: - Axes → presses (the same rules as GamepadBridge.kt)

  /// A stick or the D-pad: negative fires [negative], positive [positive],
  /// back to centre releases whichever was held. A direct flip (left straight
  /// to right) releases the old direction before pressing the new one, so
  /// Dart's held-button bookkeeping stays balanced.
  private func bipolar(
    _ device: Int, key: String, value: Float, press: Float, release: Float,
    negative: String, positive: String
  ) {
    let stateKey = "\(device)/\(key)"
    let previous = axisState[stateKey] ?? 0
    let next: Int
    if value <= -press {
      next = -1
    } else if value >= press {
      next = 1
    } else if abs(value) < release {
      next = 0
    } else {
      next = previous
    }
    if next == previous { return }
    axisState[stateKey] = next
    if previous != 0 {
      emitButton(previous < 0 ? negative : positive, pressed: false, deviceId: device)
    }
    if next != 0 {
      emitButton(next < 0 ? negative : positive, pressed: true, deviceId: device)
    }
  }

  /// A trigger: rests at 0, pulled toward 1.
  private func unipolar(_ device: Int, key: String, value: Float, button: String) {
    let stateKey = "\(device)/\(key)"
    let previous = axisState[stateKey] ?? 0
    let next: Int
    if value >= GamepadBridge.triggerPress {
      next = 1
    } else if value < GamepadBridge.triggerRelease {
      next = 0
    } else {
      next = previous
    }
    if next == previous { return }
    axisState[stateKey] = next
    emitButton(button, pressed: next == 1, deviceId: device)
  }

  private func clearAxes(for device: Int) {
    axisState = axisState.filter { !$0.key.hasPrefix("\(device)/") }
  }

  // MARK: - Emission (GameController calls back on the main queue)

  private func emitButton(_ button: String, pressed: Bool, deviceId: Int) {
    guard captureEnabled, let sink = sink else { return }
    sink([
      "type": "button",
      "button": button,
      "pressed": pressed,
      "deviceId": deviceId,
    ])
  }

  private func emitConnection(_ deviceId: Int, name: String, connected: Bool) {
    sink?([
      "type": "connection",
      "deviceId": deviceId,
      "name": name,
      "connected": connected,
    ])
  }
}
