import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_presets.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Two ways in to hands-free control that did not exist before:
///
/// * the **front door** — with settings scoped per profile, the profile picker
///   has no active profile to read from, so a gaze learner could not reach the
///   profile that enables gaze. It now runs on the first profile that has gaze
///   switched on.
/// * the **accessibility wizard** — the Motor Impairment preset never mentioned
///   gaze, so the category whose defining barrier is reaching the screen was
///   never offered the feature built for it.

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
          disabilityType: DisabilityType.motor,
          createdAt: DateTime(2026),
        );
}

ProviderContainer _containerFor(String? profileId) => ProviderContainer(
      overrides: [
        profileProvider.overrideWith(() => _StubProfileNotifier(profileId)),
      ],
    );

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/gaze_front_door');
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
  });
  setUp(() async => Hive.box('settings').clear());

  group('the profile picker can be driven before anyone signs in', () {
    test('runs on the gaze learner\'s tuning, not the last user\'s settings',
        () async {
      // A learner configured gaze on their own profile…
      final learner = _containerFor('p-motor');
      learner.read(gazeSettingsProvider.notifier).update(
            const GazeSettings(enabled: true, sensitivity: 5, dwellMs: 2200),
          );
      learner.dispose();
      // …then somebody else used the tablet and is still the "active" profile,
      // which is the state a cold start actually lands in.
      final other = _containerFor('p-deaf');
      other.read(gazeSettingsProvider.notifier).setSensitivity(2);
      other.dispose();
      await Future<void>.delayed(Duration.zero);

      final picker = _containerFor('p-deaf');
      addTearDown(picker.dispose);

      // The ordinary provider follows the remembered profile — gaze off.
      expect(picker.read(gazeSettingsProvider).enabled, isFalse);
      // The picker's provider finds the learner who needs it.
      final atPicker = picker.read(gazePickerSettingsProvider);
      expect(atPicker.enabled, isTrue);
      expect(atPicker.sensitivity, 5);
      expect(atPicker.dwellMs, 2200);
    });

    test('stays off when no profile has enabled it', () async {
      final learner = _containerFor('p-motor');
      learner.read(gazeSettingsProvider.notifier).setSensitivity(4);
      learner.dispose();
      await Future<void>.delayed(Duration.zero);

      final picker = _containerFor(null);
      addTearDown(picker.dispose);
      expect(picker.read(gazePickerSettingsProvider).enabled, isFalse,
          reason: 'no camera at the front door unless somebody asked for one');
    });

    test('with no profile at all it reads the device-level key', () async {
      await HiveService.saveSetting(
        kGazeSettingsKey,
        const GazeSettings(sensitivity: 1).toMap(),
      );
      final picker = _containerFor(null);
      addTearDown(picker.dispose);
      expect(picker.read(gazeSettingsProvider).sensitivity, 1);
    });
  });

  group('the accessibility wizard offers gaze where it matters', () {
    test('motor and multiple enable it; nobody else does', () {
      expect(AccessibilityPresets.enablesGazeControl(DisabilityType.motor),
          isTrue);
      expect(AccessibilityPresets.enablesGazeControl(DisabilityType.multiple),
          isTrue);
      for (final type in const [
        DisabilityType.visual,
        DisabilityType.hearing,
        DisabilityType.cognitive,
        DisabilityType.none,
      ]) {
        expect(AccessibilityPresets.enablesGazeControl(type), isFalse,
            reason: 'the front camera stays off for $type unless asked');
      }
    });

    test('the preview tells the learner before the camera is switched on', () {
      for (final type in const [
        DisabilityType.motor,
        DisabilityType.multiple,
      ]) {
        expect(
          AccessibilityPresets.changeSummary(type).map((c) => c.name),
          contains('Gaze Control'),
          reason: 'a camera turning on must never be a silent side effect',
        );
      }
      expect(
        AccessibilityPresets.changeSummary(DisabilityType.visual)
            .map((c) => c.name),
        isNot(contains('Gaze Control')),
      );
    });
  });

  tearDownAll(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 10));
    } catch (_) {}
  });
}
