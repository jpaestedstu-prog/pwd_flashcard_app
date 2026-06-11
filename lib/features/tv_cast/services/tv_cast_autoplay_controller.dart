import 'dart:async';

/// Drives the periodic "advance to next slide" tick used in flashcard
/// cast mode. The notifier owns one of these and calls [start] when
/// auto-advance should run, [pause]/[resume] to gate it, and [stop]
/// when leaving the cast session.
class TvCastAutoplayController {
  TvCastAutoplayController({required this.onTick});

  final void Function() onTick;
  Timer? _timer;
  Duration _interval = const Duration(seconds: 4);
  bool _paused = false;

  Duration get interval => _interval;

  /// Begins ticking. Idempotent.
  void start({Duration? interval}) {
    if (interval != null) _interval = interval;
    _timer?.cancel();
    if (_paused) return;
    _timer = Timer.periodic(_interval, (_) => onTick());
  }

  /// Stops ticking and clears state — used on cast session teardown.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Pauses the timer without forgetting it. Call [resume] to continue.
  void pause() {
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    _paused = false;
    if (_timer == null) start();
  }

  void setInterval(Duration interval) {
    _interval = interval;
    if (_timer != null) {
      _timer?.cancel();
      _timer = Timer.periodic(_interval, (_) => onTick());
    }
  }

  void dispose() => stop();
}
