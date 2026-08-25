import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/widgets/learner_assignment_sync.dart';

/// New work should appear without restarting the app.
///
/// [learnerAssignmentSyncProvider] is a `FutureProvider.family`: it runs once
/// per profile and then caches, so a learner sitting on the home screen never
/// saw work assigned to them until a relaunch. That is precisely the classroom
/// case — the tablet is put down, the teacher assigns, the learner picks it up.
///
/// [LearnerAssignmentSync] invalidates the pull on resume. These tests drive
/// the real lifecycle callback through the binding rather than calling the
/// method directly, so an observer that was never registered would fail.
void main() {
  const learner = 'learner-1';

  /// Pumps a stand-in for a learner home: something that *watches* the sync
  /// provider (as both real homes do) plus the invisible refresher.
  Future<int Function()> pumpHome(WidgetTester tester) async {
    var runs = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnerAssignmentSyncProvider.overrideWith((ref, id) async {
            runs++;
          }),
        ],
        child: const MaterialApp(home: _FakeLearnerHome(profileId: learner)),
      ),
    );
    await tester.pump();
    return () => runs;
  }

  testWidgets('pulls once when the screen first builds', (tester) async {
    final runs = await pumpHome(tester);

    expect(runs(), 1);
  });

  testWidgets('pulls again when the app is resumed', (tester) async {
    final runs = await pumpHome(tester);
    expect(runs(), 1);

    // The learner puts the tablet down; the teacher assigns; they pick it up.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      runs(),
      2,
      reason: 'resuming must re-check for work assigned while away',
    );
  });

  testWidgets('backgrounding alone does not spend a read', (tester) async {
    final runs = await pumpHome(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(
      runs(),
      1,
      reason: 'only coming back to the foreground is worth a round trip',
    );
  });

  testWidgets('stops listening once the screen is gone', (tester) async {
    var runs = 0;
    final overrides = [
      learnerAssignmentSyncProvider.overrideWith((ref, id) async {
        runs++;
      }),
    ];
    // The same ProviderScope throughout — Riverpod asserts the override count
    // cannot change across rebuilds, so only the child is swapped out.
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: _FakeLearnerHome(profileId: learner)),
      ),
    );
    await tester.pump();
    expect(runs, 1);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(runs, 1, reason: 'a disposed observer must not keep firing reads');
  });

  testWidgets('an empty profile id never pulls on resume', (tester) async {
    var runs = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnerAssignmentSyncProvider.overrideWith((ref, id) async {
            runs++;
          }),
        ],
        child: const MaterialApp(
          home: LearnerAssignmentSync(profileId: ''),
        ),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(runs, 0);
  });
}

/// Watches the sync provider the way the real learner homes do, and hosts the
/// refresher. The watch matters: the "Pending Assignments" banner is chosen by
/// an `if` in the home's own build, so the home is what has to rebuild.
class _FakeLearnerHome extends ConsumerWidget {
  final String profileId;

  const _FakeLearnerHome({required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(learnerAssignmentSyncProvider(profileId));
    return LearnerAssignmentSync(profileId: profileId);
  }
}
