import 'package:flutter/foundation.dart';

/// One control a screen offers to the controller.
@immutable
class GamepadItem {
  /// What the learner hears when the cursor lands here.
  final String label;

  /// Extra detail spoken after the label — a card's translation, an answer's
  /// hint. Kept separate so item-stepping can stay terse while "read the whole
  /// screen" can be complete.
  final String? detail;

  final VoidCallback onActivate;

  /// A disabled control is still announced (so its presence is known) but
  /// cannot be opened — matching how a greyed button behaves to a sighted
  /// learner.
  final bool enabled;

  const GamepadItem({
    required this.label,
    required this.onActivate,
    this.detail,
    this.enabled = true,
  });
}

/// What the foreground screen offers the Bluetooth controller: the things that
/// can be **done**, and the things that can be **read**.
///
/// The hubs already publish their tiles to `gazeHomeGrid`, which the gamepad
/// host drives directly. That covers the five tabs — but a learner who cannot
/// see the screen spends most of their time somewhere else: inside a game, a
/// story, a quiz. Those are pushed routes with no tile grid, where the
/// controller could only fall back to Flutter's focus traversal: it could reach
/// a button but often not name it, and it could never read the question the
/// game was actually asking.
///
/// This bridge is how such a screen says what it contains. Both halves matter
/// and they are deliberately published together:
///
/// * [items] — the answers, the choices, the actions. Walked with ▲ ▼ and
///   opened with R1, exactly like hub tiles.
/// * [narration] — the prose: the prompt, the question, the sentence of the
///   story. Read on request (R2), and the reason a blind learner can follow a
///   quiz at all rather than just operate its buttons.
///
/// App-wide singleton rather than a Riverpod provider, matching `gazeHomeGrid`
/// and `gamepadSections`: it is mutated from `initState`/`dispose` and read
/// inside input callbacks, where "modified a provider during build" hazards
/// would otherwise bite.
class GamepadScreenContent extends ChangeNotifier {
  String? _title;
  List<String> _narration = const [];
  List<GamepadItem> _items = const [];
  int? _focusedIndex;
  Object? _owner;

  /// The screen's name, spoken when asked "where am I?".
  String? get title => _title;

  /// The screen's readable prose, in reading order.
  List<String> get narration => _narration;

  /// The screen's controls, in reading order.
  List<GamepadItem> get items => _items;

  /// Whether a screen is currently offering itself to the controller.
  ///
  /// True when there is *anything* to work with — a screen that is pure prose
  /// (a story page with no buttons) still wants the controller reading it
  /// rather than falling through to focus traversal.
  bool get hasContent => _items.isNotEmpty || _narration.isNotEmpty;

  /// Which item the controller is resting on, published back by the host so
  /// the screen can draw its highlight.
  int? get focusedIndex => _focusedIndex;

  /// Publishes this screen's content.
  ///
  /// Only notifies when something structural changed — the label list, the
  /// narration or the title. A screen re-publishes on every rebuild to keep its
  /// `onActivate` closures fresh (they capture round state that changes every
  /// answer), and notifying on each of those would reset the reading cursor
  /// mid-sentence.
  void publish({
    required List<GamepadItem> items,
    List<String> narration = const [],
    String? title,
    Object? owner,
  }) {
    final changed = !_sameLabels(items) ||
        !listEquals(narration, _narration) ||
        title != _title;
    // A *different screen* is publishing, so the cursor position belongs to a
    // list that is no longer on screen. Carried over, it pointed into the new
    // screen's items at the old index — pressing R1 straight after opening the
    // category sheet toggled whichever category happened to sit where the
    // previous screen's cursor had been, instead of the Start button the
    // learner was aiming at.
    //
    // Keyed on the owner, not on the content: a screen that republishes its
    // own changed items (a game dealing the next round, a letter being used
    // up) must keep the learner where they were.
    if (owner != null && !identical(owner, _owner)) _focusedIndex = null;
    _owner = owner;
    _items = List.unmodifiable(items);
    _narration = List.unmodifiable(narration);
    _title = title;
    if (changed) notifyListeners();
  }

