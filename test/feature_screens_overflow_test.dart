import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/goals/screens/goals_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/child_home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/educator_home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/player_home_screen.dart';
import 'package:pwdpwdpwd/features/mood_tracker/screens/mood_check_in_screen.dart';
import 'package:pwdpwdpwd/features/mood_tracker/screens/mood_history_screen.dart';
import 'package:pwdpwdpwd/features/mood_tracker/screens/mood_insights_screen.dart';
import 'package:pwdpwdpwd/features/notebook/screens/note_editor_screen.dart';
import 'package:pwdpwdpwd/features/notebook/screens/notebook_screen.dart';
import 'package:pwdpwdpwd/features/stickers/screens/sticker_album_screen.dart';
import 'package:pwdpwdpwd/features/object_scan/screens/word_hunt_collection_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/parent_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/parental_controls_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/adaptive_analytics_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/certificate_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/detailed_analytics_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/progress_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/streak_calendar_screen.dart';
import 'package:pwdpwdpwd/features/reports/screens/weekly_report_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';
import 'package:pwdpwdpwd/features/teacher_analytics/screens/teacher_dashboard_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/parent_provider.dart';

import 'support/screen_matrix.dart';
import 'support/device_matrix.dart';

/// Overflow matrix for the high-traffic non-game feature screens (progress &
/// analytics, settings, goals, notebook, mood, weekly report, parent surfaces).
/// Each is rendered at its first frame across every tablet size × orientation ×
/// font scale and asserted to lay out without an overflow.

/// Stubs [profileProvider] with a fixed profile of [role] so screens that read
/// `profile.id` / branch on role build — without dragging in
/// `ProfileNotifier.build`'s Firebase remote-changes stream.
class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role, {this.guest = false});
  final UserRole _role;
  final bool guest;

  @override
  UserProfile? build() => UserProfile(
        id: 'test-profile',
        name: 'Test User',
        role: _role,
        isGuestPlayer: guest,
        createdAt: DateTime(2026),
      );
}

List<Override> _asRole(UserRole role, {bool guest = false}) => [
      profileProvider.overrideWith(() => _StubProfileNotifier(role, guest: guest))
    ];

/// One roster learner, with a full week of study minutes.
///
/// The minutes matter: the "This Week" bar chart only draws its per-day value
/// labels for days with minutes, and it was exactly those labels that used to
/// burst the chart's box.
ChildSummary _rosterChild(String name, List<int> minutes) {
  final now = DateTime.now();
  final daily = <String, int>{};
  for (int i = 0; i < 7; i++) {
    final date = now.subtract(Duration(days: 6 - i));
    daily['${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}'] = minutes[i];
  }
  return ChildSummary(
    profileId: 'child-$name',
    name: name,
    avatarEmoji: '🐼',
    avatarIndex: 0,
    disabilityType: DisabilityType.hearing,
    wordsLearned: 128,
    totalStars: 340,
    streakDays: 12,
    gamesPlayed: 46,
    averageAccuracy: 0.72,
    studyMinutesThisWeek: minutes.fold(0, (a, b) => a + b),
    studyMinutesLastWeek: 95,
    totalSessions: 31,
    dailyStudyMinutes: daily,
    categoryProgress: const {'Animals': 0.8, 'Food': 0.45},
    categoryCoverage: const {'Animals': 0.6, 'Food': 0.3},
    wordHuntFinds: 7,
    signsWatched: 22,
    wordHuntStreak: 3,
    recentScores: const [],
    lastActivityDate: now,
  );
}

