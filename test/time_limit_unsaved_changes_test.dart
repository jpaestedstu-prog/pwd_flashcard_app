import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/parent/screens/child_time_limits_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/child_time_limit_provider.dart';
import 'package:pwdpwdpwd/providers/lock_announcement_provider.dart';
import 'package:pwdpwdpwd/providers/managed_child_profile_provider.dart';

import 'support/lock_test_doubles.dart';

/// Leaving the time-limit editor with unsaved changes.
///
/// Until 1.4.1, Back from the editor dropped whatever the educator had
/// changed without a word: a teacher who turned the daily limit on and went
/// back believed it was set, and the child's tablet never locked. Now the
/// editor asks: save, leave without saving, or keep editing.

final _child = UserProfile(
  id: 'child-1',
  name: 'Test Learner',
  role: UserRole.child,
  disabilityType: DisabilityType.motor,
  createdAt: DateTime(2026),
);

final _parent = UserProfile(
  id: 'parent-1',
  name: 'Test Parent',
  role: UserRole.parent,
  createdAt: DateTime(2026),
);

/// The roster (`/`) with the editor pushed on top, as the app opens it.
Future<void> _openEditor(WidgetTester tester) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => const Scaffold(body: Text('Roster')),
      ),
      GoRoute(
        path: '/edit',
        builder: (context, _) => ChildTimeLimitsScreen(
          childProfileId: _child.id,
          childDisplayName: _child.name,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => FixedProfile(_parent)),
        settingsProvider.overrideWith(() => FixedSettings(const AppSettings())),
        lockAnnouncerProvider.overrideWithValue(RecordingAnnouncer()),
        managedChildProfileProvider(_child.id).overrideWith(
          (ref) async => _child,
        ),
        childTimeLimitProvider(_child.id).overrideWith(
          (ref) => Stream.value(null),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  router.push('/edit');
  await tester.pumpAndSettle();
  expect(find.text('Time limits — Test Learner'), findsOneWidget);
}

/// Changes something: turns the daily limit on.
Future<void> _change(WidgetTester tester) async {
  await tester.tap(find.text('Enforce a daily limit'));
  await tester.pump();
  expect(find.text('Save'), findsOneWidget, reason: 'the draft is dirty');
}

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Go back'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with nothing changed, Back just leaves', (tester) async {
    await _openEditor(tester);
    await _tapBack(tester);
    expect(find.text('Save your changes?'), findsNothing);
    expect(find.text('Roster'), findsOneWidget);
  });

  testWidgets('with a change, Back asks first', (tester) async {
    await _openEditor(tester);
    await _change(tester);
    await _tapBack(tester);

    expect(find.text('Save your changes?'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.text('Leave without saving'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Save')),
      findsOneWidget,
    );
  });

  testWidgets('"Keep editing" stays, with the change still there',
      (tester) async {
    await _openEditor(tester);
    await _change(tester);
    await _tapBack(tester);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('Save your changes?'), findsNothing);
    expect(find.text('Roster'), findsNothing);
    expect(find.text('Save'), findsOneWidget, reason: 'still unsaved');
  });

  testWidgets('"Leave without saving" leaves', (tester) async {
    await _openEditor(tester);
    await _change(tester);
    await _tapBack(tester);
    await tester.tap(find.text('Leave without saving'));
    await tester.pumpAndSettle();

    expect(find.text('Roster'), findsOneWidget);
  });

  testWidgets('the Android Back gesture asks too', (tester) async {
    await _openEditor(tester);
    await _change(tester);
    // What the system Back button sends.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Save your changes?'), findsOneWidget);
    await tester.tap(find.text('Leave without saving'));
    await tester.pumpAndSettle();
    expect(find.text('Roster'), findsOneWidget);
  });

  testWidgets('a save that fails keeps the editor and the change',
      (tester) async {
    // No local store and no cloud in a widget test, so the save throws:
    // the educator is told, and nothing they changed is thrown away.
    await _openEditor(tester);
    await _change(tester);
    await _tapBack(tester);
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Save')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Roster'), findsNothing);
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget, reason: 'still unsaved');
  });

  test('the dialog has its Filipino words', () {
    final fil = lookupAppLocalizations(const Locale('fil'));
    expect(fil.tlUnsavedTitle, 'I-save ang mga pagbabago?');
    expect(fil.tlUnsavedBody, contains('mawawala ang mga pagbabago'));
    expect(fil.tlLeaveWithoutSaving, 'Umalis nang hindi nagse-save');
    expect(fil.tlKeepEditing, 'Ituloy ang pag-edit');
    expect(fil.tlSave, 'I-save');
  });
}
