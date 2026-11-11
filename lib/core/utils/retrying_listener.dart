import 'dart:async';

/// Keeps a live cloud query open across the failures that end one.
///
/// A Firestore listener that the server refuses (a sign-in still renewing, a
/// rule that needs a record not written yet) is over: it never reports again,
/// and whatever it fed goes quietly stale until the app is next opened. The
/// number on a Home's Messages tile stopped changing that way, for the rest of
/// the session. This one listens again, a few times, a little later each time,
/// and any answer that gets through starts the count over.
///
/// The count is small on purpose. A refusal that lasts (a profile restored on
/// another device) must not read the database for ever on the free plan: after
/// the last attempt it stays closed until the next time the listener is made,
/// which is the next time the profile is opened.
class RetryingListener<T> {
  RetryingListener({
    required Stream<T> Function() open,
    required void Function(T value) onData,
    required void Function(Object error, StackTrace stack) onError,
    List<Duration> retryAfter = defaultRetryDelays,
  }) : _open = open,
       _onData = onData,
       _onError = onError,
       _retryAfter = retryAfter {
    _listen();
  }

  /// How long to wait before each new attempt, in order.
  static const defaultRetryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 30),
    Duration(minutes: 2),
  ];

  final Stream<T> Function() _open;
  final void Function(T value) _onData;
  final void Function(Object error, StackTrace stack) _onError;
  final List<Duration> _retryAfter;

  StreamSubscription<T>? _subscription;
  Timer? _timer;
  var _failures = 0;
  var _cancelled = false;

  void _listen() {
    final Stream<T> stream;
    try {
      stream = _open();
    } catch (e, stack) {
      _failed(e, stack);
      return;
    }
    _subscription = stream.listen(
      (value) {
        _failures = 0;
        _onData(value);
      },
      onError: _failed,
      cancelOnError: true,
    );
  }

  void _failed(Object error, StackTrace stack) {
    if (_cancelled) return;
    _subscription = null;
    _onError(error, stack);
    // [_onError] may have cancelled this listener.
    if (_cancelled || _failures >= _retryAfter.length) return;
    _timer = Timer(_retryAfter[_failures++], () {
      if (!_cancelled) _listen();
    });
  }

  /// Stops listening, and any attempt still waiting.
  Future<void> cancel() async {
    _cancelled = true;
    _timer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }
}
