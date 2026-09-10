import 'package:flutter/foundation.dart';

/// App-wide bridge letting the navigation shell tell the gamepad host what the
/// top-level **sections** are, and how to move between them.
///
/// Deliberately the same shape as `gazeHomeGrid`: a plain [ChangeNotifier]
/// singleton rather than a Riverpod provider, so the shell can publish from
/// `build`/`dispose` and the host can read it inside an input callback without
/// "modified a provider during build" hazards.
///
/// It exists because the gamepad host lives *above* the router (in
/// `MaterialApp.builder`), where there is no `GoRouter` in scope — the same
/// constraint the TV Cast status host works around. The shell knows the tab
/// list and how to switch tabs; the host knows the controller. This carries the
/// former to the latter without either reaching into the other.
class GamepadSections extends ChangeNotifier {
  List<String> _labels = const [];
  int _currentIndex = 0;
  void Function(int index)? _onSelect;
  Object? _owner;

  /// Visible names of the sections, in tab order.
  List<String> get labels => _labels;

  /// Which section is live.
  int get currentIndex => _currentIndex;

  /// Whether a shell with sections is currently on screen. False on the guest
  /// Player shell (no tab bar) and before the first hub builds.
  bool get hasSections => _labels.isNotEmpty;

  /// Name of the live section, or null when there are none.
  String? get currentLabel =>
      _labels.isEmpty ? null : _labels[_currentIndex.clamp(0, _labels.length - 1)];

  /// Publishes the shell's tab set. Only notifies when something the host cares
  /// about actually changed — the shell republishes on every rebuild to keep
  /// [_onSelect] fresh, and notifying each frame would reset the confirm
  /// question mid-sentence.
  void publish({
    required List<String> labels,
    required int currentIndex,
    required void Function(int index) onSelect,
    Object? owner,
  }) {
    final changed =
        currentIndex != _currentIndex || !listEquals(labels, _labels);
    _owner = owner;
    _labels = List.unmodifiable(labels);
    _currentIndex = currentIndex;
    _onSelect = onSelect;
    if (changed) notifyListeners();
  }

  /// Clears the sections when the shell goes away. Ignores a clear from an
  /// owner that no longer holds the publication — during a role switch the
  /// outgoing shell can dispose after the incoming one has already published,
  /// and without this guard that would wipe the newer tab set.
  void clear({Object? owner}) {
    if (owner != null && !identical(owner, _owner)) return;
    _owner = null;
    if (_labels.isEmpty) return;
    _labels = const [];
    _currentIndex = 0;
    _onSelect = null;
    notifyListeners();
  }

  /// Switches to a section. Returns false when the index is stale or no shell
  /// is published — the layout can change between a button press and its
  /// handler running.
  bool select(int index) {
    final callback = _onSelect;
    if (callback == null) return false;
    if (index < 0 || index >= _labels.length) return false;
    callback(index);
    return true;
  }
}

/// The single, app-wide section bridge.
final GamepadSections gamepadSections = GamepadSections();
