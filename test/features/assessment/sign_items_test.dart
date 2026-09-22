import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/haptic_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_test_screen.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';
import 'package:pwdpwdpwd/features/experiment/models/experiment_models.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/experiment_provider.dart';

/// "Watch the sign, pick the word" as an assessment item.
///
/// For a Deaf learner the instrument was entirely text multiple-choice, so a
/// pre-test measured their reading rather than the signing the app spends its
/// whole FSL half teaching. A third of the items are now the thing itself.
///
/// The clip builder is injected, so nothing here reaches for the video plugin
/// that no test binding provides.

class _StubProfileNotifier extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'learner-1',
    name: 'Learner',
    role: UserRole.student,
    createdAt: DateTime(2026),
    disabilityType: DisabilityType.hearing,
  );
}

class _FakeResults extends StateNotifier<List<AssessmentResult>>
    implements AssessmentResultsNotifier {
  _FakeResults() : super([]);

  @override
  String get profileId => 'learner-1';

  @override
  AssessmentCloudService get cloud => const AssessmentCloudService();

  @override
  void Function()? get onUploadMissed => null;

  @override
  Future<void> saveResult(AssessmentResult result) async {
    state = [...state, result];
  }

  @override
  void refresh() {}

  @override
  List<AssessmentResult> getByType(AssessmentType type) =>
      state.where((r) => r.type == type).toList();

  @override
  AssessmentResult? get latestPreTest => null;

  @override
  AssessmentResult? get latestPostTest => null;

  @override
  LearningGainReport? get learningGainReport => null;

  @override
  bool get hasPreTest => false;

  @override
  bool get hasPostTest => false;
}

