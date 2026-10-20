import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/settings/models/settings_presentation.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart';
import 'package:pwdpwdpwd/core/accessibility/learner_support.dart';

/// Which settings each kind of profile is offered, pinned for all six.
///
/// The Settings screen used to decide row by row, and the rows drifted from
/// what each profile is for: a Teacher's and a Parent's own Settings offered
/// Gaze Control and the game controller, a Student's offered "Classroom Mode
/// — Monitor all students" (a route that turned them away), and a Parent's
/// offered the Teacher's live class view. Change a decision here on purpose,
/// never as a side effect.

UserProfile _profile(ProfileKind kind) => UserProfile(
      id: 'p-${kind.name}',
      name: kind.name,
      role: switch (kind) {
        ProfileKind.guestPlayer || ProfileKind.player => UserRole.player,
        ProfileKind.student => UserRole.student,
        ProfileKind.child => UserRole.child,
        ProfileKind.teacher => UserRole.teacher,
        ProfileKind.parent => UserRole.parent,
      },
      isGuestPlayer: kind == ProfileKind.guestPlayer,
      createdAt: DateTime(2026),
    );

/// Every row decision, by name, so a failure says which row moved.
Map<String, bool> _rows(SettingsPresentation p) => {
      'handsFreeInput': p.handsFreeInput,
      'setsUpLearnerInput': p.setsUpLearnerInput,
      'voiceTour': p.voiceTour,
      'accessibilitySetup': p.accessibilitySetup,
      'selfClassifiesDisability': p.selfClassifiesDisability,
      'accessibilityManagedByEducator': p.accessibilityManagedByEducator,
      'learningModes': p.learningModes,
      'learnerAudio': p.learnerAudio,
      'reminders': p.reminders,
      'myDay': p.myDay,
      'tutorialReplay': p.tutorialReplay,
      'presentation': p.presentation,
      'classroomMode': p.classroomMode,
      'parentalControls': p.parentalControls,
      'manageProfiles': p.manageProfiles,
      'telemetry': p.telemetry,
      'linkAccount': p.linkAccount,
      'deviceBackup': p.deviceBackup,
      'recoveryCode': p.recoveryCode,
      'resetAllData': p.resetAllData,
    };

