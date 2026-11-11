import 'package:flutter/material.dart';

import '../../../widgets/app_back_button.dart';

/// Drives Flutter's **built-in directional focus traversal** from gaze input.
///
/// The published-grid D-pad ([gazeHomeGrid] / `GazeDpadScope`) only reaches
/// cells a screen has explicitly registered. That covers the hubs and a handful
/// of adopters — but a dialog, a bottom sheet or any of the ~15 pushed screens
/// the hub tiles can open registers nothing, so a hands-free learner could open
/// them and then not operate or leave them. The Daily Reward dialog that greets
/// a learner on login was exactly this: touch-only.
///
/// Rather than hand-wiring every one of those screens, this drives the focus
/// traversal Flutter already implements for keyboards and Android TV D-pads.
/// Material's buttons, list tiles, text fields and dialog actions are focusable
/// out of the box, so the covering route becomes navigable for free — including
/// its back button, which is what gives a learner the way out.
///
/// Pure static helpers over [FocusManager]: no camera, no widgets, so the
/// mapping is unit-testable with plain `Focus` nodes.
abstract final class GazeFocusDriver {
  /// The node gaze should act on: whatever currently holds focus. When a route
  /// is pushed, Flutter moves focus into that route's own [FocusScopeNode], so
  /// this naturally follows the topmost screen and traversal stays inside it.
  static FocusNode? get focused {
    final node = FocusManager.instance.primaryFocus;
    // A node with no context can't be traversed from or activated.
    return node?.context == null ? null : node;
  }

  /// Moves focus one step in [direction]. Returns whether focus actually moved,
  /// so the caller can fall back (e.g. keep a scroll gesture) when the route has
  /// nothing focusable that way.
  static bool move(TraversalDirection direction) {
    final node = focused;
    if (node == null) return false;
    if (startOnScreen(
      forward: direction == TraversalDirection.down ||
          direction == TraversalDirection.right,
    )) {
      return true;
    }
    _openShellPageEdge(node);
    // Geometry first: for a D-pad, "the control below this one" is what the
    // learner means.
    final row = _skippedRow(node, direction);
    if (row != null) {
      _focusChosen(node, row);
      _revealFocused();
      return true;
    }
    // On a page inside the navigation shell, the shell's own controls are
    // part of the one screen the learner sees. Flutter searches the page
    // first, and a page control even off to one side beat a shell control
    // straight that way: on a guest's two-column Cards page nothing led to
    // the AI Buddy beside the last deck.
    final inLine = _shellControlToward(node, direction, inLineOnly: true);
    if (inLine != null) {
      _focusChosen(node, inLine);
      _revealFocused();
      return true;
    }
    // ◀ ▶ stay in their row. With nothing beside it in the row, Flutter takes
    // the nearest control anywhere that way — from the last Mood Check-In
    // face that was the Star Shop button at the top of Home, and every
    // further ▶ went round the top of the page again, so the rest of Home
    // could not be stepped to. The reading order below carries on into the
    // next row instead.
    final across = direction == TraversalDirection.left ||
        direction == TraversalDirection.right;
    if ((!across || _hasNeighbourInRow(node, direction)) &&
        node.focusInDirection(direction)) {
      _revealFocused();
      return true;
    }
    // Geometry can legitimately fail while there is still somewhere to go.
    // Directional traversal will not cross a scroll boundary into a pinned
    // footer, so on the game category picker a learner reached the last
    // category and then simply stopped — the "Start" button underneath was
    // unreachable and the screen was a dead end. Reading order has no such
    // blind spot, so fall back to it rather than stranding them.
    final forward =
        direction == TraversalDirection.down ||
        direction == TraversalDirection.right;
    // Off the end of a page inside the navigation shell, the shell's own
    // controls come next. Flutter's search above only takes a control whose
    // centre lies past the focused one's far edge, and a guest's floating
    // Home button sits over the lower corner of the last deck: down wrapped
    // round to the first deck, and the button was never reached.
    if (!across && (forward ? isLast() : isFirst())) {
      final shell = _shellControlToward(node, direction, inLineOnly: false);
      if (shell != null) {
        _focusChosen(node, shell);
        _revealFocused();
        return true;
      }
    }
    // Past the last control, going on wraps round to the start of the page —
    // the real start, which reading order alone would not find (see
    // [moveToStart]).
    if (forward && isLast()) return moveToStart();
    // The next control in *this* driver's reading order — rows top to
    // bottom, each left to right, the order [isFirst], [isLast] and scanning
    // use — so ▶ at the end of a row carries on into the next row. Flutter's
    // own next-focus order bands controls differently, and from the end of a
    // row it could step back to one already passed.
    final order = _readingOrder(node);
    final at = order.indexOf(node);
    final step = forward ? at + 1 : at - 1;
    if (at >= 0 && step >= 0 && step < order.length) {
      _focusChosen(node, order[step]);
      _revealFocused();
      return true;
    }
    if (forward ? node.nextFocus() : node.previousFocus()) {
      _revealFocused();
      return true;
    }
    return false;
  }

