import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/parent/models/parental_controls.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_presets.dart';

void main() {
  // ─── UserProfile.copyWith ──────────────────────────────

  group('UserProfile.copyWith', () {
    final profile = UserProfile(
      id: 'p1',
      name: 'Maria',
      role: UserRole.student,
      avatarIndex: 3,
      createdAt: DateTime(2025),
    );

    test('copies name', () {
      final updated = profile.copyWith(name: 'Juan');
      expect(updated.name, 'Juan');
      expect(updated.avatarIndex, 3); // unchanged
    });

    test('copies avatarIndex', () {
      final updated = profile.copyWith(avatarIndex: 7);
      expect(updated.avatarIndex, 7);
      expect(updated.name, 'Maria'); // unchanged
    });

    test('copies disabilityType', () {
      final updated = profile.copyWith(disabilityType: DisabilityType.visual);
      expect(updated.disabilityType, DisabilityType.visual);
    });

    test('copies PIN (set)', () {
      final updated = profile.copyWith(pin: () => '1234');
      expect(updated.pin, '1234');
      expect(updated.hasPinProtection, true);
    });

    test('copies PIN (remove)', () {
      final withPin = profile.copyWith(pin: () => '1234');
      final removed = withPin.copyWith(pin: () => null);
      expect(removed.pin, isNull);
      expect(removed.hasPinProtection, false);
    });

    test('preserves id and createdAt', () {
      final updated = profile.copyWith(name: 'New');
      expect(updated.id, 'p1');
      expect(updated.createdAt, DateTime(2025));
    });
  });

  // ─── Accessibility Presets ─────────────────────────────

  group('AccessibilityPresets', () {
    test('visual preset enables high contrast and large font', () {
      final preset = AccessibilityPresets.presetFor(DisabilityType.visual);
      expect(preset.fontScale, 1.4);
      expect(preset.highContrastMode, true);
      expect(preset.ttsEnabled, true);
      expect(preset.voiceNavigation, true);
    });

    test('hearing preset disables sound', () {
      final preset = AccessibilityPresets.presetFor(DisabilityType.hearing);
      expect(preset.ttsEnabled, false);
      expect(preset.soundEffects, false);
      expect(preset.voiceNavigation, false);
    });

    test('motor preset enables reduced motion', () {
      final preset = AccessibilityPresets.presetFor(DisabilityType.motor);
      expect(preset.reducedMotion, true);
    });

    test('cognitive preset slows TTS', () {
      final preset = AccessibilityPresets.presetFor(DisabilityType.cognitive);
      expect(preset.ttsSpeed, 0.35);
      expect(preset.adaptiveDifficulty, true);
    });

    test('none preset returns defaults', () {
      final preset = AccessibilityPresets.presetFor(DisabilityType.none);
      expect(preset.fontScale, 1.0);
      expect(preset.highContrastMode, false);
    });

    test('preserves existing locale when applying preset', () {
      const current = AppSettings(locale: 'fil');
      final preset = AccessibilityPresets.presetFor(
        DisabilityType.visual,
        current: current,
      );
      expect(preset.locale, 'fil'); // preserved
      expect(preset.fontScale, 1.4); // overridden
    });

    test('changeSummary returns non-empty for non-none types', () {
      for (final type in DisabilityType.values) {
        final changes = AccessibilityPresets.changeSummary(type);
        if (type == DisabilityType.none) {
          expect(changes, isEmpty);
        } else {
          expect(changes, isNotEmpty);
        }
      }
    });

    test('changeSummary entries have all fields', () {
      final changes =
          AccessibilityPresets.changeSummary(DisabilityType.visual);
      for (final c in changes) {
        expect(c.name, isNotEmpty);
        expect(c.value, isNotEmpty);
        expect(c.emoji, isNotEmpty);
      }
    });
  });

  // ─── ParentalControls Model ────────────────────────────

  group('ParentalControls', () {
    test('defaults have no restrictions', () {
      const controls = ParentalControls();
      expect(controls.hasAnyRestriction, false);
      expect(controls.timeLimitEnabled, false);
      expect(controls.scheduleEnabled, false);
      expect(controls.shopBlocked, false);
      expect(controls.multiplayerBlocked, false);
      expect(controls.messagingBlocked, false);
      expect(controls.blockedGames, isEmpty);
      expect(controls.blockedCategories, isEmpty);
    });

    test('toJson → fromJson roundtrip', () {
      const controls = ParentalControls(
        dailyTimeLimitMinutes: 60,
        timeLimitEnabled: true,
        blockedGames: {GameType.memoryMatch, GameType.dragAndDrop},
        blockedCategories: {FlashcardCategory.animals},
        shopBlocked: true,
        multiplayerBlocked: true,
        allowedStartHour: 9,
        allowedEndHour: 17,
        scheduleEnabled: true,
      );

      final json = controls.toJson();
      final restored = ParentalControls.fromJson(json);

      expect(restored.dailyTimeLimitMinutes, 60);
      expect(restored.timeLimitEnabled, true);
      expect(restored.blockedGames,
          {GameType.memoryMatch, GameType.dragAndDrop});
      expect(restored.blockedCategories, {FlashcardCategory.animals});
      expect(restored.shopBlocked, true);
      expect(restored.multiplayerBlocked, true);
      expect(restored.messagingBlocked, false);
      expect(restored.allowedStartHour, 9);
      expect(restored.allowedEndHour, 17);
      expect(restored.scheduleEnabled, true);
    });

    test('fromJson handles missing fields gracefully', () {
      final restored = ParentalControls.fromJson({});
      expect(restored.dailyTimeLimitMinutes, 0);
      expect(restored.timeLimitEnabled, false);
      expect(restored.blockedGames, isEmpty);
      expect(restored.blockedCategories, isEmpty);
    });

    test('hasAnyRestriction detects single restriction', () {
      expect(
        const ParentalControls(shopBlocked: true).hasAnyRestriction,
        true,
      );
      expect(
        const ParentalControls(timeLimitEnabled: true).hasAnyRestriction,
        true,
      );
      expect(
        const ParentalControls(
                blockedGames: {GameType.wordMatch}).hasAnyRestriction,
        true,
      );
    });

    test('isWithinSchedule returns true when disabled', () {
      const controls = ParentalControls();
      expect(controls.isWithinSchedule, true);
    });

    test('isWithinSchedule checks current hour', () {
      // Create a schedule that includes current hour
      const controls = ParentalControls(
        scheduleEnabled: true,
        allowedStartHour: 0,
        allowedEndHour: 24,
      );
      expect(controls.isWithinSchedule, true);
    });

    test('isWithinSchedule rejects out-of-range hour', () {
      final now = DateTime.now().hour;
      // Create a schedule that excludes current hour
      // Use the hour after current (wrapping) as start, and current hour as end
      final excludeStart = (now + 1) % 24;
      final excludeEnd = now;
      final controls = ParentalControls(
        scheduleEnabled: true,
        allowedStartHour: excludeStart,
        allowedEndHour: excludeEnd,
      );
      expect(controls.isWithinSchedule, false);
    });

    test('copyWith preserves unmodified fields', () {
      const original = ParentalControls(
        dailyTimeLimitMinutes: 90,
        timeLimitEnabled: true,
        shopBlocked: true,
      );
      final updated = original.copyWith(messagingBlocked: true);
      expect(updated.dailyTimeLimitMinutes, 90);
      expect(updated.timeLimitEnabled, true);
      expect(updated.shopBlocked, true);
      expect(updated.messagingBlocked, true);
    });

    test('blockedGames serialization handles invalid indices', () {
      final json = {
        'blockedGames': [0, 1, 999, -1], // 999 and -1 are invalid
      };
      final restored = ParentalControls.fromJson(json);
      expect(restored.blockedGames.length, 2); // only valid ones
    });

    test('blockedCategories serialization handles invalid indices', () {
      final json = {
        'blockedCategories': [0, 999],
      };
      final restored = ParentalControls.fromJson(json);
      expect(restored.blockedCategories.length, 1);
    });
  });

  // ─── DisabilityType extensions ─────────────────────────

  group('DisabilityType extensions', () {
    test('all types have label', () {
      for (final dt in DisabilityType.values) {
        expect(dt.label, isNotEmpty);
      }
    });

    test('all types have description', () {
      for (final dt in DisabilityType.values) {
        expect(dt.description, isNotEmpty);
      }
    });

    test('all types have emoji', () {
      for (final dt in DisabilityType.values) {
        expect(dt.emoji, isNotEmpty);
      }
    });
  });
}
