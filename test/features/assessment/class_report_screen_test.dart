import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/screens/class_report_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/student_list_provider.dart';

import '../../support/device_matrix.dart';

/// The educator's whole-class read: gain by accessibility category, the
/// hardest items, and who retook which half.
///
/// `testWidgets` only in this file — seeding happens once in `setUpAll`,
/// outside the fake-async zone, so no awaited `box.put` can poison the write
/// queue. (See retake_policy_test.dart for the persistence half.)

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role);
  final UserRole _role;

  @override
  UserProfile? build() => UserProfile(
    id: 'educator-1',
    name: 'Teacher',
    role: _role,
    createdAt: DateTime(2026),
  );
}

void main() {
  /// Two learners in different categories, each with a finished pair, plus a
  /// third who has only sat the pre-test.
  Map<String, dynamic> resultJson({
    required String id,
    required String learner,
    required AssessmentType type,
    required int score,
    required Map<String, bool> answers,
    required DateTime at,
  }) => AssessmentResult(
    id: id,
    assessmentId: 'a1',
    profileId: learner,
    type: type,
    score: score,
    totalQuestions: answers.length,
    answers: [
      for (final e in answers.entries)
        QuestionAnswer(
          questionId: e.key,
          givenAnswer: e.value ? 'Aso' : 'Pusa',
          isCorrect: e.value,
          responseTimeMs: 2000,
        ),
    ],
    completedAt: at,
    durationSeconds: 90,
  ).toJson();

  setUpAll(() async {
    const cacheDir = './build/test_cache/class_report';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Still locked by a stray process — Hive reports it plainly below.
    }
    Hive.init(cacheDir);
    for (final name in const ['profiles', 'progress', 'settings']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    final progress = Hive.box('progress');
    await progress.clear();

    await Hive.box('profiles').put('profiles', [
      for (final (id, name, type) in const [
        ('deaf-1', 'Deaf Learner', DisabilityType.hearing),
        ('blind-1', 'Blind Learner', DisabilityType.visual),
        ('pending-1', 'Half Done Learner', DisabilityType.hearing),
      ])
        {
          'id': id,
          'name': name,
          'role': UserRole.student.index,
          'avatarIndex': 0,
          'createdAt': DateTime(2026).toIso8601String(),
          'disabilityType': type.index,
        },
    ]);

    // Deaf learner: 1/3 → 3/3. Blind learner: 2/3 → 3/3.
    // "q_hard" is failed by everyone on the pre-test, so it tops the item list.
    await progress.put('assessment_results_deaf-1', [
      resultJson(
        id: 'r1',
        learner: 'deaf-1',
        type: AssessmentType.preTest,
        score: 1,
        answers: {'q_easy': true, 'q_mid': false, 'q_hard': false},
        at: DateTime(2026, 9, 4),
      ),
      resultJson(
        id: 'r2',
        learner: 'deaf-1',
        type: AssessmentType.postTest,
        score: 3,
        answers: {'q_easy': true, 'q_mid': true, 'q_hard': true},
        at: DateTime(2026, 9, 20),
      ),
    ]);
    await progress.put('assessment_results_blind-1', [
      resultJson(
        id: 'r3',
        learner: 'blind-1',
        type: AssessmentType.preTest,
        score: 2,
        answers: {'q_easy': true, 'q_mid': true, 'q_hard': false},
        at: DateTime(2026, 9, 2),
      ),
      resultJson(
        id: 'r4',
        learner: 'blind-1',
        type: AssessmentType.postTest,
        score: 3,
        answers: {'q_easy': true, 'q_mid': true, 'q_hard': true},
        at: DateTime(2026, 9, 21),
      ),
    ]);
    // Two pre-test sittings, so the attempts row has something to report.
    await progress.put('assessment_results_pending-1', [
      resultJson(
        id: 'r5',
        learner: 'pending-1',
        type: AssessmentType.preTest,
        score: 1,
        answers: {'q_easy': true, 'q_mid': false, 'q_hard': false},
        at: DateTime(2026, 9, 3),
      ),
      resultJson(
        id: 'r6',
        learner: 'pending-1',
        type: AssessmentType.preTest,
        score: 2,
        answers: {'q_easy': true, 'q_mid': true, 'q_hard': false},
        at: DateTime(2026, 9, 12),
      ),
    ]);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  Future<String?> pumpReport(
    WidgetTester tester,
    UserRole role, {
    Size? device,
    double dpr = 1.75,
    double textScale = 1.0,
    List<Override> overrides = const [],
    Locale locale = const Locale('en'),
  }) async {
    String? landed;
    final router = GoRouter(
      initialLocation: '/assessment/class-report',
      routes: [
        GoRoute(
          path: '/assessment/class-report',
          builder: (_, _) => const ClassReportScreen(),
        ),
        GoRoute(
          path: '/assessment/assign',
          builder: (_, state) {
            landed = state.uri.path;
            return const Scaffold(body: Center(child: Text('LANDED')));
          },
        ),
      ],
    );

    tester.view.physicalSize = (device ?? const Size(1200, 1920)) * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(() => _StubProfileNotifier(role)),
          ...overrides,
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return landed;
  }

  // ─── Who it is for ───────────────────────────────────────

  testWidgets('a learner is turned away, not shown the class', (tester) async {
    await pumpReport(tester, UserRole.student);

    expect(find.text('For teachers and parents'), findsOneWidget);
    expect(find.textContaining('Learning gain by accessibility'), findsNothing);
  });

  for (final role in const [UserRole.teacher, UserRole.parent]) {
    testWidgets('a ${role.name} sees all three sections', (tester) async {
      await pumpReport(tester, role);

      expect(
        find.textContaining('Learning gain by accessibility'),
        findsOneWidget,
      );
      expect(find.textContaining('Hardest items'), findsOneWidget);
      expect(find.textContaining('🔁 Attempts'), findsOneWidget);
    });
  }

  // ─── What it says ────────────────────────────────────────

  testWidgets('each accessibility category is averaged on its own', (
    tester,
  ) async {
    await pumpReport(tester, UserRole.teacher);

    // Deaf: 33% → 100%, a +67 gain. Blind: 67% → 100%, +33.
    expect(find.text('Hearing Impairment'), findsOneWidget);
    expect(find.text('Visual Impairment'), findsOneWidget);
    expect(find.text('Gain +67%'), findsOneWidget);
    expect(find.text('Gain +33%'), findsOneWidget);
  });

  testWidgets('a learner with only one half is counted, not averaged in', (
    tester,
  ) async {
    await pumpReport(tester, UserRole.teacher);

    // The half-done learner is in the hearing category, whose mean is still
    // over the one learner who finished.
    expect(find.text('Measured 1'), findsWidgets);
    expect(find.text('Still waiting 1'), findsOneWidget);
  });

  testWidgets('one learner measured is read out in the singular', (
    tester,
  ) async {
    // Seen on the Honor: TalkBack read "1 learners measured".
    await pumpReport(tester, UserRole.teacher);

    final labels = [
      for (final w in tester.widgetList<Semantics>(find.byType(Semantics)))
        if (w.properties.label case final l? when l.contains('measured')) l,
    ];
    expect(
      labels,
      contains(startsWith('Hearing Impairment. 1 learner measured.')),
    );
    expect(labels, everyElement(isNot(contains('1 learners'))));
  });

  testWidgets('the hardest item is listed first', (tester) async {
    await pumpReport(tester, UserRole.teacher);

    final hard = tester.getTopLeft(find.text('q_hard'));
    final easy = tester.getTopLeft(find.text('q_easy'));
    expect(
      hard.dy,
      lessThan(easy.dy),
      reason: 'an educator reads this list to find what to teach next',
    );
  });

  testWidgets('the distractor doing the damage is named', (tester) async {
    await pumpReport(tester, UserRole.teacher);

    expect(find.textContaining('Often answered Pusa'), findsWidgets);
  });

  testWidgets('a learner who retook a half shows both sittings', (
    tester,
  ) async {
    await pumpReport(tester, UserRole.teacher);

    // Newest counts (67%), with the earlier attempt acknowledged.
    expect(find.text('Pre 67% (+1 earlier)'), findsOneWidget);
  });

  testWidgets('an educator with no learners is pointed at assigning work', (
    tester,
  ) async {
    // The roster is overridden rather than emptied in Hive: an awaited
    // `box.put` from inside a `testWidgets` fake-async zone poisons the box's
    // write queue and hangs the whole file at teardown.
    await pumpReport(
      tester,
      UserRole.teacher,
      overrides: [educatorLearnerRosterProvider.overrideWithValue(const [])],
    );

    expect(find.text('No learners yet'), findsOneWidget);
    await tester.tap(find.text('Assign work'));
    await tester.pumpAndSettle();
    expect(find.text('LANDED'), findsOneWidget);
  });

  // ─── In Filipino ─────────────────────────────────────────

  group('in Filipino', () {
    testWidgets('every section heading is translated', (tester) async {
      await pumpReport(tester, UserRole.teacher, locale: const Locale('fil'));

      expect(find.text('Ulat ng Klase'), findsOneWidget);
      expect(find.textContaining('Pag-unlad ayon sa accessibility'), findsOne);
      expect(find.textContaining('Pinakamahihirap na tanong'), findsOneWidget);
      expect(find.textContaining('Mga Pagsubok'), findsOneWidget);

      // …and none of the English ones survive alongside them.
      expect(find.textContaining('Learning gain by accessibility'), findsNothing);
      expect(find.textContaining('Hardest items'), findsNothing);
    });

    testWidgets('the numbers read in Filipino too', (tester) async {
      await pumpReport(tester, UserRole.teacher, locale: const Locale('fil'));

      expect(find.text('Pag-unlad +67%'), findsOneWidget);
      expect(find.text('Naghihintay pa 1'), findsOneWidget);
      expect(find.text('Panimula 67% (+1 nauna)'), findsOneWidget);
      expect(find.textContaining('Madalas na sagot Pusa'), findsWidgets);
    });

    testWidgets('the accessibility categories use their Filipino names', (
      tester,
    ) async {
      await pumpReport(tester, UserRole.teacher, locale: const Locale('fil'));

      expect(find.text('Hearing Impairment'), findsNothing);
      expect(find.text('Visual Impairment'), findsNothing);
    });

    testWidgets('a learner is turned away in Filipino', (tester) async {
      await pumpReport(tester, UserRole.student, locale: const Locale('fil'));

      expect(find.text('Para sa mga guro at magulang'), findsOneWidget);
    });
  });

  // ─── Layout ──────────────────────────────────────────────

  // Every row here is a Wrap of metric chips beside a long prompt — the shape
  // that bursts on a narrow screen at a large font.
  for (final device in kTabletMatrix) {
    for (final scale in kTextScales) {
      testWidgets('the report lays out at ${device.label}, ${scale}x text', (
        tester,
      ) async {
        // Both languages: the Filipino strings run noticeably longer, and
        // longer is where a narrow phone at 2.0x gives out.
        for (final locale in const [Locale('en'), Locale('fil')]) {
          await pumpReport(
            tester,
            UserRole.teacher,
            device: device.size,
            dpr: device.devicePixelRatio,
            textScale: scale,
            locale: locale,
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
            reason:
                'class report (${locale.languageCode}) at ${device.label} '
                '${scale}x: $firstError',
          );
        }
      });
    }
  }
}