  /// Whether a control sits beside [node], level with it, in [direction] —
  /// anywhere a move from it may reach (see [reachableScope]).
  static bool _hasNeighbourInRow(FocusNode node, TraversalDirection direction) {
    final scope = reachableScope(node);
    if (scope == null || node is FocusScopeNode) return false;
    final Rect from;
    try {
      from = node.rect;
    } catch (_) {
      return false;
    }
    final right = direction == TraversalDirection.right;
    for (final other in scope.traversalDescendants) {
      if (identical(other, node) || other is FocusScopeNode) continue;
      final Rect r;
      try {
        r = other.rect;
      } catch (_) {
        continue;
      }
      final level = r.top < from.bottom - rowSlack &&
          r.bottom > from.top + rowSlack;
      final beside = right
          ? r.center.dx > from.center.dx + 1
          : r.center.dx < from.center.dx - 1;
      if (level && beside) return true;
    }
    return false;
  }

  /// Where a move between a page inside the navigation shell and the shell's
  /// own controls — the tab bar, a guest's floating Home button, the AI Buddy
  /// launcher — should land, judged by centres. Null when neither side is
  /// involved, or Flutter's own search should decide.
  ///
  /// With [inLineOnly], only controls in [node]'s row (◀ ▶) or column (▲ ▼)
  /// count, on the page and in the shell alike:
  ///  * from the page, the nearest shell control, but only when the page has
  ///    nothing further that way — the page's own are Flutter's to find. A
  ///    page goes on before the shell starts: on a tablet held sideways, ▼
  ///    from a tall deck or story went out to a tab or the guest's Home button
  ///    (nearer by its centre than the next card), so the column below could
  ///    not be stepped down;
  ///  * from a shell control, whichever it is. Flutter counts the page itself
  ///    as a control there, one the size of the page, and lands on whatever
  ///    the page last had focused: ◀ from the AI Buddy, level with a guest's
  ///    last deck, went to a deck up in the other column.
  ///
  /// Otherwise — a move off the end of the page — only the shell's controls
  /// count, those in line first, then the nearest.
  ///
  /// The shell's other pages are passed over: a page under the current one
  /// is hidden but keeps its controls in the focus tree.
  static FocusNode? _shellControlToward(
    FocusNode node,
    TraversalDirection direction, {
    required bool inLineOnly,
  }) {
    final own = node.nearestScope;
    if (node is FocusScopeNode || node.context == null || own == null) {
      return null;
    }
    final fromShell = !_isShellPage(own);
    FocusScopeNode? page;
    final FocusScopeNode? scope;
    if (!fromShell) {
      page = own;
      scope = own.enclosingScope;
    } else {
      if (!inLineOnly) return null;
      scope = own;
      page = _shellPageInside(own);
    }
    final pageContext = page?.context;
    if (page == null || scope == null || pageContext == null) return null;
    final pages = Navigator.maybeOf(pageContext)?.focusNode;
    if (pages == null) return null;
    final Rect from;
    try {
      // A page control by the part of it that shows: held sideways, a story
      // card running on behind the tab bar was level with the tabs by its
      // hidden lower half, and ▶ from it went to Progress rather than to the
      // AI Buddy's button floating beside it (10 Nov).
      from = fromShell ? node.rect : _shownRect(node);
    } catch (_) {
      return null;
    }
    final vertical = direction == TraversalDirection.up ||
        direction == TraversalDirection.down;
    final forward = direction == TraversalDirection.down ||
        direction == TraversalDirection.right;
    FocusNode? best;
    var pageGoesOn = false;
    var bestKey = (0, 0.0, 0.0);
    for (final other in scope.traversalDescendants) {
      if (identical(other, node) ||
          other is FocusScopeNode ||
          other.context == null) {
        continue;
      }
      final inPage = other.ancestors.contains(page);
      if (inPage ? !inLineOnly : other.ancestors.contains(pages)) continue;
      // From the tab bar or a floating button, what is in view. On a short
      // window a page control can sit behind the tab bar, and ◀ ▶ along the
      // tabs went to it, level with them but out of sight.
      if (fromShell && inPage && !_middleInView(other)) continue;
      final Rect r;
      try {
        r = other.rect;
      } catch (_) {
        continue;
      }
      final ahead = vertical
          ? r.center.dy - from.center.dy
          : r.center.dx - from.center.dx;
      // Within a row's slack is level, not below or above.
      final past = vertical ? rowSlack : 1.0;
      if (forward ? ahead <= past : ahead >= -past) continue;
      final inLine = vertical
          ? r.right > from.left && r.left < from.right
          : r.top < from.bottom - rowSlack && r.bottom > from.top + rowSlack;
      if (inLineOnly && !inLine) continue;
      // Level with a tab only by an edge hidden under the tab bar is not level
      // to the eye. Scrolled, a sideways Home has a row of tiles whose lower
      // edges run behind the bar, and ◀ ▶ along the tabs went up to them
      // instead of to the next tab.
      if (fromShell &&
          inPage &&
          !vertical &&
          _underShellControl(
            other,
            Offset(r.center.dx, from.center.dy.clamp(r.top, r.bottom)),
          )) {
        continue;
      }
      if (inPage) pageGoesOn = true;
      // From a tab, ▲ ▼ take a button floating in its column (the AI Buddy
      // above Progress) before the page behind it: it is drawn over the
      // page, so to the eye it is the nearest thing above the tab, and the
      // next press goes on into the page. A page card nearer by its centre
      // took ▲ every time, and the buddy was reached only round a wrap.
      final behind = fromShell && vertical && inPage ? 1 : 0;
      final key = (
        (inLine ? 0 : 1) * 2 + behind,
        ahead.abs(),
        (vertical
                ? r.center.dx - from.center.dx
                : r.center.dy - from.center.dy)
            .abs(),
      );
      if (best == null ||
          key.$1 < bestKey.$1 ||
          (key.$1 == bestKey.$1 &&
              (key.$2 < bestKey.$2 ||
                  (key.$2 == bestKey.$2 && key.$3 < bestKey.$3)))) {
        best = other;
        bestKey = key;
      }
    }
    return !fromShell && pageGoesOn ? null : best;
  }

