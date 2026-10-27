import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_home_tiles.dart';

import 'deep_scroll.dart' show scrollEachVertical;

/// One thing a finger can tap, and which D-pad paths can reach it.
///
/// The app has three: the gaze D-pad and the game controller both walk the
/// cells a hub publishes (plus the tab bar), and a plain D-pad — arrow keys
/// on a keyboard, a remote, a switch box in arrow mode, the web app — moves
/// Flutter's keyboard focus. A target is reachable by the first two when a
/// published cell frames it, and by the third when a focusable control does.
class ReachTarget {
  ReachTarget(this.label, this.at);

  final String label;

  /// Where it was first seen (dp, on screen).
  final Offset at;

  /// A published grid cell or a tab-bar item frames it.
  bool inGrid = false;

  /// A focusable control of about its size frames it.
  bool focusable = false;

  /// Labels of other targets that shared its grid cell. A cell opens one
  /// thing, so a second target inside it is unreachable by the grid.
  final Set<String> sharesCellWith = {};

  /// The widgets that made it, nearest first, for the report.
  String madeBy = '?';

  @override
  String toString() =>
      '"$label" @ (${at.dx.round()}, ${at.dy.round()}) made by $madeBy';
}

String _creatorChain(RenderObject owner) => owner.debugCreator
    .toString()
    .split('←')
    .map((s) => s.trim().replaceAll(RegExp(r'[-#][0-9a-f]{5}\b'), ''))
    .where((s) => s.isNotEmpty)
    .take(6)
    .join(' ← ');

/// What [surveyDpadReach] saw on one screen.
class ReachReport {
  ReachReport(this.targets);

  final Map<String, ReachTarget> targets;

  Iterable<ReachTarget> get notInGrid =>
      targets.values.where((t) => !t.inGrid);
  Iterable<ReachTarget> get notFocusable =>
      targets.values.where((t) => !t.focusable);
  Iterable<ReachTarget> get sharedCells =>
      targets.values.where((t) => t.sharesCellWith.isNotEmpty);
}

Rect _globalRect(RenderBox box) =>
    box.localToGlobal(Offset.zero) & box.size;

/// The grid cell [owner]'s control sits in: its nearest [GazeFocusable] or
/// [GazeShellFocusable] — or a tab of the shell's bar, the grid's last row —
/// else null. Decided by the widget tree rather than by position, so a
/// button floating over a tile is not mistaken for part of the tile.
Element? _cellOf(RenderObject owner) {
  final creator = owner.debugCreator;
  if (creator is! DebugCreator) return null;
  bool isCell(Widget w) =>
      w is GazeFocusable ||
      w is GazeShellFocusable ||
      w.runtimeType.toString() == '_AnimatedNavItem';
  if (isCell(creator.element.widget)) return creator.element;
  Element? found;
  creator.element.visitAncestorElements((a) {
    if (isCell(a.widget)) {
      found = a;
      return false;
    }
    return true;
  });
  if (found != null) return found;
  // A cell can sit inside the target's own widget (a labelled Semantics
  // around a tile that wraps it).
  void down(Element e, int depth) {
    if (found != null || depth > 12) return;
    if (isCell(e.widget)) {
      found = e;
      return;
    }
    e.visitChildren((c) => down(c, depth + 1));
  }

  creator.element.visitChildren((c) => down(c, 1));
  return found;
}

bool _frames(Rect frame, Rect target) =>
    frame.inflate(1).contains(target.center);

/// The render object that made each semantics node, by node id.
Map<int, RenderObject> _semanticsOwners(WidgetTester tester) {
  final out = <int, RenderObject>{};
  void walk(RenderObject ro) {
    final node = ro.debugSemantics;
    if (node != null) out.putIfAbsent(node.id, () => ro);
    ro.visitChildren(walk);
  }

  for (final view in tester.binding.renderViews) {
    walk(view);
  }
  return out;
}