void main() {
  Flashcard card(String id, String english) => Flashcard(
    id: id,
    wordEnglish: english,
    wordFilipino: '$english-fil',
    category: FlashcardCategory.animals,
  );

  final signCards = [
    card('c1', 'Dog'),
    card('c2', 'Cat'),
    card('c3', 'Bird'),
    card('c4', 'Fish'),
    card('c5', 'Cow'),
    card('c6', 'Pig'),
  ];

  List<AssessmentQuestion> readingItems(int count) => [
    for (var i = 0; i < count; i++)
      AssessmentQuestion(
        id: 'q$i',
        questionText: 'Question $i',
        correctAnswer: 'Aso',
        choices: const ['Aso', 'Pusa', 'Ibon', 'Isda'],
        category: FlashcardCategory.animals,
      ),
  ];

  // ─── Building one item ───────────────────────────────────

  group('a sign item', () {
    test('asks for the word and keeps the clip on the card id', () {
      final q = AssessmentService.buildSignQuestion(
        signCards.first,
        signCards,
        Random(1),
      );
      expect(q.format, QuestionFormat.signVideo);
      expect(q.signCardId, 'c1');
      expect(q.correctAnswer, 'Dog');
      expect(q.choices, contains('Dog'));
      expect(q.choices, hasLength(4));
    });

    test('never offers the answer twice', () {
      final q = AssessmentService.buildSignQuestion(
        signCards.first,
        [...signCards, card('dupe', 'Dog')],
        Random(2),
      );
      expect(q.choices.where((c) => c == 'Dog'), hasLength(1));
    });

    test('its id cannot collide with the reading item about the same word', () {
      // Item analysis averages by question id. A sign item and a reading item
      // about "Dog" measure different things and must not be pooled.
      final sign = AssessmentService.buildSignQuestion(
        signCards.first,
        signCards,
        Random(3),
      );
      expect(sign.id, 'sign_c1');
      expect(sign.id, isNot('q_c1'));
    });

    test('distractors come from the same category when it has enough', () {
      // Seen on the tablet: a Days & Time sign offered Nose, Rainbow, Three
      // and Saturday. One day of the week among three unrelated words is
      // answerable without understanding the sign at all.
      final mixed = [
        const Flashcard(
          id: 'd1',
          wordEnglish: 'Saturday',
          wordFilipino: 'Sabado',
          category: FlashcardCategory.daysAndTime,
        ),
        for (final (id, word) in const [
          ('d2', 'Monday'),
          ('d3', 'Friday'),
          ('d4', 'Sunday'),
        ])
          Flashcard(
            id: id,
            wordEnglish: word,
            wordFilipino: word,
            category: FlashcardCategory.daysAndTime,
          ),
        for (final (id, word) in const [
          ('x1', 'Nose'),
          ('x2', 'Rainbow'),
          ('x3', 'Three'),
        ])
          Flashcard(
            id: id,
            wordEnglish: word,
            wordFilipino: word,
            category: FlashcardCategory.bodyParts,
          ),
      ];

      for (var seed = 0; seed < 20; seed++) {
        final q = AssessmentService.buildSignQuestion(
          mixed.first,
          mixed,
          Random(seed),
        );
        expect(
          q.choices.toSet(),
          {'Saturday', 'Monday', 'Friday', 'Sunday'},
          reason: 'seed $seed pulled a distractor from another category',
        );
      }
    });

    test('a small category is topped up rather than short of choices', () {
      final pool = [
        const Flashcard(
          id: 'd1',
          wordEnglish: 'Saturday',
          wordFilipino: 'Sabado',
          category: FlashcardCategory.daysAndTime,
        ),
        const Flashcard(
          id: 'd2',
          wordEnglish: 'Monday',
          wordFilipino: 'Lunes',
          category: FlashcardCategory.daysAndTime,
        ),
        ...signCards,
      ];
      final q = AssessmentService.buildSignQuestion(pool.first, pool, Random(1));
      expect(q.choices, hasLength(4));
      expect(q.choices, contains('Monday'), reason: 'same-category first');
    });

    test('a tiny pool still produces a usable item', () {
      final q = AssessmentService.buildSignQuestion(
        signCards.first,
        [signCards.first, signCards[1]],
        Random(4),
      );
      expect(q.choices, contains('Dog'));
      expect(q.choices.length, greaterThanOrEqualTo(2));
    });
  });

  // ─── Mixing them into an instrument ──────────────────────

  group('mixing sign items in', () {
    test('a third of the items become signs', () {
      final mixed = AssessmentService.withSignItems(
        readingItems(15),
        signCards,
        Random(5),
      );
      final signs = mixed.where(
        (q) => q.format == QuestionFormat.signVideo,
      );
      expect(signs, hasLength(5));
    });

    test('the test does not get longer for a learner who signs', () {
      // A longer paper for Deaf learners would be its own unfairness.
      final mixed = AssessmentService.withSignItems(
        readingItems(15),
        signCards,
        Random(6),
      );
      expect(mixed, hasLength(15));
    });

    test('no clips means no change at all', () {
      final original = readingItems(9);
      final mixed = AssessmentService.withSignItems(
        original,
        const [],
        Random(7),
      );
      expect(mixed, same(original));
    });

    test('fewer clips than the share asks for is not an error', () {
      final mixed = AssessmentService.withSignItems(
        readingItems(30),
        [signCards.first],
        Random(8),
      );
      expect(
        mixed.where((q) => q.format == QuestionFormat.signVideo),
        hasLength(1),
      );
      expect(mixed, hasLength(30));
    });

    test('the same clip is never used twice in one sitting', () {
      final mixed = AssessmentService.withSignItems(
        readingItems(15),
        signCards,
        Random(9),
      );
      final ids = mixed
          .where((q) => q.format == QuestionFormat.signVideo)
          .map((q) => q.signCardId)
          .toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  // ─── The post-test has to match the pre-test ─────────────

  group('the parallel form', () {
    test('a post-test keeps the pre-test’s sign items', () {
      // The whole point of the parallel form is comparing like with like. A
      // post-test that dropped the sign items would compare a signing test
      // against a reading one.
      final pre = Assessment(
        id: 'pre-1',
        title: 'Pre',
        type: AssessmentType.preTest,
        questions: AssessmentService.withSignItems(
          readingItems(6),
          signCards,
          Random(10),
        ),
        categories: const [FlashcardCategory.animals],
        createdBy: 'system',
        createdAt: DateTime(2026, 9),
      );

      final narrowed = AssessmentService.limitChoices(pre.questions, 2);
      for (final q in narrowed.where(
        (q) => q.format == QuestionFormat.signVideo,
      )) {
        expect(
          q.signCardId,
          isNotNull,
          reason: 'narrowing the choices must not drop the clip',
        );
        expect(q.choices, hasLength(2));
        expect(q.choices, contains(q.correctAnswer));
      }
    });
  });

  // ─── What the learner actually sees ──────────────────────

  group('on screen', () {
    Future<void> pump(
      WidgetTester tester,
      Assessment assessment, {
      double? clipHeight,
      bool honorTablet = false,
      Future<List<String>> Function(List<String>)? prepare,
    }) async {
      final router = GoRouter(
        initialLocation: '/take',
        routes: [
          GoRoute(
            path: '/take',
            builder: (_, _) => AssessmentTestScreen(
              assessment: assessment,
              clock: () => DateTime(2026, 9, 10, 9),
              // Every clip "on the tablet" unless a test says otherwise.
              prepareSignClips: prepare ?? (_) async => const [],
              // Stands in for the video plugin, which no test binding has.
              signClipBuilder: (context, cardId) => clipHeight == null
                  ? Text('CLIP:$cardId', key: const Key('clip'))
                  // As tall as the real clip on the tablet, which is what
                  // pushed the feedback below the fold.
                  : SizedBox(
                      key: const Key('clip'),
                      height: clipHeight,
                      child: Text('CLIP:$cardId'),
                    ),
            ),
          ),
          GoRoute(
            path: '/assessment/summary',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('SUMMARY'))),
          ),
        ],
      );

      // The Honor tablet is 1200×1920 *physical* pixels at 1.75 — about
      // 686×1097 dp. Multiplying by the ratio instead gives a 1200×1920 dp
      // screen, where everything fits and nothing ever needs to scroll.
      tester.view.physicalSize = honorTablet
          ? const Size(1200, 1920)
          : const Size(1200, 1920) * 1.75;
      tester.view.devicePixelRatio = 1.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(_StubProfileNotifier.new),
            hapticServiceProvider.overrideWithValue(
              HapticService(enabled: false),
            ),
            assessmentResultsProvider.overrideWith((ref) => _FakeResults()),
            gamificationFeatureProvider(
              GamificationFeature.stars,
            ).overrideWithValue(false),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    Assessment withTwoSignItems() => Assessment(
      id: 'sign-2',
      title: 'Signs',
      type: AssessmentType.preTest,
      questions: [
        for (final c in signCards.take(2))
          AssessmentService.buildSignQuestion(c, signCards, Random(12)),
      ],
      categories: const [FlashcardCategory.animals],
      createdBy: 'system',
      createdAt: DateTime(2026, 9),
    );

    Assessment withOneSignItem() => Assessment(
      id: 'sign-1',
      title: 'Signs',
      type: AssessmentType.preTest,
      questions: [
        AssessmentService.buildSignQuestion(
          signCards.first,
          signCards,
          Random(11),
        ),
      ],
      categories: const [FlashcardCategory.animals],
      createdBy: 'system',
      createdAt: DateTime(2026, 9),
    );

    group('before the first question', () {
      // Clips stream the first time. A learner who met a sign item with no
      // connection answered it blind, and the study counted that as not
      // knowing the sign.
      testWidgets('a missing clip stops the test before it starts', (
        tester,
      ) async {
        await pump(
          tester,
          withOneSignItem(),
          prepare: (ids) async => ids,
        );
        expect(find.text('The sign videos need the internet'), findsOneWidget);
        expect(find.textContaining('Question 1'), findsNothing);
        expect(find.text('CLIP:c1'), findsNothing);
      });

      testWidgets('trying again once online starts it', (tester) async {
        var online = false;
        await pump(
          tester,
          withOneSignItem(),
          prepare: (ids) async => online ? const [] : ids,
        );
        expect(find.text('Try again'), findsOneWidget);

        online = true;
        await tester.tap(find.text('Try again'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('CLIP:c1'), findsOneWidget);
        expect(find.textContaining('Question 1'), findsOneWidget);
      });

      testWidgets('it asks for exactly the clips the test uses', (
        tester,
      ) async {
        List<String>? asked;
        await pump(
          tester,
          withTwoSignItems(),
          prepare: (ids) async {
            asked = ids;
            return const [];
          },
        );
        expect(asked, hasLength(2));
      });
    });

    testWidgets('the clip is shown above the choices', (tester) async {
      await pump(tester, withOneSignItem());

      expect(find.text('CLIP:c1'), findsOneWidget);
      expect(find.text('Dog'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the prompt never names the word', (tester) async {
      // The clip *is* the question. A caption would be the answer.
      await pump(tester, withOneSignItem());

      expect(find.text('Watch the sign. Which word is it?'), findsOneWidget);
      // "Dog" appears exactly once — as an answer choice, not as a caption.
      expect(find.text('Dog'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('after answering, the feedback is scrolled into view', (
      tester,
    ) async {
      // On the tablet, a sign item's clip pushed "Correct! / The correct
      // answer is…" — and the fourth choice — below the fold, and nothing
      // brought it back.
      await pump(
        tester,
        withTwoSignItems(),
        clipHeight: 470,
        honorTablet: true,
      );

      await tester.tap(find.text('Dog'));
      await tester.pumpAndSettle();

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final feedback = find.textContaining('Correct');
      expect(feedback, findsWidgets);
      expect(
        tester.getRect(feedback.first).bottom,
        lessThanOrEqualTo(screen.height),
        reason: 'the feedback must be on screen, not below the fold',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the next question starts at its own top', (tester) async {
      await pump(
        tester,
        withTwoSignItems(),
        clipHeight: 470,
        honorTablet: true,
      );

      await tester.tap(find.text('Dog'));
      await tester.pumpAndSettle();
      // The scroll view that holds the question — the clip's ancestor.
      double offset() => tester
          .state<ScrollableState>(
            find
                .ancestor(
                  of: find.byKey(const Key('clip')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      final scrolled = offset();
      expect(scrolled, greaterThan(0), reason: 'answering scrolled down');

      await tester.tap(find.text('Next Question'));
      await tester.pumpAndSettle();
      expect(
        offset(),
        0,
        reason: 'the new question must not inherit the old scroll position',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the category chip is not shown on a sign item', (
      tester,
    ) async {
      // It narrows the choices to the one word in the right category, which
      // makes the item answerable without reading the sign.
      await pump(tester, withOneSignItem());

      expect(find.text(FlashcardCategory.animals.label), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a reading item still shows its category', (tester) async {
      await pump(
        tester,
        Assessment(
          id: 'plain-2',
          title: 'Plain',
          type: AssessmentType.preTest,
          questions: readingItems(1),
          categories: const [FlashcardCategory.animals],
          createdBy: 'system',
          createdAt: DateTime(2026, 9),
        ),
      );

      expect(find.text(FlashcardCategory.animals.label), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a reading item shows no clip', (tester) async {
      await pump(
        tester,
        Assessment(
          id: 'plain-1',
          title: 'Plain',
          type: AssessmentType.preTest,
          questions: readingItems(1),
          categories: const [FlashcardCategory.animals],
          createdBy: 'system',
          createdAt: DateTime(2026, 9),
        ),
      );

      expect(find.byKey(const Key('clip')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('answering a sign item is marked like any other', (
      tester,
    ) async {
      await pump(tester, withOneSignItem());

      await tester.tap(find.text('Dog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The feedback banner only appears once an answer has been graded.
      expect(find.textContaining('Correct'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
