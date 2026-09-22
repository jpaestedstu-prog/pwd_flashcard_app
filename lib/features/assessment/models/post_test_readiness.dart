import '../../../l10n/app_localizations.dart';

/// Whether a learner has studied long enough for their post-test to mean
/// anything yet.
///
/// A post-test taken the same afternoon as the pre-test measures short-term
/// recall of the pre-test, not learning — and the app let exactly that happen:
/// the card unlocked the moment a pre-test was submitted. A learning gain is
/// the difference the *teaching in between* made, so the second half of the
/// instrument waits for some teaching to have happened.
///
/// Two conditions, both of which have to hold:
///
///  * **Time.** At least [requiredDays] days since the pre-test. Learning that
///    sticks needs nights in between, not minutes.
///  * **Practice.** At least [requiredSessions] separate days of study since
///    the pre-test. Time alone would let a tablet sit in a drawer for a week
///    and call the result a gain.
///
/// An educator always overrides both: if they *assign* a post-test the wait is
/// over, because they have judged the teaching done. That deliberately rides on
/// the existing assignment mechanism rather than a new synced flag — the
/// assignment already reaches the learner's device, and one source of truth
/// for "your teacher says go" is better than two.
class PostTestReadiness {
  /// Default wait. A school week: long enough for lessons to have happened,
  /// short enough to fit inside a unit of work.
  static const int requiredDays = 7;

  /// Default practice bar, in separate days the learner actually studied.
  static const int requiredSessions = 3;

  /// Why the post-test is (not) open.
  final PostTestGate gate;

  /// Days still to wait. Zero once the time condition is met.
  final int daysRemaining;

  /// Study days still needed. Zero once the practice condition is met.
  final int sessionsRemaining;

  /// When the pre-test was sat, or null when there is none.
  final DateTime? preTestAt;

  const PostTestReadiness({
    required this.gate,
    this.daysRemaining = 0,
    this.sessionsRemaining = 0,
    this.preTestAt,
  });

  bool get isReady => gate != PostTestGate.noPreTest && gate != PostTestGate.waiting;

  /// True when the learner has not even started the instrument.
  bool get needsPreTest => gate == PostTestGate.noPreTest;

  /// What to tell the learner on the locked card. Null once it is open.
  String? get lockMessage => switch (gate) {
    PostTestGate.noPreTest => 'Complete a Pre-Test first',
    PostTestGate.waiting => _waitMessage,
    _ => null,
  };

  String get _waitMessage {
    final parts = <String>[
      if (daysRemaining > 0)
        daysRemaining == 1 ? '1 more day' : '$daysRemaining more days',
      if (sessionsRemaining > 0)
        sessionsRemaining == 1
            ? '1 more study day'
            : '$sessionsRemaining more study days',
    ];
    if (parts.isEmpty) return 'Keep studying';
    return 'Keep studying — ${parts.join(' and ')}';
  }

  /// Localized [lockMessage].
  String? lockMessageOf(AppLocalizations? l10n) {
    if (l10n == null) return lockMessage;
    return switch (gate) {
      PostTestGate.noPreTest => l10n.assessNeedPreTestFirst,
      PostTestGate.waiting => _waitMessageOf(l10n),
      _ => null,
    };
  }

  String _waitMessageOf(AppLocalizations l10n) {
    final parts = <String>[
      if (daysRemaining > 0)
        daysRemaining == 1
            ? l10n.assessOneMoreDay
            : l10n.assessMoreDays(daysRemaining),
      if (sessionsRemaining > 0)
        sessionsRemaining == 1
            ? l10n.assessOneMoreStudyDay
            : l10n.assessMoreStudyDays(sessionsRemaining),
    ];
    if (parts.isEmpty) return l10n.assessKeepStudying;
    final what = parts.length == 1
        ? parts.first
        : l10n.assessAndJoin(parts[0], parts[1]);
    return l10n.assessKeepStudyingFor(what);
  }

  /// Localized [educatorSummary].
  String educatorSummaryOf(AppLocalizations? l10n) {
    if (l10n == null) return educatorSummary;
    return switch (gate) {
      PostTestGate.noPreTest => l10n.assessPreOutstanding,
      PostTestGate.waiting => l10n.assessPostIn(_educatorWait),
      PostTestGate.assigned => l10n.assessPostAssigned,
      PostTestGate.ready => l10n.assessReadyForPost,
    };
  }

  /// One line for an educator's roster row.
  String get educatorSummary => switch (gate) {
    PostTestGate.noPreTest => 'Pre-test outstanding',
    PostTestGate.waiting =>
      'Pre-test done · post-test suggested after $_educatorWait',
    PostTestGate.assigned => 'Post-test assigned',
    PostTestGate.ready => 'Ready for post-test',
  };

  String get _educatorWait {
    if (daysRemaining > 0 && sessionsRemaining > 0) {
      return '$daysRemaining d, $sessionsRemaining study days';
    }
    if (daysRemaining > 0) return '$daysRemaining d';
    return '$sessionsRemaining study days';
  }

  /// Decide readiness from data the learner's own device already holds.
  ///
  /// [studyDates] is every day the learner had a session — duplicates and
  /// times of day are ignored, because two sittings on one afternoon are one
  /// day of teaching, not two.
  static PostTestReadiness evaluate({
    required DateTime? preTestAt,
    required Iterable<DateTime> studyDates,
    required DateTime now,
    bool assignedByEducator = false,
    int days = requiredDays,
    int sessions = requiredSessions,
  }) {
    if (preTestAt == null) {
      return const PostTestReadiness(gate: PostTestGate.noPreTest);
    }
    if (assignedByEducator) {
      return PostTestReadiness(
        gate: PostTestGate.assigned,
        preTestAt: preTestAt,
      );
    }

    final elapsed = _wholeDaysBetween(preTestAt, now);
    final daysLeft = (days - elapsed).clamp(0, days);

    // Distinct calendar days with study *after* the pre-test. The pre-test's
    // own day does not count: sitting a test is not practising.
    final preDay = _dayKey(preTestAt);
    final studied = <String>{};
    for (final date in studyDates) {
      if (date.isBefore(preTestAt)) continue;
      final key = _dayKey(date);
      if (key == preDay) continue;
      studied.add(key);
    }
    final sessionsLeft = (sessions - studied.length).clamp(0, sessions);

    if (daysLeft == 0 && sessionsLeft == 0) {
      return PostTestReadiness(gate: PostTestGate.ready, preTestAt: preTestAt);
    }
    return PostTestReadiness(
      gate: PostTestGate.waiting,
      daysRemaining: daysLeft,
      sessionsRemaining: sessionsLeft,
      preTestAt: preTestAt,
    );
  }

  /// Whole days from [from] to [to], counted on the calendar rather than in
  /// 24-hour blocks: a pre-test at 4pm Monday is one day old on Tuesday
  /// morning, which is how a teacher counts it.
  static int _wholeDaysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    final diff = b.difference(a).inDays;
    return diff < 0 ? 0 : diff;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// The state a learner's post-test is in.
enum PostTestGate {
  /// No pre-test yet — there is nothing to compare against.
  noPreTest,

  /// Pre-test done, but not enough time or practice has passed.
  waiting,

  /// An educator has set a post-test, which overrides the wait.
  assigned,

  /// The wait is over and the learner may start it themselves.
  ready,
}
