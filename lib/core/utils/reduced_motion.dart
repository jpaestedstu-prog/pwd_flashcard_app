// Reduced Motion for animations that loop forever.
//
// [Motion] in `motion.dart` is the richer helper and the one to prefer when a
// `WidgetRef` is in scope: it reads `reducedMotion` and `slowMotionEnabled`
// from settings and picks a duration. It answers "how long should this run
// for", which is the wrong question for a loop — a loop has no length, so the
// only answers are "running" and "not running".
//
// `main.dart` sets [Animate.defaultDuration] to zero when the setting is on,
// which is enough for a one-shot entrance — it reads its duration from that
// global — but not for a `repeat()`, which passes its own durations and keeps
// going. Those need to be started and stopped explicitly, which is what the
// two helpers below do.
//
// Both read [ReducedMotionScope], so a widget that uses them **rebuilds the
// moment the learner flips the switch**. That is the whole point: an earlier
// version of this file guarded only in `initState`, so the setting appeared to
// do nothing until the screen was rebuilt — measured on device at 78% idle CPU
// after toggling, versus 0% after a restart.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Carries the live Reduced Motion setting down the tree.
///
/// Installed once, above `MaterialApp` in `main.dart`, so it also covers the
/// overlays inserted in `MaterialApp.builder`. It exists so a plain
/// `StatefulWidget` can react to the setting without being rewritten as a
/// `ConsumerStatefulWidget` — several of these loops live in overlays and in
/// widgets that tests pump on their own, where requiring a `ProviderScope`
/// ancestor would be a needless constraint.
class ReducedMotionScope extends InheritedWidget {
  const ReducedMotionScope({
    required this.reduced,
    required super.child,
    super.key,
  });

  final bool reduced;

  /// Reads the setting **and subscribes** the calling widget to changes in it.
  ///
  /// Falls back to [Animate.defaultDuration] when no scope is present. In the
  /// app the two can never disagree — `main.dart` sets both from the same
  /// setting in the same build — so the fallback only matters outside it: a
  /// widget pumped bare in a test still honours a test that sets the global,
  /// and no caller has to care which of the two mechanisms it sits under.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ReducedMotionScope>()
          ?.reduced ??
      (Animate.defaultDuration == Duration.zero);

  @override
  bool updateShouldNotify(ReducedMotionScope oldWidget) =>
      oldWidget.reduced != reduced;
}

/// A key that changes when Reduced Motion is toggled — for `flutter_animate`.
///
/// `.animate(onPlay: (c) => c.repeat())` hands its controller to a callback
/// that `flutter_animate` only invokes when playback *starts*, so there is no
/// later moment at which the widget could stop it. Rebuilding is not enough
/// either: `Animate` only re-plays on update when its total duration changed,
/// and an effect that names its own duration never sees `defaultDuration`
/// move.
///
/// Re-keying sidesteps both. A changed key replaces the element, so the old
/// controller is disposed with it and the new one asks [motionLoop] afresh
/// whether it should loop at all — which is why the two are always used
/// together.
///
/// Pass [id] to tell two *sibling* animations apart; keys only have to be
/// unique among siblings, and identical `ValueKey`s in one children list are an
/// error.
Key motionKey(BuildContext context, [Object? id]) =>
    ValueKey<Object>(('reducedMotion', ReducedMotionScope.of(context), id));

extension MotionAwareController on AnimationController {
  /// Runs this controller's endless loop only while motion is allowed.
  ///
  /// Call it from `build`, passing a [reduced] that the build method actually
  /// read this frame — `ref.watch(settingsProvider.select((s) => s.reducedMotion))`
  /// where a ref is in scope, otherwise `ReducedMotionScope.of(context)`. Either
  /// one subscribes the widget, which is what makes the toggle immediate;
  /// reading the setting outside build (in `initState`, say) reverts this to the
  /// stale behaviour it exists to fix. Leave the controller un-started in
  /// `initState`. Idempotent in both
  /// directions: the `isAnimating` checks mean repeated toggling can neither
  /// stack a second ticker on a controller already looping nor stop one twice,
  /// so no duplicate animation or timer can accumulate.
  ///
  /// Stopping deliberately leaves the controller wherever it was rather than
  /// rewinding it. Every frame of these loops is a valid still, and snapping
  /// back to `lowerBound` is a jump — motion — at the exact moment the learner
  /// asked for less of it. Pass [restAt] where a specific resting value does
  /// matter (an identity transform, say).
  ///
  /// For *endless* loops only. A `repeat(count: n)` ends on its own and is
  /// already covered by [Animate.defaultDuration].
  void syncMotionLoop(
    bool reduced, {
    double? min,
    double? max,
    bool reverse = false,
    Duration? period,
    double? restAt,
  }) {
    if (reduced) {
      if (isAnimating) {
        stop();
        if (restAt != null) value = restAt;
      }
    } else if (!isAnimating) {
      repeat(min: min, max: max, reverse: reverse, period: period);
    }
  }

}

/// The `onPlay` callback for a `flutter_animate` loop — or null to not loop.
///
/// Pair it with [motionKey] on the same `.animate()`:
///
/// ```dart
/// widget.animate(
///   key: motionKey(context),
///   onPlay: motionLoop(context, reverse: true),
/// )
/// ```
///
/// Both halves are needed and they do different jobs. This one decides whether
/// the loop starts at all; the key is what forces `Animate` to rebuild its
/// controller so the decision is re-made — on its own, a changed `onPlay` is
/// ignored, because `Animate` only replays when its *duration* changes and an
/// effect that names its own duration never sees `defaultDuration` move.
///
/// Returning null leaves the one-shot entrance effects (`fadeIn`, `scale`)
/// alone: they still play, and [Animate.defaultDuration] already collapses
/// them to nothing when the setting is on. Only the looping stops.
AnimateCallback? motionLoop(
  BuildContext context, {
  double? min,
  double? max,
  bool reverse = false,
  Duration? period,
}) {
  if (ReducedMotionScope.of(context)) return null;
  return (controller) => controller.repeat(
        min: min,
        max: max,
        reverse: reverse,
        period: period,
      );
}
