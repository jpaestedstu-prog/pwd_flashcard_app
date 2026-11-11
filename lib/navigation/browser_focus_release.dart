/// A text box lets go when a browser moves the page's focus to a button: see
/// `browser_focus_release_web.dart`. Only the web build has anything to do.
library;

export 'browser_focus_release_stub.dart'
    if (dart.library.js_interop) 'browser_focus_release_web.dart';
