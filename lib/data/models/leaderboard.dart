/// A single entry on the leaderboard
class LeaderboardEntry {
  final String profileId;
  final String profileName;
  final int avatarIndex;
  final int totalStars;
  final int wordsLearned;
  final int streakDays;
  final int gamesPlayed;
  final DateTime lastActivity;

  /// Equipped Star Shop cosmetics, so a learner's purchases are visible in the
  /// one place they are meant to be seen by other people.
  ///
  /// Null when nothing is equipped, or when the row came from a member whose
  /// equipped state has not reached this device — the UI then falls back to
  /// the profile's starting avatar, which is exactly what it always showed.
  final String? equippedAvatarId;
  final String? equippedBorderId;
  final String? equippedTitleId;

  const LeaderboardEntry({
    required this.profileId,
    required this.profileName,
    this.avatarIndex = 0,
    this.totalStars = 0,
    this.wordsLearned = 0,
    this.streakDays = 0,
    this.gamesPlayed = 0,
    required this.lastActivity,
    this.equippedAvatarId,
    this.equippedBorderId,
    this.equippedTitleId,
  });

  /// A combined score for ranking: stars + words × 2 + streak × 3
  int get rankScore => totalStars + wordsLearned * 2 + streakDays * 3;

  Map<String, dynamic> toJson() => {
    'profileId': profileId,
    'profileName': profileName,
    'avatarIndex': avatarIndex,
    'totalStars': totalStars,
    'wordsLearned': wordsLearned,
    'streakDays': streakDays,
    'gamesPlayed': gamesPlayed,
    'lastActivity': lastActivity.toIso8601String(),
    'equippedAvatarId': equippedAvatarId,
    'equippedBorderId': equippedBorderId,
    'equippedTitleId': equippedTitleId,
  };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        profileId: json['profileId'] as String,
        profileName: json['profileName'] as String,
        avatarIndex: json['avatarIndex'] as int? ?? 0,
        totalStars: json['totalStars'] as int? ?? 0,
        wordsLearned: json['wordsLearned'] as int? ?? 0,
        streakDays: json['streakDays'] as int? ?? 0,
        gamesPlayed: json['gamesPlayed'] as int? ?? 0,
        lastActivity: DateTime.parse(json['lastActivity'] as String),
        equippedAvatarId: json['equippedAvatarId'] as String?,
        equippedBorderId: json['equippedBorderId'] as String?,
        equippedTitleId: json['equippedTitleId'] as String?,
      );
}

/// Sort options for the leaderboard
enum LeaderboardSort {
  byStars,
  byWords,
  byStreak,
  byOverall;

  String get label => switch (this) {
    LeaderboardSort.byStars => 'Stars',
    LeaderboardSort.byWords => 'Words Learned',
    LeaderboardSort.byStreak => 'Streak',
    LeaderboardSort.byOverall => 'Overall',
  };
}

/// Time-period filter
enum LeaderboardPeriod {
  allTime,
  thisWeek,
  thisMonth;

  String get label => switch (this) {
    LeaderboardPeriod.allTime => 'All Time',
    LeaderboardPeriod.thisWeek => 'This Week',
    LeaderboardPeriod.thisMonth => 'This Month',
  };
}

/// Which roster a leaderboard is scoped to.
enum LeaderboardScopeKind { classroom, homeGroup, none }

/// Identifies the membership boundary a leaderboard is drawn from — the
/// classroom a student joined, the home group a child joined, or `none`
/// (the learner hasn't joined anything yet, so the screen shows a
/// "join" prompt instead of a board).
class LeaderboardScope {
  final LeaderboardScopeKind kind;
  final String? id; // classroomId or homeGroupId
  final String? displayName; // class / group name for the header

  const LeaderboardScope.classroom(this.id, {this.displayName})
      : kind = LeaderboardScopeKind.classroom;
  const LeaderboardScope.homeGroup(this.id, {this.displayName})
      : kind = LeaderboardScopeKind.homeGroup;
  const LeaderboardScope.none()
      : kind = LeaderboardScopeKind.none,
        id = null,
        displayName = null;

  bool get isReal => kind != LeaderboardScopeKind.none && id != null;

  // Value equality so `FutureProvider.family` / `StreamProvider.family`
  // memoise correctly (two scopes for the same class share one listener).
  @override
  bool operator ==(Object other) =>
      other is LeaderboardScope && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Pure ranking/filter pipeline shared by the online leaderboard.
///
/// Lifted out of the old `LeaderboardNotifier.filtered()` so both the
/// screen and any preview can rank a list the same way.
///
/// Order of operations:
///   1. drop entries whose profileId is in [hiddenIds] (educator hid them),
///   2. drop entries inactive since [seasonStartAt] (a "new season" reset)
///      or outside the [period] window — both compare `lastActivity`,
///   3. sort by [sort].
///
/// Note: `totalStars` / `wordsLearned` are lifetime cumulative, so the
/// period / season filters act on *activity recency*, not on a per-period
/// score reset. See the caveat surfaced in the educator config UI.
List<LeaderboardEntry> applyLeaderboardFilters(
  List<LeaderboardEntry> entries, {
  LeaderboardSort sort = LeaderboardSort.byOverall,
  LeaderboardPeriod period = LeaderboardPeriod.allTime,
  Set<String> hiddenIds = const {},
  DateTime? seasonStartAt,
}) {
  var list = entries.where((e) => !hiddenIds.contains(e.profileId)).toList();

  // Period activity window.
  DateTime? cutoff;
  if (period != LeaderboardPeriod.allTime) {
    final now = DateTime.now();
    cutoff = switch (period) {
      LeaderboardPeriod.thisWeek => now.subtract(const Duration(days: 7)),
      LeaderboardPeriod.thisMonth => DateTime(now.year, now.month),
      _ => null,
    };
  }
  // Season reset: take the later of the two cutoffs so both constraints hold.
  if (seasonStartAt != null) {
    cutoff = (cutoff == null || seasonStartAt.isAfter(cutoff))
        ? seasonStartAt
        : cutoff;
  }
  if (cutoff != null) {
    final c = cutoff;
    list = list.where((e) => e.lastActivity.isAfter(c)).toList();
  }

  list.sort((a, b) => switch (sort) {
        LeaderboardSort.byStars => b.totalStars.compareTo(a.totalStars),
        LeaderboardSort.byWords => b.wordsLearned.compareTo(a.wordsLearned),
        LeaderboardSort.byStreak => b.streakDays.compareTo(a.streakDays),
        LeaderboardSort.byOverall => b.rankScore.compareTo(a.rankScore),
      });
  return list;
}
