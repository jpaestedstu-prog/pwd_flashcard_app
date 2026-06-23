import 'package:flutter/foundation.dart';

/// Tracks how many **foreground** camera surfaces currently hold the device
/// camera, as an app-wide singleton (the camera is a single hardware resource,
/// not per-widget-tree state — and unlike a Riverpod provider it can be mutated
/// safely from `initState` / `dispose`).
///
/// The hardware allows only one camera session at a time, so the gaze feature
/// must never run two. The bottom-nav gaze (`NavGazeScope`) lives on the
/// long-lived navigation shell and is a *background* owner: it runs its camera
/// only while [isBusy] is false. Every full-screen camera surface pushed over
/// the shell — the per-screen `GazeScope` adopters, the gaze preview, and Word
/// Hunt's object scanner — calls [acquire] on mount and [release] on dispose,
/// so the shell yields the single camera to whichever activity is on top and
/// re-acquires it on return.
///
/// Any **new** full-screen screen that opens a camera should do the same
/// (acquire in `initState`, release in `dispose`) so it never collides with the
/// shell's nav-gaze camera.
class GazeCameraOwners extends ChangeNotifier {
  int _count = 0;

  /// Number of foreground camera surfaces currently active.
  int get count => _count;

  /// Whether a foreground camera surface is holding the camera right now.
  bool get isBusy => _count > 0;

  /// Registers a foreground camera owner.
  void acquire() {
    _count++;
    notifyListeners();
  }

  /// Releases a foreground camera owner, clamped at zero so an extra release can
  /// never drive the count negative (which would wedge the shell camera off).
  void release() {
    if (_count > 0) {
      _count--;
      notifyListeners();
    }
  }
}

/// The single, app-wide camera-ownership gate.
final GazeCameraOwners gazeCameraOwners = GazeCameraOwners();
