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

  /// Whether the timer is active and counting down.
  bool get isTimedMode => _timedModeActive;

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
  }

  /// Resume a previously paused countdown from the remaining seconds. Only
  /// restarts if the game was in timed mode and time is still on the clock.
  @protected
  void resumeTimer() {
    if (!_timedModeActive) return;
    if (countdownTimer != null) return;
    if (_remainingSeconds <= 0) return;
    _startTickerFromRemaining();
  }

  /// Call this from `dispose`.
  void disposeTimer() {
    countdownTimer?.cancel();
  }
}
