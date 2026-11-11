import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/models/enums.dart';
import '../../data/models/models.dart';

/// The device's media sound: the stream the app's speech plays on.
///
/// With it at zero every spoken word is silent, and nothing in the app said
/// why (found on the tablet: its media volume was 0 of 15). Read through the
/// `flashlearn/audio` channel (MainActivity on Android, AppDelegate on iOS).
class DeviceSound {
  const DeviceSound._();

  static const _channel = MethodChannel('flashlearn/audio');

  /// True when the media sound is all the way down or muted; null when it
  /// cannot be told (no native side, as on a desktop or in a test).
  static Future<bool?> isOff() async {
    final probe = debugIsOff;
    if (probe != null) return probe();
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('mediaVolume');
      if (r == null) return null;
      final level = (r['level'] as num?)?.toDouble();
      return r['muted'] == true || (level != null && level <= 0);
    } catch (_) {
      return null;
    }
  }

  /// Whether the app may turn the sound up itself. Android only: iOS leaves
  /// the volume to the person holding the device.
  static bool get canTurnUp =>
      debugCanTurnUp ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// Turns the media sound up to a third of the way, with the system's own
  /// volume panel on screen so the change is seen. Only ever on a tap. True
  /// when it could.
  static Future<bool> turnUp() async {
    final probe = debugTurnUp;
    if (probe != null) return probe();
    try {
      return await _channel.invokeMethod<bool>('turnUp') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Whether the app can open the device's own voice settings, where a
  /// Filipino voice is added ([openVoiceSettings]). Android only.
  static bool get canOpenVoiceSettings =>
      debugCanOpenVoiceSettings ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// Opens the speech engine's "install voice data" screen, or else the
  /// device's text-to-speech settings. True when one opened. Only on a tap.
  static Future<bool> openVoiceSettings() async {
    final probe = debugOpenVoiceSettings;
    if (probe != null) return probe();
    try {
      return await _channel.invokeMethod<bool>('openVoiceSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android's language screen for TalkBack, or else the device's
  /// languages: TalkBack's own words ("Button") follow its language, not the
  /// app's. True when one opened. Only on a tap.
  static Future<bool> openTalkBackLanguage() async {
    final probe = debugOpenTalkBackLanguage;
    if (probe != null) return probe();
    try {
      return await _channel.invokeMethod<bool>('openTalkBackLanguage') ?? false;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static Future<bool> Function()? debugOpenTalkBackLanguage;

  @visibleForTesting
  static bool? debugCanOpenVoiceSettings;

  @visibleForTesting
  static Future<bool> Function()? debugOpenVoiceSettings;

  @visibleForTesting
  static Future<bool?> Function()? debugIsOff;

  @visibleForTesting
  static Future<bool> Function()? debugTurnUp;

  @visibleForTesting
  static bool? debugCanTurnUp;
}

/// Whether [profile] should be told when the sound is off while the app
/// speaks: by the profile's own choice, or by default for learners who listen
/// to the words (Visual Impairment, or Voice-Guided Navigation on). A learner
/// with speech switched off never is: there is nothing to miss.
bool soundOffHintWanted(UserProfile? profile, AppSettings settings) {
  if (!settings.ttsEnabled) return false;
  return switch (settings.soundOffHint) {
    SoundOffHintChoice.on => true,
    SoundOffHintChoice.off => false,
    SoundOffHintChoice.auto =>
      settings.voiceNavigation ||
          profile?.disabilityType == DisabilityType.visual,
  };
}
