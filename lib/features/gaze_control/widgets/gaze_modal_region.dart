import 'package:flutter/widgets.dart';

/// How many in-screen modals ([GazeModalRegion]s) are open under one gaze
/// scope. A plain counter, read at event time — never a listenable, because
/// regions mount and unmount mid-build, where notifying would be illegal.
class GazeModalCount {
  int _value = 0;

  /// True while at least one in-screen modal is open.
  bool get isBusy => _value > 0;

  void _open() => _value++;

  void _close() {
    if (_value > 0) _value--;
  }
}

/// Lets the [GazeModalRegion]s inside a gaze scope's screen find that scope.
///
/// Every gaze scope puts one of these around its content (see
/// `GazeRouteGuard.hostGazeModals`); a region registers with the *nearest*
/// one, so a pause card covers exactly the game it belongs to, and a level-up
/// celebration in the navigation shell covers exactly the shell.
class GazeModalHost extends InheritedWidget {
  const GazeModalHost({super.key, required this.count, required super.child});

  final GazeModalCount count;

  static GazeModalCount? _maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GazeModalHost>()?.count;

  @override
  bool updateShouldNotify(GazeModalHost oldWidget) =>
      !identical(oldWidget.count, count);
}

/// Marks a modal that is drawn **inside a screen** rather than pushed as a
/// route — a game's pause card, the achievement and level-up celebrations.
///
/// Gaze scopes notice dialogs and sheets by their routes. These overlays have
/// no route: they sit in the screen's own `Stack`, so to the scope underneath
/// nothing had changed. On device that meant two things. A game paused by
/// voice ("go back") showed a pause card that no head move, blink or phrase
/// could operate — every edge target was disabled while paused, and the scope
/// had no idea why. And the level-up celebration floated over the hubs while
/// the shell's D-pad went on steering the tabs hidden beneath it.
///
/// Wrapping such an overlay in this region does two things:
///  * the nearest gaze scope treats its screen as covered, and hands head,
///    blink, scanning and voice to focus traversal for as long as it is open;
///  * the overlay becomes its own focus scope and takes focus when it opens,
///    so traversal moves among *its* buttons and never strays onto the
///    controls dimmed behind it.
class GazeModalRegion extends StatefulWidget {
  const GazeModalRegion({super.key, required this.child});

  final Widget child;

  @override
  State<GazeModalRegion> createState() => _GazeModalRegionState();
}

class _GazeModalRegionState extends State<GazeModalRegion> {
  final FocusScopeNode _focusScope = FocusScopeNode(
    debugLabel: 'GazeModalRegion',
  );
  GazeModalCount? _host;
  bool _registered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_registered) {
      _registered = true;
      _host = GazeModalHost._maybeOf(context);
      _host?._open();
    }
    // Take the focus whenever this region's screen is the one on top — on
    // mount, and again when a page above it closes (`ModalRoute.of` makes
    // this method re-run then). `autofocus` alone is not enough: it yields to
    // anything already focused on the screen, and on the tablet the level-up
    // celebration left focus on the hub tile behind it, so the learner's
    // second blink opened Player Profile instead of closing the celebration.
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusScope.hasFocus) _focusScope.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _host?._close();
    _focusScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(node: _focusScope, autofocus: true, child: widget.child);
  }
}
