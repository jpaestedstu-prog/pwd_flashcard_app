import '../../../data/models/enums.dart';

/// Parental control settings for restricting student usage.
///
/// Stored per-educator in Hive. Controls are enforced on students
/// linked to the educator's device.
class ParentalControls {
  /// Maximum daily screen time in minutes (0 = unlimited).
  final int dailyTimeLimitMinutes;

  /// Whether to enforce the time limit.
  final bool timeLimitEnabled;

  /// Game types that are blocked for students.
  final Set<GameType> blockedGames;

  /// Flashcard categories that are hidden from students.
  final Set<FlashcardCategory> blockedCategories;

  /// Whether to block access to the Star Shop.
  final bool shopBlocked;

  /// Whether to block multiplayer features.
  final bool multiplayerBlocked;

  /// Whether to block messaging.
  final bool messagingBlocked;

  /// Allowed start hour (0-23) for app usage.
  final int allowedStartHour;

  /// Allowed end hour (0-23) for app usage.
  final int allowedEndHour;

  /// Whether time-of-day restriction is enabled.
  final bool scheduleEnabled;

  const ParentalControls({
    this.dailyTimeLimitMinutes = 0,
    this.timeLimitEnabled = false,
    this.blockedGames = const {},
    this.blockedCategories = const {},
    this.shopBlocked = false,
    this.multiplayerBlocked = false,
    this.messagingBlocked = false,
    this.allowedStartHour = 8,
    this.allowedEndHour = 20,
    this.scheduleEnabled = false,
  });

  bool get hasAnyRestriction =>
      timeLimitEnabled ||
      blockedGames.isNotEmpty ||
      blockedCategories.isNotEmpty ||
      shopBlocked ||
      multiplayerBlocked ||
      messagingBlocked ||
      scheduleEnabled;

  /// Whether the current time is within the allowed schedule.
  bool get isWithinSchedule {
    if (!scheduleEnabled) return true;
    final now = DateTime.now().hour;
    if (allowedStartHour <= allowedEndHour) {
      return now >= allowedStartHour && now < allowedEndHour;
    }
    // Wraps around midnight (e.g., 22:00 – 06:00)
    return now >= allowedStartHour || now < allowedEndHour;
  }

  Map<String, dynamic> toJson() => {
        'dailyTimeLimitMinutes': dailyTimeLimitMinutes,
        'timeLimitEnabled': timeLimitEnabled,
        'blockedGames': blockedGames.map((g) => g.index).toList(),
        'blockedCategories': blockedCategories.map((c) => c.index).toList(),
        'shopBlocked': shopBlocked,
        'multiplayerBlocked': multiplayerBlocked,
        'messagingBlocked': messagingBlocked,
        'allowedStartHour': allowedStartHour,
        'allowedEndHour': allowedEndHour,
        'scheduleEnabled': scheduleEnabled,
      };

  factory ParentalControls.fromJson(Map<String, dynamic> json) {
    return ParentalControls(
      dailyTimeLimitMinutes: json['dailyTimeLimitMinutes'] as int? ?? 0,
      timeLimitEnabled: json['timeLimitEnabled'] as bool? ?? false,
      blockedGames: _parseGameTypes(json['blockedGames']),
      blockedCategories: _parseCategories(json['blockedCategories']),
      shopBlocked: json['shopBlocked'] as bool? ?? false,
      multiplayerBlocked: json['multiplayerBlocked'] as bool? ?? false,
      messagingBlocked: json['messagingBlocked'] as bool? ?? false,
      allowedStartHour: json['allowedStartHour'] as int? ?? 8,
      allowedEndHour: json['allowedEndHour'] as int? ?? 20,
      scheduleEnabled: json['scheduleEnabled'] as bool? ?? false,
    );
  }

  ParentalControls copyWith({
    int? dailyTimeLimitMinutes,
    bool? timeLimitEnabled,
    Set<GameType>? blockedGames,
    Set<FlashcardCategory>? blockedCategories,
    bool? shopBlocked,
    bool? multiplayerBlocked,
    bool? messagingBlocked,
    int? allowedStartHour,
    int? allowedEndHour,
    bool? scheduleEnabled,
  }) {
    return ParentalControls(
      dailyTimeLimitMinutes:
          dailyTimeLimitMinutes ?? this.dailyTimeLimitMinutes,
      timeLimitEnabled: timeLimitEnabled ?? this.timeLimitEnabled,
      blockedGames: blockedGames ?? this.blockedGames,
      blockedCategories: blockedCategories ?? this.blockedCategories,
      shopBlocked: shopBlocked ?? this.shopBlocked,
      multiplayerBlocked: multiplayerBlocked ?? this.multiplayerBlocked,
      messagingBlocked: messagingBlocked ?? this.messagingBlocked,
      allowedStartHour: allowedStartHour ?? this.allowedStartHour,
      allowedEndHour: allowedEndHour ?? this.allowedEndHour,
      scheduleEnabled: scheduleEnabled ?? this.scheduleEnabled,
    );
  }

  static Set<GameType> _parseGameTypes(dynamic list) {
    if (list == null) return {};
    return (list as List)
        .map((e) => e as int)
        .where((i) => i >= 0 && i < GameType.values.length)
        .map((i) => GameType.values[i])
        .toSet();
  }

  static Set<FlashcardCategory> _parseCategories(dynamic list) {
    if (list == null) return {};
    return (list as List)
        .map((e) => e as int)
        .where((i) => i >= 0 && i < FlashcardCategory.values.length)
        .map((i) => FlashcardCategory.values[i])
        .toSet();
  }
}