  /// [node]'s box cut to what its scroll view shows; the whole box when it is
  /// in no scroll view, or shows nothing (then the box is all there is).
  static Rect _shownRect(FocusNode node) {
    final rect = node.rect;
    final context = node.context;
    if (context == null || !context.mounted) return rect;
    final scrollable = Scrollable.maybeOf(context);
    final box = scrollable?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return rect;
    final view = box.localToGlobal(Offset.zero) & box.size;
    final shown = rect.intersect(view);
    return shown.width > 0 && shown.height > 0 ? shown : rect;
  }

  /// Lets a move off the edge of a page **inside the navigation shell** carry
  /// on into the shell: down from a hub's last tile reaches the tab bar.
  ///
  /// Every page has a focus scope of its own, and Flutter's directional
  /// traversal stops at a scope's edge unless told otherwise — and the tab
  /// bar is outside the page, in the shell. So a learner on arrow keys could
  /// step through a hub but never leave it, and gaze on Settings could never
  /// reach the tabs. Only a current *page* on the shell's own navigator gets
  /// this: a sheet or a dialog stays a closed box, and a page pushed over the
  /// whole shell has nothing behind it that it should lead to.
  static void _openShellPageEdge(FocusNode node) {
    final scope = node is FocusScopeNode ? node : node.nearestScope;
    if (scope == null || !_isShellPage(scope)) return;
    scope.directionalTraversalEdgeBehavior = TraversalEdgeBehavior.parentScope;
  }

  /// The navigation shell's current page inside [scope] — when [scope] is
  /// the shell's own, around it — or null.
  static FocusScopeNode? _shellPageInside(FocusScopeNode scope) {
    for (final n in scope.traversalDescendants) {
      if (n is FocusScopeNode && _isShellPage(n)) return n;
    }
    return null;
  }

