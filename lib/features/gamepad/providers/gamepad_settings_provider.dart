import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart' show profileProvider;
import '../models/gamepad_settings.dart';

/// Hive key (in the shared `settings` box) holding the serialised
/// [GamepadSettings] map, namespaced per profile.
const String kGamepadSettingsKey = 'gamepadSettings';

/// Owns the persisted [GamepadSettings].
///
/// **Per profile, like `GazeSettings`.** A shared classroom tablet may be
/// passed from a blind learner (who wants every move spoken) to a sighted one
/// (who would find it maddening), so the speech and confirm preferences follow
/// the learner rather than the device.
///
/// Reads are guarded so the provider yields defaults when Hive isn't
/// initialised (widget tests), and writes are fire-and-forget and guarded so a
/// closed box can never crash the UI.
class GamepadSettingsNotifier extends Notifier<GamepadSettings> {
  @override
  GamepadSettings build() {
    final profileId = _watchProfileId();
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

  String? _watchProfileId() {
    try {
      return ref.watch(profileProvider.select((p) => p?.id));
    } catch (_) {
      return null;
    }
  }

  String? _readProfileId() {
    try {
      return ref.read(profileProvider)?.id;
    } catch (_) {
      return null;
    }
  }

  void update(GamepadSettings settings) {
    state = settings;
    _persist(settings);
  }

  void setEnabled(bool v) => update(state.copyWith(enabled: v));
  void setSpeak(bool v) => update(state.copyWith(speak: v));
  void setConfirmSectionChange(bool v) =>
      update(state.copyWith(confirmSectionChange: v));
  void setAnnounceItems(bool v) => update(state.copyWith(announceItems: v));
  void setVibrate(bool v) => update(state.copyWith(vibrate: v));
  void setDedupeMs(int v) => update(state.copyWith(dedupeMs: v));
  void setSwapConfirmButtons(bool v) =>
      update(state.copyWith(swapConfirmButtons: v));
  void setHoldToRepeat(bool v) => update(state.copyWith(holdToRepeat: v));
  void setRepeatDelayMs(int v) => update(state.copyWith(repeatDelayMs: v));
  void setRepeatRateMs(int v) => update(state.copyWith(repeatRateMs: v));

  void _persist(GamepadSettings s) {
    try {
      HiveService.saveProfileSetting(
        kGamepadSettingsKey,
        s.toMap(),
        profileId: _readProfileId(),
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
