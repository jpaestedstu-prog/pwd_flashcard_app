import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart'
    show profileAtTablet, profileProvider;
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
class GazeSettingsNotifier extends Notifier<GazeSettings>
    with GazeSettingsEditing {
  @override
  GazeSettings get current => state;

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

  /// The id of the profile at the tablet, **watched** so switching learners
  /// reloads that learner's own gaze config. Null before a profile is chosen
  /// (splash / profile picker), which reads the device-level key. Guarded
  /// because the profile store reads Hive too, and this provider is expected
  /// to yield defaults rather than throw when Hive isn't up (widget tests).
  ///
  /// The person at the tablet, not simply the active profile: while a teacher
  /// or parent "views as" a learner (their dashboard), the learner is active
  /// but the face in front of the camera is still the educator's. Following
  /// the active profile ran the camera on the learner's settings for the
  /// teacher — and counted the teacher's gaze use as the learner's in the
  /// study's measurements (see [profileAtTablet]).
  String? _watchProfileId() {
    try {
      ref.watch(profileProvider.select((p) => p?.id));
      return gazeProfileIdAtTablet(ref.read);
    } catch (_) {
      return null;
    }
  }

  /// The same profile read fresh (not watched) at write time, so a save
  /// landing right after a profile switch always targets the correct profile —
  /// mirroring `SettingsNotifier._save`.
  String? _readProfileId() {
    try {
      return gazeProfileIdAtTablet(ref.read);
    } catch (_) {
      return null;
    }
  }

  @override
  void update(GazeSettings settings) {
    state = settings;
    _persist(settings);
  }


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

/// The id of the profile whose gaze is in use: the person at the tablet —
/// the educator, while they view a learner's dashboard ([profileAtTablet]).
/// [read] is a `ref.read` (a `Ref`'s or a `WidgetRef`'s). May throw when the
/// profile store is not up; callers guard it.
String? gazeProfileIdAtTablet(T Function<T>(ProviderListenable<T>) read) =>
    profileAtTablet(read(profileProvider), read(profileProvider.notifier))?.id;

/// Every change the Gaze Control screen can make, shared by the signed-in
/// learner's settings and a learner's settings opened by their teacher or
/// parent ([gazeSettingsForProfileProvider]).
mixin GazeSettingsEditing {
  GazeSettings get current;
  void update(GazeSettings settings);

  void setEnabled(bool v) => update(current.copyWith(enabled: v));

  /// Switches gaze on for a learner whose chosen way of using the app *is*
  /// gaze (their setup answer), with the full "Bottom nav + feature tiles"
  /// reach. Setup used to switch on the camera alone, which left such a
  /// learner on the bottom-nav-only reach: they could move between the five
  /// hubs but open nothing on any of them.
  void enableForGazeLearner() => update(
    current.copyWith(
      enabled: true,
      navScope: GazeNavScope.bottomNavAndHomeTiles,
    ),
  );
  void setSensitivity(int v) => update(current.copyWith(sensitivity: v));
  void setDwellMs(int v) => update(current.copyWith(dwellMs: v));
  void setBlinkEnabled(bool v) => update(current.copyWith(blinkEnabled: v));
  void setMirrorHorizontal(bool v) =>
      update(current.copyWith(mirrorHorizontal: v));
  void setInvertVertical(bool v) =>
      update(current.copyWith(invertVertical: v));
  void setScanMode(bool v) => update(current.copyWith(scanMode: v));
  void setScanStepMs(int v) => update(current.copyWith(scanStepMs: v));
  void setVoiceCommands(bool v) => update(current.copyWith(voiceCommands: v));
  void setNavScope(GazeNavScope v) => update(current.copyWith(navScope: v));
  void setSmoothing(GazeSmoothing v) => update(current.copyWith(smoothing: v));
  void setPickWith(GazePick v) => update(current.copyWith(pickWith: v));
  void setDwellSelect(bool v) => update(current.copyWith(dwellSelect: v));
  void setDwellSelectMs(int v) =>
      update(current.copyWith(dwellSelectMs: v));
  void setSpeakHighlight(bool v) =>
      update(current.copyWith(speakHighlight: v));

  /// Saves a captured resting position (raw camera angles).
  void setRestPosition(double yaw, double pitch) =>
      update(current.copyWith(restYaw: yaw, restPitch: pitch));

  /// Back to measuring from straight ahead.
  void clearRestPosition() =>
      update(current.copyWith(restYaw: 0, restPitch: 0));
}

/// One learner's gaze settings by profile id, for a **teacher or parent**
/// changing them from their own profile on the same tablet — the learner
/// does not have to be signed in, and a child (whose home has no Settings)
/// gets the same full Gaze Control screen through their grown-up.
///
/// The same storage as [gazeSettingsProvider], so the learner's own scopes
/// pick the change up the next time the learner signs in.
class GazeProfileSettingsNotifier
    extends FamilyNotifier<GazeSettings, String>
    with GazeSettingsEditing {
  @override
  GazeSettings get current => state;

  @override
  GazeSettings build(String profileId) {
    try {
      final raw = HiveService.getProfileSetting(
        kGazeSettingsKey,
        profileId: profileId,
      );
      if (raw is Map) return GazeSettings.fromMap(raw);
    } catch (_) {}
    return const GazeSettings();
  }

  @override
  void update(GazeSettings settings) {
    state = settings;
    try {
      HiveService.saveProfileSetting(
        kGazeSettingsKey,
        settings.toMap(),
        profileId: arg,
      ).ignore();
    } catch (_) {}
    // If this learner happens to be the one at the tablet, keep their live
    // copy in step (it reads the same storage, but only when it rebuilds).
    try {
      if (gazeProfileIdAtTablet(ref.read) == arg) {
        ref.invalidate(gazeSettingsProvider);
      }
    } catch (_) {}
  }
}

final gazeSettingsForProfileProvider = NotifierProvider.family<
  GazeProfileSettingsNotifier,
  GazeSettings,
  String
>(GazeProfileSettingsNotifier.new);

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