  /// Whether [scope] is the current page on a navigator nested inside the
  /// app's own — the navigation shell's.
  static bool _isShellPage(FocusScopeNode scope) {
    final context = scope.context;
    if (context == null || !context.mounted) return false;
    final route = ModalRoute.of(context);
    if (route is! PageRoute || !route.isCurrent) return false;
    final navigator = route.navigator;
    if (navigator == null) return false;
    final root = Navigator.maybeOf(context, rootNavigator: true);
    return !identical(navigator, root);
  }

  /// The surface a move from [node] may reach: its own page or dialog — or,
  /// for a page inside the navigation shell, the shell around it.
  static FocusScopeNode? reachableScope(FocusNode node) {
    final scope = node is FocusScopeNode ? node : node.nearestScope;
    if (scope == null) return null;
    return _isShellPage(scope) ? (scope.enclosingScope ?? scope) : scope;
  }

  /// The nearest row of controls that Flutter's own ▲ ▼ would jump over, or
  /// null when it would not skip one.
  ///
  /// Flutter's directional traversal looks first in the current control's
  /// column. From a small button at the far left of an app bar, ▼ therefore
  /// went past a text field whose box starts a little further right — its
  /// own padding insets it — and landed on the full-width button under it.
  /// On the Join Home Group screen the code field could not be reached going
  /// down at all, and every form under a back button had the same gap.
  ///
  /// Flutter's pick is kept except for exactly that: a row of controls lying
  /// wholly between this control and the one it would choose. Side-by-side
  /// layouts (a tall card beside short ones) are left alone, because their
  /// controls overlap vertically rather than forming a row in between.
  static FocusNode? _skippedRow(FocusNode node, TraversalDirection direction) {
    final down = direction == TraversalDirection.down;
    if (!down && direction != TraversalDirection.up) return null;
    if (node is FocusScopeNode) return null; // nothing focused yet
    // Rows of a page, not the shell's own controls: from a tab or the AI
    // Buddy, the move is [_shellControlToward]'s. From the tab bar, the AI
    // Buddy floating off at the right counted as a row between each tab and
    // the page, and up from every tab went to it.
    final own = node.nearestScope;
    if (own != null && _shellPageInside(own) != null) return null;
    final Rect from;
    try {
      from = node.rect;
    } catch (_) {
      return null;
    }
    final ahead = <({FocusNode node, Rect rect})>[];
    for (final n in _readingOrder(node)) {
      if (identical(n, node)) continue;
      final Rect r;
      try {
        r = n.rect;
      } catch (_) {
        continue;
      }
      final dy = r.center.dy - from.center.dy;
      if (down ? dy > rowSlack : dy < -rowSlack) ahead.add((node: n, rect: r));
    }
    if (ahead.isEmpty) return null;
    // What Flutter would choose: the nearest control in this column.
    final inColumn = [
      for (final c in ahead)
        if (c.rect.right > from.left && c.rect.left < from.right) c,
    ];
    if (inColumn.isEmpty) return null;
    double gap(Rect r) => (r.center.dy - from.center.dy).abs();
    final pick = inColumn.reduce((a, b) => gap(a.rect) <= gap(b.rect) ? a : b);
    // Rows wholly between here and there: past this control as well as short
    // of that one. A control level with this one is beside it, not between —
    // up from the AI Buddy, level with a guest's last deck, went to that deck
    // instead of the one above it.
    final between = [
      for (final c in ahead)
        if (down
            ? c.rect.top >= from.bottom - rowSlack &&
                c.rect.bottom <= pick.rect.top + rowSlack
            : c.rect.bottom <= from.top + rowSlack &&
                c.rect.top >= pick.rect.bottom - rowSlack)
          if (!identical(c.node, pick.node)) c,
    ];
    if (between.isEmpty) return null;
    final nearest = between.map((c) => gap(c.rect)).reduce((a, b) => a < b ? a : b);
    final row = [
      for (final c in between)
        if (gap(c.rect) - nearest <= rowSlack) c,
    ];
    double across(Rect r) => (r.center.dx - from.center.dx).abs();
    return row.reduce((a, b) => across(a.rect) <= across(b.rect) ? a : b).node;
  }

  /// Controls whose centres are this close share a row.
  static const double rowSlack = 8;

