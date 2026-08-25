import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_assign_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/student_list_provider.dart';

/// Who an educator may assign an assessment to.
///
/// "Assign Tasks" built its own roster: local Hive, filtered on
/// `role == UserRole.student`. That is the exact filter
/// [UserRoleX.isEnrollableLearner] exists to replace — it drops every
/// home-group `child`, so a Parent with children saw "No students found", and
/// it reads only local Hive, so a teacher never saw a student who joined their
/// class from another device. The screen now takes
/// [educatorLearnerRosterProvider], the same source the rest of the educator
/// surfaces use.
///
/// `testWidgets` only in this file — nothing here taps "Assign", which writes.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role);
  final UserRole _role;

  @override
  UserProfile? build() => UserProfile(
    id: 'educator-1',
    name: 'Educator',
    role: _role,
    createdAt: DateTime(2026),
  );
}

void main() {
  const educatorId = 'educator-1';

  (UserProfile, LearningProgress) learner(
    String id,
    String name,
    UserRole role, {
    bool guest = false,
  }) => (
    UserProfile(
      id: id,
      name: name,
      role: role,
      isGuestPlayer: guest,
      createdAt: DateTime(2026),
    ),
    LearningProgress(profileId: id, lastActivityDate: DateTime(2026, 8)),
  );

  final roster = [
    learner('s1', 'Hearing Student', UserRole.student),
    learner('c1', 'Motor Child', UserRole.child),
    learner('p1', 'Guest Player', UserRole.player, guest: true),
    learner('p2', 'Progress Player', UserRole.player),
    learner('t2', 'Another Teacher', UserRole.teacher),
  ];

  final custom = Assessment(
    id: 'a1',
    title: 'Farm Animals Check',
    type: AssessmentType.custom,
    questions: [
      const AssessmentQuestion(
        id: 'q1',
        questionText: 'What is the Filipino word for "dog"?',
        correctAnswer: 'Aso',
        choices: ['Aso', 'Pusa', 'Ibon', 'Isda'],
        category: FlashcardCategory.animals,
      ),
    ],
    createdBy: educatorId,
    createdAt: DateTime(2026, 8),
  );

  setUpAll(() async {
    // Self-healing: a suite that once hung leaves a flutter_tester holding
    // `*.lock` in this directory, and every later run fails setUpAll with
    // PathAccessException. The dir is disposable, so start from nothing.
    const cacheDir = './build/test_cache/assessment_assign_roster';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Still locked by a stray process — Hive will report it plainly below.
    }
    Hive.init(cacheDir);
    for (final name in const ['profiles', 'progress', 'settings']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    final box = Hive.box('progress');
    await box.clear();
    await box.put('assessments_$educatorId', [custom.toJson()]);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  Future<void> pumpAssign(
    WidgetTester tester,
    UserRole role, {
    List<(UserProfile, LearningProgress)>? people,
  }) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(() => _StubProfileNotifier(role)),
          // The Firestore-backed roster is unavailable in tests; the real
          // provider falls back to this local list exactly as it does offline.
          allProfilesWithProgressProvider.overrideWithValue(people ?? roster),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AssessmentAssignScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  for (final role in const [UserRole.teacher, UserRole.parent]) {
    testWidgets('${role.name} can assign to students and children', (
      tester,
    ) async {
      await pumpAssign(tester, role);

      expect(
        find.text('Motor Child'),
        findsOneWidget,
        reason: 'a home-group child is an enrollable learner; filtering on '
            '`role == student` is what showed a Parent an empty screen',
      );
      expect(find.text('Hearing Student'), findsOneWidget);
    });

    testWidgets('${role.name} is not offered players or other educators', (
      tester,
    ) async {
      await pumpAssign(tester, role);

      expect(find.text('Guest Player'), findsNothing);
      expect(find.text('Progress Player'), findsNothing);
      expect(
        find.text('Another Teacher'),
        findsNothing,
        reason: 'only enrollable learners belong on an assignment roster',
      );
    });
  }

  testWidgets('the roster count matches the tick boxes offered', (tester) async {
    await pumpAssign(tester, UserRole.teacher);

    expect(find.text('Select Students (0/2)'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
  });

  testWidgets('a parent with nobody enrolled is pointed at their group code', (
    tester,
  ) async {
    await pumpAssign(tester, UserRole.parent, people: const []);

    expect(find.text('No children yet'), findsOneWidget);
    expect(find.text('Share Group Code'), findsOneWidget);
    expect(
      find.text('Create Student'),
      findsNothing,
      reason: 'minting a learner from the role picker never enrolled anyone',
    );
  });

  testWidgets('a teacher with nobody enrolled is pointed at their class code', (
    tester,
  ) async {
    await pumpAssign(tester, UserRole.teacher, people: const []);

    expect(find.text('No students yet'), findsOneWidget);
    expect(find.text('Share Class Code'), findsOneWidget);
  });

  testWidgets('Assign stays disabled until an assessment and a learner are '
      'picked', (tester) async {
    await pumpAssign(tester, UserRole.teacher);

    FilledButton assignButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Assign Assessment'),
    );

    expect(assignButton().onPressed, isNull);

    await tester.tap(find.text('Farm Animals Check'));
    await tester.pump();
    expect(
      assignButton().onPressed,
      isNull,
      reason: 'an assessment assigned to nobody is not an assignment',
    );

    await tester.tap(find.text('Motor Child'));
    await tester.pump();
    expect(assignButton().onPressed, isNotNull);
  });
}