/// A role stub plus a **populated** dashboard snapshot.
///
/// Without this the educator dashboards resolve to an empty roster and render
/// only their empty state, so the whole body — roster stats, recommendations,
/// learner cards and the "This Week" chart — never reached the matrix at all.
/// That is how a bar chart that overflowed its box by 7 px at the *default*
/// font scale shipped past a green suite. Names are the long end of the real
/// roster, because a starved name column is the other way this body breaks.
List<Override> _asEducatorWithRoster(UserRole role) => [
      ..._asRole(role),
      parentDashboardProvider.overrideWithValue(
        ParentDashboardSnapshot(
          timestamp: DateTime.now(),
          children: [
            _rosterChild('Ana', const [12, 45, 0, 8, 30, 5, 22]),
            _rosterChild(
                'Cognitive/Learning Student', const [3, 0, 60, 15, 0, 9, 40]),
            _rosterChild('Bien', const [0, 0, 0, 0, 0, 0, 7]),
          ],
        ),
      ),
    ];

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/feature_screens');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
      'goals',
      'notebook',
      'mood_entries',
      // A populated educator dashboard reads the alert bell, the per-learner
      // time limits and the active-time log; without these boxes the roster
      // pass fails on "Box not found" rather than on a layout.
      'alerts',
      'active_time_logs',
      'child_time_limits',
      'child_alarms',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name, compactionStrategy: (_, _) => false);
    }
    // SettingsScreen renders the Cloud Sync tile (SyncStatusWidget), which reads
    // the sync-queue box. The real app opens it in HiveService.init(); mirror
    // that here so the box-backed status read doesn't assert. (The student
    // variant happened to keep this tile below the lazy ListView fold, but the
    // trimmed Teacher/Parent variant pulls it into the first frame.)
    await SyncQueueStorage.init();
  });

  // Some of these screens subscribe to providers backed by a never-connecting
  // remote stream in the test environment, which can keep a Hive box from
  // closing cleanly and make `deleteFromDisk` hang. The test_cache dir is
  // disposable, so cap cleanup and never let it stall the suite.
  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  // ─── Student-facing screens ──────────────────────────────────────
  final studentScreens = <String, Widget Function()>{
    'ProgressScreen': () => const ProgressScreen(),
    'DetailedAnalyticsScreen': () => const DetailedAnalyticsScreen(),
    // Learner-reachable since the Progress tab grew a "Learning Insights"
    // button; it had never been through the matrix because nothing could open
    // it but a voice command.
    'AdaptiveAnalyticsScreen': () => const AdaptiveAnalyticsScreen(),
    'StreakCalendarScreen': () => const StreakCalendarScreen(),
    'CertificateScreen': () => const CertificateScreen(),
    'SettingsScreen': () => const SettingsScreen(),
    'GoalsScreen': () => const GoalsScreen(),
    'NotebookScreen': () => const NotebookScreen(),
    'MoodCheckInScreen': () => const MoodCheckInScreen(),
    'MoodHistoryScreen': () => const MoodHistoryScreen(),
    // Never in the matrix before: the research dashboard, the album's
    // tabbed grid, and the note editor are all learner-reachable.
    'MoodInsightsScreen': () => const MoodInsightsScreen(),
    'StickerAlbumScreen': () => const StickerAlbumScreen(),
    'NoteEditorScreen': () => const NoteEditorScreen(),
    'WeeklyReportScreen': () => const WeeklyReportScreen(),
    // Word Hunt's collection: a long checklist of picture tiles, the shape
    // most likely to burst a row at a big font scale.
    'WordHuntCollectionScreen': () => const WordHuntCollectionScreen(),
  };

  for (final entry in studentScreens.entries) {
    testWidgets('${entry.key} survives the device matrix', (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        entry.value,
        overrides: _asRole(UserRole.student),
      );
    });
  }

  // ─── Educator dashboards (need a non-student role) ───────────────
  // Same widget, two audiences — see EducatorDashboardScreen. Both are
  // covered because the role-specific copy ("Your Students" + the counter,
  // "Class Overview") is what has to fit on the narrowest row.
  testWidgets('ParentDashboardScreen survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const ParentDashboardScreen(),
      overrides: _asRole(UserRole.parent),
    );
  });

  testWidgets('TeacherDashboardScreen survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const TeacherDashboardScreen(),
      overrides: _asRole(UserRole.teacher),
    );
  });

  // …and again with learners on the roster. The two passes above render the
  // empty state and nothing else, which is the entire dashboard an educator
  // never sees. See [_asEducatorWithRoster].
  for (final (label, build, role) in <(String, Widget Function(), UserRole)>[
    ('ParentDashboardScreen', () => const ParentDashboardScreen(),
        UserRole.parent),
    ('TeacherDashboardScreen', () => const TeacherDashboardScreen(),
        UserRole.teacher),
  ]) {
    testWidgets('$label (populated roster) survives the device matrix',
        (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        build,
        overrides: _asEducatorWithRoster(role),
      );
    });
  }

  testWidgets('ParentalControlsScreen survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const ParentalControlsScreen(),
      overrides: _asRole(UserRole.parent),
    );
  });

  // SettingsScreen is shared across roles, but the Teacher / Parent monitoring
  // profiles get a trimmed variant: the learner-only sections (Learning Modes,
  // Audio, Reminders, Adaptive Difficulty, Gaze Control, accessibility wizard,
  // tutorial replays) are hidden. Render that trimmed variant across the matrix
  // so the role-conditional layout stays overflow-safe.
  for (final role in const [UserRole.teacher, UserRole.parent]) {
    testWidgets('SettingsScreen (${role.name}) survives the device matrix',
        (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => const SettingsScreen(),
        overrides: _asRole(role),
      );
    });
  }

  // The educator Home renders the large "Primary + More" action grids for both
  // teacher and parent roles. Without Firebase the roster resolves to the empty
  // Hive fallback, which still lays out the action grids + overview stats +
  // empty state — exactly the layout we need overflow coverage for.
  for (final role in const [UserRole.teacher, UserRole.parent]) {
    testWidgets('EducatorHomeScreen (${role.name}) survives the device matrix',
        (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => const EducatorHomeScreen(),
        overrides: _asRole(role),
      );
    });
  }

  // The Guest Player home is a centered, stretched Column (not a sliver hub),
  // so short viewports are its risk case: it must scroll instead of
  // bottom-overflowing on phones / landscape / split-screen (regression: it
  // used to overflow below ~750 dp of height at normal text scale).
  testWidgets('PlayerHomeScreen (guest) survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const PlayerHomeScreen(),
      overrides: _asRole(UserRole.player, guest: true),
    );
  });

  // The Child home mirrors the Student hub structure (scrolling sliver grids),
  // rendered here across the matrix so its kid-sized tiles stay overflow-safe
  // on phones and at large font scales.
  testWidgets('ChildHomeScreen survives the device matrix', (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const ChildHomeScreen(),
      overrides: _asRole(UserRole.child),
    );
  });

  // ─── The accessibility themes, at the accessibility font sizes ───
  //
  // Everything above renders under Flutter's default theme, which is not a
  // theme any learner ever sees. The dyslexia theme adds a 1.6 line height and
  // 0.6 letter spacing on top of its own font sizes, so every line is wider
  // *and* taller than the pass above measured; high contrast overrides the
  // text theme and outlines every card. Both are what a learner actually turns
  // on, and both had no screen coverage at all until now.
  //
  // Narrow portrait only, at 1.5x/2.0x: a theme cannot change glyph widths in
  // a widget test, only the metrics, so it fails first where the column is
  // narrowest and the type largest.
  // The role-specific screens, which sit outside `studentScreens` above and so
  // were the last ones the theme pass did not reach. Educator dashboards and
  // the trimmed Teacher/Parent Settings are dense two-column layouts, and the
  // Child and guest Player homes are the kid-sized tile grids — all of them
  // the shapes that a 1.6 line height pushes hardest.
  final roleScreens = <String, ({Widget Function() build, List<Override> ov})>{
    'ParentDashboardScreen': (
      build: () => const ParentDashboardScreen(),
      ov: _asEducatorWithRoster(UserRole.parent),
    ),
    'TeacherDashboardScreen': (
      build: () => const TeacherDashboardScreen(),
      ov: _asEducatorWithRoster(UserRole.teacher),
    ),
    'ParentalControlsScreen': (
      build: () => const ParentalControlsScreen(),
      ov: _asRole(UserRole.parent),
    ),
    'SettingsScreen (teacher)': (
      build: () => const SettingsScreen(),
      ov: _asRole(UserRole.teacher),
    ),
    'SettingsScreen (parent)': (
      build: () => const SettingsScreen(),
      ov: _asRole(UserRole.parent),
    ),
    'EducatorHomeScreen (teacher)': (
      build: () => const EducatorHomeScreen(),
      ov: _asRole(UserRole.teacher),
    ),
    'EducatorHomeScreen (parent)': (
      build: () => const EducatorHomeScreen(),
      ov: _asRole(UserRole.parent),
    ),
    'PlayerHomeScreen (guest)': (
      build: () => const PlayerHomeScreen(),
      ov: _asRole(UserRole.player, guest: true),
    ),
    'ChildHomeScreen': (
      build: () => const ChildHomeScreen(),
      ov: _asRole(UserRole.child),
    ),
  };

  for (final theme in kLayoutThemes.entries) {
    for (final entry in roleScreens.entries) {
      testWidgets('${entry.key} survives the ${theme.key} theme',
          (tester) async {
        await expectScreenNoOverflowAcrossDevices(
          tester,
          entry.value.build,
          theme: theme.value(),
          themeLabel: theme.key,
          devices: kNarrowPortrait,
          textScales: kLargeTextScales,
          overrides: entry.value.ov,
        );
      });
    }
  }

  for (final theme in kLayoutThemes.entries) {
    for (final entry in studentScreens.entries) {
      testWidgets('${entry.key} survives the ${theme.key} theme',
          (tester) async {
        await expectScreenNoOverflowAcrossDevices(
          tester,
          entry.value,
          theme: theme.value(),
          devices: kNarrowPortrait,
          textScales: kLargeTextScales,
          overrides: _asRole(UserRole.student),
        );
      });
    }
  }
}
