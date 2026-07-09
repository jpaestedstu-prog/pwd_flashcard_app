import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_content_policy.dart';
import 'package:pwdpwdpwd/data/models/classroom.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/home_group.dart';

void main() {
  group('AccessibilityContentPolicy.forType', () {
    test('hearing surfaces FSL but hides the audio-only game', () {
      final p = AccessibilityContentPolicy.forType(DisabilityType.hearing);
      expect(p.showFsl, isTrue);
      expect(p.showAudioGame, isFalse);
    });

    test('cognitive hides FSL but keeps audio', () {
      final p = AccessibilityContentPolicy.forType(DisabilityType.cognitive);
      expect(p.showFsl, isFalse);
      expect(p.showAudioGame, isTrue);
    });

    test('visual hides FSL (signs are visual) but keeps audio', () {
      final p = AccessibilityContentPolicy.forType(DisabilityType.visual);
      expect(p.showFsl, isFalse);
      expect(p.showAudioGame, isTrue);
    });

    test('motor / multiple / none keep the full experience', () {
      for (final t in [
        DisabilityType.motor,
        DisabilityType.multiple,
        DisabilityType.none,
      ]) {
        final p = AccessibilityContentPolicy.forType(t);
        expect(p.showFsl, isTrue, reason: '$t should show FSL');
        expect(p.showAudioGame, isTrue, reason: '$t should show audio game');
      }
    });

    test('every category resolves to a policy', () {
      for (final t in DisabilityType.values) {
        expect(() => AccessibilityContentPolicy.forType(t), returnsNormally);
      }
    });
  });

  group('Classroom accessibility serialization', () {
    Classroom sample(DisabilityType a) => Classroom(
          id: 'c1',
          code: 'ABC123',
          name: 'Grade 3',
          teacherId: 't1',
          accessibility: a,
          createdAt: DateTime.parse('2026-01-01T00:00:00.000'),
          updatedAt: DateTime.parse('2026-01-02T00:00:00.000'),
        );

    test('round-trips the accessibility field', () {
      for (final a in DisabilityType.values) {
        final restored = Classroom.fromJson(sample(a).toJson());
        expect(restored.accessibility, a);
      }
    });

    test('legacy doc without accessibility defaults to none', () {
      final legacy = {
        'id': 'c1',
        'code': 'ABC123',
        'name': 'Grade 3',
        'teacher_id': 't1',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-02T00:00:00.000',
      };
      expect(Classroom.fromJson(legacy).accessibility, DisabilityType.none);
    });

    test('out-of-range index clamps instead of throwing', () {
      final json = sample(DisabilityType.hearing).toJson()
        ..['accessibility'] = 9999;
      expect(
        Classroom.fromJson(json).accessibility,
        DisabilityType.values.last,
      );
    });
  });

  group('HomeGroup accessibility serialization', () {
    HomeGroup sample(DisabilityType a) => HomeGroup(
          id: 'g1',
          code: 'XYZ789',
          name: 'The Smiths',
          ownerProfileId: 'p1',
          accessibility: a,
          createdAt: DateTime.parse('2026-01-01T00:00:00.000'),
          updatedAt: DateTime.parse('2026-01-02T00:00:00.000'),
        );

    test('round-trips the accessibility field', () {
      for (final a in DisabilityType.values) {
        final restored = HomeGroup.fromJson(sample(a).toJson());
        expect(restored.accessibility, a);
      }
    });

    test('legacy doc without accessibility defaults to none', () {
      final legacy = {
        'id': 'g1',
        'code': 'XYZ789',
        'name': 'The Smiths',
        'owner_profile_id': 'p1',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-02T00:00:00.000',
      };
      expect(HomeGroup.fromJson(legacy).accessibility, DisabilityType.none);
    });
  });
}
