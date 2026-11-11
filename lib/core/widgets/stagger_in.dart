import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../utils/reduced_motion.dart';

/// A list item's staggered entrance, played only while its list is first
/// appearing.
///
/// Lists that build their items as they scroll in (the decks on Cards, the
/// conversations in Messages, a class's assessments) gave every item a delay
/// by its place in the list. Built when it scrolled into view, the twelfth
/// deck then waited more than a second, blank, before it faded in; and at
/// opacity 0 a widget has no semantics, so for that second TalkBack and the
/// arrow keys could not find it either (Cards held sideways on the Honor, 10
/// Nov: the last decks were "unreached").
///
/// [builder] adds the item's own effects, waiting the delay given to it: the
/// planned one ([base] + [step] × [index]) less the time the list has already
/// been showing. An item built once the list's entrance is over appears as it
/// is, at once. With Reduced Motion an item never animates in: the global
/// default duration that Reduced Motion zeroes does not reach an effect that
/// names its own duration, as these do.
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    required this.builder,
    this.base = Duration.zero,
    this.step = const Duration(milliseconds: 60),
  });

  /// The item's place in its list.
  final int index;

  /// The delay of the first item, and the delay added for each one after it.
  final Duration base;
  final Duration step;

  final Widget child;

  /// The item's entrance: [child] with its effects, after [delay].
  final Widget Function(Widget child, Duration delay) builder;

  /// How long after a list's first item is built a later one still counts as
  /// part of its entrance (the items built with it, and those just below it).
  static const Duration window = Duration(milliseconds: 700);

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> {
  /// When each list (its [ScrollableState], else its route) built its first
  /// staggered item, on the frame clock: the same clock as the animations, so
  /// it also runs right under a widget test's fake time.
  static final Expando<Duration> _listStart = Expando('stagger list start');

  /// The delay this item waits, or null when it simply appears.
  Duration? _delay;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    final planned = widget.base + widget.step * widget.index;
    final Object? list =
        Scrollable.maybeOf(context) ?? ModalRoute.of(context);
    if (list == null) {
      _delay = planned;
      return;
    }
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final start = _listStart[list] ??= now;
    final elapsed = now - start;
    if (elapsed > StaggerIn.window) {
      _delay = null;
      return;
    }
    _delay = planned > elapsed ? planned - elapsed : Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    final delay = _delay;
    if (delay == null || ReducedMotionScope.of(context)) return widget.child;
    return widget.builder(widget.child, delay);
  }
}
