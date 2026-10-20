import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_presets.dart';
import 'package:pwdpwdpwd/core/accessibility/assigned_accessibility.dart';
import 'package:pwdpwdpwd/core/accessibility/learner_support.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/classroom_member.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/home_group_member.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_settings.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/assigned_accessibility_provider.dart';

/// A Student's or a Child's accessibility needs are their Teacher's or
/// Parent's to manage: set in Manage Classes / Home Groups, carried on the
/// learner's membership row, and applied by whichever device the learner
/// uses. Their own Settings no longer re-run the setup wizard.

UserProfile _learner(
  String id,
  UserRole role, {
  DisabilityType type = DisabilityType.hearing,
  String? classroomId,
  String? homeGroupId,
}) => UserProfile(
  id: id,
  name: id,
  role: role,
  disabilityType: type,
  classroomId: classroomId,
  homeGroupId: homeGroupId,
  // A handle already: the cloud half of a save then writes nothing here, so
  // no stray write can land in the next test.
  username: '$id-123456',
  createdAt: DateTime(2026),
);

AssignedAccessibility _assign(
  DisabilityType type, [
  Set<LearnerSupportOption>? supports,
  String at = '2026-10-19T08:00:00.000Z',
]) => AssignedAccessibility(
  type: type,
  supports: LearnerSupportCatalog.normalize(
    type,
    supports ?? LearnerSupportCatalog.defaultsFor(type),
  ),
  setAt: at,
  setBy: 'educator-1',
);

