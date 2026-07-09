import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_hub_screen.dart';
import 'package:pwdpwdpwd/features/break_time/screens/break_time_screen.dart';
import 'package:pwdpwdpwd/features/classroom/screens/classroom_management_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_list_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/game_hub_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart';
import 'package:pwdpwdpwd/features/home/screens/player_home_screen.dart';
import 'package:pwdpwdpwd/features/home_group/screens/home_group_management_screen.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_list_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/screen_matrix.dart';

/// Second overflow matrix, covering the high-traffic **profile hubs and
/// button-dense learner/educator screens** that the first matrix
/// (`feature_screens_overflow_test.dart`) does not: the main learner Home,
/// the Player-with-Progress home, the Games hub, the flashcard deck list, the
/// Stories list, the Assessment center, Break Time, and the Teacher/Parent
/// class/home-group management screens.
///
/// Each is rendered at its first frame across every tablet size × orientation ×
/// font scale (7"→10"+ tablets and phones, both orientations, 1.0/1.3/2.0×) and
/// asserted to lay out without a `RenderFlex` / bottom overflow. This is the
/// automated backstop behind "no button overflow on any profile, in portrait
/// or landscape, on any Android tablet".
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
  profileProvider.overrideWith(() => _StubProfileNotifier(role, guest: guest)),
];

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/profile_screens');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
      'classrooms',
      'classroom_members',
      'home_groups',
      'home_group_members',
      'child_alarms',
      'child_time_limits',
      'active_time_logs',
      'friends_cache',
      'friend_requests_cache',
      'friend_directory_cache',
      'leaderboard_config',
      'goals',
      'notebook',
      'mood_entries',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
    await SyncQueueStorage.init();
  });

  // Some of these screens subscribe to never-connecting remote streams in the
  // test environment, which can keep a Hive box from closing cleanly and make
  // `deleteFromDisk` hang. The test_cache dir is disposable, so cap cleanup.
  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  // ─── Learner hubs & button-dense learner screens ─────────────────
  for (final entry in <String, Widget Function()>{
    'HomeScreen': () => const HomeScreen(),
    'GameHubScreen': () => const GameHubScreen(),
    'DeckListScreen': () => const DeckListScreen(),
    'StoryListScreen': () => const StoryListScreen(),
    'AssessmentHubScreen': () => const AssessmentHubScreen(),
    'BreakTimeScreen': () => const BreakTimeScreen(),
  }.entries) {
    testWidgets('${entry.key} (student) survives the device matrix', (
      tester,
    ) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        entry.value,
        overrides: _asRole(UserRole.student),
      );
    });
  }

  // The Games hub gates content by the learner's accessibility category, so
  // render it for the child role too (kid-sized tiles).
  testWidgets('GameHubScreen (child) survives the device matrix', (
    tester,
  ) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const GameHubScreen(),
      overrides: _asRole(UserRole.child),
    );
  });

  // ─── Player (with Progress) home ─────────────────────────────────
  // The non-guest Player home keeps XP/streak/badge surfaces the guest home
  // hides, so it is a distinct layout from the guest variant already covered.
  testWidgets('PlayerHomeScreen (with progress) survives the device matrix', (
    tester,
  ) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const PlayerHomeScreen(),
      overrides: _asRole(
        UserRole.player,
      ), // non-guest (default): keeps progress
    );
  });

  // ─── Educator management surfaces ────────────────────────────────
  // Without Firebase the cloud providers resolve to loading/empty states,
  // which still lay out the header + action buttons + empty state we need
  // overflow coverage for.
  testWidgets(
    'ClassroomManagementScreen (teacher) survives the device matrix',
    (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => const ClassroomManagementScreen(),
        overrides: _asRole(UserRole.teacher),
      );
    },
  );

  testWidgets('HomeGroupManagementScreen (parent) survives the device matrix', (
    tester,
  ) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const HomeGroupManagementScreen(),
      overrides: _asRole(UserRole.parent),
    );
  });
}
