import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/object_scan/services/object_scan_discovery_service.dart';

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/object_scan_discovery');
    if (!Hive.isBoxOpen('progress')) await Hive.openBox('progress');
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  setUp(() async {
    await Hive.box('progress').clear();
    // Clearing the box is not enough: the service keeps a session mirror of
    // what it wrote (so a read right after a fire-and-forget write is correct),
    // and that mirror would otherwise leak state between tests.
    ObjectScanDiscoveryService.resetWriteCache();
  });

  final day = DateTime(2026, 6, 12, 10);

  group('ObjectScanDiscoveryService', () {
    test('first discovery is new and awards a star', () {
      final r = ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13',
          now: day);
      expect(r.isNew, isTrue);
      expect(r.starAwarded, isTrue);
      expect(ObjectScanDiscoveryService.isDiscovered('p1', 'cr13'), isTrue);
      expect(ObjectScanDiscoveryService.starsAwardedToday('p1', now: day), 1);
    });

    test('rediscovering the same word gives no second star', () {
      ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13', now: day);
      final r = ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13',
          now: day);
      expect(r.isNew, isFalse);
      expect(r.starAwarded, isFalse);
      expect(ObjectScanDiscoveryService.starsAwardedToday('p1', now: day), 1);
    });

    test('stars cap per day but discoveries keep logging', () {
      for (var i = 0; i < ObjectScanDiscoveryService.dailyStarCap; i++) {
        final r = ObjectScanDiscoveryService.recordDiscovery('p1', 'word$i',
            now: day);
        expect(r.starAwarded, isTrue);
      }
      final capped =
          ObjectScanDiscoveryService.recordDiscovery('p1', 'extra', now: day);
      expect(capped.isNew, isTrue);
      expect(capped.starAwarded, isFalse);
      expect(ObjectScanDiscoveryService.discoveredWordIds('p1'),
          hasLength(ObjectScanDiscoveryService.dailyStarCap + 1));
    });

    test('the star cap resets the next day', () {
      for (var i = 0; i < ObjectScanDiscoveryService.dailyStarCap; i++) {
        ObjectScanDiscoveryService.recordDiscovery('p1', 'word$i', now: day);
      }
      final nextDay = day.add(const Duration(days: 1));
      final r = ObjectScanDiscoveryService.recordDiscovery('p1', 'fresh',
          now: nextDay);
      expect(r.starAwarded, isTrue);
      expect(
          ObjectScanDiscoveryService.starsAwardedToday('p1', now: nextDay), 1);
    });

    test('profiles are isolated; null profile falls back to guest bucket', () {
      ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13', now: day);
      expect(ObjectScanDiscoveryService.isDiscovered('p2', 'cr13'), isFalse);

      final guest =
          ObjectScanDiscoveryService.recordDiscovery(null, 'cr13', now: day);
      expect(guest.isNew, isTrue);
      expect(ObjectScanDiscoveryService.isDiscovered(null, 'cr13'), isTrue);
      expect(ObjectScanDiscoveryService.isDiscovered('', 'cr13'), isTrue);
    });
  });

  group('tryAwardGameStar (once-per-day per word)', () {
    test('first win today awards; same-day repeat does not', () {
      expect(
          ObjectScanDiscoveryService.tryAwardGameStar('p1', 'a01', now: day),
          isTrue);
      expect(
          ObjectScanDiscoveryService.tryAwardGameStar('p1', 'a01', now: day),
          isFalse);
      // A different word the same day still awards.
      expect(
          ObjectScanDiscoveryService.tryAwardGameStar('p1', 'a02', now: day),
          isTrue);
    });

    test('resets the next day', () {
      ObjectScanDiscoveryService.tryAwardGameStar('p1', 'a01', now: day);
      expect(
        ObjectScanDiscoveryService.tryAwardGameStar('p1', 'a01',
            now: day.add(const Duration(days: 1))),
        isTrue,
      );
    });

    test('profiles are isolated', () {
      ObjectScanDiscoveryService.tryAwardGameStar('p1', 'a01', now: day);
      expect(
          ObjectScanDiscoveryService.tryAwardGameStar('p2', 'a01', now: day),
          isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Daily finds + hunt streak
  // ─────────────────────────────────────────────────────────────────────
  //
  // These drive the streak chip on "My Finds" and the Daily Hunter badge. The
  // rule that matters: only a *new* word counts, so re-photographing the same
  // chair all morning neither inflates today's tally nor extends the streak.
  group('findsToday', () {
    test('counts new words only, never repeats', () {
      ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13', now: day);
      ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13', now: day);
      ObjectScanDiscoveryService.recordDiscovery('p1', 'f14', now: day);
      expect(ObjectScanDiscoveryService.findsToday('p1', now: day), 2);
    });

    test('keeps counting past the daily star cap', () {
      for (var i = 0; i < ObjectScanDiscoveryService.dailyStarCap + 3; i++) {
        ObjectScanDiscoveryService.recordDiscovery('p1', 'word$i', now: day);
      }
      // Stars stop at the cap; the hunt does not.
      expect(ObjectScanDiscoveryService.starsAwardedToday('p1', now: day),
          ObjectScanDiscoveryService.dailyStarCap);
      expect(ObjectScanDiscoveryService.findsToday('p1', now: day),
          ObjectScanDiscoveryService.dailyStarCap + 3);
    });

    test('resets the next day', () {
      ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13', now: day);
      final tomorrow = day.add(const Duration(days: 1));
      expect(ObjectScanDiscoveryService.findsToday('p1', now: tomorrow), 0);
    });
  });

  group('huntStreak', () {
    test('a first find starts a 1-day streak', () {
      expect(ObjectScanDiscoveryService.huntStreak('p1', now: day), 0);
      ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13', now: day);
      expect(ObjectScanDiscoveryService.huntStreak('p1', now: day), 1);
    });

    test('a second find the same day does not extend it', () {
      ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13', now: day);
      ObjectScanDiscoveryService.recordDiscovery('p1', 'f14', now: day);
      expect(ObjectScanDiscoveryService.huntStreak('p1', now: day), 1);
    });

    test('consecutive days build up', () {
      var d = day;
      for (var i = 0; i < 4; i++) {
        ObjectScanDiscoveryService.recordDiscovery('p1', 'word$i', now: d);
        d = d.add(const Duration(days: 1));
      }
      final last = day.add(const Duration(days: 3));
      expect(ObjectScanDiscoveryService.huntStreak('p1', now: last), 4);
    });

    test('a skipped day restarts the streak', () {
      ObjectScanDiscoveryService.recordDiscovery('p1', 'a', now: day);
      final threeDaysOn = day.add(const Duration(days: 3));
      ObjectScanDiscoveryService.recordDiscovery('p1', 'b', now: threeDaysOn);
      expect(ObjectScanDiscoveryService.huntStreak('p1', now: threeDaysOn), 1);
    });

    test('yesterday keeps the streak alive; older reads as zero', () {
      ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13', now: day);
      // The day is not over — a learner who hunted yesterday still has it.
      expect(
        ObjectScanDiscoveryService.huntStreak(
            'p1', now: day.add(const Duration(days: 1))),
        1,
      );
      // Two days later it is gone, without needing a write to expire it.
      expect(
        ObjectScanDiscoveryService.huntStreak(
            'p1', now: day.add(const Duration(days: 2))),
        0,
      );
    });

    test('profiles keep separate streaks', () {
      ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13', now: day);
      expect(ObjectScanDiscoveryService.huntStreak('p2', now: day), 0);
    });
  });

  group('read-after-write', () {
    test('a discovery is visible immediately, before the disk write lands', () {
      // The UI reads the collection back on the same frame (the bag count, the
      // NEW badges, the achievement check). Hive publishes a `put` only once
      // the write completes, so this would fail without the session mirror.
      ObjectScanDiscoveryService.recordDiscovery('p1', 'cr13', now: day);
      expect(ObjectScanDiscoveryService.discoveryCount('p1'), 1);
      expect(ObjectScanDiscoveryService.isDiscovered('p1', 'cr13'), isTrue);
      expect(ObjectScanDiscoveryService.huntStreak('p1', now: day), 1);
    });
  });
}