void main() {
  group('on the membership row', () {
    test('what the educator saves is what the learner reads', () {
      final saved = AssignedAccessibility.chosen(
        DisabilityType.hearing,
        const {LearnerSupportOption.signAsl, LearnerSupportOption.visualAlerts},
        setBy: 'kevin',
        now: DateTime.utc(2026, 10, 19, 8),
      );
      final read = AssignedAccessibility.fromRow({
        'classroom_id': 'c1',
        'profile_id': 'ana',
        'display_name': 'Ana',
        ...saved.toFields(),
      })!;
      expect(read.type, DisabilityType.hearing);
      expect(read.supports, {
        LearnerSupportOption.signAsl,
        LearnerSupportOption.visualAlerts,
      });
      expect(read.setAt, '2026-10-19T08:00:00.000Z');
      expect(read.setBy, 'kevin');
    });

    test('a row nobody set anything on is not an assignment', () {
      expect(AssignedAccessibility.fromRow(null), isNull);
      // What a join writes.
      expect(
        AssignedAccessibility.fromRow({
          'classroom_id': 'c1',
          'profile_id': 'ana',
          'display_name': 'Ana',
          'joined_at': '2026-10-01T00:00:00.000',
        }),
        isNull,
      );
      // Half-written or from a future version: ignored, never guessed.
      expect(
        AssignedAccessibility.fromRow({'accessibility': 1}),
        isNull,
        reason: 'no version',
      );
      expect(
        AssignedAccessibility.fromRow({
          'accessibility': 99,
          'accessibility_set_at': 'x',
        }),
        isNull,
        reason: 'unknown category',
      );
      expect(
        AssignedAccessibility.fromRow({
          'accessibility': 'hearing',
          'accessibility_set_at': 'x',
        }),
        isNull,
        reason: 'not an index',
      );
    });

    test('supports are re-scoped to the category as they are read', () {
      final read = AssignedAccessibility.fromRow({
        'accessibility': DisabilityType.motor.index,
        'support_options': ['signFsl', 'inputSwitch', 'notAnOption'],
        'accessibility_set_at': 'x',
      })!;
      expect(read.supports, contains(LearnerSupportOption.inputSwitch));
      expect(read.supports, isNot(contains(LearnerSupportOption.signFsl)));
    });

    test('a roster row keeps it through the tablet’s cache', () {
      final a = _assign(DisabilityType.visual);
      final row = {
        'classroom_id': 'c1',
        'profile_id': 'ana',
        'display_name': 'Ana',
        'joined_at': '2026-10-01T00:00:00.000',
        ...a.toFields(),
      };
      final member = ClassroomMember.fromJson(row);
      expect(member.assigned?.type, DisabilityType.visual);
      expect(
        ClassroomMember.fromJson(member.toJson()).assigned?.setAt,
        a.setAt,
      );
      final child = HomeGroupMember.fromJson({
        ...row,
        'home_group_id': 'g1',
      });
      expect(child.assigned?.type, DisabilityType.visual);
      expect(
        HomeGroupMember.fromJson(child.toJson()).assigned?.setAt,
        a.setAt,
      );
    });

    test('a join writes no accessibility of its own', () {
      final joined = ClassroomMember(
        classroomId: 'c1',
        profileId: 'ana',
        displayName: 'Ana',
        joinedAt: DateTime(2026, 10),
      );
      expect(joined.toJson().containsKey('accessibility'), isFalse);
      expect(joined.toJson().containsKey('accessibility_set_at'), isFalse);
    });
  });

  group('what the learner gets', () {
    test('the category and its supports', () {
      final profile = _learner('ana', UserRole.student);
      final next = _assign(
        DisabilityType.motor,
        const {LearnerSupportOption.inputSwitch},
      ).appliedTo(profile);
      expect(next.disabilityType, DisabilityType.motor);
      expect(next.supports, contains(LearnerSupportOption.inputSwitch));
      expect(next.supports, isNot(contains(LearnerSupportOption.signFsl)));
    });

    test('settings are set up afresh for the new category', () {
      // A Cognitive learner moved to Hearing must not keep the dyslexia
      // palette under Hearing's high contrast, or slow speech they no
      // longer hear.
      final cognitive = AccessibilityPresets.presetFor(DisabilityType.cognitive)
          .copyWith(
            locale: 'fil',
            reminderHour: 7,
            screenOrientation: ScreenOrientationChoice.landscape,
          );
      final s = _assign(DisabilityType.hearing).settingsFrom(cognitive);
      expect(s.dyslexiaMode, isFalse);
      expect(s.highContrastMode, isTrue);
      expect(s.ttsEnabled, isFalse);
      expect(s.soundEffects, isFalse);
      expect(s.reducedMotion, isFalse);
      expect(s.fontScale, 1.2);
      // What is the learner's own stays.
      expect(s.locale, 'fil');
      expect(s.reminderHour, 7);
      expect(s.screenOrientation, ScreenOrientationChoice.landscape);
    });

    test('the supports go on top of the preset', () {
      final s = _assign(
        DisabilityType.visual,
        const {LearnerSupportOption.largePrint},
      ).settingsFrom(const AppSettings());
      expect(s.fontScale, 1.6);
      expect(s.highContrastMode, isTrue);
    });

    test('"None" is the app as it comes', () {
      final visual = AccessibilityPresets.presetFor(DisabilityType.visual);
      final s = _assign(DisabilityType.none).settingsFrom(visual);
      expect(s.fontScale, 1.0);
      expect(s.highContrastMode, isFalse);
      expect(s.voiceNavigation, isFalse);
    });

    test('only the input the supports name is switched on', () {
      expect(_assign(DisabilityType.motor).inputMode,
          LearnerSupportOption.inputGaze);
      expect(
        _assign(DisabilityType.motor, const {LearnerSupportOption.inputSwitch})
            .inputMode,
        LearnerSupportOption.inputSwitch,
      );
      expect(_assign(DisabilityType.hearing).inputMode, isNull);
    });
  });

  group('where it is read from', () {
    test('a Student’s class row, a Child’s home-group row', () {
      expect(
        assignedAccessibilityRowPath(
          _learner('ana', UserRole.student, classroomId: 'c1'),
        ),
        'classroom_members/c1_ana',
      );
      expect(
        assignedAccessibilityRowPath(
          _learner('ben', UserRole.child, homeGroupId: 'g1'),
        ),
        'home_group_members/g1_ben',
      );
    });

    test('nobody else has one', () {
      expect(assignedAccessibilityRowPath(null), isNull);
      for (final role in const [
        UserRole.player,
        UserRole.teacher,
        UserRole.parent,
      ]) {
        expect(
          assignedAccessibilityRowPath(
            _learner('x', role, classroomId: 'c1', homeGroupId: 'g1'),
          ),
          isNull,
          reason: role.name,
        );
      }
      expect(
        assignedAccessibilityRowPath(_learner('ana', UserRole.student)),
        isNull,
        reason: 'not in a class',
      );
      expect(
        assignedAccessibilityRowPath(_learner('ben', UserRole.child)),
        isNull,
        reason: 'not in a home group',
      );
    });
  });

  group('applied on this device', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/assigned_accessibility');
      for (final name in const ['settings', 'profiles', 'progress']) {
        if (!Hive.isBoxOpen(name)) {
          await Hive.openBox(name, compactionStrategy: (_, _) => false);
        }
      }
    });
    setUp(() async {
      await Hive.box('settings').clear();
      await Hive.box('profiles').clear();
    });
    tearDownAll(() async {
      await Hive.deleteFromDisk()
          .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
    });

    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    Future<bool> apply(
      ProviderContainer c,
      String id,
      AssignedAccessibility a,
    ) => applyAssignedAccessibility(
      read: c.read,
      invalidate: c.invalidate,
      profileId: id,
      assigned: a,
    );

    test('a Student here gets the category, settings and gaze — once', () async {
      await HiveService.saveProfile(
        _learner('ana', UserRole.student, classroomId: 'c1'),
      );
      await HiveService.saveSettings(
        AccessibilityPresets.presetFor(DisabilityType.hearing),
        profileId: 'ana',
      );
      final c = container();
      final motor = _assign(DisabilityType.motor);

      expect(isUnappliedAssignment('ana', motor), isTrue);
      expect(await apply(c, 'ana', motor), isTrue);

      final stored = HiveService.getProfileById('ana')!;
      expect(stored.disabilityType, DisabilityType.motor);
      expect(stored.supports, {LearnerSupportOption.inputGaze});
      final settings = HiveService.getSettings(profileId: 'ana');
      expect(settings.reducedMotion, isTrue);
      expect(settings.highContrastMode, isFalse, reason: 'Hearing’s, reset');
      expect(settings.ttsEnabled, isTrue);
      final gaze = c.read(gazeSettingsForProfileProvider('ana'));
      expect(gaze.enabled, isTrue);
      expect(gaze.navScope, GazeNavScope.bottomNavAndHomeTiles);

      // The same version is never applied twice…
      expect(isUnappliedAssignment('ana', motor), isFalse);
      expect(await apply(c, 'ana', motor), isFalse);
      // …but a newer one is, even with the same choice.
      final again = _assign(
        DisabilityType.motor,
        null,
        '2026-10-19T09:00:00.000Z',
      );
      expect(await apply(c, 'ana', again), isTrue);
    });

    test('a Child set to use a switch gets the game controller', () async {
      await HiveService.saveProfile(
        _learner('ben', UserRole.child, homeGroupId: 'g1'),
      );
      // Switched off on this tablet before (it is on out of the box).
      await HiveService.saveProfileSetting(
        kGamepadSettingsKey,
        const GamepadSettings(enabled: false).toMap(),
        profileId: 'ben',
      );
      final c = container();
      expect(c.read(gamepadSettingsForProfileProvider('ben')).enabled, isFalse);
      expect(
        await apply(
          c,
          'ben',
          _assign(
            DisabilityType.motor,
            const {LearnerSupportOption.inputSwitch},
          ),
        ),
        isTrue,
      );
      expect(c.read(gamepadSettingsForProfileProvider('ben')).enabled, isTrue);
      expect(c.read(gazeSettingsForProfileProvider('ben')).enabled, isFalse);
    });

    test('the learner signed in sees it straight away', () async {
      await HiveService.saveProfile(
        _learner('ana', UserRole.student, classroomId: 'c1'),
      );
      await HiveService.setActiveProfileId('ana');
      final c = container();
      expect(c.read(profileProvider)?.disabilityType, DisabilityType.hearing);
      expect(c.read(settingsProvider).highContrastMode, isFalse);

      expect(await apply(c, 'ana', _assign(DisabilityType.visual)), isTrue);
      expect(c.read(profileProvider)?.disabilityType, DisabilityType.visual);
      expect(c.read(settingsProvider).highContrastMode, isTrue);
      expect(c.read(settingsProvider).fontScale, 1.4);
    });

    test('only a Student’s or a Child’s, and only one stored here', () async {
      await HiveService.saveProfile(_learner('pia', UserRole.player));
      await HiveService.saveProfile(_learner('tess', UserRole.teacher));
      final c = container();
      for (final id in const ['pia', 'tess', 'not-on-this-tablet']) {
        expect(
          await apply(c, id, _assign(DisabilityType.visual)),
          isFalse,
          reason: id,
        );
      }
      expect(
        HiveService.getProfileById('pia')!.disabilityType,
        DisabilityType.hearing,
      );
      expect(
        HiveService.getSettings(profileId: 'tess').highContrastMode,
        isFalse,
      );
    });
  });
}
