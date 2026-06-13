import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/local/spaced_repetition_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/models/tutor_models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_engine.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_memory_service.dart';

/// In-memory Hive setup (tutor memory + SR services share the `progress` box).
Future<void> _initHive() async {
  Hive.init('./build/test_cache/ai_tutor_interests');
  if (!Hive.isBoxOpen('progress')) {
    await Hive.openBox('progress');
  }
}

LearningProgress _emptyProgress(String profileId) => LearningProgress(
      profileId: profileId,
      lastActivityDate: DateTime.now(),
    );

void main() {
  setUpAll(_initHive);

  setUp(() async {
    await Hive.box('progress').clear();
  });

  group('interest persistence', () {
    test('round-trips favorites and implicit scores', () async {
      final memory = TutorMemory(
        favoriteCategories: [
          FlashcardCategory.animals.name,
          FlashcardCategory.weather.name,
        ],
        interestScores: {
          FlashcardCategory.animals.name: 4.0,
          FlashcardCategory.numbers.name: 1.5,
        },
      );
      await TutorMemoryService.saveMemory('p1', memory);
      final loaded = TutorMemoryService.getMemory('p1');

      expect(loaded.favoriteCategories,
          [FlashcardCategory.animals.name, FlashcardCategory.weather.name]);
      expect(loaded.interestScores[FlashcardCategory.animals.name], 4.0);
      expect(loaded.interestScores[FlashcardCategory.numbers.name], 1.5);
    });

    test('legacy records without interest fields load with empty defaults',
        () async {
      // Simulates memory written by the pre-interests app version.
      await Hive.box('progress').put('tutor_legacy', {
        'messages': [],
        'stats': const TutorStats(questionsAsked: 5).toJson(),
        'planWordIds': ['w1'],
      });
      final loaded = TutorMemoryService.getMemory('legacy');
      expect(loaded.favoriteCategories, isEmpty);
      expect(loaded.interestScores, isEmpty);
      expect(loaded.stats.questionsAsked, 5);
    });
  });

  group('topInterests + bumpInterest', () {
    test('explicit favorites outrank implicit scores and order is kept', () {
      final memory = TutorMemory(
        favoriteCategories: [
          FlashcardCategory.weather.name,
          FlashcardCategory.animals.name,
        ],
        interestScores: {
          // Strong implicit signal, but explicit picks still come first.
          FlashcardCategory.numbers.name: 10.0,
        },
      );
      expect(TutorEngine.topInterests(memory), [
        FlashcardCategory.weather,
        FlashcardCategory.animals,
        FlashcardCategory.numbers,
      ]);
    });

    test('implicit categories need the threshold and sort by strength', () {
      final memory = TutorMemory(interestScores: {
        FlashcardCategory.clothing.name: 1.0, // below threshold → ignored
        FlashcardCategory.emotions.name: 3.0,
        FlashcardCategory.classroom.name: 5.0,
      });
      expect(TutorEngine.topInterests(memory), [
        FlashcardCategory.classroom,
        FlashcardCategory.emotions,
      ]);
    });

    test('caps at maxFavorites and deduplicates', () {
      final memory = TutorMemory(
        favoriteCategories: [
          FlashcardCategory.animals.name,
          FlashcardCategory.weather.name,
          FlashcardCategory.numbers.name,
        ],
        interestScores: {
          FlashcardCategory.animals.name: 9.0, // dup of explicit pick
          FlashcardCategory.clothing.name: 9.0, // beyond the cap
        },
      );
      final top = TutorEngine.topInterests(memory);
      expect(top.length, TutorEngine.maxFavorites);
      expect(top.toSet().length, top.length);
    });

    test('bumpInterest accumulates and clamps at the ceiling', () {
      var scores = const <String, double>{};
      scores = TutorEngine.bumpInterest(
          scores, FlashcardCategory.animals, TutorEngine.signalAsk);
      scores = TutorEngine.bumpInterest(
          scores, FlashcardCategory.animals, TutorEngine.signalPick);
      expect(scores[FlashcardCategory.animals.name],
          TutorEngine.signalAsk + TutorEngine.signalPick);

      scores = TutorEngine.bumpInterest(
          scores, FlashcardCategory.animals, 999);
      expect(scores[FlashcardCategory.animals.name],
          TutorEngine.maxInterestScore);
    });
  });

  group('categoryInText', () {
    test('finds English and Filipino category mentions', () {
      expect(TutorEngine.categoryInText('I like animals!'),
          FlashcardCategory.animals);
      expect(TutorEngine.categoryInText('gusto ko ang mga hayop'),
          FlashcardCategory.animals);
      expect(TutorEngine.categoryInText('help with transportation please'),
          FlashcardCategory.transportation);
      expect(TutorEngine.categoryInText('give me a quiz'), isNull);
    });
  });

  group('respondToQuestion interest flows', () {
    test('"I like animals" returns a confirmation carrying the pick', () {
      final msg = TutorEngine.respondToQuestion(
          'I like animals!', _emptyProgress('u1'), 'u1');
      expect(msg.action?.type, TutorActionType.pickInterests);
      expect(msg.action?.options, isNull); // confirmation, not a picker
      expect(msg.action?.categoryLabel, FlashcardCategory.animals.name);
    });

    test('"favorites" with no topic shows the full topic picker', () {
      final msg = TutorEngine.respondToQuestion(
          'favorites', _emptyProgress('u1'), 'u1');
      expect(msg.action?.type, TutorActionType.pickInterests);
      expect(msg.action?.options?.length, FlashcardCategory.values.length);
    });

    test('"gusto ko ng quiz" still reaches the quiz branch', () {
      final msg = TutorEngine.respondToQuestion(
          'gusto ko ng quiz', _emptyProgress('u1'), 'u1');
      expect(msg.action?.type, TutorActionType.quickQuiz);
    });
  });

  group('interest-biased picks', () {
    test('quickQuiz consistently draws from the favorite topic', () {
      for (var i = 0; i < 5; i++) {
        final msg = TutorEngine.quickQuiz(
            interests: const [FlashcardCategory.transportation]);
        expect(msg.action?.type, TutorActionType.quickQuiz);
        expect(msg.action?.categoryLabel,
            FlashcardCategory.transportation.label);
        expect(msg.content, contains('favorite'));
      }
    });

    test('learning plan keeps the weak word but adds a favorite-topic word',
        () async {
      // Make an *animals* word weak; favorite is transportation.
      final target = SeedData.getByCategory(FlashcardCategory.animals).first;
      await SpacedRepetitionService.recordWordAttempt(
          profileId: 'u2', wordId: target.id, wasCorrect: false);
      await SpacedRepetitionService.recordWordAttempt(
          profileId: 'u2', wordId: target.id, wasCorrect: false);

      final plan = TutorEngine.buildLearningPlan(
        _emptyProgress('u2'),
        'u2',
        interests: const [FlashcardCategory.transportation],
      );
      expect(plan.length, 3);
      expect(plan.map((c) => c.id), contains(target.id));
      expect(
        plan.any((c) => c.category == FlashcardCategory.transportation),
        isTrue,
      );
    });

    test('learning plan is untouched when interests are empty', () {
      final withInterests = TutorEngine.buildLearningPlan(
          _emptyProgress('u3'), 'u3');
      expect(withInterests.length, 3);
    });
  });

  group('welcomeBack', () {
    test('mentions the favorite topic and offers a lesson plan', () {
      final msg = TutorEngine.welcomeBack(
        'Ana',
        _emptyProgress('u4'),
        'u4',
        interests: const [FlashcardCategory.animals],
      );
      expect(msg.content, contains('Ana'));
      expect(msg.content, contains(FlashcardCategory.animals.label));
      expect(msg.action?.type, TutorActionType.startLesson);
      expect(msg.action?.planWordIds?.length, 3);
    });
  });

  group('askInterests / interestConfirmation messages', () {
    test('askInterests offers every category as an option', () {
      final msg = TutorEngine.askInterests();
      expect(msg.action?.type, TutorActionType.pickInterests);
      expect(msg.action?.options,
          FlashcardCategory.values.map((c) => c.name).toList());
    });

    test('interestConfirmation localizes the label and carries the name', () {
      final en = TutorEngine.interestConfirmation(FlashcardCategory.weather);
      expect(en.content, contains(FlashcardCategory.weather.label));
      expect(en.action?.categoryLabel, FlashcardCategory.weather.name);

      final fil = TutorEngine.interestConfirmation(FlashcardCategory.weather,
          isFilipino: true);
      expect(fil.content, contains(FlashcardCategory.weather.labelFilipino));
    });
  });
}
