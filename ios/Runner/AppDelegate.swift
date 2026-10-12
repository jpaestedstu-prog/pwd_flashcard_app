import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Bluetooth game controllers (Settings → Game Controller); kept alive for
  /// the engine's lifetime.
  private var gamepadBridge: GamepadBridge?

  /// The media volume for the "your device sound is off" note (DeviceSound on
  /// the Dart side). iOS leaves changing the volume to the person holding it.
  private var audioChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Routine reminders, the "Check-in time" prompt and the daily reminder
    // are local notifications. iOS hides a notification that arrives while
    // the app is open unless the app is the notification centre's delegate;
    // FlutterAppDelegate forwards these callbacks to
    // flutter_local_notifications, which then shows the banner.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FlashLearnGamepadBridge") {
      gamepadBridge = GamepadBridge(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FlashLearnDeviceSound") {
      let channel = FlutterMethodChannel(
        name: "flashlearn/audio", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "mediaVolume":
          // The output volume, 0...1. Speech plays in the playback session
          // (TtsService), which the Ring/Silent switch does not mute.
          let level = AVAudioSession.sharedInstance().outputVolume
          result(["level": Double(level), "max": 1.0, "muted": false])
        case "turnUp":
          result(false)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      audioChannel = channel
    }
  }
}
