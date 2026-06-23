/// How far the hands-free **bottom-nav D-pad** reaches.
///
/// [bottomNav] (default) — the head D-pad only moves the highlight across the
/// bottom navigation tabs, exactly as before.
///
/// [bottomNavAndHomeTiles] — on the foreground hub (Home, Cards, Games, Stories
/// or Progress) the same D-pad also reaches the feature tiles: look ▲ ▼ moves
/// between tile rows, ◀ ▶ within a row, and the bottom-nav bar is the grid's
/// bottom row. A blink (or, when blink is off, look-up) opens the focused tile.
/// (The enum value name is kept for persisted-settings compatibility.)
enum GazeNavScope { bottomNav, bottomNavAndHomeTiles }

/// User-tunable configuration for the Gaze (head + blink) accessibility
/// control, persisted in the Hive `settings` box (see `gazeSettingsProvider`).
///
/// A single friendly **sensitivity** (1 = needs a big, deliberate head turn …
/// 5 = a small movement is enough) is exposed instead of raw degrees; the
/// per-axis thresholds the `resolveGazeZone` resolver needs are derived from it
/// so a teacher only has to reason about one dial. Plain immutable class with
/// `copyWith`, mirroring `AppSettings`.
class GazeSettings {
  /// Whether gaze control is allowed to drive the app. The preview screen itself
  /// always runs when opened.
  final bool enabled;

  /// 1 … 5. Higher = more sensitive (smaller head movement selects).
  final int sensitivity;

  /// How long a target must be held before it fires, in milliseconds.
  final int dwellMs;

  /// Whether a deliberate long blink acts as a confirm gesture.
  final bool blinkEnabled;

  /// Front-camera yaw is mirrored relative to the user; on by default. Flip if
  /// Left/Right feel swapped on a given device.
  final bool mirrorHorizontal;

  /// Flip if Up/Down feel swapped on a given device.
  final bool invertVertical;

  /// Scanning fallback: instead of head movement choosing a target, the app
  /// highlights each target in turn and the learner blinks to pick the
  /// highlighted one. For learners who can blink reliably but cannot move their
  /// head. Off by default (head movement is the primary mode).
  final bool scanMode;

  /// How long each item stays highlighted in scanning mode, in milliseconds.
  final int scanStepMs;

  /// Listen for spoken commands ("next", "back", "flip", "scroll down", …) and
  /// run them, alongside the targets. Off by default.
  final bool voiceCommands;

  /// How far the hands-free bottom-nav D-pad reaches. Defaults to
  /// [GazeNavScope.bottomNav] so existing behaviour is unchanged until the
  /// learner opts into the Home-tiles reach.
  final GazeNavScope navScope;

  const GazeSettings({
    this.enabled = false,
    this.sensitivity = 3,
    this.dwellMs = 1500,
    this.blinkEnabled = true,
    this.mirrorHorizontal = true,
    this.invertVertical = false,
    this.scanMode = false,
    this.scanStepMs = 2000,
    this.voiceCommands = false,
    this.navScope = GazeNavScope.bottomNav,
  });

  /// Whether the D-pad should also drive the foreground hub's feature tiles
  /// (Home, Cards, Games, Stories, Progress).
  bool get navHomeTiles => navScope == GazeNavScope.bottomNavAndHomeTiles;

  /// Lowest/highest values the UI sliders allow.
  static const int minSensitivity = 1;
  static const int maxSensitivity = 5;
  static const int minDwellMs = 800;
  static const int maxDwellMs = 3000;
  static const int minScanStepMs = 1000;
  static const int maxScanStepMs = 4000;

  /// Dwell time as a [Duration] for `DwellTracker`.
  Duration get dwellDuration => Duration(milliseconds: dwellMs);

  /// Scanning step as a [Duration] for the scan timer.
  Duration get scanStepDuration => Duration(milliseconds: scanStepMs);

