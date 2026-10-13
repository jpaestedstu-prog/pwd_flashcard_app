import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/features/settings/screens/multi_student_dashboard_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/student_list_provider.dart';

/// The All Students screen showed the stored streak, which only moves on the
/// next activity: a learner whose run ended days ago still read "1d" there
/// while their own home said 0 (found on the Honor, 13 October 2026). The
/// screen already sorted by the live streak.

class _Teacher extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'teacher-1',
    name: 'Guro',
    role: UserRole.teacher,
    createdAt: DateTime(2026),
  );
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(reducedMotion: true);
}

(UserProfile, LearningProgress) _learner(String id, String name, int streak, int daysAgo) {
  final now = DateTime.now();
  return (
    UserProfile(id: id, name: name, role: UserRole.student, createdAt: DateTime(2026)),
    LearningProgress(
      profileId: id,
      streakDays: streak,
      lastActivityDate: DateTime(now.year, now.month, now.day - daysAgo, 12),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async => 1);
    // The filter bar and the cards read local storage directly; empty boxes.
    const cacheDir = './build/test_cache/all_students_live_streak';
    final dir = Directory(cacheDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    Hive.init(cacheDir);
    for (final name in const ['profiles', 'settings', 'progress', 'custom_cards', 'sessions',
                              'classrooms', 'classroom_members', 'home_groups', 'home_group_members',
                              'active_time_logs', 'error_logs']) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  testWidgets('each card shows the streak as it stands today', (tester) async {
    final roster = [
      _learner('ended', 'Ended Run', 3, 5), // last played 5 days ago: the run is over
      _learner('alive', 'Alive Run', 4, 1), // played yesterday: still alive today
    ];
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(_Teacher.new),
          settingsProvider.overrideWith(_Settings.new),
          educatorRosterProvider.overrideWith((ref, id) async => roster),
          educatorLearnerRosterProvider.overrideWithValue(roster),
          allFlashcardsProvider.overrideWithValue(SeedData.allFlashcards),
        ],
        child: const MaterialApp(home: MultiStudentDashboardScreen()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('0d'), findsOneWidget, reason: 'the ended run reads 0');
    expect(find.text('4d'), findsOneWidget, reason: 'the live run keeps its length');
    expect(find.text('3d'), findsNothing, reason: 'not the stored length of a run that ended');
    expect(find.bySemanticsLabel(RegExp(r'^Ended Run, .*\b0 day streak')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Alive Run, .*\b4 day streak')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
