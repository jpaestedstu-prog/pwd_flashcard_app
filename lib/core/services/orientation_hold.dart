import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../data/models/enums.dart';

/// Which ways the screen may turn, decided in one place.
///
/// The app follows the device in every orientation — phones and tablets,
/// portrait and landscape, split screen and resizable windows — unless:
///
///  * the active profile chose to stay **portrait** or **landscape**
///    (Settings → Accessibility → Screen orientation): a screen that turns by
///    itself is disorienting for some learners, and a mounted tablet should
///    stay the way it is mounted; or
///  * something **holds** the current orientation. Head tracking does: the
///    learner's resting head position is measured against where the front
///    camera sits, and turning the device moves the camera to another edge of
///    the screen — a tablet turned in the middle of a session would read a
///    resting head as a steady turn and keep picking one side. While a gaze
///    camera runs, the screen stays portrait or landscape, whichever it was
///    when tracking started.
///
/// Before 1.4.0 the whole app was locked to portrait for that reason; now
/// only the moments that need it are.
class OrientationHold {
  OrientationHold._();

  static ScreenOrientationChoice _preference = ScreenOrientationChoice.device;
  static final Map<Object, List<DeviceOrientation>> _holds = {};
  static List<DeviceOrientation>? _applied;

  /// The active profile's choice.
  static void prefer(ScreenOrientationChoice choice) {
    if (_preference == choice) return;
    _preference = choice;
    _apply();
  }

  /// Keeps the screen the shape it is now (portrait or landscape) until
  /// [release] is called with the same [owner].
  static void hold(Object owner) {
    _holds[owner] = _currentShape();
    _apply();
  }

  /// Turns the screen [landscape] (or portrait) and keeps it so until
  /// [release] is called with the same [owner], even with the device's
  /// auto-rotate off: the full-screen sign player's "turn sideways", which a
  /// phone held upright needs (the sign filled a quarter of its screen).
  /// The newest hold wins, so releasing it restores whatever held before.
  static void holdShape(Object owner, {required bool landscape}) {
    _holds.remove(owner);
    _holds[owner] = landscape ? _landscape : _portrait;
    _apply();
  }

  static void release(Object owner) {
    if (_holds.remove(owner) == null) return;
    _apply();
  }

  /// What the platform is asked for: the newest hold, else the preference.
  /// Empty means "whatever the device and its rotation lock say".
  static List<DeviceOrientation> get effective {
    if (_holds.isNotEmpty) return _holds.values.last;
    return orientationsFor(_preference);
  }

  static List<DeviceOrientation> orientationsFor(
    ScreenOrientationChoice choice,
  ) =>
      switch (choice) {
        ScreenOrientationChoice.device => const [],
        ScreenOrientationChoice.portrait => _portrait,
        ScreenOrientationChoice.landscape => _landscape,
      };

  static const _portrait = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];
  static const _landscape = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static List<DeviceOrientation> _currentShape() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return const [];
    final size = views.first.physicalSize;
    if (size.isEmpty) return const [];
    return size.width > size.height ? _landscape : _portrait;
  }

  static void _apply() {
    final next = effective;
    final applied = _applied;
    if (applied != null &&
        applied.length == next.length &&
        Iterable<int>.generate(next.length).every((i) => applied[i] == next[i])) {
      return;
    }
    _applied = next;
    SystemChrome.setPreferredOrientations(next).catchError((Object _) {});
  }

  /// Forgets every hold and the preference (tests).
  @visibleForTesting
  static void debugReset() {
    _preference = ScreenOrientationChoice.device;
    _holds.clear();
    _applied = null;
  }
}
