import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_copy_sheet.dart';

/// "Copy to other learners" — the picker.
///
/// The picker only chooses; it returns ids and writes nothing, so every path
/// through it can be exercised here without a Hive write in the widget-test
/// zone. What a copy contains is covered by `routine_copy_test.dart`.

final _morning = Routine(
  id: 'ana-morning',
  childProfileId: 'ana',
  setterProfileId: 'rose',
  setterRole: UserRole.teacher,
  name: 'Morning Routine',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _targets = [
  RoutineCopyTarget(
    profileId: 'ben',
    name: 'Ben',
    avatarEmoji: '🦊',
    groupName: 'Hearing Class',
  ),
  RoutineCopyTarget(
    profileId: 'cy',
    name: 'Cy',
    avatarEmoji: '🐼',
    groupName: 'Hearing Class',
    routineNames: {'morning routine'},
  ),
  RoutineCopyTarget(profileId: 'dee', name: 'Dee', groupName: 'Motor Class'),
];

/// Opens the sheet from a button and records what it returned.
Future<List<Set<String>?>> _open(
  WidgetTester tester, {
  List<RoutineCopyTarget> targets = _targets,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final results = <Set<String>?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                results.add(await showModalBottomSheet<Set<String>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => RoutineCopySheet(
                    routine: _morning,
                    targets: targets,
                    filipino: false,
                  ),
                ));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('lists learners under their class, and says what copying does',
      (tester) async {
    await _open(tester);
    expect(find.text('Copy “Morning Routine”'), findsOneWidget);
    expect(find.textContaining('Each learner gets their own copy'), findsOneWidget);
    expect(find.text('Hearing Class'), findsOneWidget);
    expect(find.text('Motor Class'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    expect(find.text('Dee'), findsOneWidget);
  });

  testWidgets('warns about a learner who already has a routine by that name',
      (tester) async {
    await _open(tester);
    expect(
      find.text('Already has a routine called “Morning Routine”'),
      findsOneWidget,
    );
  });

  testWidgets('nothing chosen, nothing to copy', (tester) async {
    await _open(tester);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Choose learners'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('select all takes a whole class, and copy returns the picks',
      (tester) async {
    final results = await _open(tester);
    await tester.tap(find.text('Select all').first);
    await tester.pump();
    expect(find.text('Copy to 2 learners'), findsOneWidget);

    await tester.tap(find.text('Dee'));
    await tester.pump();
    expect(find.text('Copy to 3 learners'), findsOneWidget);

    await tester.tap(find.text('Copy to 3 learners'));
    await tester.pumpAndSettle();
    expect(results.single, {'ben', 'cy', 'dee'});
  });

  testWidgets('a whole selected class can be cleared again', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Select all').first);
    await tester.pump();
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('Choose learners'), findsOneWidget);
  });

  testWidgets('an educator with nobody else to copy to is told so',
      (tester) async {
    await _open(tester, targets: const []);
    expect(find.text('There are no other learners to copy to yet.'),
        findsOneWidget);
  });
}
