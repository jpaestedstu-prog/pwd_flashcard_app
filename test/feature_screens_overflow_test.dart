import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/goals/screens/goals_screen.dart';
import 'package:pwdpwdpwd/features/mood_tracker/screens/mood_check_in_screen.dart';
import 'package:pwdpwdpwd/features/mood_tracker/screens/mood_history_screen.dart';
import 'package:pwdpwdpwd/features/notebook/screens/notebook_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/parent_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/parental_controls_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/certificate_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/detailed_analytics_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/progress_screen.dart';
import 'package:pwdpwdpwd/features/progress/screens/streak_calendar_screen.dart';
import 'package:pwdpwdpwd/features/reports/screens/weekly_report_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';
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
  _StubProfileNotifier(this._role);
  final UserRole _role;

  @override
  UserProfile? build() => UserProfile(
        id: 'test-profile',
        name: 'Test User',
        role: _role,
        createdAt: DateTime(2026),
      );
}

List<Override> _asRole(UserRole role) =>
    [profileProvider.overrideWith(() => _StubProfileNotifier(role))];

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
    'StreakCalendarScreen': () => const StreakCalendarScreen(),
    'CertificateScreen': () => const CertificateScreen(),
    'SettingsScreen': () => const SettingsScreen(),
    'GoalsScreen': () => const GoalsScreen(),
    'NotebookScreen': () => const NotebookScreen(),
    'MoodCheckInScreen': () => const MoodCheckInScreen(),
    'MoodHistoryScreen': () => const MoodHistoryScreen(),
    'WeeklyReportScreen': () => const WeeklyReportScreen(),
  }.entries) {
    testWidgets('${entry.key} survives the device matrix', (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        entry.value,
        overrides: _asRole(UserRole.student),
      );
    });
  }

  // ─── Parent surfaces (need a non-student role) ───────────────────
  testWidgets('ParentDashboardScreen survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const ParentDashboardScreen(),
      overrides: _asRole(UserRole.parent),
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
}
