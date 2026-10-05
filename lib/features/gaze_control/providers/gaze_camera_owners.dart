import 'package:flutter/foundation.dart';

/// Tracks the **foreground** camera surfaces that currently hold the device
/// camera, as an app-wide singleton (the camera is a single hardware resource,
/// not per-widget-tree state — and unlike a Riverpod provider it can be mutated
/// safely from `initState` / `dispose`).
///
/// The hardware allows only one camera session at a time, so the gaze feature
/// must never run two. The bottom-nav gaze (`NavGazeScope`) lives on the
/// long-lived navigation shell and is a *background* owner: it runs its camera
/// only while [isBusy] is false. Every full-screen camera surface pushed over
/// the shell — the per-screen `GazeScope` / `GazeDpadScope` adopters, the gaze
/// preview, Word Hunt's object scanner, Sign It, the in-app media camera —
/// calls [acquire] on mount and [release] on dispose, so the shell yields the
/// single camera to whichever activity is on top and re-acquires it on return.
///
/// Owners form a **stack**, newest on top, because foreground surfaces stack
/// too: the Play Together lobby (a gaze screen) opens a race (another one), and
/// a message thread (a gaze screen) opens the media camera. Only the [isTop]
/// owner may run its camera — a gaze screen underneath stands its own camera
/// and microphone down until it is on top again. Before, the screen below kept
/// streaming, and two sessions fought over one front camera.
///
/// Any **new** full-screen screen that opens a camera should do the same
/// (acquire in `initState`, release in `dispose`) so it never collides with a
/// gaze camera.
class GazeCameraOwners extends ChangeNotifier {
  final List<Object> _owners = [];

  /// Number of foreground camera surfaces currently active.
  int get count => _owners.length;

  /// Whether a foreground camera surface is holding the camera right now.
  bool get isBusy => _owners.isNotEmpty;

  /// Registers a foreground camera owner on top of any others and returns its
  /// token (a fresh one unless [token] is given) for [release] and [isTop].
  Object acquire([Object? token]) {
    final owner = token ?? Object();
    _owners.add(owner);
    notifyListeners();
    return owner;
  }

  /// Releases a foreground camera owner — [token]'s, or the newest one when
  /// no token is given. An extra release is ignored, so it can never wedge
  /// the shell camera off.
  void release([Object? token]) {
    if (_owners.isEmpty) return;
    if (token == null) {
      _owners.removeLast();
    } else if (!_owners.remove(token)) {
      return;
    }
    notifyListeners();
  }

  /// Whether [token] is the newest owner — the surface the learner is looking
  /// at, and the only one that may run a camera.
  bool isTop(Object token) => _owners.isNotEmpty && identical(_owners.last, token);
}

/// The single, app-wide camera-ownership gate.
final GazeCameraOwners gazeCameraOwners = GazeCameraOwners();
