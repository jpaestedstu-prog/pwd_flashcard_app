import 'package:flutter/material.dart';

/// *When* a mood was recorded.
///
/// [MoodEntry.activityContext] has always been a free-form `String?` on the
/// model, and the Mood Insights dashboard has always drawn a "Mood by
/// Activity" chart from it — but nothing in the app ever wrote a value, so
/// every entry fell into the `'general'` bucket and the chart was a single
/// meaningless bar. This enum is the writeable half of that instrument: the
/// small, closed set of moments the app can actually recognise.
///
/// Stored by [storageKey], never by index, so re-ordering the enum can never
/// silently re-label a learner's history.
enum MoodContext {
  /// Opened from a home tile or the mood screen itself — no activity attached.
  general,

  /// Straight after a game's result screen.
  afterGame,

  /// During a Break Time pause.
  breakTime,

  /// After finishing a story.
  afterStory,

  /// At the end of a study session.
  endSession,
}

extension MoodContextX on MoodContext {
  /// The value persisted in [MoodEntry.activityContext]. `after_game` is kept
  /// verbatim from the doc comment the model shipped with, so any hand-seeded
  /// research data still lands in the right bucket.
  String get storageKey => switch (this) {
        MoodContext.general => 'general',
        MoodContext.afterGame => 'after_game',
        MoodContext.breakTime => 'break_time',
        MoodContext.afterStory => 'after_story',
        MoodContext.endSession => 'end_session',
      };

  String get label => switch (this) {
        MoodContext.general => 'Anytime',
        MoodContext.afterGame => 'After a game',
        MoodContext.breakTime => 'Break time',
        MoodContext.afterStory => 'After a story',
        MoodContext.endSession => 'End of session',
      };

  String get labelFilipino => switch (this) {
        MoodContext.general => 'Kahit kailan',
        MoodContext.afterGame => 'Pagkatapos maglaro',
        MoodContext.breakTime => 'Oras ng pahinga',
        MoodContext.afterStory => 'Pagkatapos ng kwento',
        MoodContext.endSession => 'Katapusan ng session',
      };

  String labelOf({required bool isFilipino}) =>
      isFilipino ? labelFilipino : label;

  /// The question the learner is actually answering in this moment. A generic
  /// "how do you feel?" after a game reads as a survey; naming the moment is
  /// what makes the answer worth charting.
  String get prompt => switch (this) {
        MoodContext.general => 'How are you feeling right now?',
        MoodContext.afterGame => 'How did that game feel?',
        MoodContext.breakTime => 'How are you feeling on your break?',
        MoodContext.afterStory => 'How did that story feel?',
        MoodContext.endSession => 'How do you feel after today?',
      };

  String get promptFilipino => switch (this) {
        MoodContext.general => 'Kumusta ang pakiramdam mo ngayon?',
        MoodContext.afterGame => 'Kumusta ang laro na iyon?',
        MoodContext.breakTime => 'Kumusta ka sa iyong pahinga?',
        MoodContext.afterStory => 'Kumusta ang kwentong iyon?',
        MoodContext.endSession => 'Kumusta ang pakiramdam mo pagkatapos ngayon?',
      };

  String promptOf({required bool isFilipino}) =>
      isFilipino ? promptFilipino : prompt;

  IconData get icon => switch (this) {
        MoodContext.general => Icons.wb_sunny_rounded,
        MoodContext.afterGame => Icons.sports_esports_rounded,
        MoodContext.breakTime => Icons.self_improvement_rounded,
        MoodContext.afterStory => Icons.menu_book_rounded,
        MoodContext.endSession => Icons.nights_stay_rounded,
      };

  /// Resolve a stored value back to a context. Unknown / null values (older
  /// entries written before contexts existed) read as [MoodContext.general]
  /// rather than being dropped — a learner's history is never discarded for
  /// being old.
  static MoodContext fromKey(String? key) {
    if (key == null) return MoodContext.general;
    for (final c in MoodContext.values) {
      if (c.storageKey == key) return c;
    }
    return MoodContext.general;
  }
}
