import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

/// How much slower learning/quiz animations run when Slow-Motion mode is on.
/// 2.0 ≈ half speed. Mirrors [Motion.slowFactor].
const double kSlowMotionFactor = 2.0;

/// Slows **every** Flutter animation rendered while this scope is mounted to
/// roughly half speed when the learner has enabled Slow-Motion mode.
///
/// It works by driving Flutter's global [timeDilation] (the animation/ticker
/// clock multiplier), which covers implicit animations, `flutter_animate`,
/// Lottie, and hand-rolled `AnimationController`s alike — without having to
/// touch every duration literal in the games. Crucially this does **not**
/// touch TTS / audio playback (a separate engine) or other devices' clocks,
/// so the requirement "do not change TTS or non-learning UI animations" holds.
///
/// Wrap only learning surfaces (games, flashcards, quizzes). The previous
/// global value is captured on mount and restored on dispose, so:
///   * non-learning screens are never left slowed, and
///   * nested scopes (e.g. a game launched from a lesson) restore correctly.
///
/// Default off ([AppSettings.slowMotionEnabled]); a no-op when the flag is off.
class SlowMotionScope extends ConsumerStatefulWidget {
  final Widget child;

  /// Multiplier applied when slow-motion is enabled.
  final double factor;

  const SlowMotionScope({
    super.key,
    required this.child,
    this.factor = kSlowMotionFactor,
  });

  @override
  ConsumerState<SlowMotionScope> createState() => _SlowMotionScopeState();
}

class _SlowMotionScopeState extends ConsumerState<SlowMotionScope> {
  /// The global time scale captured when this scope mounted. Restored on
  /// dispose so we only ever undo our own change.
  double _restoreTo = 1.0;

  /// Whether we currently have slow-motion applied to the global clock.
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    _restoreTo = timeDilation;
    // Apply after the first frame so the *entry* page transition (a
    // non-learning UI animation) plays at normal speed; only the content
    // that follows is slowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _apply(ref.read(settingsProvider).slowMotionEnabled);
    });
  }

  void _apply(bool enabled) {
    timeDilation = enabled ? widget.factor : _restoreTo;
    _applied = enabled;
  }

  @override
  void dispose() {
    // Restore on the way out so the exit transition and every later screen
    // animate normally. Guarded so we never clobber a value we didn't set.
    if (_applied) timeDilation = _restoreTo;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // React live if the learner flips the toggle while a learning screen is
    // open (e.g. from a settings shortcut).
    ref.listen<bool>(
      settingsProvider.select((s) => s.slowMotionEnabled),
      (_, next) => _apply(next),
    );
    return widget.child;
  }
}
