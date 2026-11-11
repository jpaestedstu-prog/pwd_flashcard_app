import 'package:flutter/widgets.dart';

import '../../../navigation/dpad_modal_focus.dart';

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
///    controls dimmed behind it;
///  * what it covers is gone for a screen reader too, as behind a dialog: on
///    the tablet TalkBack could still reach "Back" and the tabs under a new
///    sticker's card, where a finger could not.
///
/// Two app-wide counts sit beside the scopes' own:
///  * [anyOpen] — the game controller has no gaze scope to ask, and drove the
///    hub's grid under a level-up celebration or Home's first-visit tour; it
///    steps through the region by focus instead while any is open;
///  * [openAboveScopes] — a region with no scope above it at all: the AI
///    Buddy's panel floats over the router, outside every scope, so the
///    navigation shell counts it as covering itself.
class GazeModalRegion extends StatefulWidget {
  const GazeModalRegion({super.key, required this.child, this.onBack});

  final Widget child;

  /// What Android's Back does while this is open: it closes a pop-up, as it
  /// closes a dialog. With no route of its own, Back went straight through to
  /// the screen underneath, and out of the app on Home (the tablet, 4 Nov).
  /// Null leaves Back to the screen (a paused game has its own rule).
  final VoidCallback? onBack;

  static int _open = 0;
  static int _openUnhosted = 0;

  /// Whether any in-screen modal is open anywhere in the app.
  static bool get anyOpen => _open > 0;

  /// Whether a modal outside every gaze scope is open (see above).
  static bool get openAboveScopes => _openUnhosted > 0;

  /// [anyOpen] as a count, for a widget that must redraw when it changes: the
  /// AI Buddy's floating button steps aside under Home's first-visit tour and
  /// the celebrations, which it floated over, bright and tappable. Set after
  /// the frame: regions come and go mid-build, where notifying is not allowed.
  static final ValueNotifier<int> openCount = ValueNotifier<int>(0);

  static void _announce() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openCount.value = _open;
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  State<GazeModalRegion> createState() => _GazeModalRegionState();
}

class _GazeModalRegionState extends State<GazeModalRegion> {
  final FocusScopeNode _focusScope = FocusScopeNode(
    debugLabel: 'GazeModalRegion',
  );
  GazeModalCount? _host;
  bool _registered = false;
  BackButtonDispatcher? _routerBack;
  ChildBackButtonDispatcher? _back;

  /// Asks the router first: it comes before a hub's or a game's own Back.
  void _claimBack() {
    if (_back != null || widget.onBack == null) return;
    final dispatcher = Router.maybeOf(context)?.backButtonDispatcher;
    if (dispatcher == null) return;
    _routerBack = dispatcher;
    _back = dispatcher.createChildBackButtonDispatcher()
      ..addCallback(_onBack)
      ..takePriority();
    // Android's predictive Back asks beforehand whether the app wants Back at
    // all; on Home the answer was no, and the key never came here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        const NavigationNotification(canHandlePop: true).dispatch(context);
      }
    });
  }

  Future<bool> _onBack() async {
    final onBack = widget.onBack;
    if (onBack == null) return false;
    onBack();
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _claimBack();
    if (!_registered) {
      _registered = true;
      _host = GazeModalHost._maybeOf(context);
      _host?._open();
      GazeModalRegion._open++;
      if (_host == null) GazeModalRegion._openUnhosted++;
      GazeModalRegion._announce();
      // And onto its first control once it has the focus, as a dialog does:
      // on the scope alone, a remote's first OK pressed nothing.
      DpadModalFocus.watchRegion(_focusScope);
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
    final back = _back;
    if (back != null) {
      back.removeCallback(_onBack);
      _routerBack?.forget(back);
    }
    DpadModalFocus.forgetRegion(_focusScope);
    _host?._close();
    if (_registered) {
      if (GazeModalRegion._open > 0) GazeModalRegion._open--;
      if (_host == null && GazeModalRegion._openUnhosted > 0) {
        GazeModalRegion._openUnhosted--;
      }
      GazeModalRegion._announce();
    }
    _focusScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = BlockSemantics(
      child: FocusScope(node: _focusScope, autofocus: true, child: widget.child),
    );
    // No router above: the screen's own route takes Back.
    final onBack = widget.onBack;
    if (onBack == null || _back != null) return region;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: region,
    );
  }
}