/// Whether a directional D-pad press can land on the control [owner] made:
/// a focus node of about the target's own size sits around it (an InkWell's)
/// or inside it (a button wrapped in a labelled Semantics). A page-wide
/// Focus (a key handler) frames everything and reaches nothing, so size
/// matters; so does [FocusNode.canRequestFocus], which a disabled control
/// or an ExcludeFocus above it turns off.
bool _hasOwnFocus(RenderObject owner, Rect target, {bool merged = false}) {
  final creator = owner.debugCreator;
  if (creator is! DebugCreator) return false;
  final element = creator.element;
  final targetArea = target.width * target.height;

  bool usable(FocusNode node, {required bool around}) {
    if (node is FocusScopeNode) return false;
    if (!node.canRequestFocus || node.skipTraversal) return false;
    final ro = node.context?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return false;
    final r = _globalRect(ro);
    final area = r.width * r.height;
    if (around) return _frames(r, target) && area <= targetArea * 3;
    // A merged node (a text field's, a row that reads as one with its
    // switch) takes its press from the control inside it, whatever its size.
    return target.inflate(1).contains(r.center) &&
        (merged || area >= targetArea * 0.3);
  }

  var found = false;
  element.visitAncestorElements((a) {
    final w = a.widget;
    if (w is InheritedNotifier<FocusNode> && w.notifier != null) {
      if (w.notifier is FocusScopeNode) return true;
      found = usable(w.notifier!, around: true);
      return false;
    }
    return true;
  });
  if (found) return true;
  void down(Element e) {
    if (found) return;
    final w = e.widget;
    if (w is InheritedNotifier<FocusNode> &&
        w.notifier != null &&
        usable(w.notifier!, around: false)) {
      found = true;
      return;
    }
    e.visitChildren(down);
  }

  element.visitChildren(down);
  return found;
}

/// Surveys the screen on show as each vertical scrolling area scrolls: every
/// tap target a screen reader would stop on, and which D-pad paths reach it.
///
/// [devicePixelRatio] must match the test view's, since semantics rects are
/// in physical pixels.
Future<ReachReport> surveyDpadReach(
  WidgetTester tester, {
  required double devicePixelRatio,
  int maxScrolls = 40,
  double step = 250,
}) async {
  final targets = <String, ReachTarget>{};
  final screen = Offset.zero & tester.view.physicalSize / devicePixelRatio;

  void survey() {
    final owners = _semanticsOwners(tester);
    // Targets seen in each cell this step, to find cells holding two.
    final perCell = <Element, Set<String>>{};

    bool visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      final tappable = data.hasAction(SemanticsAction.tap) ||
          data.hasAction(SemanticsAction.longPress);
      if (tappable &&
          !node.isMergedIntoParent &&
          !data.flagsCollection.isHidden) {
        var rect = node.rect;
        for (SemanticsNode? n = node; n != null; n = n.parent) {
          final t = n.transform;
          if (t != null) rect = MatrixUtils.transformRect(t, rect);
        }
        final dp = Rect.fromLTRB(
          rect.left / devicePixelRatio,
          rect.top / devicePixelRatio,
          rect.right / devicePixelRatio,
          rect.bottom / devicePixelRatio,
        );
        // Wholly on screen: one cut off at an edge is judged once whole.
        if (!dp.isEmpty && screen.inflate(1).contains(dp.topLeft) &&
            screen.inflate(1).contains(dp.bottomRight)) {
          final named = data.label.trim().isNotEmpty
              ? data.label.trim()
              : data.tooltip.trim();
          final label = (named.isEmpty ? '(unnamed)' : named)
              .replaceAll('\n', ' / ');
          // Unnamed targets are told apart by where they sit.
          final key = named.isEmpty
              ? '$label@${dp.center.dx.round()},${dp.center.dy.round()}'
              : label;
          final t = targets.putIfAbsent(key, () => ReachTarget(label, dp.center));
          final owner = owners[node.id];
          if (owner != null) {
            if (t.madeBy == '?') t.madeBy = _creatorChain(owner);
            // A node whose press can only be the control inside it: merged
            // (a text field, a row read as one with its switch), or with no
            // separate tap targets of its own below it.
            var innerTargets = false;
            node.visitChildren((c) {
              final d = c.getSemanticsData();
              if ((d.hasAction(SemanticsAction.tap) ||
                      d.hasAction(SemanticsAction.longPress)) &&
                  !c.isMergedIntoParent) {
                innerTargets = true;
                return false;
              }
              return true;
            });
            final merged = node.mergeAllDescendantsIntoThisNode ||
                data.flagsCollection.isTextField ||
                !innerTargets;
            if (_hasOwnFocus(owner, dp, merged: merged)) t.focusable = true;
          }
          // Flutter gives a node the focus action only when a focusable
          // Focus widget sits on it — the plainest proof there is.
          if (data.hasAction(SemanticsAction.focus)) t.focusable = true;
          if (owner != null) {
            final cell = _cellOf(owner);
            if (cell != null) {
              t.inGrid = true;
              (perCell[cell] ??= {}).add(key);
            }
          }
        }
      }
      node.visitChildren(visit);
      return true;
    }

    for (final view in tester.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root != null) visit(root);
    }
    for (final keys in perCell.values) {
      if (keys.length < 2) continue;
      for (final k in keys) {
        targets[k]!.sharesCellWith.addAll(keys.where((o) => o != k));
      }
    }
  }

  survey();
  await scrollEachVertical(
    tester,
    maxScrolls: maxScrolls,
    step: step,
    onStep: survey,
  );
  return ReachReport(targets);
}

