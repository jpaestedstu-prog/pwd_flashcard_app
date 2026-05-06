/// Experiment mode configuration for thesis research.
///
/// Allows educators to toggle gamification elements on/off for
/// individual students, enabling controlled experiments comparing
/// gamified vs. non-gamified learning experiences.
library;

/// Which gamification features can be toggled.
enum GamificationFeature {
  stars,
  achievements,
  leaderboard,
  streaks,
  shop,
  levelUp,
  celebrations,
  stickers,
  dailyChallenge,
}

extension GamificationFeatureX on GamificationFeature {
  String get label => switch (this) {
        GamificationFeature.stars => 'Stars & Rewards',
        GamificationFeature.achievements => 'Achievements & Badges',
        GamificationFeature.leaderboard => 'Leaderboard',
        GamificationFeature.streaks => 'Streaks',
        GamificationFeature.shop => 'Star Shop',
        GamificationFeature.levelUp => 'Level-Up System',
        GamificationFeature.celebrations => 'Celebrations & Animations',
        GamificationFeature.stickers => 'Sticker Album',
        GamificationFeature.dailyChallenge => 'Daily Challenge',
      };

  String get labelFilipino => switch (this) {
        GamificationFeature.stars => 'Mga Bituin at Gantimpala',
        GamificationFeature.achievements => 'Mga Tagumpay at Badge',
        GamificationFeature.leaderboard => 'Leaderboard',
        GamificationFeature.streaks => 'Mga Streak',
        GamificationFeature.shop => 'Tindahan ng Bituin',
        GamificationFeature.levelUp => 'Level-Up System',
        GamificationFeature.celebrations => 'Mga Selebrasyon at Animasyon',
        GamificationFeature.stickers => 'Sticker Album',
        GamificationFeature.dailyChallenge => 'Daily Challenge',
      };

  String get description => switch (this) {
        GamificationFeature.stars =>
          'Stars earned from games and activities',
        GamificationFeature.achievements =>
          'Achievement badges and unlock notifications',
        GamificationFeature.leaderboard =>
          'Student ranking and comparison',
        GamificationFeature.streaks =>
          'Consecutive day streak counter',
        GamificationFeature.shop =>
          'Shop for avatars, themes, and customizations',
        GamificationFeature.levelUp =>
          'XP-based level progression system',
        GamificationFeature.celebrations =>
          'Victory animations and confetti effects',
        GamificationFeature.stickers =>
          'Collectible sticker album rewards',
        GamificationFeature.dailyChallenge =>
          'Daily randomized challenge tasks',
      };

  IconDataEquivalent get iconName => switch (this) {
        GamificationFeature.stars => IconDataEquivalent.star,
        GamificationFeature.achievements => IconDataEquivalent.trophy,
        GamificationFeature.leaderboard => IconDataEquivalent.leaderboard,
        GamificationFeature.streaks => IconDataEquivalent.fire,
        GamificationFeature.shop => IconDataEquivalent.shop,
        GamificationFeature.levelUp => IconDataEquivalent.levelUp,
        GamificationFeature.celebrations => IconDataEquivalent.celebration,
        GamificationFeature.stickers => IconDataEquivalent.sticker,
        GamificationFeature.dailyChallenge => IconDataEquivalent.challenge,
      };
}

/// Simple icon mapping to avoid importing flutter material in models.
enum IconDataEquivalent {
  star,
  trophy,
  leaderboard,
  fire,
  shop,
  levelUp,
  celebration,
  sticker,
  challenge,
}

/// Experiment configuration for a student profile.
class ExperimentConfig {
  /// Whether experiment mode is active for this student.
  final bool enabled;

  /// The experiment group label (e.g., 'treatment', 'control').
  final String groupLabel;

  /// Which gamification features are disabled.
  /// When experiment mode is enabled and a feature is in this set,
  /// it should be hidden from the student's UI.
  final Set<GamificationFeature> disabledFeatures;

  const ExperimentConfig({
    this.enabled = false,
    this.groupLabel = 'treatment',
    this.disabledFeatures = const {},
  });

  /// Quick preset: full gamification (treatment group).
  factory ExperimentConfig.treatment() => const ExperimentConfig(
        enabled: true,
      );

  /// Quick preset: no gamification (control group).
  factory ExperimentConfig.control() => ExperimentConfig(
        enabled: true,
        groupLabel: 'control',
        disabledFeatures: GamificationFeature.values.toSet(),
      );

  /// Check if a specific gamification feature is active.
  bool isFeatureEnabled(GamificationFeature feature) {
    if (!enabled) return true; // Experiment mode off = all features on
    return !disabledFeatures.contains(feature);
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'groupLabel': groupLabel,
        'disabledFeatures':
            disabledFeatures.map((f) => f.index).toList(),
      };

  factory ExperimentConfig.fromJson(Map<String, dynamic> json) {
    final rawDisabled = json['disabledFeatures'] as List? ?? [];
    return ExperimentConfig(
      enabled: json['enabled'] as bool? ?? false,
      groupLabel: json['groupLabel'] as String? ?? 'treatment',
      disabledFeatures: rawDisabled
          .map((e) => e as int)
          .where((i) => i >= 0 && i < GamificationFeature.values.length)
          .map((i) => GamificationFeature.values[i])
          .toSet(),
    );
  }

  ExperimentConfig copyWith({
    bool? enabled,
    String? groupLabel,
    Set<GamificationFeature>? disabledFeatures,
  }) {
    return ExperimentConfig(
      enabled: enabled ?? this.enabled,
      groupLabel: groupLabel ?? this.groupLabel,
      disabledFeatures: disabledFeatures ?? this.disabledFeatures,
    );
  }
}
