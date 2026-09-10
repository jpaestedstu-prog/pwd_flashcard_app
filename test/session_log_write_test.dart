import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/session_tracker.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';

/// Session logging — the write side.
///
/// Everything that reports study time reads `sessions_<profileId>`: the
/// Progress week panel, Detailed Analytics, the streak calendar, the teacher
/// dashboard and both CSV/research exports. For the whole life of the app that
/// key was empty, because `SessionTracker` was only ever constructed inside a
/// lazy Riverpod provider that nothing read — so the observer never registered
/// and no row was ever written.
///
/// These tests pin the two properties that made it silent, so it cannot go
/// quiet again without failing here:
///   1. an in-progress sitting is on disk, not only a finished one;
///   2. checkpointing the same sitting overwrites its row rather than
///      appending one per minute.
///
/// Plain `test()`, not `testWidgets`: a Hive write started inside the
/// fake-async zone leaves its Future pending and hangs teardown.
void main() {
  // `SessionTracker` registers a `WidgetsBindingObserver`, so it needs a
  // binding. This gives it a real one without moving to `testWidgets` — which
  // would put the Hive writes below inside a fake-async zone and hang teardown.
  TestWidgetsFlutterBinding.ensureInitialized();

  const profileId = 'p_session';

  setUpAll(() async {
    const dir = './build/test_cache/session_log_write';
    try {
      final d = Directory(dir);
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {}
    Hive.init(dir);
    for (final name in const <String>['sessions']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (total, deleted) => false);
      }
    }
  });

  tearDown(() async => Hive.box('sessions').clear());
  tearDownAll(() async => Hive.deleteFromDisk());

  group('upsertSessionLog', () {
    test('replaces the row carrying the same id instead of appending', () async {
      await HiveService.upsertSessionLog(profileId, {
        'id': 's1',
        'date': '2026-08-28T10:00:00.000',
        'durationSeconds': 60,
        'gamesPlayed': 0,
        'cardsReviewed': 0,
      });
      await HiveService.upsertSessionLog(profileId, {
        'id': 's1',
        'date': '2026-08-28T10:00:00.000',
        'durationSeconds': 180,
        'gamesPlayed': 2,
        'cardsReviewed': 0,
      });

      final logs = HiveService.getSessionLogs(profileId);
      expect(logs, hasLength(1), reason: 'a checkpoint must not add a row');
      expect(logs.single['durationSeconds'], 180);
      expect(logs.single['gamesPlayed'], 2);
    });

    test('a different id is a different sitting', () async {
      await HiveService.upsertSessionLog(
          profileId, {'id': 's1', 'durationSeconds': 60});
      await HiveService.upsertSessionLog(
          profileId, {'id': 's2', 'durationSeconds': 90});
      expect(HiveService.getSessionLogs(profileId), hasLength(2));
    });

    test('a row with no id still appends, so old callers keep working',
        () async {
      await HiveService.upsertSessionLog(profileId, {'durationSeconds': 30});
      await HiveService.upsertSessionLog(profileId, {'durationSeconds': 30});
      expect(HiveService.getSessionLogs(profileId), hasLength(2));
    });
  });

  group('SessionTracker', () {
    test('registers itself as the active tracker and releases it on dispose',
        () {
      expect(SessionTracker.active, isNull);
      final tracker = SessionTracker(profileId: profileId);
      expect(SessionTracker.active, same(tracker));
      tracker.dispose();
      expect(SessionTracker.active, isNull);
    });

    test('writes the sitting on dispose, counting games played along the way',
        () async {
      final tracker = SessionTracker(profileId: profileId);
      tracker.recordGamePlayed();
      tracker.recordGamePlayed();
      tracker.recordCardsReviewed(5);

      // The tracker refuses to log a sitting under 5 seconds, so backdate the
      // start rather than making the test wait for real time to pass.
      tracker.debugBackdateStart(const Duration(minutes: 3));
      tracker.endCurrentSession();
      await Future<void>.delayed(Duration.zero);

      final logs = HiveService.getSessionLogs(profileId);
      expect(logs, hasLength(1));
      expect(logs.single['durationSeconds'], greaterThanOrEqualTo(180));
      expect(logs.single['gamesPlayed'], 2);
      expect(logs.single['cardsReviewed'], 5);
      tracker.dispose();
    });

    test('an accidental open — under five seconds — is not logged', () async {
      final tracker = SessionTracker(profileId: profileId);
      tracker.endCurrentSession();
      await Future<void>.delayed(Duration.zero);
      expect(HiveService.getSessionLogs(profileId), isEmpty);
      tracker.dispose();
    });

    test('repeated checkpoints of one sitting stay a single row', () async {
      final tracker = SessionTracker(profileId: profileId);
      tracker.debugBackdateStart(const Duration(minutes: 1));
      tracker.debugCheckpoint();
      tracker.debugCheckpoint();
      tracker.debugCheckpoint();
      await Future<void>.delayed(Duration.zero);

      expect(HiveService.getSessionLogs(profileId), hasLength(1));
      tracker.dispose();
    });
  });
}
