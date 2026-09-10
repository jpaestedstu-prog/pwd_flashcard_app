/// User-tunable configuration for Bluetooth gamepad control, persisted per
/// profile in the Hive `settings` box (see `gamepadSettingsProvider`).
///
/// Mirrors `GazeSettings`: a plain immutable class with `copyWith`, a
/// primitive-only `toMap`, and a `fromMap` that tolerates missing keys so an
/// older saved blob never crashes a newer build.
class GamepadSettings {
  /// Whether a connected controller may drive the app.
  ///
  /// **On by default**, unlike Gaze Control. Gaze costs a camera and a
  /// permission, so it has to be opted into; a gamepad costs nothing until one
  /// is actually paired, and a learner who cannot see the screen should not
  /// have to find a settings toggle — using their own hands, on the screen
  /// they cannot read — before their controller works.
  final bool enabled;

  /// Speak what is happening. This is the whole point of the feature for a
  /// blind learner, so it defaults on; sighted learners using a pad for
  /// convenience can turn it off and keep the navigation.
  final bool speak;

  /// Ask "Do you want to go to the Cards section?" before switching sections,
  /// instead of switching immediately.
  final bool confirmSectionChange;

  /// Announce each item as the cursor lands on it ("Cards, 2 of 8").
  final bool announceItems;

  /// Pulse the tablet on every accepted press — a second, silent channel
  /// confirming the press registered, which matters when the speech is still
  /// finishing the previous sentence.
  final bool vibrate;

  /// How long one control stays "spent" after firing, in milliseconds. Guards
  /// against the pad's duplicate HID reports, auto-repeat and contact bounce.
  /// Raise it for a learner whose grip tremor produces extra presses.
  final int dedupeMs;

  /// Swap which face button means *yes*. Most Android pads (the X3 included)
  /// report the bottom button as A; Nintendo-layout pads report it as B, which
  /// would otherwise make "press A for yes" answer *no*.
  final bool swapConfirmButtons;

  /// Holding a navigation control keeps it moving, instead of one press per
  /// step.
  ///
  /// **Off by default, and deliberately so.** One press meaning exactly one
  /// move is what makes the controller predictable for a learner with a motor
  /// impairment, who may hold a button simply because releasing it is hard.
  /// But a learner walking a forty-item Home screen one press at a time has a
  /// fair complaint, so this is offered — opt-in, and only for movement.
  /// Opening, going back and switching section never repeat.
  final bool holdToRepeat;

  /// How long a control must be held before repeating starts, in milliseconds.
  /// Long enough that an ordinary press never triggers it.
  final int repeatDelayMs;

  /// Milliseconds between repeats once they start.
  final int repeatRateMs;

  const GamepadSettings({
    this.enabled = true,
    this.speak = true,
    this.confirmSectionChange = true,
    this.announceItems = true,
    this.vibrate = true,
    this.dedupeMs = 140,
    this.swapConfirmButtons = false,
    this.holdToRepeat = false,
    this.repeatDelayMs = 600,
    this.repeatRateMs = 350,
  });

  static const int minDedupeMs = 60;
  static const int maxDedupeMs = 600;
  static const int minRepeatDelayMs = 300;
  static const int maxRepeatDelayMs = 1500;
  static const int minRepeatRateMs = 150;
  static const int maxRepeatRateMs = 900;

  Duration get repeatDelay => Duration(milliseconds: repeatDelayMs);
  Duration get repeatRate => Duration(milliseconds: repeatRateMs);

  Duration get dedupeWindow => Duration(milliseconds: dedupeMs);

  GamepadSettings copyWith({
    bool? enabled,
    bool? speak,
    bool? confirmSectionChange,
    bool? announceItems,
    bool? vibrate,
    int? dedupeMs,
    bool? swapConfirmButtons,
    bool? holdToRepeat,
    int? repeatDelayMs,
    int? repeatRateMs,
  }) {
    return GamepadSettings(
      enabled: enabled ?? this.enabled,
      speak: speak ?? this.speak,
      confirmSectionChange: confirmSectionChange ?? this.confirmSectionChange,
      announceItems: announceItems ?? this.announceItems,
      vibrate: vibrate ?? this.vibrate,
      dedupeMs: (dedupeMs ?? this.dedupeMs).clamp(minDedupeMs, maxDedupeMs),
      swapConfirmButtons: swapConfirmButtons ?? this.swapConfirmButtons,
      holdToRepeat: holdToRepeat ?? this.holdToRepeat,
      repeatDelayMs: (repeatDelayMs ?? this.repeatDelayMs)
          .clamp(minRepeatDelayMs, maxRepeatDelayMs),
      repeatRateMs: (repeatRateMs ?? this.repeatRateMs)
          .clamp(minRepeatRateMs, maxRepeatRateMs),
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'speak': speak,
        'confirmSectionChange': confirmSectionChange,
        'announceItems': announceItems,
        'vibrate': vibrate,
        'dedupeMs': dedupeMs,
        'swapConfirmButtons': swapConfirmButtons,
        'holdToRepeat': holdToRepeat,
        'repeatDelayMs': repeatDelayMs,
        'repeatRateMs': repeatRateMs,
      };

  factory GamepadSettings.fromMap(Map? map) {
    const d = GamepadSettings();
    if (map == null) return d;
    bool asBool(Object? v, bool fallback) => v is bool ? v : fallback;
    int asInt(Object? v, int fallback) =>
        v is int ? v : (v is num ? v.toInt() : fallback);
    return GamepadSettings(
      enabled: asBool(map['enabled'], d.enabled),
      speak: asBool(map['speak'], d.speak),
      confirmSectionChange:
          asBool(map['confirmSectionChange'], d.confirmSectionChange),
      announceItems: asBool(map['announceItems'], d.announceItems),
      vibrate: asBool(map['vibrate'], d.vibrate),
      dedupeMs:
          asInt(map['dedupeMs'], d.dedupeMs).clamp(minDedupeMs, maxDedupeMs),
      swapConfirmButtons:
          asBool(map['swapConfirmButtons'], d.swapConfirmButtons),
      holdToRepeat: asBool(map['holdToRepeat'], d.holdToRepeat),
      repeatDelayMs: asInt(map['repeatDelayMs'], d.repeatDelayMs)
          .clamp(minRepeatDelayMs, maxRepeatDelayMs),
      repeatRateMs: asInt(map['repeatRateMs'], d.repeatRateMs)
          .clamp(minRepeatRateMs, maxRepeatRateMs),
    );
  }
}
