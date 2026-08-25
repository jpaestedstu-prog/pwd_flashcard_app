import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// A mixin that provides countdown timer functionality for timed game modes.
///
/// The host widget state must call [startTimerIfNeeded] in `initState`
/// and [disposeTimer] in `dispose`.
///
/// Override [onTimeUp] to handle what happens when time runs out.
mixin TimedGameMixin<T extends StatefulWidget> on State<T> {
  @protected
  Timer? countdownTimer;
  int _remainingSeconds = AppConstants.gameTimerSeconds;
  bool _timedModeActive = false;

  /// Measures how long this playthrough has actually been *played*.
  ///
  /// Runs from the moment the screen mounts and is suspended for every
  /// stretch the learner is not playing — the pause overlay, a calming break,
  /// and the app losing foreground all route through [pauseTimer] /
  /// [resumeTimer] regardless of timed mode, so this is time on task rather
  /// than time on screen. That distinction matters for a learner who leaves a
  /// game open, and it is the figure the exports and the parent/teacher
  /// dashboard report.
  final Stopwatch _playClock = Stopwatch();

  /// Seconds of active play in this run, for `GameScore.durationSeconds`.
  int get elapsedSeconds => _playClock.elapsed.inSeconds;

  /// Same clock at millisecond resolution, so a test can assert that a pause
  /// actually stopped it without sleeping for a whole second.
  @visibleForTesting
  int get elapsedMilliseconds => _playClock.elapsed.inMilliseconds;

  /// Whether the timer is active and counting down.
  bool get isTimedMode => _timedModeActive;

  @override
  void initState() {
    super.initState();
    // Games that never offer timed mode (the two FSL practice modes, the
    // multiplayer quiz) never call [startTimerIfNeeded], so the clock has to
    // start on mount to cover them too.
    _playClock.start();
  }

  /// Remaining seconds on the timer (defaults to [AppConstants.gameTimerSeconds]).
  int get remainingSeconds => _remainingSeconds;

  /// Total seconds for the timer.
  int get totalTimerSeconds => AppConstants.gameTimerSeconds;

  /// Called when time runs out. Override in host to auto-end the game.
  void onTimeUp();

  /// Call this from `initState` or `_startGame` with `timedMode` from the widget.
  void startTimerIfNeeded(bool timedMode) {
    _timedModeActive = timedMode;
    countdownTimer?.cancel();
    _remainingSeconds = AppConstants.gameTimerSeconds;
    // Every game also calls this from its "Play Again" path, so it doubles as
    // the signal that a fresh run has begun — the clock restarts from zero
    // rather than carrying the previous run's minutes into the new score.
    _playClock
      ..reset()
      ..start();
    if (!timedMode) return;
    _startTickerFromRemaining();
  }

  void _startTickerFromRemaining() {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          timer.cancel();
          onTimeUp();
        }
      });
    });
  }

  /// Pause the countdown without losing the remaining seconds. Safe to call
  /// when the timer isn't running (no-op).
  @protected
  void pauseTimer() {
    countdownTimer?.cancel();
    countdownTimer = null;
    _playClock.stop();
  }

  /// Resume a previously paused countdown from the remaining seconds. Only
  /// restarts if the game was in timed mode and time is still on the clock.
  @protected
  void resumeTimer() {
    // The play clock resumes for every game, timed or not — it is the pair to
    // [pauseTimer]'s stop, and the guards below are about the countdown only.
    _playClock.start();
    if (!_timedModeActive) return;
    if (countdownTimer != null) return;
    if (_remainingSeconds <= 0) return;
    _startTickerFromRemaining();
  }

  /// Call this from `dispose`.
  void disposeTimer() {
    countdownTimer?.cancel();
    _playClock.stop();
  }
}
