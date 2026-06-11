import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/local/spaced_repetition_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/models/tutor_models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_engine.dart';
import 'package:pwdpwdpwd/features/ai_tutor/services/tutor_memory_service.dart';

/// In-memory Hive setup (the tutor memory + SR services both use the
/// `progress` box).
Future<void> _initHive() async {
  Hive.init('./build/test_cache/ai_tutor');
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

  group('TutorMemoryService persistence', () {
    test('round-trips messages, stats, plan date and plan ids', () async {
      final memory = TutorMemory(
        messages: [
          TutorMessage(
            id: 'm1',
            role: TutorMessageRole.tutor,
            content: 'Quick Quiz!',
            timestamp: DateTime.now(),
            action: const TutorAction(
              type: TutorActionType.quickQuiz,
              options: ['aso', 'pusa', 'ibon', 'isda'],
              correctAnswer: 'aso',
              wordId: 'w_dog',
              categoryLabel: 'Animals',
            ),
          ),
          TutorMessage(
            id: 'm2',
            role: TutorMessageRole.student,
            content: 'aso',
            timestamp: DateTime.now(),
          ),
        ],
        stats: const TutorStats(
          questionsAsked: 2,
          quizzesAnswered: 3,
          quizzesCorrect: 1,
          lessonsCompleted: 1,
        ),
        lastPlanDate: '2026-06-01',
        planWordIds: const ['w_dog', 'w_cat'],
      );

      await TutorMemoryService.saveMemory('p1', memory);
      final loaded = TutorMemoryService.getMemory('p1');

      expect(loaded.messages.length, 2);
      final quiz = loaded.messages.first;
      expect(quiz.role, TutorMessageRole.tutor);
      expect(quiz.content, 'Quick Quiz!');
      expect(quiz.action?.type, TutorActionType.quickQuiz);
      expect(quiz.action?.options, ['aso', 'pusa', 'ibon', 'isda']);
      expect(quiz.action?.wordId, 'w_dog');
      expect(quiz.action?.categoryLabel, 'Animals');

      expect(loaded.stats.questionsAsked, 2);
      expect(loaded.stats.quizzesAnswered, 3);
      expect(loaded.stats.quizzesCorrect, 1);
      expect(loaded.stats.lessonsCompleted, 1);
      expect(loaded.lastPlanDate, '2026-06-01');
      expect(loaded.planWordIds, ['w_dog', 'w_cat']);
    });

    test('empty memory on first visit', () {
      final loaded = TutorMemoryService.getMemory('never_seen');
      expect(loaded.messages, isEmpty);
      expect(loaded.stats.questionsAsked, 0);
      expect(loaded.lastPlanDate, isNull);
    });

    test('caps stored history to the most recent messages', () async {
      final many = List.generate(
        50,
        (i) => TutorMessage(
          id: '$i',
          role: TutorMessageRole.tutor,
          content: 'm$i',
          timestamp: DateTime.now(),
        ),
      );
      await TutorMemoryService.saveMemory('p2', TutorMemory(messages: many));
      final loaded = TutorMemoryService.getMemory('p2');

      expect(loaded.messages.length, TutorMemoryService.maxStoredMessages);
      // The most recent are kept (last 40 → m10 … m49).
      expect(loaded.messages.first.content, 'm10');
      expect(loaded.messages.last.content, 'm49');
    });
  });

  group('once-per-day lesson guard', () {
    test('dayKey is stable for the same calendar day', () {
      final a = DateTime(2026, 6, 1, 8);
      final b = DateTime(2026, 6, 1, 23, 59);
      expect(TutorMemoryService.dayKey(a), TutorMemoryService.dayKey(b));
      expect(TutorMemoryService.dayKey(a), '2026-06-01');
    });

    test('lessonDoneToday reflects lastPlanDate', () {
      final now = DateTime(2026, 6, 1, 10);
      final done = TutorMemory(lastPlanDate: TutorMemoryService.dayKey(now));
      final stale = TutorMemory(
          lastPlanDate: TutorMemoryService.dayKey(
              now.subtract(const Duration(days: 1))));
      expect(TutorMemoryService.lessonDoneToday(done, now: now), isTrue);
      expect(TutorMemoryService.lessonDoneToday(stale, now: now), isFalse);
    });
  });

  group('TutorEngine learning plan', () {
    test('builds a plan of 3 distinct real flashcards', () {
      final plan = TutorEngine.buildLearningPlan(_emptyProgress('u1'), 'u1');
      expect(plan.length, 3);
      expect(plan.map((c) => c.id).toSet().length, 3);
      final allIds = SeedData.allFlashcards.map((c) => c.id).toSet();
      expect(plan.every((c) => allIds.contains(c.id)), isTrue);
    });

    test('prioritizes a word the learner keeps getting wrong', () async {
      final target = SeedData.allFlashcards.first;
      // A word answered wrong (accuracy 0) outranks unseen words.
      await SpacedRepetitionService.recordWordAttempt(
          profileId: 'u2', wordId: target.id, wasCorrect: false);
      await SpacedRepetitionService.recordWordAttempt(
          profileId: 'u2', wordId: target.id, wasCorrect: false);

      final plan = TutorEngine.buildLearningPlan(_emptyProgress('u2'), 'u2');
      expect(plan.map((c) => c.id), contains(target.id));
    });

    test('offerLearningPlan returns a startLesson action with 3 word ids', () {
      final msg =
          TutorEngine.offerLearningPlan(_emptyProgress('u3'), 'u3');
      expect(msg.action?.type, TutorActionType.startLesson);
      expect(msg.action?.planWordIds?.length, 3);
    });
  });

  group('TutorEngine quiz word tagging', () {
    test('quizForWord tags the action with wordId + category', () {
      final card = SeedData.allFlashcards.first;
      final msg = TutorEngine.quizForWord(card);
      expect(msg.action?.type, TutorActionType.quickQuiz);
      expect(msg.action?.wordId, card.id);
      expect(msg.action?.categoryLabel, card.category.label);
      expect(msg.action?.correctAnswer, card.wordFilipino);
      expect(msg.action?.options, contains(card.wordFilipino));
    });
  });
}
