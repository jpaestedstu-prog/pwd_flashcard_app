import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/object_scan/services/object_scan_discovery_service.dart';

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/object_scan_discovery');
    if (!Hive.isBoxOpen('progress')) await Hive.openBox('progress');
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  setUp(() async => Hive.box('progress').clear());

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
}
