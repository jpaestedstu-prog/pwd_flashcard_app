import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/parent/widgets/child_detail_sheet.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/parent_provider.dart';

/// Word Hunt is the one activity that happens *away* from the screen, so it
/// never shows up in a game score — an educator reviewing a learner would see
/// no trace of it at all. This puts it on the child detail surface.
///
/// That surface is a single widget shared by the Teacher and Parent dashboards
/// (see `EducatorDashboardScreen`), so covering it once covers both audiences.

ChildSummary _child({int finds = 0, int streak = 0}) => ChildSummary(
      profileId: 'p1',
      name: 'Test Learner',
      avatarEmoji: '🦊',
      avatarIndex: 0,
      disabilityType: DisabilityType.motor,
      wordsLearned: 12,
      totalStars: 30,
      streakDays: 2,
      gamesPlayed: 4,
      averageAccuracy: 0.8,
      studyMinutesThisWeek: 40,
      studyMinutesLastWeek: 20,
      totalSessions: 5,
      dailyStudyMinutes: const {},
      categoryProgress: const {},
      categoryCoverage: const {},
      wordHuntFinds: finds,
      signsWatched: 0,
      wordHuntStreak: streak,
      recentScores: const [],
      lastActivityDate: DateTime(2026, 8, 10),
    );

void main() {
  const storeDir = './build/test_cache/word_hunt_educator';

  setUpAll(() async {
    final dir = Directory(storeDir);
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Held by a dead run; the boxes below are opened either way.
      }
    }
    Hive.init(storeDir);
    // The sheet pulls the learner's progress skin, layout, sessions and group
    // membership, so it needs the boxes `HiveService.init` opens in the app.
    for (final name in const [
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
      'classrooms',
      'classroom_members',
      'home_groups',
      'home_group_members',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  Future<void> pumpSheet(WidgetTester tester, ChildSummary child) async {
    // Tall viewport: the stat grid sits well down a scrollable sheet.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ChildDetailSheet(child: child)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('shows the learner\'s camera finds', (tester) async {
    await pumpSheet(tester, _child(finds: 14));

    // ProStatTile renders its label uppercased.
    expect(find.text('WORD HUNT FINDS'), findsOneWidget);
    expect(find.text('14'), findsWidgets);
    expect(find.text('with the camera'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an active hunt streak replaces the caption', (tester) async {
    await pumpSheet(tester, _child(finds: 14, streak: 3));

    expect(find.text('3-day streak'), findsOneWidget);
    expect(find.text('with the camera'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a learner who has never hunted reads zero, not blank',
      (tester) async {
    await pumpSheet(tester, _child());

    expect(find.text('WORD HUNT FINDS'), findsOneWidget);
    expect(find.text('with the camera'), findsOneWidget);
    await unmount(tester);
  });
}
