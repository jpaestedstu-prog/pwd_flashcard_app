import '../../../data/local/seed_stories.dart';
import '../../../l10n/app_localizations.dart';

/// Difficulty level shown on story cover cards. Derived, not stored — so the
/// 24 seed stories don't need editing.
enum StoryDifficulty { easy, medium, hard }

extension StoryDifficultyLabel on StoryDifficulty {
  String get label => switch (this) {
        StoryDifficulty.easy => 'Easy',
        StoryDifficulty.medium => 'Medium',
        StoryDifficulty.hard => 'Hard',
      };

  /// [label] in the learner's language.
  String labelOf(AppLocalizations l10n) => switch (this) {
        StoryDifficulty.easy => l10n.easy,
        StoryDifficulty.medium => l10n.medium,
        StoryDifficulty.hard => l10n.hard,
      };
}

/// Presentation helpers derived from a [Story]'s existing data so the themed
/// cover cards can show difficulty + read-time without new model fields.
extension StoryPresentation on Story {
  /// Difficulty derived from the story's unlock position within its category
  /// (0 = always unlocked → Easy, 1 → Medium, 2+ → Hard). Mirrors the unlock
  /// thresholds in `StoryListScreen._isUnlocked`.
  StoryDifficulty get difficulty {
    final index = SeedStories.getByCategory(category).indexOf(this);
    return switch (index) {
      0 => StoryDifficulty.easy,
      1 => StoryDifficulty.medium,
      _ => StoryDifficulty.hard,
    };
  }

  /// Rough read-time estimate at ~6 seconds per sentence, floored at 1 minute.
  int get estimatedMinutes =>
      ((sentencesEn.length * 6) / 60).ceil().clamp(1, 99);
}
