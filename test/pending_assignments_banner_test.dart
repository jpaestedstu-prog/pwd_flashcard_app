import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/home/screens/child_home_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/device_matrix.dart';

/// Assigned work has to be visible to a Child, not just to a Student.
///
/// A Parent enrols children exactly as a Teacher enrols students, and can now
/// set them work — but the "Pending Assignments" banner was a private widget
/// inside `home_screen.dart`, so the Child home had no banner, no route into
/// the Assessment Center, and no way to learn the work existed. Both homes now
/// render the same shared [PendingAssignmentsBanner].
///
/// `testWidgets` only: nothing here writes to a box after the seed.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.id);
  final String id;

  @override
  UserProfile? build() => UserProfile(
    id: id,
    name: 'Anak',
    role: UserRole.child,
    homeGroupId: 'group-1',
    createdAt: DateTime(2026),
  );
}

void main() {
  const assignedChild = 'child-assigned';
  const idleChild = 'child-idle';
  const overdueChild = 'child-overdue';
  const parentId = 'parent-1';

  final template = Assessment(
    id: 'a1',
    title: 'Home Words',
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
    createdBy: parentId,
    createdAt: DateTime(2026, 8),
  );

  final assignment = AssessmentAssignment(
    id: 'as1',
    assessmentId: 'a1',
    assessmentTitle: 'Home Words',
    assignedBy: parentId,
    studentIds: const [assignedChild],
    assignedAt: DateTime(2026, 8),
  );

  setUpAll(() async {
    const cacheDir = './build/test_cache/pending_assignments_banner';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Still locked by a stray flutter_tester — Hive reports it below.
    }
    Hive.init(cacheDir);
    for (final name in const [
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    await SyncQueueStorage.init();

    final box = Hive.box('progress');
    await box.clear();
    await box.put('assessments_$parentId', [template.toJson()]);
    await box.put('assignments_$parentId', [
      assignment.toJson(),
      AssessmentAssignment(
        id: 'as2',
        assessmentId: 'a1',
        assessmentTitle: 'Home Words',
        assignedBy: parentId,
        studentIds: const [overdueChild],
        assignedAt: DateTime(2026, 8),
        deadline: DateTime(2020),
      ).toJson(),
    ]);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  Future<void> pumpChildHome(
    WidgetTester tester,
    String profileId, {
    Size? device,
    double dpr = 1.75,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = (device ?? const Size(1200, 1920)) * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(() => _StubProfileNotifier(profileId)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChildHomeScreen(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    // Plain pumps, never pumpAndSettle: the hub backdrop animates forever.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('a child with assigned work sees the banner', (tester) async {
    await pumpChildHome(tester, assignedChild);

    expect(find.text('Pending Assignments'), findsOneWidget);
    expect(
      find.text('You have 1 assessment to complete'),
      findsOneWidget,
      reason: 'a Parent can assign to a child; the child has to be told',
    );
  });

  testWidgets('a child with nothing assigned sees no banner', (tester) async {
    await pumpChildHome(tester, idleChild);

    expect(find.text('Pending Assignments'), findsNothing);
    expect(find.text('Overdue Assignments'), findsNothing);
  });

  testWidgets('the banner reads as overdue once the deadline passes', (
    tester,
  ) async {
    await pumpChildHome(tester, overdueChild);

    expect(find.text('Overdue Assignments'), findsOneWidget);
    expect(find.text('Pending Assignments'), findsNothing);
  });

  // The Child home had never rendered a banner above its tile grid; check the
  // new row survives the matrix rather than assuming FeatureBanner is safe
  // everywhere it is dropped.
  for (final device in kTabletMatrix) {
    for (final scale in kTextScales) {
      testWidgets('the child home lays out at ${device.label}, ${scale}x text', (
        tester,
      ) async {
        await pumpChildHome(
          tester,
          assignedChild,
          device: device.size,
          dpr: device.devicePixelRatio,
          textScale: scale,
        );

        Object? firstError;
        for (
          Object? e = tester.takeException();
          e != null;
          e = tester.takeException()
        ) {
          firstError ??= e;
        }
        expect(
          firstError,
          isNull,
          reason: 'child home at ${device.label} ${scale}x: $firstError',
        );
      });
    }
  }
}