void main() {
  group('the six kinds of profile', () {
    test('a profile maps to its kind; the guest is split from the Player', () {
      for (final kind in ProfileKind.values) {
        expect(_profile(kind).kind, kind);
      }
    });

    test('nobody signed in is neither a learner nor an educator', () {
      final p = SettingsPresentation.of(null);
      expect(p.kind, isNull);
      expect(p.isLearner, isFalse);
      expect(p.isEducator, isFalse);
    });
  });

  group('what each kind of profile is offered', () {
    // true = offered. One column per kind, in ProfileKind order:
    //                         guest  player student child  teacher parent
    const expected = <String, List<bool>>{
      'handsFreeInput': [true, true, true, true, false, false],
      'setsUpLearnerInput': [false, false, false, false, true, true],
      'voiceTour': [true, true, true, true, false, false],
      // A Student's and a Child's accessibility needs are their Teacher's or
      // Parent's to manage (Manage Classes / Home Groups): no wizard of
      // their own, and no picking their own category.
      'accessibilitySetup': [true, true, false, false, false, false],
      'selfClassifiesDisability': [true, true, false, false, false, false],
      'accessibilityManagedByEducator': [false, false, true, true, false, false],
      'learningModes': [true, true, true, true, false, false],
      'learnerAudio': [true, true, true, true, false, false],
      'reminders': [true, true, true, true, false, false],
      'myDay': [false, true, false, false, false, false],
      'tutorialReplay': [true, true, true, true, false, false],
      'presentation': [false, false, false, false, true, true],
      'classroomMode': [false, false, false, false, true, false],
      'parentalControls': [false, false, false, false, true, true],
      'manageProfiles': [false, false, false, false, true, true],
      'telemetry': [false, false, false, false, true, true],
      'linkAccount': [false, false, false, false, true, true],
      'deviceBackup': [false, true, false, false, true, true],
      'recoveryCode': [false, true, true, true, true, true],
      'resetAllData': [false, false, false, false, true, true],
    };

    for (final kind in ProfileKind.values) {
      test(kind.name, () {
        final rows = _rows(SettingsPresentation.of(_profile(kind)));
        expect(rows.keys.toSet(), expected.keys.toSet(),
            reason: 'every row decision is pinned here');
        for (final entry in expected.entries) {
          expect(rows[entry.key], entry.value[kind.index],
              reason: '${kind.name}: ${entry.key}');
        }
      });
    }
  });

  group('hands-free input belongs to the learner at the tablet', () {
    test('Teacher and Parent never run gaze or the controller themselves', () {
      for (final kind in ProfileKind.values) {
        final educator =
            kind == ProfileKind.teacher || kind == ProfileKind.parent;
        expect(ownsHandsFreeInput(_profile(kind)), !educator,
            reason: kind.name);
      }
    });

    test('before anyone signs in, the picker stays drivable', () {
      expect(ownsHandsFreeInput(null), isTrue);
    });
  });

  group('an educator\'s own hands-free pages are turned away', () {
    bool own(String location, {Object? extra}) =>
        isOwnHandsFreeInputRoute(Uri.parse(location), extra: extra);

    test('their own Gaze Control and controller pages', () {
      expect(own('/gaze-settings'), isTrue);
      expect(own('/gaze-calibrate'), isTrue);
      expect(own('/gamepad-settings'), isTrue);
      expect(own('/gamepad-practice'), isTrue);
      expect(own('/gaze-control'), isTrue);
      expect(own('/accessibility-setup'), isTrue);
    });

    test('a learner\'s, set up from the learner\'s card, stay open', () {
      expect(own('/gaze-settings?profile=kid-1&name=Ana'), isFalse);
      expect(own('/gaze-calibrate?profile=kid-1'), isFalse);
      expect(own('/gamepad-settings?profile=kid-1&name=Ana'), isFalse);
      // "Try it now" on the learner's page hands over the learner's settings.
      expect(own('/gaze-control', extra: const GazeSettings(enabled: true)),
          isFalse);
    });

    test('an empty profile is not a learner', () {
      expect(own('/gaze-settings?profile='), isTrue);
    });

    test('nothing else is touched', () {
      for (final location in const [
        '/settings',
        '/home',
        '/parental-controls',
        '/gaze-settings-help',
        '/voice-guided',
      ]) {
        expect(own(location), isFalse, reason: location);
      }
    });
  });

  group('a Student or a Child never opens the setup wizard', () {
    test('their Teacher or Parent manages their needs instead', () {
      for (final kind in ProfileKind.values) {
        final managed =
            kind == ProfileKind.student || kind == ProfileKind.child;
        expect(
          isManagedLearnerSetupRoute(
            _profile(kind),
            Uri.parse('/accessibility-setup'),
          ),
          managed,
          reason: kind.name,
        );
      }
    });

    test('nothing else is touched', () {
      for (final location in const [
        '/settings',
        '/edit-profile',
        '/home',
        '/gaze-settings',
        '/accessibility-setup-help',
      ]) {
        expect(
          isManagedLearnerSetupRoute(
            _profile(ProfileKind.student),
            Uri.parse(location),
          ),
          isFalse,
          reason: location,
        );
      }
    });
  });

  group('an educator profile carries no accessibility category', () {
    UserProfile educator(UserRole role) => UserProfile(
          id: 'e',
          name: 'E',
          role: role,
          createdAt: DateTime(2026),
          disabilityType: DisabilityType.visual,
          supportOptions: const {LearnerSupportOption.audioFirst},
        );

    test('a Teacher or Parent saved with one reads as none', () {
      for (final role in const [UserRole.teacher, UserRole.parent]) {
        final read = educator(role).normalizedForRole();
        expect(read.disabilityType, DisabilityType.none, reason: role.name);
        expect(read.supportOptions, isEmpty, reason: role.name);
      }
    });

    test('a learner keeps theirs, untouched', () {
      for (final role in const [
        UserRole.student,
        UserRole.child,
        UserRole.player,
      ]) {
        final saved = educator(role);
        expect(identical(saved.normalizedForRole(), saved), isTrue,
            reason: role.name);
      }
    });
  });
}
