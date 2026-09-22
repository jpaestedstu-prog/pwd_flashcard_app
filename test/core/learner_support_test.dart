import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_content_policy.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_presets.dart';
import 'package:pwdpwdpwd/core/accessibility/learner_support.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

/// Per-learner supports: the sign system a Deaf learner uses, how a learner
/// with low vision reads the screen, how a learner with a motor impairment
/// drives the app, and the accommodations they sit a test with.
///
/// The accessibility *category* could never express any of this. Every Deaf
/// learner was assumed to sign, and to sign FSL; every motor learner had gaze
/// control switched on whether or not they could use it.
///
/// Plain `test()` against real Hive for the round-trip — no `testWidgets` in
/// this file, so an awaited `box.put` cannot poison the write queue.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UserProfile learner({
    DisabilityType type = DisabilityType.hearing,
    Set<LearnerSupportOption> supports = const {},
    UserRole role = UserRole.student,
  }) => UserProfile(
    id: 'learner-1',
    name: 'Learner',
    role: role,
    createdAt: DateTime(2026),
    disabilityType: type,
    supportOptions: supports,
  );

  // ─── Defaults reproduce the old behaviour ────────────────

  group('defaults', () {
    test('a Deaf learner starts on FSL', () {
      expect(
        LearnerSupportCatalog.defaultsFor(DisabilityType.hearing),
        {LearnerSupportOption.signFsl},
      );
    });

    test('a motor learner still starts hands-free', () {
      // AccessibilityPresets.enablesGazeControl switched gaze on for motor and
      // multiple. If this default ever became `inputTouch`, every existing
      // motor profile would silently lose the only way they can drive the app.
      for (final type in const [
        DisabilityType.motor,
        DisabilityType.multiple,
      ]) {
        expect(
          LearnerSupportCatalog.defaultsFor(type),
          contains(LearnerSupportOption.inputGaze),
          reason: '${type.name} must keep gaze control by default',
        );
      }
    });

    test('every category with a primary group gets one selection', () {
      for (final type in DisabilityType.values) {
        final defaults = LearnerSupportCatalog.defaultsFor(type);
        for (final group in LearnerSupportCatalog.groupsFor(type)) {
          if (!group.singleChoice) continue;
          expect(
            group.options.where(defaults.contains),
            hasLength(1),
            reason: '${type.name}/${group.id} needs exactly one default',
          );
        }
      }
    });

    test('an unconfigured profile reads as its category defaults', () {
      expect(
        learner(type: DisabilityType.visual).supports,
        LearnerSupportCatalog.defaultsFor(DisabilityType.visual),
      );
    });

    test('no accessibility need means nothing is forced on', () {
      expect(LearnerSupportCatalog.defaultsFor(DisabilityType.none), isEmpty);
    });
  });

  // ─── normalize is the guard on re-categorising ───────────

  group('normalize', () {
    test('drops a support the new category does not offer', () {
      final moved = LearnerSupportCatalog.normalize(DisabilityType.motor, {
        LearnerSupportOption.signAsl,
        LearnerSupportOption.inputSwitch,
      });
      expect(moved, isNot(contains(LearnerSupportOption.signAsl)));
      expect(moved, contains(LearnerSupportOption.inputSwitch));
    });

    test('fills a missing primary choice rather than leaving none', () {
      final empty = LearnerSupportCatalog.normalize(
        DisabilityType.hearing,
        const {},
      );
      expect(
        LearnerSupportCatalog.communicationModeIn(empty),
        LearnerSupportOption.signFsl,
      );
    });

    test('keeps exactly one option from a single-choice group', () {
      final both = LearnerSupportCatalog.normalize(DisabilityType.hearing, {
        LearnerSupportOption.signAsl,
        LearnerSupportOption.signSee,
        LearnerSupportOption.oralLipReading,
      });
      final communication = both.where((o) => o.isSigningSystem || o ==
          LearnerSupportOption.oralLipReading);
      expect(communication, hasLength(1));
    });

    test('keeps every extra a category does offer', () {
      final picked = LearnerSupportCatalog.normalize(DisabilityType.hearing, {
        LearnerSupportOption.writtenCaptions,
        LearnerSupportOption.captionsAlwaysOn,
        LearnerSupportOption.extendedTestTime,
      });
      expect(picked, containsAll(const [
        LearnerSupportOption.writtenCaptions,
        LearnerSupportOption.captionsAlwaysOn,
        LearnerSupportOption.extendedTestTime,
      ]));
    });

    test('a profile re-categorised to Motor loses its sign system', () {
      final deaf = learner(supports: {LearnerSupportOption.signSee});
      final moved = deaf.copyWith(
        disabilityType: DisabilityType.motor,
        supportOptions: LearnerSupportCatalog.normalize(
          DisabilityType.motor,
          deaf.supports,
        ),
      );
      expect(moved.communicationMode, isNull);
      expect(moved.inputMode, LearnerSupportOption.inputGaze);
    });
  });

  // ─── Sign surfaces follow the learner, not the label ─────

  group('content policy', () {
    test('a Deaf learner who reads instead of signing gets no sign video', () {
      final policy = AccessibilityContentPolicy.forProfile(
        learner(supports: {LearnerSupportOption.writtenCaptions}),
      );
      expect(policy.showFsl, isFalse);
      expect(policy.signSystem, isNull);
    });

    test('a lip-reading learner gets no sign video either', () {
      final policy = AccessibilityContentPolicy.forProfile(
        learner(supports: {LearnerSupportOption.oralLipReading}),
      );
      expect(policy.showFsl, isFalse);
    });

    test('an ASL signer keeps the sign surfaces, named honestly', () {
      // The clips are filmed in FSL. Hiding them from an ASL signer would take
      // away the only signing content there is; pretending they are ASL would
      // be a lie. The surfaces get to say which system they are showing.
      final policy = AccessibilityContentPolicy.forProfile(
        learner(supports: {LearnerSupportOption.signAsl}),
      );
      expect(policy.showFsl, isTrue);
      expect(policy.signSystem, LearnerSupportOption.signAsl);
      expect(policy.signSystemDiffersFromMedia, isTrue);
    });

    test('an FSL signer is unchanged from before the feature', () {
      final policy = AccessibilityContentPolicy.forProfile(
        learner(supports: {LearnerSupportOption.signFsl}),
      );
      expect(policy.showFsl, isTrue);
      expect(policy.signSystemDiffersFromMedia, isFalse);
      expect(policy.showAudioGame, isFalse);
    });

    test('an unconfigured Deaf profile behaves exactly as it used to', () {
      final before = AccessibilityContentPolicy.forType(DisabilityType.hearing);
      final after = AccessibilityContentPolicy.forProfile(learner());
      expect(after.showFsl, before.showFsl);
      expect(after.showAudioGame, before.showAudioGame);
    });

    test('an educator viewing a learner reads the learner, not themselves', () {
      final policy = AccessibilityContentPolicy.forLearner(
        DisabilityType.hearing,
        const {LearnerSupportOption.writtenCaptions},
      );
      expect(policy.showFsl, isFalse);
    });
  });

  // ─── Test accommodations ─────────────────────────────────

  group('timed tests', () {
    test('extra time is half again as long, rounded up', () {
      expect(
        LearnerSupportCatalog.timeLimitMinutes(10, const {
          LearnerSupportOption.extendedTestTime,
        }),
        15,
      );
      expect(
        LearnerSupportCatalog.timeLimitMinutes(5, const {
          LearnerSupportOption.extendedTestTime,
        }),
        8,
      );
    });

    test('without the accommodation the limit is untouched', () {
      expect(LearnerSupportCatalog.timeLimitMinutes(10, const {}), 10);
    });

    test('an accommodation never imposes a clock on an untimed test', () {
      expect(
        LearnerSupportCatalog.timeLimitMinutes(null, const {
          LearnerSupportOption.extendedTestTime,
        }),
        isNull,
      );
      expect(
        LearnerSupportCatalog.timeLimitMinutes(0, const {
          LearnerSupportOption.extendedTestTime,
        }),
        isNull,
      );
    });
  });

  // ─── Settings overlay ────────────────────────────────────

  group('settings overlay', () {
    test('large print raises the font scale without lowering it', () {
      final base = const AppSettings().copyWith(fontScale: 1.8);
      final kept = AccessibilityPresets.applySupports(base, const {
        LearnerSupportOption.largePrint,
      });
      expect(kept.fontScale, 1.8);

      final raised = AccessibilityPresets.applySupports(
        const AppSettings(),
        const {LearnerSupportOption.largePrint},
      );
      expect(raised.fontScale, greaterThanOrEqualTo(1.6));
    });

    test('audio-first turns speech on', () {
      final s = AccessibilityPresets.applySupports(
        const AppSettings().copyWith(ttsEnabled: false, voiceNavigation: false),
        const {LearnerSupportOption.audioFirst},
      );
      expect(s.ttsEnabled, isTrue);
      expect(s.voiceNavigation, isTrue);
    });

    test('visual alerts silence the sound effects', () {
      final s = AccessibilityPresets.applySupports(
        const AppSettings().copyWith(soundEffects: true),
        const {LearnerSupportOption.visualAlerts},
      );
      expect(s.soundEffects, isFalse);
    });

    test('supports a learner did not pick change nothing', () {
      const base = AppSettings();
      final s = AccessibilityPresets.applySupports(base, const {
        LearnerSupportOption.captionsAlwaysOn,
      });
      expect(s.fontScale, base.fontScale);
      expect(s.ttsEnabled, base.ttsEnabled);
      expect(s.soundEffects, base.soundEffects);
    });
  });

  // ─── Persistence ─────────────────────────────────────────

  group('encoding', () {
    test('round-trips by name, not by index', () {
      const chosen = {
        LearnerSupportOption.signSee,
        LearnerSupportOption.extendedTestTime,
      };
      final encoded = LearnerSupportCatalog.encode(chosen);
      expect(encoded, ['signSee', 'extendedTestTime']);
      expect(LearnerSupportCatalog.decode(encoded), chosen);
    });

    test('an id this build does not know is skipped, not fatal', () {
      expect(
        LearnerSupportCatalog.decode(const ['signFsl', 'telepathy', 42]),
        {LearnerSupportOption.signFsl},
      );
    });

    test('the same set always encodes identically', () {
      expect(
        LearnerSupportCatalog.encode({
          LearnerSupportOption.extendedTestTime,
          LearnerSupportOption.signAsl,
        }),
        LearnerSupportCatalog.encode({
          LearnerSupportOption.signAsl,
          LearnerSupportOption.extendedTestTime,
        }),
      );
    });
  });

  group('Hive round-trip', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('learner_support_test');
      Hive.init(tempDir.path);
      for (final name in const ['profiles', 'progress', 'settings']) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    });

    tearDown(() async {
      await Hive.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('a learner keeps their supports across a save and load', () async {
      final profile = learner(
        supports: const {
          LearnerSupportOption.signSee,
          LearnerSupportOption.extendedTestTime,
        },
      );
      await HiveService.saveProfile(profile);

      final loaded = HiveService.getProfileById(profile.id);
      expect(loaded, isNotNull);
      expect(loaded!.supportOptions, profile.supportOptions);
      expect(loaded.communicationMode, LearnerSupportOption.signSee);
      expect(loaded.hasSupport(LearnerSupportOption.extendedTestTime), isTrue);
    });

    test('a profile saved before the field existed still loads', () async {
      // Written straight into the box in the old shape — no supportOptions
      // key at all — so this asserts the read path, not the write path.
      final box = Hive.box('profiles');
      await box.put('profiles', [
        {
          'id': 'legacy-1',
          'name': 'Legacy',
          'role': UserRole.student.index,
          'avatarIndex': 0,
          'createdAt': DateTime(2026).toIso8601String(),
          'disabilityType': DisabilityType.hearing.index,
        },
      ]);

      final loaded = HiveService.getProfileById('legacy-1');
      expect(loaded, isNotNull);
      expect(loaded!.supportOptions, isEmpty);
      expect(loaded.communicationMode, LearnerSupportOption.signFsl);
    });
  });
}
