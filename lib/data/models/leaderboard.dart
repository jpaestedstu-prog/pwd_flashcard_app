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

  const LeaderboardEntry({
    required this.profileId,
    required this.profileName,
    this.avatarIndex = 0,
    this.totalStars = 0,
    this.wordsLearned = 0,
    this.streakDays = 0,
    this.gamesPlayed = 0,
    required this.lastActivity,
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