  /// Head-turn (yaw) threshold in degrees, derived from [sensitivity]:
  /// sensitivity 1 → 20° (big movement), sensitivity 5 → 8° (small movement).
  double get turnThresholdDeg => _lerpBySensitivity(20, 8);

  /// Head-tilt (pitch) threshold in degrees: 16° (s=1) … 6° (s=5). Slightly
  /// tighter than yaw because up/down head movement has less comfortable range.
  double get tiltThresholdDeg => _lerpBySensitivity(16, 6);

  double _lerpBySensitivity(double atMin, double atMax) {
    final s = sensitivity.clamp(minSensitivity, maxSensitivity);
    final t = (s - minSensitivity) / (maxSensitivity - minSensitivity);
    return atMin + (atMax - atMin) * t;
  }

  GazeSettings copyWith({
    bool? enabled,
    int? sensitivity,
    int? dwellMs,
    bool? blinkEnabled,
    bool? mirrorHorizontal,
    bool? invertVertical,
    bool? scanMode,
    int? scanStepMs,
    bool? voiceCommands,
    GazeNavScope? navScope,
  }) {
    return GazeSettings(
      enabled: enabled ?? this.enabled,
      sensitivity:
          (sensitivity ?? this.sensitivity).clamp(minSensitivity, maxSensitivity),
      dwellMs: (dwellMs ?? this.dwellMs).clamp(minDwellMs, maxDwellMs),
      blinkEnabled: blinkEnabled ?? this.blinkEnabled,
      mirrorHorizontal: mirrorHorizontal ?? this.mirrorHorizontal,
      invertVertical: invertVertical ?? this.invertVertical,
      scanMode: scanMode ?? this.scanMode,
      scanStepMs:
          (scanStepMs ?? this.scanStepMs).clamp(minScanStepMs, maxScanStepMs),
      voiceCommands: voiceCommands ?? this.voiceCommands,
      navScope: navScope ?? this.navScope,
    );
  }

  /// Serialises to a plain map for Hive. Kept primitive so it round-trips
  /// through Hive's default type adapters.
  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'sensitivity': sensitivity,
        'dwellMs': dwellMs,
        'blinkEnabled': blinkEnabled,
        'mirrorHorizontal': mirrorHorizontal,
        'invertVertical': invertVertical,
        'scanMode': scanMode,
        'scanStepMs': scanStepMs,
        'voiceCommands': voiceCommands,
        'navScope': navScope.name,
      };

  /// Rebuilds from a Hive map, tolerating missing/typo'd keys by falling back
  /// to the defaults — so an older saved blob never crashes a newer build.
  factory GazeSettings.fromMap(Map? map) {
    const d = GazeSettings();
    if (map == null) return d;
    int asInt(Object? v, int fallback) => v is int ? v : (v is num ? v.toInt() : fallback);
    bool asBool(Object? v, bool fallback) => v is bool ? v : fallback;
    GazeNavScope asNavScope(Object? v) => GazeNavScope.values
        .firstWhere((s) => s.name == v, orElse: () => d.navScope);
    return GazeSettings(
      enabled: asBool(map['enabled'], d.enabled),
      sensitivity: asInt(map['sensitivity'], d.sensitivity)
          .clamp(minSensitivity, maxSensitivity),
      dwellMs: asInt(map['dwellMs'], d.dwellMs).clamp(minDwellMs, maxDwellMs),
      blinkEnabled: asBool(map['blinkEnabled'], d.blinkEnabled),
      mirrorHorizontal: asBool(map['mirrorHorizontal'], d.mirrorHorizontal),
      invertVertical: asBool(map['invertVertical'], d.invertVertical),
      scanMode: asBool(map['scanMode'], d.scanMode),
      scanStepMs: asInt(map['scanStepMs'], d.scanStepMs)
          .clamp(minScanStepMs, maxScanStepMs),
      voiceCommands: asBool(map['voiceCommands'], d.voiceCommands),
      navScope: asNavScope(map['navScope']),
    );
  }
}