/// How [surveyDpadReach] names a target: its label (or tooltip), one line.
String? _targetKey(SemanticsNode node) {
  final data = node.getSemanticsData();
  final named =
      data.label.trim().isNotEmpty ? data.label.trim() : data.tooltip.trim();
  if (named.isEmpty) return null;
  return named.replaceAll('\n', ' / ');
}

bool _isTarget(SemanticsNode node) {
  final data = node.getSemanticsData();
  return (data.hasAction(SemanticsAction.tap) ||
          data.hasAction(SemanticsAction.longPress)) &&
      !data.flagsCollection.isHidden;
}

/// The tap target the D-pad ring frames when [focus] holds focus: the
/// on-screen target overlapping the control's box the most. Matched by area,
/// not by the widget tree, because a tile's label and its tap often live on
/// different semantics nodes (My Day: a labelled container over an InkWell).
String? _targetKeyAt(WidgetTester tester, FocusNode focus, double dpr) {
  final Rect box;
  try {
    box = focus.rect;
  } catch (_) {
    return null;
  }
  if (box.isEmpty) return null;
  String? best;
  var bestScore = 0.0;
  bool visit(SemanticsNode node) {
    if (_isTarget(node) && !node.isMergedIntoParent) {
      var rect = node.rect;
      for (SemanticsNode? n = node; n != null; n = n.parent) {
        final m = n.transform;
        if (m != null) rect = MatrixUtils.transformRect(m, rect);
      }
      final dp = Rect.fromLTRB(rect.left / dpr, rect.top / dpr,
          rect.right / dpr, rect.bottom / dpr);
      final overlap = dp.intersect(box);
      if (!overlap.isEmpty && overlap.width > 0 && overlap.height > 0) {
        final inter = overlap.width * overlap.height;
        final union = dp.width * dp.height + box.width * box.height - inter;
        final score = inter / union;
        if (score > bestScore) {
          bestScore = score;
          best = _targetKey(node);
        }
      }
    }
    node.visitChildren(visit);
    return true;
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return bestScore >= 0.4 ? best : null;
}

/// The same, by the widget tree: the nearest tappable semantics node inside
/// the focused control, else around it — for controls whose box and target
/// differ in size (a chip inside a padded strip).
String? _targetKeyFor(FocusNode focus) {
  final ro = focus.context?.findRenderObject();
  if (ro == null) return null;
  SemanticsNode? inside;
  void down(RenderObject o, int depth) {
    if (inside != null || depth > 30) return;
    final node = o.debugSemantics;
    if (node != null && _isTarget(node) && _targetKey(node) != null) {
      inside = node;
      return;
    }
    o.visitChildren((c) => down(c, depth + 1));
  }

  down(ro, 0);
  var node = inside;
  if (node == null) {
    for (RenderObject? o = ro; o != null; o = o.parent) {
      final s = o.debugSemantics;
      if (s != null && _isTarget(s)) {
        node = s;
        break;
      }
    }
  }
  while (node != null && node.isMergedIntoParent && node.parent != null) {
    node = node.parent;
  }
  return node == null ? null : _targetKey(node);
}

/// Every tap target an arrow-key D-pad can land on, from a fresh page.
///
/// Explores exhaustively: from each control reached, each of the four
/// arrows in turn — pressing again when a press only scrolled the page (a
/// long list builds its next controls as they scroll in). The keys go
/// through the app's real shortcuts, so this is the path a keyboard, a
/// remote or a switch box takes. Between presses it jumps focus back to the
/// control being explored, which a learner cannot do; the traversal's memory
/// of earlier moves is wiped each time so the jump leaves no trace.
Future<Set<String>> walkArrowKeys(
  WidgetTester tester, {
  required double devicePixelRatio,
  int maxControls = 300,
  Set<String>? straight,
}) async {
  final reached = <String>{};
  // Named once each, after scrolling into view: in the middle of a press
  // the control is still moving, and often cannot be named yet.
  final names = <FocusNode, String>{};
  final seen = <FocusNode>{};
  final queue = <FocusNode>[];

  FocusNode? current() {
    final f = FocusManager.instance.primaryFocus;
    return f == null || f is FocusScopeNode ? null : f;
  }

  Future<void> land(FocusNode? f) async {
    if (f == null) return;
    if (seen.add(f)) queue.add(f);
    if (names.containsKey(f)) return;
    final ctx = f.context;
    if (ctx != null && ctx.mounted && Scrollable.maybeOf(ctx) != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.5);
      await tester.pump();
    }
    final key = _targetKeyAt(tester, f, devicePixelRatio) ?? _targetKeyFor(f);
    if (key != null) {
      reached.add(key);
      names[f] = key;
    }
  }

  Future<FocusNode?> press(LogicalKeyboardKey key) async {
    final before = current();
    for (var i = 0; i < 2; i++) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      if (!identical(current(), before)) break;
    }
    return current();
  }

  final first = await press(LogicalKeyboardKey.arrowDown);
  await land(first);
  // The first press, from nothing focused, lands where a learner starts.
  final start = names[first];
  if (start != null) straight?.add(start);
  const keys = [
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowLeft,
  ];
  while (queue.isNotEmpty && seen.length < maxControls) {
    final from = queue.removeAt(0);
    for (final key in keys) {
      final ctx = from.context;
      if (ctx == null || !ctx.mounted || !from.canRequestFocus) break;
      from.requestFocus();
      await tester.pump();
      for (FocusScopeNode? s = from.nearestScope;
          s != null;
          s = s.enclosingScope) {
        final scopeContext = s.context;
        if (scopeContext == null || !scopeContext.mounted) continue;
        FocusTraversalGroup.maybeOf(scopeContext)?.invalidateScopeData(s);
      }
      final to = await press(key);
      final towardKey =
          to != null && !identical(to, from) && _toward(key, from, to);
      await land(to);
      final name = names[to];
      if (towardKey && name != null) straight?.add(name);
    }
  }
  return reached;
}