  /// Focuses [to] for a move this driver chose itself, wiping Flutter's
  /// memory of the arrow steps before it.
  ///
  /// Flutter remembers its own steps so that the opposite arrow comes back
  /// the same way, and a step made here bypasses that record. On Home, after
  /// the tab bar and the AI Buddy, ▲ from the last category jumped two rows
  /// up into another column — where an arrow had last left the page.
  static void _focusChosen(FocusNode from, FocusNode to) {
    focusChosen(to, from: from);
  }

  /// [_focusChosen] for a screen that moves focus itself, after the learner
  /// acts rather than on an arrow: Drag & Drop handing focus to the next word
  /// once one is placed. Without the wipe, the next arrow retraced the steps
  /// that led to a control the screen had since taken away.
  static void focusChosen(FocusNode to, {FocusNode? from}) {
    for (final node in [?from, to]) {
      for (FocusScopeNode? s = node.nearestScope;
          s != null;
          s = s.enclosingScope) {
        final context = s.context;
        if (context == null || !context.mounted) continue;
        FocusTraversalGroup.maybeOf(context)?.invalidateScopeData(s);
      }
    }
    to.requestFocus();
  }

  /// Scrolls the newly focused control into view.
  ///
  /// Traversal will happily focus a widget below the fold — on a long pushed
  /// screen that leaves the learner steering something they cannot see, with
  /// the ring off-screen too. The published-grid path already does this
  /// (`GazeFocusable._ensureVisible`); this keeps the fallback honest on
  /// exactly the long screens it exists for.
  ///
  /// Deferred to the next frame: Flutter applies a focus change asynchronously,
  /// so reading [focused] immediately after [move] still returns the *previous*
  /// node — which would scroll the control the learner just left.
  static void _revealFocused() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = focused?.context;
      if (context == null || !context.mounted) return;
      if (Scrollable.maybeOf(context) == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5, // centre it, like the tile grid does
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Activates the focused control — the same path a keyboard Enter or an
  /// Android TV D-pad centre press takes, so a widget that responds to those
  /// responds to a blink with no extra wiring.
  ///
  /// Returns false when nothing actionable is focused (e.g. the route's bare
  /// scope node), letting the caller try [moveFirst] instead of doing nothing.
  ///
  /// Success is decided by *finding an enabled action*, not by its return
  /// value: Material's activate action runs the button's `onPressed` and
  /// returns null, so treating null as failure would report every successful
  /// press as a miss.
  static bool activate() {
    final node = focused;
    final context = node?.context;
    if (context == null) return false;
    // A control scrolled out of sight is not what the learner is pressing:
    // the caller starts again from the screen instead.
    if (node is! FocusScopeNode && !isOnScreen(node!)) return false;
    const intent = ActivateIntent();
    final action = Actions.maybeFind<ActivateIntent>(context, intent: intent);
    if (action == null || !action.isEnabled(intent)) return false;
    Actions.invoke(context, intent);
    return true;
  }

  /// Scanning mode's step over a covering route: moves focus to the next
  /// control in reading order, wrapping from the last back to the first, so a
  /// blink-only learner sees each control of a dialog or pushed page light up
  /// in turn. From a bare scope node (a route that has only just appeared)
  /// this lands on its first control.
  ///
  /// A page's own back or close button is passed over ([isBackButton]): the
  /// Back pill does the same thing in the same place on every page. Lit first
  /// on almost every page, it was what a learner's next press hit — the page
  /// they had just opened closed again.
  static bool scanNext() {
    final node = focused;
    if (node == null) return false;
    // Hidden from this one traversal step only.
    final hidden = <FocusNode>[
      for (final n in node.nearestScope?.traversalDescendants ??
          const <FocusNode>[])
        if (!identical(n, node) && isBackButton(n)) n,
    ];
    for (final n in hidden) {
      n.skipTraversal = true;
    }
    try {
      if (node.nextFocus()) {
        _revealFocused();
        return true;
      }
      return false;
    } finally {
      for (final n in hidden) {
        n.skipTraversal = false;
      }
    }
  }

  /// Whether [node] is a page's own back or close button — the app's
  /// [AppBackButton], or Material's [BackButton] / [CloseButton].
  static bool isBackButton(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return false;
    return context.findAncestorWidgetOfExactType<AppBackButton>() != null ||
        context.findAncestorWidgetOfExactType<BackButton>() != null ||
        context.findAncestorWidgetOfExactType<CloseButton>() != null;
  }

  /// How many controls come after the focused one on its surface (those laid
  /// out — a lazy list builds only what is near the screen).
  static int remainingAfterFocused() {
    final node = focused;
    if (node == null) return 0;
    final order = _readingOrder(node);
    final index = order.indexWhere((n) => identical(n, node));
    return index < 0 ? order.length : order.length - index - 1;
  }

  /// Activates [node] — a control that has just lost the highlight (a press
  /// that landed a moment after scanning moved on). See [activate].
  static bool activateNode(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return false;
    const intent = ActivateIntent();
    final action = Actions.maybeFind<ActivateIntent>(context, intent: intent);
    if (action == null || !action.isEnabled(intent)) return false;
    Actions.invoke(context, intent);
    return true;
  }

  /// Whether [node] has a place on the screen: laid out, with a real
  /// rectangle, inside the list that scrolls it and inside the screen.
  ///
  /// A control scrolled far out of its list is kept alive off stage, its
  /// rectangle not a number, and no direction from it leads anywhere. Once
  /// TalkBack, a finger or a mouse wheel had moved the page under the D-pad
  /// focus, the controller said "Nothing more that way" at every press, and
  /// so did the arrow keys (found on the tablet, 29 Oct).
  static bool isOnScreen(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return false;
    final Rect r;
    try {
      r = node.rect;
    } catch (_) {
      return false;
    }
    if (!r.isFinite || r.isEmpty) return false;
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (viewport is RenderBox && viewport.attached && viewport.hasSize) {
      final shown = MatrixUtils.transformRect(
        viewport.getTransformTo(null),
        Offset.zero & viewport.size,
      );
      if (shown.isFinite && !shown.overlaps(r)) return false;
    }
    return (Offset.zero & MediaQuery.sizeOf(context)).overlaps(r);
  }

  /// Whether the middle of [node] is in view: inside every list around it and
  /// the window, and not under the navigation shell's own controls. Stricter
  /// than [isOnScreen], which a sliver of it satisfies.
  static bool _middleInView(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return false;
    final Offset middle;
    try {
      middle = node.rect.center;
    } catch (_) {
      return false;
    }
    for (var s = Scrollable.maybeOf(context);
        s != null;
        s = Scrollable.maybeOf(s.context)) {
      final viewport = s.context.findRenderObject();
      if (viewport is! RenderBox || !viewport.attached || !viewport.hasSize) {
        continue;
      }
      final shown = MatrixUtils.transformRect(
        viewport.getTransformTo(null),
        Offset.zero & viewport.size,
      );
      if (shown.isFinite && !shown.contains(middle)) return false;
    }
    if (!(Offset.zero & MediaQuery.sizeOf(context)).contains(middle)) {
      return false;
    }
    return !_underShellControl(node, middle);
  }

  /// Whether [middle], a point of a control on a page inside the navigation
  /// shell, lies under one of the shell's own controls drawn over the page —
  /// the tab bar, a guest's floating Home button. A page scrolls on behind the
  /// tab bar: a card there is inside its list and the window, yet out of
  /// sight, and on a scrolled sideways Home ◀ from Cards went to one of them
  /// instead of the Home tab.
  static bool _underShellControl(FocusNode node, Offset middle) {
    FocusScopeNode? page;
    for (final a in node.ancestors) {
      if (a is FocusScopeNode && _isShellPage(a)) {
        page = a;
        break;
      }
    }
    final pageContext = page?.context;
    final shell = page?.enclosingScope;
    if (page == null || shell == null || pageContext == null) return false;
    final pages = Navigator.maybeOf(pageContext)?.focusNode;
    for (final other in shell.traversalDescendants) {
      if (other is FocusScopeNode || other.context == null) continue;
      if (other.ancestors.contains(page)) continue;
      // The shell's other pages, hidden under this one.
      if (pages != null && other.ancestors.contains(pages)) continue;
      final Rect r;
      try {
        r = other.rect;
      } catch (_) {
        continue;
      }
      if (r.contains(middle)) return true;
    }
    return false;
  }

  /// Whether a move from [from] may count [other] as lying ahead: from the tab
  /// bar or a floating button, only what is in view on the page. A page's
  /// controls built past its edge lie "below" a tab by their position alone.
  static bool countsAhead(FocusNode from, FocusNode other) {
    final own = from.nearestScope;
    if (own == null || from is FocusScopeNode || _isShellPage(own)) return true;
    final page = _shellPageInside(own);
    if (page == null || !other.ancestors.contains(page)) return true;
    return _middleInView(other);
  }

  /// When the focus has no place on the screen ([isOnScreen]), or rests on a
  /// bare scope (a screen reader let go of it), focuses the first control on
  /// screen — the last, when not going [forward] — and returns true. The
  /// next press starts from what the learner sees.
  ///
  /// Content first: the app bar's back button is on screen on every page,
  /// and "first on screen" would otherwise be Back, far from where TalkBack
  /// had read to.
  static bool startOnScreen({required bool forward}) {
    final node = focused;
    if (node == null) return false;
    if (node is! FocusScopeNode && isOnScreen(node)) return false;
    final shown = [
      for (final n in _readingOrder(node))
        if (isOnScreen(n)) n,
    ];
    if (shown.isEmpty) return false;
    // In the list the focus was left in, when any of it is on screen.
    final list = node is FocusScopeNode || node.context == null
        ? null
        : Scrollable.maybeOf(node.context!);
    final inList = list == null
        ? const <FocusNode>[]
        : [
            for (final n in shown)
              if (Scrollable.maybeOf(n.context!) == list) n,
          ];
    final content = [
      for (final n in inList.isNotEmpty ? inList : shown)
        if (!isBackButton(n)) n,
    ];
    final from = content.isNotEmpty
        ? content
        : (inList.isNotEmpty ? inList : shown);
    final pick = forward ? from.first : from.last;
    _focusChosen(node, pick);
    _revealFocused();
    return true;
  }

  /// The controls focus can move among on the focused surface, in reading
  /// order (top to bottom, then left to right within a row).
  static List<FocusNode> _readingOrder(FocusNode node) {
    final scope = node.nearestScope;
    if (scope == null) return const [];
    final nodes = <({FocusNode node, Rect rect})>[];
    for (final n in scope.traversalDescendants) {
      if (n is FocusScopeNode || n.context == null) continue;
      try {
        final rect = n.rect;
        // Scrolled far out of its list, kept alive off stage: no place to
        // sort by (its rectangle is not a number), and nowhere a learner is.
        if (!rect.isFinite) continue;
        nodes.add((node: n, rect: rect));
      } catch (_) {
        // Not laid out yet — not somewhere the learner can be.
      }
    }
    nodes.sort((a, b) {
      final dy = a.rect.center.dy - b.rect.center.dy;
      // Controls whose centres are this close share a row.
      if (dy.abs() > 8) return dy < 0 ? -1 : 1;
      return a.rect.center.dx.compareTo(b.rect.center.dx);
    });
    return [for (final n in nodes) n.node];
  }

  /// The controls of [node]'s surface in reading order — what the game
  /// controller's X reads out.
  static List<FocusNode> readingOrderOf(FocusNode node) => _readingOrder(node);

  /// Where [node] stands in that reading order, counted from 1, and how many
  /// controls the surface holds — what the game controller says after a move
  /// ("Games, 3 of 12"), because counting out loud is how a learner who
  /// cannot see the screen knows a list has an end. Null off the order.
  static ({int position, int total})? readingPosition(FocusNode node) {
    final order = _readingOrder(node);
    final at = order.indexOf(node);
    if (at < 0) return null;
    return (position: at + 1, total: order.length);
  }

  /// Whether the focused control is the first one on its surface — the place
  /// from which looking up reaches the surface's way out.
  static bool isFirst() {
    final node = focused;
    if (node == null || node is FocusScopeNode) return false;
    final order = _readingOrder(node);
    return order.isNotEmpty && identical(order.first, node);
  }

  /// Whether the focused control is the last one on its surface.
  static bool isLast() {
    final node = focused;
    if (node == null || node is FocusScopeNode) return false;
    final order = _readingOrder(node);
    return order.isNotEmpty && identical(order.last, node);
  }

  /// Whether the focused surface has any control to move to at all.
  static bool hasFocusable() {
    final node = focused;
    return node != null && _readingOrder(node).isNotEmpty;
  }

  /// Closes whatever holds the focus — the dialog, the sheet or the page —
  /// exactly as the system Back button would. It asks the navigator the
  /// focused control lives in, so a sheet opened on the navigation shell's own
  /// navigator closes too (the gaze scope's own navigator is a different one).
  static bool popTop() {
    final context = focused?.context;
    if (context == null) return false;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return false;
    navigator.maybePop();
    return true;
  }

  /// Pulls focus onto the first focusable control of the current scope. Used
  /// when a route has just appeared and focus is still resting on its scope
  /// node, so the learner's first head move lands somewhere visible instead of
  /// being swallowed.
  static bool moveFirst() {
    final node = focused;
    if (node == null) return false;
    if (startOnScreen(forward: true)) return true;
    // Down then right covers both column- and row-shaped layouts; whichever
    // finds a node first wins.
    return node.focusInDirection(TraversalDirection.down) ||
        node.focusInDirection(TraversalDirection.right);
  }

  /// Focuses the very first control of the focused surface, scrolling back up
  /// to it first.
  ///
  /// "First" has to mean the top of the page. A long page is a lazy list —
  /// only the controls near the screen exist — so the first control found
  /// from the bottom of the Gaze Control settings was mid-page ("Off", under
  /// Smoothing): a scanning learner went round the lower half for ever and
  /// never reached "Enable Gaze Control" or "Try it now" again, and a head
  /// learner wrapping off the bottom landed somewhere in the middle.
  static bool moveToStart() => _moveToEdge(start: true);

  /// Focuses the very last control of the focused surface, scrolling down to
  /// it first — the end of the page, as [moveToStart] finds its start.
  static bool moveToEnd() => _moveToEdge(start: false);

  static bool _moveToEdge({required bool start}) {
    final node = focused;
    final context = node?.context;
    if (node == null || context == null) return false;
    var scrolled = false;
    var scrollable = context.findAncestorStateOfType<ScrollableState>();
    while (scrollable != null) {
      final position = scrollable.position;
      if (position.hasPixels &&
          position.hasContentDimensions &&
          (start
              ? position.pixels > position.minScrollExtent
              : position.pixels < position.maxScrollExtent)) {
        position.jumpTo(
          start ? position.minScrollExtent : position.maxScrollExtent,
        );
        scrolled = true;
      }
      scrollable = scrollable.context.findAncestorStateOfType<ScrollableState>();
    }
    if (!scrolled) return _focusEdge(node, start: start);
    // The edge of the page is laid out on the next frame. The control that
    // had focus may be gone by then (scrolled out of a lazy list), so fall
    // back to its surface.
    final scope = node.nearestScope;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = focused ?? (scope?.context == null ? null : scope);
      if (now != null) _focusEdge(now, start: start);
    });
    WidgetsBinding.instance.scheduleFrame();
    return true;
  }

  static bool _focusEdge(FocusNode node, {required bool start}) {
    if (start) return _focusFirst(node);
    final order = _readingOrder(node);
    if (order.isEmpty) return false;
    if (!identical(order.last, node)) _focusChosen(node, order.last);
    _revealFocused();
    return true;
  }

  /// Steps focus to the next control in reading order — rows top to bottom,
  /// each left to right — or the previous one, wrapping round at either end.
  ///
  /// For an input with only two directions: the game controller's up and
  /// down walk items one at a time, because its left and right belong to the
  /// sections. Stepped by direction instead, down from a heading took one
  /// chip of a row and then the control under it, and Settings' other text
  /// sizes could not be reached at all.
  static bool step({required bool forward}) {
    final node = focused;
    if (node == null) return false;
    if (startOnScreen(forward: forward)) return true;
    if (node is FocusScopeNode) return false;
    final order = _readingOrder(node);
    final at = order.indexOf(node);
    if (at < 0) return false;
    final next = forward ? at + 1 : at - 1;
    if (next < 0) return moveToEnd();
    if (next >= order.length) return moveToStart();
    _focusChosen(node, order[next]);
    _revealFocused();
    return true;
  }

  static bool _focusFirst(FocusNode node) {
    final all = _readingOrder(node);
    if (all.isEmpty) return false;
    // Not the page's own back button (see [scanNext]) — unless that is all
    // there is.
    final order = [
      for (final n in all)
        if (!isBackButton(n)) n,
    ];
    final first = order.isEmpty ? all.first : order.first;
    if (!identical(first, node)) _focusChosen(node, first);
    _revealFocused();
    return true;
  }

  /// Global-coordinate rectangle of the focused control, for drawing a
  /// highlight the learner can actually see. Null when nothing real is focused
  /// or it has not been laid out.
  static Rect? get focusedRect {
    final node = focused;
    if (node == null) return null;
    final renderObject = node.context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    if (!renderObject.attached) return null;
    final origin = renderObject.localToGlobal(Offset.zero);
    return origin & renderObject.size;
  }
}
