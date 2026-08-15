import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart' show profileProvider;
import '../models/gaze_settings.dart';

/// Hive key (in the shared `settings` box) holding the serialised
/// [GazeSettings] map. Namespaced per profile by
/// [HiveService.getProfileSetting].
const String kGazeSettingsKey = 'gazeSettings';

/// Owns the persisted [GazeSettings]. Reads are guarded so the provider yields
/// defaults when Hive isn't initialised (e.g. in widget tests), and writes are
/// fire-and-forget and guarded so a closed box can never crash the UI — the
/// same defensive posture the rest of the app uses for Hive writes.
///
/// **Per profile, like [AppSettings].** Gaze Control turns on the front camera,
/// so it must never carry over to the next learner who picks up a shared
/// classroom tablet: the settings are stored under the active profile's id and
/// the notifier rebuilds when that profile changes. A profile that hasn't
/// configured gaze gets the (camera-off) defaults — *not* the device's legacy
/// global blob — matching how `HiveService.getSettings` keeps accessibility
/// settings clean from day one.
class GazeSettingsNotifier extends Notifier<GazeSettings> {
  @override
  GazeSettings build() {
    final profileId = _watchProfileId();
    try {
      final raw = HiveService.getProfileSetting(
        kGazeSettingsKey,
        profileId: profileId,
      );
      if (raw is Map) return GazeSettings.fromMap(raw);
      // Nobody signed in yet (splash / profile picker). Those screens come
      // *before* the profile that enables gaze is known, so a hands-free
      // learner could not reach their own profile at all. Fall back to the
      // first profile that has gaze switched on, so the picker is drivable —
      // its tuning is also the closest guess we have for whoever is sitting
      // in front of the camera.
      if (profileId == null) {
        final anyEnabled = HiveService.firstProfileSettingWhere(
          kGazeSettingsKey,
          (value) => value['enabled'] == true,
        );
        if (anyEnabled != null) return GazeSettings.fromMap(anyEnabled);
      }
    } catch (_) {
      // Hive not ready → fall through to defaults.
    }
    return const GazeSettings();
  }

  /// The active profile's id, **watched** so switching learners reloads that
  /// learner's own gaze config. Null before a profile is chosen (splash /
  /// profile picker), which reads the device-level key. Guarded because the
  /// profile store reads Hive too, and this provider is expected to yield
  /// defaults rather than throw when Hive isn't up (widget tests).
  String? _watchProfileId() {
    try {
      return ref.watch(profileProvider.select((p) => p?.id));
    } catch (_) {
      return null;
    }
  }

  /// The active profile's id read fresh (not watched) at write time, so a save
  /// landing right after a profile switch always targets the correct profile —
  /// mirroring `SettingsNotifier._save`.
  String? _readProfileId() {
    try {
      return ref.read(profileProvider)?.id;
    } catch (_) {
      return null;
    }
  }

  void update(GazeSettings settings) {
    state = settings;
    _persist(settings);
  }

  void setEnabled(bool v) => update(state.copyWith(enabled: v));
  void setSensitivity(int v) => update(state.copyWith(sensitivity: v));
  void setDwellMs(int v) => update(state.copyWith(dwellMs: v));
  void setBlinkEnabled(bool v) => update(state.copyWith(blinkEnabled: v));
  void setMirrorHorizontal(bool v) =>
      update(state.copyWith(mirrorHorizontal: v));
  void setInvertVertical(bool v) => update(state.copyWith(invertVertical: v));
  void setScanMode(bool v) => update(state.copyWith(scanMode: v));
  void setScanStepMs(int v) => update(state.copyWith(scanStepMs: v));
  void setVoiceCommands(bool v) => update(state.copyWith(voiceCommands: v));
  void setNavScope(GazeNavScope v) => update(state.copyWith(navScope: v));

  void _persist(GazeSettings s) {
    try {
      HiveService.saveProfileSetting(
        kGazeSettingsKey,
        s.toMap(),
        profileId: _readProfileId(),
      ).ignore();
    } catch (_) {
      // Box not open (tests) — state still updates in memory.
    }
  }
}

final gazeSettingsProvider =
    NotifierProvider<GazeSettingsNotifier, GazeSettings>(
      GazeSettingsNotifier.new,
    );

/// Gaze settings for the screens that run **before anyone has chosen a
/// profile** — the profile picker.
///
/// [gazeSettingsProvider] can't serve these: the device still remembers the
/// *last* profile that was signed in, so a picker reading it would follow
/// whoever used the tablet before rather than whoever is sitting in front of
/// it now. A gaze learner would be locked out of the app by the previous
/// user's settings.
///
/// So the picker takes the first profile that has gaze switched on (using its
/// tuning, the closest guess available), and only falls back to the ordinary
/// settings when nobody has. Read-only — the picker configures nothing.
final gazePickerSettingsProvider = Provider<GazeSettings>((ref) {
  try {
    final anyEnabled = HiveService.firstProfileSettingWhere(
      kGazeSettingsKey,
      (value) => value['enabled'] == true,
    );
    if (anyEnabled != null) return GazeSettings.fromMap(anyEnabled);
  } catch (_) {
    // Hive not ready → fall through.
  }
  return ref.watch(gazeSettingsProvider);
});
