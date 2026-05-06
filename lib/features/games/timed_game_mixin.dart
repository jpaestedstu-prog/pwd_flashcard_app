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
  Timer? _countdownTimer;
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
    _countdownTimer?.cancel();
    _remainingSeconds = AppConstants.gameTimerSeconds;
    if (!timedMode) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  /// Call this from `dispose`.
  void disposeTimer() {
    _countdownTimer?.cancel();
  }
}
