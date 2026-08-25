import 'package:flutter/material.dart';

import 'timed_game_mixin.dart';

/// Adds pause / resume / app-lifecycle handling to a game screen.
///
/// Host requirements:
///   * Mix in [TimedGameMixin] first, then [GamePauseMixin].
///   * Call [initPause] from `initState` and [disposePause] from `dispose`.
///   * Override [onPause] / [onResume] to forward to your own controllers
///     (`VideoPlayerController`, `AnimationController`, speech recorder, etc.).
///     The countdown timer is paused / resumed automatically.
///   * Optional: override [savePartialProgress] to record the in-progress run
///     when the user picks "Quit to Hub" from the pause overlay.
mixin GamePauseMixin<T extends StatefulWidget> on TimedGameMixin<T> {
  bool _isPaused = false;
  _LifecycleListener? _lifecycle;

  /// Whether the pause overlay should be shown.
  bool get isPaused => _isPaused;

  /// Call from `initState`.
  void initPause() {
    _lifecycle = _LifecycleListener(_onAppLifecycle);
    WidgetsBinding.instance.addObserver(_lifecycle!);
  }

  /// Call from `dispose`.
  void disposePause() {
    if (_lifecycle != null) {
      WidgetsBinding.instance.removeObserver(_lifecycle!);
      _lifecycle = null;
    }
  }

  /// Show the pause overlay and stop the countdown + any host-owned media.
  void pauseGame() {
    if (_isPaused || !mounted) return;
    pauseTimer();
    onPause();
    setState(() => _isPaused = true);
  }

  /// Hide the pause overlay and restart the countdown + any host-owned media.
  void resumeGame() {
    if (!_isPaused || !mounted) return;
    setState(() => _isPaused = false);
    resumeTimer();
    onResume();
  }

  /// Pauses the countdown + host media for a full-screen calming break, WITHOUT
  /// showing the pause overlay (the break screen covers the game). Unlike
  /// [pauseGame] this leaves [isPaused] false, so when the student returns from
  /// the break they go straight back to playing. Pair with [resumeFromBreak].
  /// Backs the always-visible floating "Break" button during gameplay.
  void holdForBreak() {
    if (!mounted) return;
    pauseTimer();
    onPause();
  }

  /// Resumes the countdown + host media after a calming break opened via
  /// [holdForBreak]. Safe no-op if the screen was disposed during the break.
  void resumeFromBreak() {
    if (!mounted) return;
    resumeTimer();
    onResume();
  }

  /// Override to pause host-owned controllers (video, animation, speech).
  /// Default: no-op.
  @protected
  void onPause() {}

  /// Override to resume host-owned controllers. Default: no-op.
  @protected
  void onResume() {}

  /// Override to record an in-progress run when the user quits via the
  /// pause overlay. Default: no-op. Games typically delegate this to their
  /// existing `_saveProgress()` so a partial play still counts toward stats.
  @protected
  Future<void> savePartialProgress() async {}

  /// Override to remember *where* the learner is when the app is sent to the
  /// background, so the run can be offered back to them later. Default: no-op.
  ///
  /// Distinct from [savePartialProgress]: this must not record a game result.
  /// Pressing Home is not finishing a game, and a young learner is far more
  /// likely to leave that way than to find "Quit to Games" in the pause menu —
  /// so the resume point has to survive it, while the score does not get
  /// written twice.
  @protected
  void onBackgrounded() {}

  void _onAppLifecycle(AppLifecycleState state) {
    // Auto-pause whenever the app loses foreground. We still don't auto-save
    // *progress* on background — only an explicit "Quit to Hub" tap records a
    // partial run — but we do remember the round, via [onBackgrounded].
    if (state != AppLifecycleState.resumed) {
      pauseGame();
    }
    // `inactive` fires for transient interruptions (a permission sheet, the
    // notification shade), which the learner comes straight back from. Only
    // the states that mean "really gone" are worth a write.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      onBackgrounded();
    }
  }
}

class _LifecycleListener with WidgetsBindingObserver {
  _LifecycleListener(this._onChange);
  final void Function(AppLifecycleState) _onChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _onChange(state);
  }
}
