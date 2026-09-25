import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/haptic_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_media_presentation.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_builder_screen.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_test_screen.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_cache.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';
import 'package:pwdpwdpwd/features/assessment/widgets/assessment_media_panel.dart';
import 'package:pwdpwdpwd/features/experiment/models/experiment_models.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/experiment_provider.dart';

/// Answer choices a learner taps as pictures — for a child who does not read
/// yet — authored per choice in the Assessment Builder.
///
/// Seeding only in `setUpAll`; no test writes to Hive.

class _Profile extends ProfileNotifier {
  static UserRole role = UserRole.student;
  static DisabilityType type = DisabilityType.cognitive;

  @override
  UserProfile? build() => UserProfile(
    id: role == UserRole.teacher ? 'teacher-1' : 'learner-1',
    name: 'Someone',
    role: role,
    createdAt: DateTime(2026),
    disabilityType: type,
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AssessmentQuestion _animals({Map<String, String>? pictures}) =>
    AssessmentQuestion(
      id: 'q1',
      questionText: 'Which one says meow?',
      correctAnswer: 'Cat',
      choices: const ['Cat', 'Dog', 'Bird', 'Fish'],
      category: FlashcardCategory.animals,
      choiceImages:
          pictures ??
          const {
            'Cat': 'assets/test/cat.png',
            'Dog': 'assets/test/dog.png',
            'Bird': 'assets/test/bird.png',
            'Fish': 'assets/test/fish.png',
          },
    );

void main() {
  setUpAll(() async {
    const dir = './build/test_cache/picture_choices';
    try {
      final d = Directory(dir);
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {}
    Hive.init(dir);
    for (final name in const ['progress', 'profiles', 'settings']) {
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

  setUp(() => AssessmentMediaCache.debugFetch = (_) async => null);
  tearDown(() {
    AssessmentMediaCache.debugFetch = null;
    _Profile.role = UserRole.student;
    _Profile.type = DisabilityType.cognitive;
  });

  // ─── The data ────────────────────────────────────────────

  group('the data', () {
    test('pictures survive a round trip, keyed by choice', () {
      final q = _animals();
      final back = AssessmentQuestion.fromJson(q.toJson());
      expect(back.choiceImages, q.choiceImages);
      expect(back.hasPictureChoices, isTrue);
    });

    test('a question without pictures stores no new key', () {
      final json = _animals(pictures: const {}).toJson();
      expect(json.containsKey('choiceImages'), isFalse);
    });

    test('fewer choices keeps the pictures of the choices it keeps', () {
      final narrowed = AssessmentService.limitChoices([_animals()], 2).single;
      expect(narrowed.choices, hasLength(2));
      for (final c in narrowed.choices) {
        expect(narrowed.choiceImages[c], isNotNull, reason: c);
      }
    });

    test('stored values include picked choice pictures, never links', () {
      final q = _animals(
        pictures: const {
          'Cat': 'file:///d/assessment_media/q1_choice0_photo_1.jpg',
          'Dog': 'shared://dog',
          'Bird': 'https://example.com/bird.png',
        },
      );
      expect(q.storedValues, {
        'file:///d/assessment_media/q1_choice0_photo_1.jpg',
        'shared://dog',
      });
    });

    test('a learner is held up only by pictures they will be shown', () {
      final test = Assessment(
        id: 'a',
        title: 'A',
        type: AssessmentType.custom,
        questions: [_animals()],
        createdBy: 't',
        createdAt: DateTime(2026, 9),
      );
      expect(
        AssessmentMediaCache.valuesIn(
          test,
          AssessmentMediaPresentation.forType(DisabilityType.cognitive),
        ),
        hasLength(4),
      );
      expect(
        AssessmentMediaCache.valuesIn(
          test,
          AssessmentMediaPresentation.forType(DisabilityType.visual),
        ),
        isEmpty,
        reason: 'a learner with low vision gets the words instead',
      );
    });
  });

  // ─── Taking the test ─────────────────────────────────────

  Future<void> pumpTest(
    WidgetTester tester,
    AssessmentQuestion question, {
    Size size = const Size(1200, 2600),
    double textScale = 1,
  }) async {
    final router = GoRouter(
      initialLocation: '/take',
      routes: [
        GoRoute(
          path: '/take',
          builder: (_, _) => AssessmentTestScreen(
            assessment: Assessment(
              id: 'pictures',
              title: 'Pictures',
              type: AssessmentType.custom,
              questions: [question],
              createdBy: 'teacher-1',
              createdAt: DateTime(2026, 9),
            ),
            clock: () => DateTime(2026, 9, 26, 9),
            prepareSignClips: (_) async => const [],
            prepareMedia: (_) async => const [],
          ),
        ),
        GoRoute(
          path: '/assessment/summary',
          builder: (_, _) => const Scaffold(body: Text('SUMMARY')),
        ),
      ],
    );
    tester.view.physicalSize = size * 1.75;
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(_Profile.new),
          hapticServiceProvider.overrideWithValue(HapticService(enabled: false)),
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('taking the test', () {
    testWidgets('a learner who does not read yet taps a picture', (
      tester,
    ) async {
      _Profile.type = DisabilityType.cognitive;
      await pumpTest(tester, _animals());
      expect(find.byType(AssessmentPicture), findsNWidgets(4));

      await tester.tap(find.text('Cat'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Correct!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a wrong picture is marked, and the right one shown', (
      tester,
    ) async {
      _Profile.type = DisabilityType.hearing;
      await pumpTest(tester, _animals());
      await tester.tap(find.text('Dog'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a learner with low vision gets the words, not pictures', (
      tester,
    ) async {
      _Profile.type = DisabilityType.visual;
      await pumpTest(tester, _animals());
      expect(find.byType(AssessmentPicture), findsNothing);
      expect(find.text('Cat'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('at 2.0x text on a 360×640 phone the grid fits', (
      tester,
    ) async {
      _Profile.type = DisabilityType.cognitive;
      await pumpTest(
        tester,
        _animals(),
        size: const Size(360, 640),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AssessmentPicture), findsNWidgets(4));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  // ─── Authoring ───────────────────────────────────────────

  group('authoring', () {
    Future<void> openQuestionSheet(WidgetTester tester) async {
      _Profile.role = UserRole.teacher;
      tester.view.physicalSize = const Size(1200, 2600) * 1.75;
      tester.view.devicePixelRatio = 1.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [profileProvider.overrideWith(_Profile.new)],
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AssessmentBuilderScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Add First Question'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> unmount(WidgetTester tester) async {
      // The empty state animates for ever; step the clock before leaving.
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('each multiple-choice answer can have a picture', (
      tester,
    ) async {
      await openQuestionSheet(tester);
      for (final letter in ['A', 'B', 'C', 'D']) {
        expect(
          find.byTooltip('Add a picture to choice $letter'),
          findsOneWidget,
        );
      }
      expect(find.textContaining('Learners who don’t read yet'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('true-or-false has no picture buttons', (tester) async {
      await openQuestionSheet(tester);
      await tester.tap(find.text('True or False'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('Add a picture to choice A'), findsNothing);
      await unmount(tester);
    });
  });
}
