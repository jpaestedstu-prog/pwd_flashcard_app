import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';
import '../../../data/models/models.dart' show UserProfile;
import '../../../providers/app_providers.dart'
    show profileAtTablet, profileProvider;
import '../../settings/models/settings_presentation.dart'
    show ownsHandsFreeInput;
import '../models/gamepad_settings.dart';

/// Hive key (in the shared `settings` box) holding the serialised
/// [GamepadSettings] map, namespaced per profile.
const String kGamepadSettingsKey = 'gamepadSettings';

/// Every change the Game Controller screen can make, shared by the signed-in
/// learner's settings and a learner's settings opened by their teacher or
/// parent ([gamepadSettingsForProfileProvider]) — the same split as Gaze
/// Control's `GazeSettingsEditing`.
mixin GamepadSettingsEditing {
  GamepadSettings get current;
  void update(GamepadSettings settings);

  void setEnabled(bool v) => update(current.copyWith(enabled: v));
  void setSpeak(bool v) => update(current.copyWith(speak: v));
  void setConfirmSectionChange(bool v) =>
      update(current.copyWith(confirmSectionChange: v));
  void setAnnounceItems(bool v) => update(current.copyWith(announceItems: v));
  void setVibrate(bool v) => update(current.copyWith(vibrate: v));
  void setDedupeMs(int v) => update(current.copyWith(dedupeMs: v));
  void setSwapConfirmButtons(bool v) =>
      update(current.copyWith(swapConfirmButtons: v));
  void setHoldToRepeat(bool v) => update(current.copyWith(holdToRepeat: v));
  void setRepeatDelayMs(int v) => update(current.copyWith(repeatDelayMs: v));
  void setRepeatRateMs(int v) => update(current.copyWith(repeatRateMs: v));
}

/// Owns the persisted [GamepadSettings].
///
/// **Per profile, like `GazeSettings`.** A shared classroom tablet may be
/// passed from a blind learner (who wants every move spoken) to a sighted one
/// (who would find it maddening), so the speech and confirm preferences follow
/// the learner rather than the device.
///
/// **The person at the tablet, like `GazeSettings`.** While a Teacher or a
/// Parent "views as" a learner, the hands on the controller are still theirs.
/// And a Teacher's or Parent's own profile never drives the app with a
/// controller ([ownsHandsFreeInput]): it is a learner's way in, their Settings
/// no longer offer it, and a pad paired for a learner on a shared tablet must
/// not start narrating the educator's dashboard. They set a learner's
/// controller up from the learner's card instead.
///
/// Reads are guarded so the provider yields defaults when Hive isn't
/// initialised (widget tests), and writes are fire-and-forget and guarded so a
/// closed box can never crash the UI.
class GamepadSettingsNotifier extends Notifier<GamepadSettings>
    with GamepadSettingsEditing {
  @override
  GamepadSettings get current => state;

  @override
  GamepadSettings build() {
    final atTablet = _watchProfileAtTablet();
    return _effective(_stored(atTablet?.id), atTablet);
  }

  static GamepadSettings _effective(
    GamepadSettings s,
    UserProfile? atTablet,
  ) =>
      s.enabled && !ownsHandsFreeInput(atTablet)
          ? s.copyWith(enabled: false)
          : s;

  static GamepadSettings _stored(String? profileId) {
    try {
      final raw = HiveService.getProfileSetting(
        kGamepadSettingsKey,
        profileId: profileId,
      );
      if (raw is Map) return GamepadSettings.fromMap(raw);
    } catch (_) {
      // Hive not ready → defaults.
    }
    return const GamepadSettings();
  }

  UserProfile? _watchProfileAtTablet() {
    try {
      ref.watch(profileProvider.select((p) => p?.id));
      return _profileAtTablet();
    } catch (_) {
      return null;
    }
  }

  UserProfile? _profileAtTablet() {
    try {
      return profileAtTablet(
        ref.read(profileProvider),
        ref.read(profileProvider.notifier),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void update(GamepadSettings settings) {
    state = _effective(settings, _profileAtTablet());
    _persist(settings);
  }

  void _persist(GamepadSettings s) {
    try {
      HiveService.saveProfileSetting(
        kGamepadSettingsKey,
        s.toMap(),
        profileId: _profileAtTablet()?.id,
      ).ignore();
    } catch (_) {
      // Box not open (tests) — state still updates in memory.
    }
  }
}

final gamepadSettingsProvider =
    NotifierProvider<GamepadSettingsNotifier, GamepadSettings>(
  GamepadSettingsNotifier.new,
);

/// One learner's controller settings by profile id, for a **teacher or
/// parent** changing them from their own profile on the same tablet — the
/// learner does not have to be signed in, and a Child (whose home has no
/// Settings) gets the full Game Controller screen through their grown-up.
///
/// The same storage as [gamepadSettingsProvider], so the learner's own host
/// picks the change up the next time the learner signs in.
class GamepadProfileSettingsNotifier
    extends FamilyNotifier<GamepadSettings, String>
    with GamepadSettingsEditing {
  @override
  GamepadSettings get current => state;

  @override
  GamepadSettings build(String profileId) =>
      GamepadSettingsNotifier._stored(profileId);

  @override
  void update(GamepadSettings settings) {
    state = settings;
    try {
      HiveService.saveProfileSetting(
        kGamepadSettingsKey,
        settings.toMap(),
        profileId: arg,
      ).ignore();
    } catch (_) {}
    // If this learner is the one at the tablet, keep their live copy in step.
    try {
      final atTablet = profileAtTablet(
        ref.read(profileProvider),
        ref.read(profileProvider.notifier),
      );
      if (atTablet?.id == arg) ref.invalidate(gamepadSettingsProvider);
    } catch (_) {}
  }
}

final gamepadSettingsForProfileProvider = NotifierProvider.family<
    GamepadProfileSettingsNotifier, GamepadSettings, String>(
  GamepadProfileSettingsNotifier.new,
);
