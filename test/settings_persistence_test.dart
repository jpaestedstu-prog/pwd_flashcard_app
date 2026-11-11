import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_settings.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_settings_provider.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Every setting survives a restart, and stays with the profile it belongs
/// to. A "restart" here is a fresh [ProviderContainer] reading the same Hive
/// box — exactly what the app does when it starts again.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.profileId);
  final String? profileId;

  @override
  UserProfile? build() => profileId == null
      ? null
      : UserProfile(
          id: profileId!,
          name: 'Test $profileId',
          role: UserRole.student,
          disabilityType: DisabilityType.visual,
          createdAt: DateTime(2026),
        );
}

ProviderContainer _containerFor(String? profileId) => ProviderContainer(
      overrides: [
        profileProvider.overrideWith(() => _StubProfileNotifier(profileId)),
      ],
    );

/// Every field of [s], by name, so a mismatch names the setting that was lost.
Map<String, Object> _fields(AppSettings s) => {
      'fontScale': s.fontScale,
      'highContrastMode': s.highContrastMode,
      'darkMode': s.darkMode,
      'ttsEnabled': s.ttsEnabled,
      'ttsSpeed': s.ttsSpeed,
      'reducedMotion': s.reducedMotion,
      'soundEffects': s.soundEffects,
      'speechToText': s.speechToText,
      'locale': s.locale,
      'notificationsEnabled': s.notificationsEnabled,
      'reminderHour': s.reminderHour,
      'reminderMinute': s.reminderMinute,
      'voiceNavigation': s.voiceNavigation,
      'adaptiveDifficulty': s.adaptiveDifficulty,
      'vocabReviewEnabled': s.vocabReviewEnabled,
      'dyslexiaMode': s.dyslexiaMode,
      'slowMotionEnabled': s.slowMotionEnabled,
      'dailyMissionSize': s.dailyMissionSize,
      'learningAssistEnabled': s.learningAssistEnabled,
      'aiCompanionEnabled': s.aiCompanionEnabled,
      'routineEnabled': s.routineEnabled,
      'screenOrientation': s.screenOrientation,
      'soundOffHint': s.soundOffHint,
    };

/// Every field away from its default, so a field that is not saved shows.
const _changed = AppSettings(
  fontScale: 1.4,
  highContrastMode: true,
  darkMode: true,
  ttsEnabled: false,
  ttsSpeed: 0.8,
  reducedMotion: true,
  soundEffects: false,
  speechToText: true,
  locale: 'fil',
  notificationsEnabled: false,
  reminderHour: 7,
  reminderMinute: 30,
  voiceNavigation: true,
  adaptiveDifficulty: false,
  vocabReviewEnabled: true,
  dyslexiaMode: true,
  slowMotionEnabled: true,
  dailyMissionSize: 6,
  learningAssistEnabled: false,
  aiCompanionEnabled: false,
  routineEnabled: false,
  screenOrientation: ScreenOrientationChoice.landscape,
  soundOffHint: SoundOffHintChoice.off,
);

Future<void> _initHive() async {
  Hive.init('./build/test_cache/settings_persistence');
  if (!Hive.isBoxOpen('settings')) {
    await Hive.openBox('settings', compactionStrategy: (_, _) => false);
  }
}

void main() {
  setUpAll(_initHive);
  setUp(() async => Hive.box('settings').clear());

  group('app settings', () {
    test('every field differs from its default in the fixture', () {
      final defaults = _fields(const AppSettings());
      _fields(_changed).forEach((name, value) {
        expect(value, isNot(defaults[name]), reason: name);
      });
    });

    test('every field survives a save and a fresh read', () async {
      await HiveService.saveSettings(_changed, profileId: 'p1');
      final back = HiveService.getSettings(profileId: 'p1');
      final want = _fields(_changed);
      _fields(back).forEach((name, value) {
        expect(value, want[name], reason: '$name was not kept');
      });
    });

    test('each profile keeps its own, and a new profile gets the defaults',
        () async {
      await HiveService.saveSettings(_changed, profileId: 'p1');
      final other = _fields(HiveService.getSettings(profileId: 'p2'));
      final defaults = _fields(const AppSettings());
      other.forEach((name, value) {
        expect(value, defaults[name], reason: '$name leaked into p2');
      });
    });
  });

  group('controller settings', () {
    test('a change survives a restart, for that learner only', () async {
      final before = _containerFor('ana');
      before.read(gamepadSettingsProvider.notifier)
        ..setLeftStickMoves(false)
        ..setSwapConfirmButtons(true)
        ..setHoldToRepeat(true);
      // The write is fire-and-forget; let it land.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      before.dispose();

      final after = _containerFor('ana');
      addTearDown(after.dispose);
      final s = after.read(gamepadSettingsProvider);
      expect(s.leftStickMoves, isFalse);
      expect(s.swapConfirmButtons, isTrue);
      expect(s.holdToRepeat, isTrue);

      final ben = _containerFor('ben');
      addTearDown(ben.dispose);
      final b = ben.read(gamepadSettingsProvider);
      expect(b.leftStickMoves, isTrue, reason: "Ana's change is not Ben's");
      expect(b.swapConfirmButtons, isFalse);
    });

    test('a teacher setting a learner up writes where the learner reads',
        () async {
      final teacher = _containerFor(null);
      teacher
          .read(gamepadSettingsForProfileProvider('ana').notifier)
          .setLeftStickMoves(false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      teacher.dispose();

      final ana = _containerFor('ana');
      addTearDown(ana.dispose);
      expect(ana.read(gamepadSettingsProvider).leftStickMoves, isFalse);
    });

    test('a blob saved by 1.4.3 still loads, with the stick moving', () async {
      final old = const GamepadSettings(swapConfirmButtons: true).toMap()
        ..remove('leftStickMoves');
      await HiveService.saveProfileSetting(
        kGamepadSettingsKey,
        old,
        profileId: 'ana',
      );
      final ana = _containerFor('ana');
      addTearDown(ana.dispose);
      final s = ana.read(gamepadSettingsProvider);
      expect(s.swapConfirmButtons, isTrue);
      expect(s.leftStickMoves, isTrue);
    });
  });
}
