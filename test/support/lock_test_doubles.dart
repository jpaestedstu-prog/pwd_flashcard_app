import 'package:pwdpwdpwd/core/services/lock_announcer.dart';
import 'package:pwdpwdpwd/core/services/lock_presentation.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Doubles shared by the lock-screen and lock-warning suites, so both
/// describe the announcement the same way.

/// One recorded [LockAnnouncer.announce] call.
class AnnounceCall {
  AnnounceCall({
    required this.presentation,
    required this.message,
    required this.alarmEnabled,
    required this.voiceEnabled,
    required this.speakFilipino,
  });

  final LockPresentation presentation;
  final String message;
  final bool alarmEnabled;
  final bool voiceEnabled;
  final bool speakFilipino;
}

/// Stands in for the real announcer, which drives `audioplayers` and
/// `flutter_tts` — neither exists in the test binding.
class RecordingAnnouncer implements LockAnnouncer {
  final List<AnnounceCall> calls = [];
  int stopCount = 0;

  @override
  Future<void> announce({
    required LockPresentation presentation,
    required String message,
    bool alarmEnabled = true,
    bool voiceEnabled = true,
    bool speakFilipino = false,
  }) async {
    calls.add(AnnounceCall(
      presentation: presentation,
      message: message,
      alarmEnabled: alarmEnabled,
      voiceEnabled: voiceEnabled,
      speakFilipino: speakFilipino,
    ));
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> dispose() async {}
}

/// Fixed settings so widget tests never read or write Hive.
class FixedSettings extends SettingsNotifier {
  FixedSettings(this._settings);
  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

/// Fixed active profile, same reason.
class FixedProfile extends ProfileNotifier {
  FixedProfile(this._profile);
  final UserProfile _profile;

  @override
  UserProfile? build() => _profile;
}
