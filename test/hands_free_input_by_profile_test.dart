import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_settings.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/tile_grid_active_provider.dart';

/// Gaze Control and the game controller are a **learner's** way of using the
/// app. A Teacher's or Parent's own Settings no longer offer either, so their
/// profile must not run them either — whatever an older version saved for it
/// — or a camera or a talking controller would keep running with no switch
/// left to turn it off. They set a learner's up from the learner's card.

UserProfile _p(String id, UserRole role) =>
    UserProfile(id: id, name: id, role: role, createdAt: DateTime(2026));

class _Signed extends ProfileNotifier {
  _Signed(this.profile);
  final UserProfile? profile;
  @override
  UserProfile? build() => profile;
}

/// A teacher looking at a learner's dashboard ("view as student").
class _ViewingAs extends ProfileNotifier {
  _ViewingAs(this.learner, this.educator);
  final UserProfile learner;
  final UserProfile educator;
  @override
  UserProfile? build() => learner;
  @override
  bool get isViewingAsStudent => true;
  @override
  UserProfile? get savedEducatorProfile => educator;
}

ProviderContainer _at(ProfileNotifier Function() notifier) {
  final c = ProviderContainer(
    overrides: [profileProvider.overrideWith(notifier)],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _saveGaze(String id, GazeSettings s) =>
    HiveService.saveProfileSetting(kGazeSettingsKey, s.toMap(), profileId: id);

Future<void> _saveGamepad(String id, GamepadSettings s) =>
    HiveService.saveProfileSetting(
      kGamepadSettingsKey,
      s.toMap(),
      profileId: id,
    );

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/hands_free_input_by_profile');
    // settings + profiles for the providers; the rest for deleteProfile.
    for (final name in const [
      'settings',
      'profiles',
      'progress',
      'classroom_members',
      'home_group_members',
      'friend_directory_cache',
      'friends_cache',
      'friend_requests_cache',
    ]) {
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

  const gazeOn = GazeSettings(enabled: true, sensitivity: 4, dwellMs: 1800);

  group('Gaze Control', () {
    test('runs for every kind of learner who switched it on', () async {
      for (final role in const [
        UserRole.student,
        UserRole.child,
        UserRole.player,
      ]) {
        await _saveGaze('l-${role.name}', gazeOn);
        final c = _at(() => _Signed(_p('l-${role.name}', role)));
        expect(c.read(gazeSettingsProvider).enabled, isTrue,
            reason: role.name);
      }
    });

    test('never runs on a Teacher\'s or Parent\'s own profile', () async {
      for (final role in const [UserRole.teacher, UserRole.parent]) {
        // Switched on by an older version, which offered it to them.
        await _saveGaze('e-${role.name}', gazeOn);
        final c = _at(() => _Signed(_p('e-${role.name}', role)));
        final s = c.read(gazeSettingsProvider);
        expect(s.enabled, isFalse, reason: role.name);
        // Only the switch is overridden; nothing else they saved is lost.
        expect(s.sensitivity, 4);
        expect(s.dwellMs, 1800);
      }
    });

    test('stays off while a Teacher views a learner who uses it', () async {
      // The learner is the active profile, but the face at the camera is
      // the teacher's.
      await _saveGaze('ana', gazeOn);
      final c = _at(() => _ViewingAs(
            _p('ana', UserRole.student),
            _p('rose', UserRole.teacher),
          ));
      expect(c.read(gazeSettingsProvider).enabled, isFalse);
    });

    test('an educator switching it on changes nothing that runs', () {
      final c = _at(() => _Signed(_p('rose', UserRole.teacher)));
      c.read(gazeSettingsProvider.notifier).setEnabled(true);
      expect(c.read(gazeSettingsProvider).enabled, isFalse);
      // Nor do the hub grids publish for it.
      expect(c.read(tileGridActiveProvider), isFalse);
    });

    test('a learner\'s card still sets that learner up', () {
      final c = _at(() => _Signed(_p('rose', UserRole.teacher)));
      c.read(gazeSettingsForProfileProvider('ana').notifier).setEnabled(true);
      expect(c.read(gazeSettingsForProfileProvider('ana')).enabled, isTrue);
      // …which is what the learner gets when they sign in.
      final learner = _at(() => _Signed(_p('ana', UserRole.student)));
      expect(learner.read(gazeSettingsProvider).enabled, isTrue);
    });
  });

  group('the profile picker (nobody signed in yet)', () {
    test('ignores an educator\'s saved gaze', () async {
      await HiveService.saveProfile(_p('rose', UserRole.teacher));
      await HiveService.saveProfile(_p('ana', UserRole.student));
      await _saveGaze('rose', gazeOn);
      final c = _at(() => _Signed(null));
      expect(c.read(gazePickerSettingsProvider).enabled, isFalse,
          reason: 'no camera at the front door for a teacher\'s settings');
      expect(c.read(gazeSettingsProvider).enabled, isFalse);
    });

    test('still runs on a learner\'s, so they can reach their profile',
        () async {
      await HiveService.saveProfile(_p('rose', UserRole.parent));
      await HiveService.saveProfile(_p('ana', UserRole.child));
      await _saveGaze('rose', gazeOn);
      await _saveGaze('ana', const GazeSettings(enabled: true, sensitivity: 2));
      final c = _at(() => _Signed(null));
      final atPicker = c.read(gazePickerSettingsProvider);
      expect(atPicker.enabled, isTrue);
      expect(atPicker.sensitivity, 2, reason: 'the learner\'s tuning');
    });
  });

  group('game controller', () {
    test('is on by default for a learner, off for an educator', () {
      for (final role in UserRole.values) {
        final c = _at(() => _Signed(_p('x-${role.name}', role)));
        expect(c.read(gamepadSettingsProvider).enabled, !role.isEducator,
            reason: role.name);
      }
    });

    test('a Teacher\'s saved "on" no longer drives their dashboard', () async {
      await _saveGamepad('rose', const GamepadSettings(swapConfirmButtons: true));
      final c = _at(() => _Signed(_p('rose', UserRole.teacher)));
      final s = c.read(gamepadSettingsProvider);
      expect(s.enabled, isFalse);
      expect(s.swapConfirmButtons, isTrue, reason: 'the rest is kept');
    });

    test('follows the teacher at the tablet, not the learner viewed', () async {
      await _saveGamepad('ana', const GamepadSettings());
      final c = _at(() => _ViewingAs(
            _p('ana', UserRole.student),
            _p('rose', UserRole.teacher),
          ));
      expect(c.read(gamepadSettingsProvider).enabled, isFalse);
    });

    test('a learner\'s card edits that learner\'s controller settings',
        () async {
      final teacher = _at(() => _Signed(_p('rose', UserRole.teacher)));
      final card = teacher.read(gamepadSettingsForProfileProvider('ana').notifier);
      card.setSwapConfirmButtons(true);
      card.setDedupeMs(300);
      expect(teacher.read(gamepadSettingsForProfileProvider('ana')).dedupeMs,
          300);
      // Not the teacher's own.
      expect(
        HiveService.getProfileSetting(kGamepadSettingsKey, profileId: 'rose'),
        isNull,
      );
      // The learner signs in and has them.
      await Future<void>.delayed(Duration.zero);
      final learner = _at(() => _Signed(_p('ana', UserRole.student)));
      final s = learner.read(gamepadSettingsProvider);
      expect(s.swapConfirmButtons, isTrue);
      expect(s.dedupeMs, 300);
      expect(s.enabled, isTrue);
    });

    test('a learner\'s own changes are saved under their own id', () async {
      final c = _at(() => _Signed(_p('ana', UserRole.child)));
      c.read(gamepadSettingsProvider.notifier).setHoldToRepeat(true);
      await Future<void>.delayed(Duration.zero);
      final raw = HiveService.getProfileSetting(
        kGamepadSettingsKey,
        profileId: 'ana',
      );
      expect(GamepadSettings.fromMap(raw as Map).holdToRepeat, isTrue);
    });
  });

  group('a learner\'s speech speed, from the learner\'s card', () {
    test('changes the learner\'s, not the educator\'s', () async {
      final teacher = _at(() => _Signed(_p('rose', UserRole.teacher)));
      final notifier =
          teacher.read(appSettingsForProfileProvider('ana').notifier);
      notifier.update(
        teacher.read(appSettingsForProfileProvider('ana')).copyWith(
              ttsSpeed: 0.9,
            ),
      );
      // The screen shows it at once…
      expect(teacher.read(appSettingsForProfileProvider('ana')).ttsSpeed, 0.9);
      // …and the save (one Hive write per setting, in turn) lands soon after.
      for (var i = 0;
          i < 100 && HiveService.getSettings(profileId: 'ana').ttsSpeed != 0.9;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(HiveService.getSettings(profileId: 'ana').ttsSpeed, 0.9);
      expect(teacher.read(settingsProvider).ttsSpeed, 0.5,
          reason: 'the teacher\'s own speed is untouched');
    });
  });

  group('deleting a profile', () {
    test('takes every setting saved for it, and only for it', () async {
      await HiveService.saveProfile(_p('ana', UserRole.student));
      await HiveService.saveProfile(_p('ben', UserRole.student));
      await HiveService.saveSettings(
        const AppSettings(fontScale: 1.5),
        profileId: 'ana',
      );
      await _saveGaze('ana', gazeOn);
      await _saveGamepad('ana', const GamepadSettings(holdToRepeat: true));
      await HiveService.saveProfileSetting('gazeMetrics', {'x': 1},
          profileId: 'ana');
      await _saveGaze('ben', gazeOn);
      await HiveService.saveSettings(
        const AppSettings(fontScale: 1.2),
        profileId: 'ben',
      );

      await HiveService.deleteProfile('ana');

      final left = Hive.box('settings').keys.cast<String>();
      expect(left.where((k) => k.startsWith('ana::')), isEmpty);
      expect(HiveService.getSettings(profileId: 'ben').fontScale, 1.2);
      expect(
        HiveService.getProfileSetting(kGazeSettingsKey, profileId: 'ben'),
        isNotNull,
      );
    });
  });
}
