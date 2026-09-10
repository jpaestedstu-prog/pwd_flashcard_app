import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/widgets/educator_routine_section.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';

import 'support/routine_test_doubles.dart';

/// "Today's Routines" — the Routine surface on the Teacher and Parent
/// dashboards.
///
/// One widget for both roles (see the educator-parity rule), so these tests
/// run the same tree twice with only the learner noun changed.

const _ana = EducatorRoutineLearner(
  profileId: 'learner-ana',
  name: 'Ana',
  avatarEmoji: '🐣',
  accessibility: DisabilityType.cognitive,
);

const _ben = EducatorRoutineLearner(
  profileId: 'learner-ben',
  name: 'Ben',
  avatarEmoji: '🦊',
  accessibility: DisabilityType.hearing,
);

/// Records where a tap navigated, without a real router stack.
class _RouteSpy {
  String? pushed;
}

Widget _app({
  required List<EducatorRoutineLearner> learners,
  required String learnerNoun,
  required String learnerNounPlural,
  required Map<String, List<Routine>> routines,
  Map<String, Set<String>> completed = const {},
  required _RouteSpy spy,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: EducatorRoutineSection(
              learners: learners,
              learnerNounPlural: learnerNounPlural,
              learnerNoun: learnerNoun,
              filipino: false,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/routine-manage/:profileId',
        builder: (context, state) {
          spy.pushed = state.uri.toString();
          return const Scaffold(body: Text('routine manager'));
        },
      ),
    ],
  );

  final today = DateTime.now();
  return ProviderScope(
    overrides: [
      for (final entry in routines.entries)
        routineListProvider(entry.key).overrideWith(
          (ref) => Stream.value(entry.value),
        ),
      for (final learner in learners)
        routineDayLogProvider(routineDayKey(learner.profileId, today))
            .overrideWith(
          (ref) => Stream.value(
            RoutineDayLog(
              profileId: learner.profileId,
              day: DateTime(today.year, today.month, today.day),
              completedStepIds: completed[learner.profileId] ?? const {},
              updatedAt: DateTime(2026, 9),
            ),
          ),
        ),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Future<void> _settle(
  WidgetTester tester, [
  Duration total = const Duration(milliseconds: 600),
]) async {
  const step = Duration(milliseconds: 100);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./build/test_cache/routine_educator_section');
    for (final name in const ['profiles', 'settings']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (t, d) => false);
      }
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  testWidgets('lists every learner, with or without a routine',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final spy = _RouteSpy();
    await tester.pumpWidget(_app(
      learners: const [_ana, _ben],
      learnerNoun: 'student',
      learnerNounPlural: 'students',
      routines: {
        'learner-ana': [
          buildTestRoutine().copyWith(childProfileId: 'learner-ana'),
        ],
        // Ben has none — the row is still there, because that row is how the
        // first routine ever gets built.
        'learner-ben': const [],
      },
      completed: const {
        'learner-ana': {'step-wake'},
      },
      spy: spy,
    ));
    await _settle(tester);

    expect(find.text("Today's Routines"), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('1 of 4 done'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    expect(find.text('No routine yet — set one up'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a learner opens their routine manager with the '
      'audience wording and their accessibility category', (tester) async {
    tester.view.physicalSize = const Size(900, 1400) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final spy = _RouteSpy();
    await tester.pumpWidget(_app(
      learners: const [_ben],
      learnerNoun: 'child',
      learnerNounPlural: 'children',
      routines: const {'learner-ben': []},
      spy: spy,
    ));
    await _settle(tester);

    await tester.tap(find.text('Ben'));
    await _settle(tester);

    expect(spy.pushed, isNotNull);
    // Everything the manager needs is in the URL, so a deep link or a
    // process death can reconstruct the screen.
    expect(spy.pushed, contains('/routine-manage/learner-ben'));
    expect(spy.pushed, contains('name=Ben'));
    expect(spy.pushed, contains('noun=child'));
    expect(
      spy.pushed,
      contains('access=${DisabilityType.hearing.index}'),
      reason: "the learner's own category must reach the manager, not the "
          "educator's",
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('an empty roster draws nothing at all', (tester) async {
    final spy = _RouteSpy();
    await tester.pumpWidget(_app(
      learners: const [],
      learnerNoun: 'student',
      learnerNounPlural: 'students',
      routines: const {},
      spy: spy,
    ));
    await _settle(tester);
    expect(find.text("Today's Routines"), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
