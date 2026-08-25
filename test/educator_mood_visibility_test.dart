import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_summary.dart';
import 'package:pwdpwdpwd/features/parent/screens/educator_dashboard_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/parent_provider.dart';

/// The educator-facing half of mood: what a teacher or parent sees on their
/// roster, and — just as importantly — what they do not.
///
/// Driven through the real dashboard widget rather than the model alone,
/// because the privacy claim ("no note text reaches a caregiver screen") is
/// only worth anything if it holds of what is actually rendered.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.role);
  final UserRole role;

  @override
  UserProfile? build() => UserProfile(
        id: 'educator-1',
        name: 'Sir Kevin',
        role: role,
        createdAt: DateTime(2026),
      );
}

class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._settings);
  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

ChildSummary _child({
  required String name,
  required MoodSummary mood,
}) {
  return ChildSummary(
    profileId: 'child-$name',
    name: name,
    avatarEmoji: '🐼',
    avatarIndex: 0,
    disabilityType: DisabilityType.hearing,
    wordsLearned: 20,
    totalStars: 30,
    streakDays: 2,
    gamesPlayed: 5,
    averageAccuracy: 0.6,
    studyMinutesThisWeek: 40,
    studyMinutesLastWeek: 30,
    totalSessions: 6,
    dailyStudyMinutes: const {},
    categoryProgress: const {},
    categoryCoverage: const {},
    wordHuntFinds: 0,
    signsWatched: 3,
    wordHuntStreak: 0,
    moodSummary: mood,
    recentScores: const [],
    lastActivityDate: DateTime(2026, 8, 25),
  );
}

MoodEntry _entry(MoodType mood, {required int daysAgo, String? note}) =>
    MoodEntry(
      id: 'e-${mood.name}-$daysAgo',
      profileId: 'child-1',
      mood: mood,
      note: note,
      timestamp: DateTime(2026, 8, 25, 12).subtract(Duration(days: daysAgo)),
    );

Widget _dashboard(List<ChildSummary> children) {
  return ProviderScope(
    overrides: [
      profileProvider.overrideWith(() => _StubProfileNotifier(UserRole.teacher)),
      settingsProvider.overrideWith(
        () => _FixedSettings(const AppSettings(reducedMotion: true)),
      ),
      parentDashboardProvider.overrideWithValue(
        ParentDashboardSnapshot(
          timestamp: DateTime(2026, 8, 25),
          children: children,
        ),
      ),
    ],
    child: const MaterialApp(
      home: EducatorDashboardScreen(audience: EducatorAudience.teacher),
    ),
  );
}

/// Every rendered string in the tree, so a privacy claim can be checked
/// against what is on screen rather than against intentions.
List<String> _visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .toList();

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/educator_mood');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'sessions',
      'mood_entries',
      'alerts',
      'active_time_logs',
      'child_time_limits',
      'child_alarms',
      'custom_cards',
      'notebook',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
    Animate.defaultDuration = Duration.zero;
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  testWidgets('a learner with check-ins shows a wellbeing line',
      (tester) async {
    final mood = MoodSummary.fromEntries(
      [
        _entry(MoodType.happy, daysAgo: 3),
        _entry(MoodType.happy, daysAgo: 2),
        _entry(MoodType.tired, daysAgo: 1),
      ],
      now: DateTime(2026, 8, 25, 12),
    );

    await tester.pumpWidget(_dashboard([_child(name: 'Ana', mood: mood)]));
    await tester.pump(const Duration(milliseconds: 100));

    final text = _visibleText(tester).join(' | ');
    expect(text, contains('Mostly Happy'));
    expect(text, contains('3 check-ins'));
  });

  testWidgets('a learner with no check-ins shows no wellbeing line',
      (tester) async {
    await tester.pumpWidget(
      _dashboard([_child(name: 'Ben', mood: MoodSummary.empty)]),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final text = _visibleText(tester).join(' | ');
    // Silence is not the same as "no feelings" — the row is absent rather
    // than rendering an empty or neutral state.
    expect(text, isNot(contains('Mostly')));
    expect(text, isNot(contains('check-in')));
  });

  testWidgets('a run of hard days is flagged for a conversation',
      (tester) async {
    final mood = MoodSummary.fromEntries(
      [
        _entry(MoodType.sad, daysAgo: 3),
        _entry(MoodType.frustrated, daysAgo: 2),
        _entry(MoodType.sad, daysAgo: 1),
      ],
      now: DateTime(2026, 8, 25, 12),
    );
    expect(mood.needsAttention, isTrue);

    await tester.pumpWidget(_dashboard([_child(name: 'Cara', mood: mood)]));
    await tester.pump(const Duration(milliseconds: 100));

    final text = _visibleText(tester).join(' | ');
    expect(text, contains('Check in'));
    expect(text, contains('Mostly Sad'));
  });

  testWidgets('a learner note never reaches the educator screen',
      (tester) async {
    // The whole privacy line for this feature: an educator sees the pattern,
    // not the learner writing to themselves.
    const secret = 'nobody sat with me at lunch';
    final mood = MoodSummary.fromEntries(
      [
        _entry(MoodType.sad, daysAgo: 3, note: secret),
        _entry(MoodType.sad, daysAgo: 2, note: secret),
        _entry(MoodType.frustrated, daysAgo: 1, note: secret),
      ],
      now: DateTime(2026, 8, 25, 12),
    );

    await tester.pumpWidget(_dashboard([_child(name: 'Dee', mood: mood)]));
    await tester.pump(const Duration(milliseconds: 100));

    for (final line in _visibleText(tester)) {
      expect(line, isNot(contains('lunch')), reason: 'leaked note: "$line"');
    }
  });
}
