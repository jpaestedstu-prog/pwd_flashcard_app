import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/knowledge_tracing_service.dart';
import 'package:pwdpwdpwd/core/utils/research_export_rows.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/local/spaced_repetition_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

const _pid = 'elo-test-profile';

void main() {
  late Box box;

  setUpAll(() async {
    Hive.init('./build/test_cache/knowledge_tracing');
    if (!Hive.isBoxOpen('progress')) {
      await Hive.openBox('progress');
    }
    box = Hive.box('progress');
  });

  setUp(() async {
    await box.clear();
  });

  group('Elo updates', () {
    test('repeated correct answers raise ability and predicted mastery',
        () async {
      expect(
        KnowledgeTracingService.pCorrect(profileId: _pid, wordId: 'w1'),
        0.5,
      );
      for (var i = 0; i < 12; i++) {
        await KnowledgeTracingService.recordAttempt(
          profileId: _pid,
          wordId: 'w1',
          wasCorrect: true,
        );
      }
      final state = KnowledgeTracingService.getState(_pid);
      expect(state.thetaGlobal, greaterThan(0.3));
      expect(state.items['w1']!.beta, lessThan(0));
      expect(
        KnowledgeTracingService.pCorrect(profileId: _pid, wordId: 'w1'),
        greaterThan(0.75),
      );
    });

    test('repeated wrong answers lower ability and raise word difficulty',
        () async {
      for (var i = 0; i < 8; i++) {
        await KnowledgeTracingService.recordAttempt(
          profileId: _pid,
          wordId: 'w1',
          wasCorrect: false,
        );
      }
      final state = KnowledgeTracingService.getState(_pid);
      expect(state.thetaGlobal, lessThan(0));
      expect(state.items['w1']!.beta, greaterThan(0));
      expect(
        KnowledgeTracingService.pCorrect(profileId: _pid, wordId: 'w1'),
        lessThan(0.3),
      );
    });

    test('learning rate decays as evidence accumulates', () async {
      // Alternating outcomes keep p near 0.5 so the error term stays roughly
      // constant — any shrink in |Δθ| is the K decay.
      double thetaBefore = KnowledgeTracingService.getState(_pid).thetaGlobal;
      await KnowledgeTracingService.recordAttempt(
        profileId: _pid,
        wordId: 'w1',
        wasCorrect: true,
      );
      final firstDelta =
          (KnowledgeTracingService.getState(_pid).thetaGlobal - thetaBefore)
              .abs();

      for (var i = 0; i < 40; i++) {
        await KnowledgeTracingService.recordAttempt(
          profileId: _pid,
          wordId: 'w1',
          wasCorrect: i.isEven,
        );
      }
      thetaBefore = KnowledgeTracingService.getState(_pid).thetaGlobal;
      await KnowledgeTracingService.recordAttempt(
        profileId: _pid,
        wordId: 'w1',
        wasCorrect: true,
      );
      final lateDelta =
          (KnowledgeTracingService.getState(_pid).thetaGlobal - thetaBefore)
              .abs();

      expect(lateDelta, lessThan(firstDelta));
    });

    test('recordBatch counts every attempt and persists', () async {
      await KnowledgeTracingService.recordBatch(
        profileId: _pid,
        results: {'w1': true, 'w2': false, 'w3': true},
      );
      final state = KnowledgeTracingService.getState(_pid);
      expect(state.attemptsGlobal, 3);
      expect(state.items, hasLength(3));
    });

    test('state survives a JSON round-trip through Hive', () async {
      await KnowledgeTracingService.recordBatch(
        profileId: _pid,
        results: {'w1': true, 'w2': false},
      );
      final first = KnowledgeTracingService.getState(_pid);
      final second = KnowledgeTracingService.getState(_pid);
      expect(second.thetaGlobal, first.thetaGlobal);
      expect(second.attemptsGlobal, first.attemptsGlobal);
      expect(second.items['w1']!.beta, first.items['w1']!.beta);
      expect(second.items['w2']!.history, [0]);
    });

    test('seed-vocabulary attempts update the category ability too', () async {
      final card = SeedData.allFlashcards.first;
      await KnowledgeTracingService.recordAttempt(
        profileId: _pid,
        wordId: card.id,
        wasCorrect: true,
      );
      final state = KnowledgeTracingService.getState(_pid);
      expect(state.thetaByCategory[card.category.name], isNotNull);
      expect(state.thetaByCategory[card.category.name], greaterThan(0));
    });
  });

  group('trend detection', () {
    test('trendSlope is negative for practiced-but-declining words', () {
      expect(
        KnowledgeTracingService.trendSlope([1, 1, 1, 1, 0, 0, 0, 0]),
        lessThan(-0.5),
      );
      expect(
        KnowledgeTracingService.trendSlope([0, 0, 0, 0, 1, 1, 1, 1]),
        greaterThan(0.5),
      );
    });

    test('trendSlope needs at least 6 outcomes', () {
      expect(KnowledgeTracingService.trendSlope([1, 0, 0]), 0.0);
      expect(KnowledgeTracingService.trendSlope([]), 0.0);
    });

    test('decliningWords flags a word that flipped from right to wrong',
        () async {
      for (var i = 0; i < 8; i++) {
        await KnowledgeTracingService.recordAttempt(
          profileId: _pid,
          wordId: 'fading',
          wasCorrect: i < 4,
        );
        await KnowledgeTracingService.recordAttempt(
          profileId: _pid,
          wordId: 'steady',
          wasCorrect: true,
        );
      }
      final declining = KnowledgeTracingService.decliningWords(_pid);
      expect(declining, contains('fading'));
      expect(declining, isNot(contains('steady')));
    });

    test('summary surfaces struggling words and needsAttention', () async {
      for (var i = 0; i < 8; i++) {
        await KnowledgeTracingService.recordAttempt(
          profileId: _pid,
          wordId: 'fading',
          wasCorrect: i < 4,
        );
      }
      final summary = KnowledgeTracingService.summary(_pid);
      expect(summary.trackedWords, 1);
      expect(summary.decliningWordIds, contains('fading'));
      expect(summary.needsAttention, isTrue);
    });
  });

  group('difficulty policy', () {
    test('fresh profile gets the relaxed policy', () {
      expect(
        KnowledgeTracingService.policyFor(profileId: _pid),
        same(DifficultyPolicy.relaxed),
      );
      expect(
        KnowledgeTracingService.recommendDifficulty(profileId: _pid),
        GameDifficulty.easy,
      );
    });

    test('a consistently correct student graduates to challenge', () async {
      // Distinct words so β stays near 0 and θ keeps absorbing the signal.
      for (var i = 0; i < 20; i++) {
        await KnowledgeTracingService.recordAttempt(
          profileId: _pid,
          wordId: 'w$i',
          wasCorrect: true,
        );
      }
      expect(
        KnowledgeTracingService.policyFor(profileId: _pid),
        same(DifficultyPolicy.challenge),
      );
      expect(
        KnowledgeTracingService.recommendDifficulty(profileId: _pid),
        GameDifficulty.hard,
      );
    });

    test('a struggling student stays relaxed', () async {
      for (var i = 0; i < 10; i++) {
        await KnowledgeTracingService.recordAttempt(
          profileId: _pid,
          wordId: 'w$i',
          wasCorrect: false,
        );
      }
      expect(
        KnowledgeTracingService.recommendDifficulty(profileId: _pid),
        GameDifficulty.easy,
      );
    });
  });

  group('SpacedRepetitionService integration', () {
    test('recordWordAttempt feeds the Elo model', () async {
      await SpacedRepetitionService.recordWordAttempt(
        profileId: _pid,
        wordId: 'w1',
        wasCorrect: true,
      );
      expect(KnowledgeTracingService.getState(_pid).attemptsGlobal, 1);
    });

    test('getReviewWordsElo ranks the predicted-weak word first', () async {
      final cards = SeedData.allFlashcards.take(2).toList();
      for (var i = 0; i < 5; i++) {
        await SpacedRepetitionService.recordWordAttempt(
          profileId: _pid,
          wordId: cards[0].id,
          wasCorrect: false,
        );
        await SpacedRepetitionService.recordWordAttempt(
          profileId: _pid,
          wordId: cards[1].id,
          wasCorrect: true,
        );
      }
      final ranked = SpacedRepetitionService.getReviewWordsElo(
        profileId: _pid,
        allCards: cards,
        count: 2,
      );
      expect(ranked.first.id, cards[0].id);
    });
  });

  group('knowledge_state.csv rows', () {
    test('row column count matches the header', () async {
      await KnowledgeTracingService.recordBatch(
        profileId: _pid,
        results: {SeedData.allFlashcards.first.id: true},
      );
      final summary = KnowledgeTracingService.summary(_pid);
      final rows = ResearchExportRows.knowledgeStateRows(
        studentId: 'S001',
        thetaGlobal: summary.thetaGlobal,
        thetaByCategory: summary.thetaByCategory,
        reports: KnowledgeTracingService.wordReports(_pid),
      );
      expect(rows, hasLength(1));
      final headerCols =
          ResearchExportRows.knowledgeStateHeader.split(',').length;
      expect(rows.single.split(',').length, headerCols);
    });
  });
}