/// Whether [to] lies [key]'s way from [from]: the move a learner expects,
/// as opposed to one that wraps round or carries on in reading order. A
/// control reached only that other way is one nobody would find — the AI
/// Buddy on a guest's Cards page was "reached" only by ◀ from the first
/// deck, which went backwards round the page to it.
bool _toward(LogicalKeyboardKey key, FocusNode from, FocusNode to) {
  final Rect a, b;
  try {
    a = from.rect;
    b = to.rect;
  } catch (_) {
    return true; // scrolled out of a lazy list: no way to tell
  }
  if (key == LogicalKeyboardKey.arrowDown) return b.center.dy > a.center.dy + 1;
  if (key == LogicalKeyboardKey.arrowUp) return b.center.dy < a.center.dy - 1;
  if (key == LogicalKeyboardKey.arrowRight) {
    return b.center.dx > a.center.dx + 1;
  }
  return b.center.dx < a.center.dx - 1;
}

/// The tap targets a run of [key] presses lands on, from wherever focus is
/// (a fresh page: nothing yet), until the run comes back round or stops.
///
/// A learner on a D-pad goes down a page, or steps right through it — the
/// app's right arrow carries on to the next row at the end of one — so two
/// runs, one each way from a fresh page, between them cover everything an
/// arrow can reach. The keys go through the app's real shortcuts: the path a
/// keyboard, a remote or a switch box takes.
Future<Set<String>> runArrowKeys(
  WidgetTester tester, {
  required double devicePixelRatio,
  required LogicalKeyboardKey key,
  int maxPresses = 160,
  Set<String>? straight,
}) async {
  final reached = <String>{};
  final seen = <FocusNode>{};
  FocusNode? last;
  var stuck = 0;
  for (var i = 0; i < maxPresses; i++) {
    await tester.sendKeyEvent(key);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final f = FocusManager.instance.primaryFocus;
    if (f == null || f is FocusScopeNode) continue;
    if (identical(f, last)) {
      // Only scrolled — or at the edge for good.
      if (++stuck >= 3) break;
      continue;
    }
    stuck = 0;
    final towardKey = last == null || _toward(key, last, f);
    last = f;
    if (!seen.add(f)) break; // round again
    final ctx = f.context;
    if (ctx != null && ctx.mounted && Scrollable.maybeOf(ctx) != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.5);
      await tester.pump();
    }
    final name = _targetKeyAt(tester, f, devicePixelRatio) ?? _targetKeyFor(f);
    if (name != null) {
      reached.add(name);
      if (towardKey) straight?.add(name);
    }
  }
  return reached;
}
