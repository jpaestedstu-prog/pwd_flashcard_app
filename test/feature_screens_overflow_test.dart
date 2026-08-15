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
import 'package:pwdpwdpwd/features/notebook/screens/notebook_screen.dart';
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

import 'support/screen_matrix.dart';

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
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
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
  for (final entry in <String, Widget Function()>{
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
    'WeeklyReportScreen': () => const WeeklyReportScreen(),
    // Word Hunt's collection: a long checklist of picture tiles, the shape
    // most likely to burst a row at a big font scale.
    'WordHuntCollectionScreen': () => const WordHuntCollectionScreen(),
  }.entries) {
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
}