  /// Withdraws this screen's content — on dispose, or while a dialog covers it.
  ///
  /// Ignores a clear from an owner that no longer holds the publication, so a
  /// screen disposing *after* its replacement has published cannot wipe the
  /// newer content. Same guard `gazeHomeGrid` uses, for the same reason: during
  /// a push both screens briefly coexist.
  void clear({Object? owner}) {
    if (owner != null && !identical(owner, _owner)) return;
    _owner = null;
    if (!hasContent && _title == null && _focusedIndex == null) return;
    _items = const [];
    _narration = const [];
    _title = null;
    _focusedIndex = null;
    notifyListeners();
  }

  List<GamepadItem> _floating = const [];
  Object? _floatingOwner;

  /// Controls that float **over** whatever is on screen — the AI Tutor
  /// launcher today, anything else pinned above the hubs tomorrow.
  ///
  /// Published separately because they belong to no screen: the tutor button
  /// hovers above every hub, owned by an overlay that has no route and no tile
  /// grid of its own. Put through [publish] it would have *replaced* the hub's
  /// tiles and left the learner able to reach nothing but the tutor; ignored
  /// entirely — which is what happened at first — a learner who cannot see the
  /// screen simply had no way to open the tutor at all.
  ///
  /// The host appends these after the hub's own tiles, so they are always the
  /// last thing in the list and never displace what the screen offers.
  List<GamepadItem> get floating => _floating;

  void publishFloating(List<GamepadItem> items, {Object? owner}) {
    final changed = items.length != _floating.length ||
        [for (var i = 0; i < items.length; i++) items[i].label].join('|') !=
            [for (final f in _floating) f.label].join('|');
    _floatingOwner = owner;
    _floating = List.unmodifiable(items);
    if (changed) notifyListeners();
  }

  void clearFloating({Object? owner}) {
    if (owner != null && !identical(owner, _floatingOwner)) return;
    _floatingOwner = null;
    if (_floating.isEmpty) return;
    _floating = const [];
    notifyListeners();
  }

  String? _live;
  int _liveSeq = 0;

  /// The most recent live message, and a counter that changes every time one is
  /// posted — so the host can tell a *new* announcement from a rebuild that
  /// happens to carry the same words ("Correct!" twice in a row).
  String? get liveMessage => _live;
  int get liveSequence => _liveSeq;

  /// Says something immediately, out of band from the navigation.
  ///
  /// This is what lets a screen narrate itself as it changes rather than only
  /// when asked: a quiz calls it with the result and the next question, a story
  /// calls it with the sentence it just turned to. Without it a learner who
  /// cannot see the screen would press A and hear nothing back — the app would
  /// have accepted their answer in silence.
  void announce(String message) {
    if (message.trim().isEmpty) return;
    _live = message;
    _liveSeq++;
    notifyListeners();
  }

  /// Publishes which item is focused (host → screen). Null when the cursor is
  /// not on this screen's items.
  void setFocus(int? index) {
    if (_focusedIndex == index) return;
    _focusedIndex = index;
    notifyListeners();
  }

  bool isFocused(int index) => _focusedIndex == index;

  /// The item at [index], or null when out of range — the screen can change
  /// between a button press and its handler running.
  GamepadItem? itemAt(int index) {
    if (index < 0 || index >= _items.length) return null;
    return _items[index];
  }

  bool _sameLabels(List<GamepadItem> next) {
    if (next.length != _items.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (next[i].label != _items[i].label ||
          next[i].detail != _items[i].detail ||
          next[i].enabled != _items[i].enabled) {
        return false;
      }
    }
    return true;
  }
}

/// The single, app-wide screen-content bridge.
final GamepadScreenContent gamepadScreen = GamepadScreenContent();
