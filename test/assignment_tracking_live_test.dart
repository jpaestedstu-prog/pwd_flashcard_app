import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assignment_tracking_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Assignment Tracking has to repaint.
///
/// It read Hive straight from `build()` and, after deleting, called
/// `(context as Element).markNeedsBuild()` on the *list item's* context. That
/// never recomputed the screen's list, so a deleted assignment sat there until
/// you navigated away and came back — and an assignment made from this screen's
/// own "+" button was invisible the same way. It now watches
/// [assignmentsProvider].
///
/// The provider is faked in memory here so no `box.put` runs inside a widget
/// test's fake-async zone; the boxes that are opened are only read from (the
/// cards resolve learner names and results out of them).

class _StubProfileNotifier extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'educator-1',
    name: 'Educator',
    role: UserRole.teacher,
    createdAt: DateTime(2026),
  );
}

/// In-memory [AssignmentsNotifier]: same surface, no persistence.
class _FakeAssignments extends StateNotifier<List<AssessmentAssignment>>
    implements AssignmentsNotifier {
  _FakeAssignments(super.initial, {this.deleteOutcome = CloudSyncOutcome.synced});

  /// What the cloud said about the delete. Settable so a test can play the
  /// device this profile was restored away from.
  final CloudSyncOutcome deleteOutcome;

  @override
  String get educatorId => 'educator-1';

  @override
  AssessmentCloudService get cloud => const AssessmentCloudService();

  @override
  void refresh() {}

  @override
  Future<CloudSyncOutcome> saveAssignment(
    AssessmentAssignment assignment,
  ) async {
    state = [...state.where((a) => a.id != assignment.id), assignment];
    return CloudSyncOutcome.localOnly;
  }

  @override
  Future<CloudSyncOutcome> deleteAssignment(String assignmentId) async {
    state = state.where((a) => a.id != assignmentId).toList();
    return deleteOutcome;
  }
}

void main() {
  AssessmentAssignment task(
    String id,
    String title, {
    DateTime? assignedAt,
  }) => AssessmentAssignment(
    id: id,
    assessmentId: 'assessment-$id',
    assessmentTitle: title,
    assignedBy: 'educator-1',
    studentIds: const ['learner-1'],
    assignedAt: assignedAt ?? DateTime(2026, 8),
  );

  setUpAll(() async {
    const cacheDir = './build/test_cache/assignment_tracking_live';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Still locked by a stray flutter_tester — Hive reports it below.
    }
    Hive.init(cacheDir);
    // Read-only from here: getAssignmentStatuses looks up learner names and
    // any completed results.
    for (final name in const ['profiles', 'progress', 'settings']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  Future<_FakeAssignments> pumpTracking(
    WidgetTester tester,
    List<AssessmentAssignment> initial, {
    CloudSyncOutcome deleteOutcome = CloudSyncOutcome.synced,
  }) async {
    final fake = _FakeAssignments(initial, deleteOutcome: deleteOutcome);

    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(_StubProfileNotifier.new),
          assignmentsProvider.overrideWith((ref) => fake),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AssignmentTrackingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return fake;
  }

  testWidgets('lists the educator\'s assignments, newest first', (
    tester,
  ) async {
    await pumpTracking(tester, [
      task('a', 'Older Quiz', assignedAt: DateTime(2026, 8)),
      task('b', 'Newer Quiz', assignedAt: DateTime(2026, 8, 10)),
    ]);

    expect(find.text('Older Quiz'), findsOneWidget);
    expect(find.text('Newer Quiz'), findsOneWidget);

    final newerY = tester.getTopLeft(find.text('Newer Quiz')).dy;
    final olderY = tester.getTopLeft(find.text('Older Quiz')).dy;
    expect(newerY, lessThan(olderY));
  });

  testWidgets('deleting removes the card without leaving the screen', (
    tester,
  ) async {
    await pumpTracking(tester, [task('a', 'Doomed Quiz')]);

    expect(find.text('Doomed Quiz'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text('Doomed Quiz'),
      findsNothing,
      reason: 'the deleted assignment used to stay on screen until you '
          'navigated away and back',
    );
    expect(find.text('No assignments yet'), findsOneWidget);
  });

  testWidgets('cancelling the delete keeps the assignment', (tester) async {
    final fake = await pumpTracking(tester, [task('a', 'Kept Quiz')]);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Kept Quiz'), findsOneWidget);
    expect(fake.state, hasLength(1));
  });

  testWidgets('a newly assigned task appears without a reopen', (tester) async {
    final fake = await pumpTracking(tester, const []);

    expect(find.text('No assignments yet'), findsOneWidget);

    await fake.saveAssignment(task('new', 'Fresh Quiz'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Fresh Quiz'), findsOneWidget);
    expect(find.text('No assignments yet'), findsNothing);

    // The card animates in; let its entrance timers finish so the binding
    // doesn't fail the test on a pending timer at teardown.
    await tester.pumpAndSettle();
  });

  testWidgets('a delete the cloud refused says so', (tester) async {
    // Restoring a profile with a recovery code re-stamps its `owner_uid`, and
    // the rules pin every assessment write to the owning device — so the
    // tablet it was restored *away from* silently goes read-only. Seen on two
    // real devices: the row left the teacher's list, stayed in Firestore, and
    // came straight back to the other tablet. The card going away is honest
    // (it is gone from here); implying the learner lost it too is not.
    await pumpTracking(
      tester,
      [task('a', 'Doomed Quiz')],
      deleteOutcome: CloudSyncOutcome.notOwner,
    );

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Doomed Quiz'), findsNothing);
    expect(
      find.textContaining('your learners still have this assignment'),
      findsOneWidget,
      reason: 'a teacher who thinks they withdrew work still sitting on a '
          'learner tablet finds out the hard way',
    );
  });

  testWidgets('a delete that went through says nothing extra', (tester) async {
    await pumpTracking(tester, [task('a', 'Doomed Quiz')]);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('restored on another device'), findsNothing);
  });

  testWidgets('an empty roster reads as pending nothing, not as progress', (
    tester,
  ) async {
    await pumpTracking(tester, [task('a', 'Solo Quiz')]);

    // One learner, nothing completed.
    expect(find.text('0/1'), findsOneWidget);
  });
}
