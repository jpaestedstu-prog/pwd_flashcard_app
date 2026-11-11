import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/retrying_listener.dart';

/// A live query the cloud refuses listens again by itself: a refused
/// connection used to stay closed for the rest of the session.
void main() {
  /// Every stream handed out, so a test can feed the newest or fail it.
  List<StreamController<int>> feeds() => <StreamController<int>>[];

  test('after a failure it listens again, and keeps going', () {
    fakeAsync((time) {
      final made = feeds();
      final got = <int>[];
      final errors = <Object>[];
      final listener = RetryingListener<int>(
        open: () {
          final c = StreamController<int>();
          made.add(c);
          return c.stream;
        },
        onData: got.add,
        onError: (e, _) => errors.add(e),
      );
      time.flushMicrotasks();
      expect(made, hasLength(1));

      made.last.add(1);
      time.flushMicrotasks();
      expect(got, [1]);

      made.last.addError('permission-denied');
      time.flushMicrotasks();
      expect(errors, ['permission-denied'], reason: 'reported once');
      expect(made, hasLength(1), reason: 'waits before trying again');

      time.elapse(const Duration(seconds: 5));
      expect(made, hasLength(2), reason: 'listening again');

      made.last.add(2);
      time.flushMicrotasks();
      expect(got, [1, 2], reason: 'the badge goes on changing');
      listener.cancel();
    });
  });

  test('it gives up after three tries: a lasting refusal costs little', () {
    fakeAsync((time) {
      final made = feeds();
      final errors = <Object>[];
      RetryingListener<int>(
        open: () {
          final c = StreamController<int>();
          made.add(c);
          return c.stream;
        },
        onData: (_) {},
        onError: (e, _) => errors.add(e),
      );
      for (var i = 0; i < 6; i++) {
        time.flushMicrotasks();
        if (made.last.hasListener) made.last.addError('refused');
        time.flushMicrotasks();
        time.elapse(const Duration(minutes: 3));
      }
      expect(made, hasLength(4), reason: 'the first, and three more');
      expect(errors, hasLength(4));
    });
  });

  test('an answer that gets through starts the count over', () {
    fakeAsync((time) {
      final made = feeds();
      RetryingListener<int>(
        open: () {
          final c = StreamController<int>();
          made.add(c);
          return c.stream;
        },
        onData: (_) {},
        onError: (_, _) {},
      );
      for (var i = 0; i < 8; i++) {
        time.flushMicrotasks();
        made.last.add(i); // it worked ...
        time.flushMicrotasks();
        made.last.addError('refused'); // ... and was refused again later
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 5));
      }
      expect(made, hasLength(9), reason: 'never ran out of tries');
    });
  });

  test('cancelling stops it, even a try still waiting', () {
    fakeAsync((time) {
      final made = feeds();
      final listener = RetryingListener<int>(
        open: () {
          final c = StreamController<int>();
          made.add(c);
          return c.stream;
        },
        onData: (_) {},
        onError: (_, _) {},
      );
      time.flushMicrotasks();
      made.last.addError('refused');
      time.flushMicrotasks();
      listener.cancel();
      time.elapse(const Duration(minutes: 5));
      expect(made, hasLength(1), reason: 'no new attempt after cancel');
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('a query that cannot even start counts as a failure', () {
    fakeAsync((time) {
      var calls = 0;
      final errors = <Object>[];
      RetryingListener<int>(
        open: () {
          calls++;
          throw StateError('not ready');
        },
        onData: (_) {},
        onError: (e, _) => errors.add(e),
      );
      expect(calls, 1);
      time.elapse(const Duration(minutes: 5));
      expect(calls, 4, reason: 'tried again each time, then stopped');
      expect(errors, hasLength(4));
    });
  });
}
