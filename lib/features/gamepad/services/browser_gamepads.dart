/// A game controller in a web browser, through the browser's Gamepad API —
/// the web app's counterpart of the Android bridge. Only the web build has
/// one; elsewhere [BrowserGamepads.available] is false and it does nothing.
library;

export 'browser_gamepads_stub.dart'
    if (dart.library.js_interop) 'browser_gamepads_web.dart';
