import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Imported through the assessment service on purpose: that re-export is what
// keeps the rest of the app on one enum, so exercising it here is part of the
// test rather than an accident of import ordering.
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_sync_feedback.dart';

/// What an educator is told when a routine write does not reach the cloud.
///
/// This exists because the first version of the Routine service threw on a
/// rule rejection, which the UI turned into the global "Something went wrong"
/// snackbar. Two very different failures were hiding under it: one resolves
/// itself, the other never will, and an educator told to check their wifi for
/// the second one will keep re-saving a routine their learner cannot receive.

FirebaseException _denied() => FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );

FirebaseException _unavailable() => FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'The service is currently unavailable.',
    );

Future<void> _pumpReport(
  WidgetTester tester,
  CloudSyncOutcome outcome, {
  bool filipino = false,
  String subject = 'routine',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => reportRoutineSync(
              context,
              outcome,
              filipino: filipino,
              subject: subject,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('classification', () {
    test('permission-denied is an ownership refusal, nothing else is', () {
      expect(isOwnershipRefusalError(_denied()), isTrue);
      expect(isOwnershipRefusalError(_unavailable()), isFalse);
      // A plain Dart error is a bug, not a rules rejection.
      expect(isOwnershipRefusalError(StateError('boom')), isFalse);
      expect(isOwnershipRefusalError(Exception('boom')), isFalse);
    });

    test('a refused write is notOwner; every other failure is localOnly', () {
      expect(outcomeForError(_denied()), CloudSyncOutcome.notOwner);
      expect(outcomeForError(_unavailable()), CloudSyncOutcome.localOnly);
      expect(outcomeForError(StateError('boom')), CloudSyncOutcome.localOnly);
    });

    test('only a synced write needs no attention', () {
      expect(CloudSyncOutcome.synced.needsAttention, isFalse);
      expect(CloudSyncOutcome.localOnly.needsAttention, isTrue);
      expect(CloudSyncOutcome.notOwner.needsAttention, isTrue);
    });

    test('the assessment module still sees the same vocabulary', () {
      // `CloudSyncOutcome` moved to core; the assessment service re-exports it
      // so its screens and tests keep compiling. If this breaks, the export
      // was dropped and half the app is now on a second, divergent enum.
      expect(AssessmentCloudService.isOwnershipRefusal(_denied()), isTrue);
      expect(AssessmentCloudService.isOwnershipRefusal(_unavailable()), isFalse);
      const outcome = CloudSyncOutcome.notOwner;
      expect(outcome, isA<CloudSyncOutcome>());
    });
  });

  group('what the educator is told', () {
    testWidgets('a synced write says nothing at all', (tester) async {
      await _pumpReport(tester, CloudSyncOutcome.synced);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a local-only write promises it is coming', (tester) async {
      await _pumpReport(tester, CloudSyncOutcome.localOnly);
      expect(find.textContaining('not sent yet'), findsOneWidget);
      expect(find.textContaining('will upload'), findsOneWidget);
      // Must not blame another device — this one really is just offline.
      expect(find.textContaining('another device'), findsNothing);
    });

    testWidgets('a refused write says it is never going, and why',
        (tester) async {
      await _pumpReport(tester, CloudSyncOutcome.notOwner);
      expect(find.textContaining('this device only'), findsOneWidget);
      expect(find.textContaining('restored on another device'), findsOneWidget);
      // The way out has to be in the message; this is the whole point.
      expect(find.textContaining('Restore it back here'), findsOneWidget);
      // And it must never say "yet", which is the lie that cost the feature.
      expect(find.textContaining('not sent yet'), findsNothing);
    });

    testWidgets('the subject lands in the sentence', (tester) async {
      await _pumpReport(tester, CloudSyncOutcome.notOwner, subject: 'deletion');
      expect(find.textContaining('send the deletion to your learner'),
          findsOneWidget);
    });

    testWidgets('Filipino gets its own copy, not the English one',
        (tester) async {
      await _pumpReport(tester, CloudSyncOutcome.notOwner, filipino: true);
      expect(find.textContaining('Na-restore ang profile na ito'),
          findsOneWidget);
      expect(find.textContaining('restored on another device'), findsNothing);

      await _pumpReport(tester, CloudSyncOutcome.localOnly, filipino: true);
      expect(find.textContaining('hindi pa naipapadala'), findsOneWidget);
    });
  });
}
