import 'leaderboard.dart';

/// Per-class / per-home-group leaderboard settings, controlled by the
/// owning teacher / parent.
///
/// One doc per scope, stored in Firestore at
/// `leaderboard_config_classroom/{classroomId}` or
/// `leaderboard_config_homegroup/{homeGroupId}` (doc id == [scopeId]) and
/// mirrored into Hive for offline reads. See [firestore.rules] — reads are
/// open to any signed-in member (so a learner can honor the config on
/// their own device), writes are gated on the scope owner.
class LeaderboardConfig {
  /// Whether members can see the leaderboard. Defaults to OFF so the
  /// educator explicitly opts in before any rankings appear.
  final bool visible;

  /// Which metric the board ranks by.
  final LeaderboardSort metric;

  /// Profile ids the educator excluded from the rankings.
  final List<String> hiddenMemberIds;

  /// Active time window.
  final LeaderboardPeriod period;

  /// When set, only members active after this instant appear — a
  /// pragmatic "new season" reset (lifetime stars can't be zeroed on the
  /// free tier without per-period accounting).
  final DateTime? seasonStartAt;

  /// Auth uid of the writer (matches the Firestore rule's `owner_uid`).
  final String ownerUid;

  /// classroomId or homeGroupId — also the Firestore doc id.
  final String scopeId;

  const LeaderboardConfig({
    this.visible = false,
    this.metric = LeaderboardSort.byOverall,
    this.hiddenMemberIds = const [],
    this.period = LeaderboardPeriod.allTime,
    this.seasonStartAt,
    required this.ownerUid,
    required this.scopeId,
  });

  /// A safe default for a scope that has no config doc yet.
  factory LeaderboardConfig.defaults(String scopeId, {String ownerUid = ''}) =>
      LeaderboardConfig(scopeId: scopeId, ownerUid: ownerUid);

  LeaderboardConfig copyWith({
    bool? visible,
    LeaderboardSort? metric,
    List<String>? hiddenMemberIds,
    LeaderboardPeriod? period,
    DateTime? seasonStartAt,
    bool clearSeason = false,
    String? ownerUid,
    String? scopeId,
  }) {
    return LeaderboardConfig(
      visible: visible ?? this.visible,
      metric: metric ?? this.metric,
      hiddenMemberIds: hiddenMemberIds ?? this.hiddenMemberIds,
      period: period ?? this.period,
      seasonStartAt:
          clearSeason ? null : (seasonStartAt ?? this.seasonStartAt),
      ownerUid: ownerUid ?? this.ownerUid,
      scopeId: scopeId ?? this.scopeId,
    );
  }

  /// Snake_case keys to match the Firestore collections.
  Map<String, dynamic> toJson() => {
        'visible': visible,
        'metric': metric.name,
        'hidden_member_ids': hiddenMemberIds,
        'period': period.name,
        'season_start_at': seasonStartAt?.toIso8601String(),
        'owner_uid': ownerUid,
        'scope_id': scopeId,
      };

  factory LeaderboardConfig.fromJson(Map<String, dynamic> json) {
    return LeaderboardConfig(
      visible: json['visible'] as bool? ?? false,
      metric: _sortByName(json['metric'] as String?),
      hiddenMemberIds:
          (json['hidden_member_ids'] as List?)?.cast<String>() ?? const [],
      period: _periodByName(json['period'] as String?),
      seasonStartAt: (json['season_start_at'] as String?) == null
          ? null
          : DateTime.tryParse(json['season_start_at'] as String),
      ownerUid: json['owner_uid'] as String? ?? '',
      scopeId: json['scope_id'] as String? ?? '',
    );
  }

  static LeaderboardSort _sortByName(String? name) =>
      LeaderboardSort.values.firstWhere(
        (s) => s.name == name,
        orElse: () => LeaderboardSort.byOverall,
      );

  static LeaderboardPeriod _periodByName(String? name) =>
      LeaderboardPeriod.values.firstWhere(
        (p) => p.name == name,
        orElse: () => LeaderboardPeriod.allTime,
      );
}
