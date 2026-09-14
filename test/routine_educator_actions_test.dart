import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_lock_status.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_educator_actions.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// The buttons an educator gets for a step holding a learner's device.
///
/// Every action here reaches a child's screen in another room, so each one
/// confirms first, in words that say what will actually happen. These tests
/// open each confirmation and cancel it — the writes behind them are covered
/// by `routine_actions_service_test.dart`, outside the widget-test zone where
/// Hive writes are safe.
///
/// "Mark done" ends a step before its time is up, so it is only offered on a
/// step the educator set as "can be released early". Otherwise the learner
/// waits until the time ends; excusing the step and the 30-minute unlock stay
/// on every step, for a day that went wrong.

class _Educator extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'rose',
        name: 'Rose',
        role: UserRole.teacher,
        createdAt: DateTime(2026),
      );
}

const _brush = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
);

/// The same step, set by its educator as "can be released early".
const _brushEarly = RoutineStep(
  id: 'brush',
  activity: RoutineActivity.brushingTeeth,
  hour: 6,
  minute: 45,
  releaseEarly: true,
);

Routine _routine(RoutineStep step) => Routine(
      id: 'morning',
      childProfileId: 'ana',
      setterProfileId: 'rose',
      setterRole: UserRole.teacher,
      name: 'Morning',
      steps: [step],
      lockEnabled: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

RoutineStepLockStatus _status({
  RoutineStep step = _brush,
  RoutineDayActions? actions,
}) {
  final now = DateTime.now();
  return RoutineLockSummary.statusFor(
    routine: _routine(step),
    step: step,
    view: RoutineDayView.of(profileId: 'ana', day: now, actions: actions),
    now: DateTime(now.year, now.month, now.day, 6, 50),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileProvider.overrideWith(_Educator.new)],
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    ),
  );
}

Future<void> _openAndCancel(
  WidgetTester tester,
  String button, {
  required String title,
  String? bodyContains,
}) async {
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  expect(find.text(title), findsOneWidget);
  if (bodyContains != null) {
    expect(find.textContaining(bodyContains), findsOneWidget);
  }
  await tester.tap(find.text('Cancel'));
  await tester.pumpAndSettle();
  expect(find.text(title), findsNothing);
}

void main() {
  testWidgets('a step that may end early offers mark done, excuse and unlock',
      (tester) async {
    await _pump(
      tester,
      RoutineStepActionBar(
        childProfileId: 'ana',
        learnerName: 'Ana',
        status: _status(step: _brushEarly),
        filipino: false,
      ),
    );
    expect(find.text('Mark done'), findsOneWidget);
    expect(find.text('Excuse today'), findsOneWidget);
    expect(find.text('Unlock 30 min'), findsOneWidget);
  });

  testWidgets('a step that must wait offers no mark done — only excuse and '
      'unlock', (tester) async {
    await _pump(
      tester,
      RoutineStepActionBar(
        childProfileId: 'ana',
        learnerName: 'Ana',
        status: _status(),
        filipino: false,
      ),
    );
    expect(find.text('Mark done'), findsNothing);
    expect(find.text('Excuse today'), findsOneWidget);
    expect(find.text('Unlock 30 min'), findsOneWidget);
  });

  testWidgets('each action says what it will do before doing it', (
    tester,
  ) async {
    await _pump(
      tester,
      RoutineStepActionBar(
        childProfileId: 'ana',
        learnerName: 'Ana',
        status: _status(step: _brushEarly),
        filipino: false,
      ),
    );
    await _openAndCancel(
      tester,
      'Mark done',
      title: 'Mark Brushing Teeth done for Ana?',
      bodyContains: 'Only if you saw it done',
    );
    await _openAndCancel(
      tester,
      'Excuse today',
      title: 'Excuse Brushing Teeth for today?',
      bodyContains: 'The step stays not done',
    );
    await _openAndCancel(
      tester,
      'Unlock 30 min',
      title: 'Unlock Ana’s device for 30 minutes?',
      bodyContains: 'Every lock pauses',
    );
  });

  testWidgets('undo names which adult decision it takes back', (tester) async {
    final approved = RoutineDayActions.empty('ana', DateTime.now()).withApproval(
      'brush',
      RoutineStepMark(
        at: DateTime.now(),
        byProfileId: 'rose',
        byName: 'Rose',
        source: RoutineMarkSource.educator,
      ),
    );
    await _pump(
      tester,
      RoutineUndoMarkButton(
        childProfileId: 'ana',
        status: _status(actions: approved),
        filipino: false,
      ),
    );
    await _openAndCancel(
      tester,
      'Undo',
      title: 'Take back "mark done"?',
      bodyContains: 'goes back to not done',
    );
  });

  testWidgets('speaks Filipino to a Filipino-language educator', (tester) async {
    await _pump(
      tester,
      RoutineStepActionBar(
        childProfileId: 'ana',
        learnerName: 'Ana',
        status: _status(step: _brushEarly),
        filipino: true,
      ),
    );
    expect(find.text('Markahang tapos'), findsOneWidget);
    expect(find.text('Laktawan ngayon'), findsOneWidget);
    expect(find.text('I-unlock 30 minuto'), findsOneWidget);
  });
}
