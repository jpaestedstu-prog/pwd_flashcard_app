import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/settings/screens/dashboard_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// A learner's Dashboard drew its Category Breakdown, and the "needs
/// practice" / "doing great" insights, from `categoryProgress`, a rolling
/// average of game accuracy. On the Honor (13 October 2026) it read
/// "Animals 28%" for a learner who knew 1 animal word of 12, while their own
/// Cards tab said 8%. It now shows how much of each category is learned.

class _Learner extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'kid',
    name: 'Kid',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );
}

class _Progress extends ProgressNotifier {
  _Progress(this._initial);
  final LearningProgress _initial;
  @override
  LearningProgress build() {
    profileId = _initial.profileId;
    return _initial;
  }
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(reducedMotion: true);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async => 1);
    const cacheDir = './build/test_cache/student_dashboard_coverage';
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

  testWidgets('the breakdown and insights count words learned, not accuracy', (tester) async {
    final animals = SeedData.allFlashcards.where((c) => c.category == FlashcardCategory.animals).toList();
    expect(animals, hasLength(12), reason: 'the fixture assumes the 12-word Animals deck');
    final progress = LearningProgress(
      profileId: 'kid',
      lastActivityDate: DateTime(2026, 10, 5),
      wordsLearned: 1,
      learnedWordIds: {animals.first.id},
      // The accuracy averages the screen used to show as progress.
      categoryProgress: const {'Animals': 0.28, 'Colors & Shapes': 0.36},
    );
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(_Learner.new),
          progressProvider.overrideWith(() => _Progress(progress)),
          settingsProvider.overrideWith(_Settings.new),
          allFlashcardsProvider.overrideWithValue(SeedData.allFlashcards),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.text('8%'), findsWidgets, reason: '1 of 12 animal words');
    expect(find.text('28%'), findsNothing);
    expect(find.text('36%'), findsNothing);
    expect(find.textContaining('Animals (8%)'), findsOneWidget, reason: 'the insight agrees with the bar');
    expect(find.textContaining('(28%)'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
