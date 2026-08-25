import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/models/custom_quiz_models.dart';
import 'package:pwdpwdpwd/features/assessment/screens/quiz_builder_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Two quizzes may not share a name.
///
/// The title is how a teacher finds a quiz again in Assign Tasks, and saving
/// resets the field back to "My Quiz" — which is exactly how a duplicate got
/// made by accident during device testing, leaving two identical rows.
///
/// Refused rather than silently renamed: quietly changing what somebody typed
/// is worse in a tool where the name is the handle.
///
/// `testWidgets` only; the save path is blocked before it writes.

class _StubProfileNotifier extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'educator-1',
    name: 'Educator',
    role: UserRole.teacher,
    createdAt: DateTime(2026),
  );
}

void main() {
  const educatorId = 'educator-1';

  setUpAll(() async {
    const cacheDir = './build/test_cache/quiz_duplicate_title';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Still locked by a stray flutter_tester — Hive reports it below.
    }
    Hive.init(cacheDir);
    for (final name in const [
      'profiles',
      'progress',
      'settings',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    final box = Hive.box('progress');
    await box.clear();
    await box.put('custom_quizzes_$educatorId', [
      CustomQuiz(
        id: 'q1',
        title: 'Farm Words',
        flashcardIds: const ['c0', 'c1', 'c2'],
        questionFormats: const [QuestionFormat.multipleChoice],
        createdBy: educatorId,
        createdAt: DateTime(2026, 8),
      ).toJson(),
    ]);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  Future<void> pumpBuilder(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileProvider.overrideWith(_StubProfileNotifier.new)],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QuizBuilderScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the existing quiz is listed', (tester) async {
    await pumpBuilder(tester);

    expect(find.text('Farm Words'), findsWidgets);
  });

  testWidgets('saving a clashing title is refused, and says why', (
    tester,
  ) async {
    await pumpBuilder(tester);

    await tester.enterText(find.byType(TextField).first, 'Farm Words');
    await tester.pump();

    // Pick enough cards for Save to be reachable at all.
    final checkboxes = find.byType(CheckboxListTile);
    if (checkboxes.evaluate().length >= 3) {
      for (var i = 0; i < 3; i++) {
        await tester.tap(checkboxes.at(i), warnIfMissed: false);
        await tester.pump();
      }
    }

    await tester.tap(find.text('Save'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('already have a quiz called'),
      findsOneWidget,
      reason: 'the teacher needs to know the name is taken, not be guessed at',
    );

    // Still exactly one quiz with that name.
    final stored = Hive.box('progress').get('custom_quizzes_$educatorId')
        as List;
    expect(stored, hasLength(1));
  });

  testWidgets('the comparison ignores case', (tester) async {
    await pumpBuilder(tester);

    await tester.enterText(find.byType(TextField).first, 'farm words');
    await tester.pump();

    final checkboxes = find.byType(CheckboxListTile);
    if (checkboxes.evaluate().length >= 3) {
      for (var i = 0; i < 3; i++) {
        await tester.tap(checkboxes.at(i), warnIfMissed: false);
        await tester.pump();
      }
    }

    await tester.tap(find.text('Save'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('already have a quiz called'),
      findsOneWidget,
      reason: '"farm words" and "Farm Words" are the same name to a person',
    );
  });
}
