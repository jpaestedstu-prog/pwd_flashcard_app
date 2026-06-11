// Some cases spell out default values (e.g. fslSign correctIndex 0) to make
// the contract under test explicit.
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/live_session/models/live_session_models.dart';
import 'package:pwdpwdpwd/features/live_session/services/live_session_service.dart';

/// Guards the JSON contracts that flow over Firestore (activities, responses,
/// hands, session, scoring) and the per-type answer-checking logic the learner
/// device relies on to award stars.
void main() {
  group('LiveActivity round-trips + isCorrectAnswer', () {
    test('multipleChoice', () {
      final a = LiveActivity.multipleChoice(
        prompt: 'What sign is this?',
        options: const ['Cat', 'Dog', 'Bird'],
        correctIndex: 1,
      );
      final back = LiveActivity.fromJson(a.toJson());
      expect(back.type, LiveActivityType.multipleChoice);
      expect(back.prompt, 'What sign is this?');
      expect(back.options, ['Cat', 'Dog', 'Bird']);
      expect(back.correctIndex, 1);
      expect(back.isCorrectAnswer(1), isTrue);
      expect(back.isCorrectAnswer(0), isFalse);
      expect(back.isCorrectAnswer('1'), isFalse);
    });

    test('trueFalse', () {
      final a = LiveActivity.trueFalse(statement: 'A dog says moo', correctValue: false);
      final back = LiveActivity.fromJson(a.toJson());
      expect(back.type, LiveActivityType.trueFalse);
      expect(back.prompt, 'A dog says moo');
      expect(back.isCorrectAnswer(false), isTrue);
      expect(back.isCorrectAnswer(true), isFalse);
    });

    test('pictureChoice', () {
      final a = LiveActivity.pictureChoice(
        flashcardId: 'animals_cat',
        options: const ['Dog', 'Cat'],
        correctIndex: 1,
      );
      final back = LiveActivity.fromJson(a.toJson());
      expect(back.type, LiveActivityType.pictureChoice);
      expect(back.flashcardId, 'animals_cat');
      expect(back.isCorrectAnswer(1), isTrue);
    });

    test('fslSign with options', () {
      final a = LiveActivity.fslSign(
        flashcardId: 'animals_bird',
        options: const ['Bird', 'Fish'],
        correctIndex: 0,
      );
      final back = LiveActivity.fromJson(a.toJson());
      expect(back.type, LiveActivityType.fslSign);
      expect(back.selfReport, isFalse);
      expect(back.isCorrectAnswer(0), isTrue);
      expect(back.isCorrectAnswer(1), isFalse);
    });

    test('fslSign self-report treats "I got it" (true) as correct', () {
      final a = LiveActivity.fslSign(flashcardId: 'animals_cow', selfReport: true);
      final back = LiveActivity.fromJson(a.toJson());
      expect(back.selfReport, isTrue);
      expect(back.isCorrectAnswer(true), isTrue);
      expect(back.isCorrectAnswer(false), isFalse);
    });

    test('forPush re-stamps id + pushedAt and adds question numbers', () {
      final a = LiveActivity.multipleChoice(
        prompt: 'q', options: const ['a', 'b'], correctIndex: 0);
      final pushed = a.forPush(questionNumber: 2, totalQuestions: 5);
      expect(pushed.id, isNot(a.id));
      expect(pushed.questionNumber, 2);
      expect(pushed.totalQuestions, 5);
      expect(pushed.type, a.type);
      expect(pushed.options, a.options);
    });

    test('question number meta survives serialization', () {
      final a = LiveActivity.trueFalse(statement: 's', correctValue: true)
          .forPush(questionNumber: 1, totalQuestions: 3);
      final back = LiveActivity.fromJson(a.toJson());
      expect(back.questionNumber, 1);
      expect(back.totalQuestions, 3);
    });
  });

  group('LiveScoringRules', () {
    test('round-trips and reports enable flags', () {
      const r = LiveScoringRules(
        baseStars: 3,
        speedBonusMax: 2,
        speedWindowSec: 15,
        firstCorrectBonus: 1,
        sessionCap: 20,
      );
      final back = LiveScoringRules.fromJson(r.toJson());
      expect(back, r);
      expect(back.speedBonusEnabled, isTrue);
      expect(back.firstCorrectEnabled, isTrue);
      expect(back.hasCap, isTrue);
    });

    test('defaults are base-only with no bonuses or cap', () {
      const r = LiveScoringRules();
      expect(r.baseStars, 2);
      expect(r.speedBonusEnabled, isFalse);
      expect(r.firstCorrectEnabled, isFalse);
      expect(r.hasCap, isFalse);
    });

    test('null json yields defaults', () {
      expect(LiveScoringRules.fromJson(null), const LiveScoringRules());
    });
  });

  group('LiveResponse', () {
    test('round-trips correctness, answer, elapsed + stars', () {
      final r = LiveResponse(
        activityId: 'a1',
        profileId: 'p1',
        profileName: 'Ana',
        submittedAt: DateTime.parse('2026-05-31T10:00:00.000'),
        isCorrect: true,
        answer: 2,
        elapsedMs: 3400,
        starsAwarded: 4,
      );
      final back = LiveResponse.fromJson(r.toJson());
      expect(back.isCorrect, isTrue);
      expect(back.answer, 2);
      expect(back.elapsedMs, 3400);
      expect(back.starsAwarded, 4);
      expect(back.profileName, 'Ana');
    });

    test('legacy got_it payload is read as correct', () {
      final back = LiveResponse.fromJson({
        'activity_id': 'a1',
        'profile_id': 'p1',
        'profile_name': 'Bea',
        'submitted_at': '2026-05-31T10:00:00.000',
        'payload': {'got_it': true},
      });
      expect(back.isCorrect, isTrue);
    });
  });

  group('RaisedHand', () {
    test('round-trips and defaults to active', () {
      final h = RaisedHand(
        profileId: 'p1',
        profileName: 'Cy',
        raisedAt: DateTime.parse('2026-05-31T10:00:00.000'),
      );
      final back = RaisedHand.fromJson(h.toJson());
      expect(back.profileName, 'Cy');
      expect(back.active, isTrue);
    });
  });

  group('LiveSession', () {
    test('round-trips session key, owner kind, scoring + activity', () {
      final s = LiveSession(
        sessionKey: 'class123',
        ownerKind: LiveSessionOwnerKind.homeGroup,
        ownerProfileId: 'parent1',
        ownerUid: 'uid1',
        scoring: const LiveScoringRules(baseStars: 4, firstCorrectBonus: 2),
        currentActivity:
            LiveActivity.trueFalse(statement: 'x', correctValue: true),
        startedAt: DateTime.parse('2026-05-31T10:00:00.000'),
      );
      final back = LiveSession.fromJson(s.toJson());
      expect(back.sessionKey, 'class123');
      expect(back.ownerKind, LiveSessionOwnerKind.homeGroup);
      expect(back.ownerProfileId, 'parent1');
      expect(back.ownerUid, 'uid1');
      expect(back.scoring.baseStars, 4);
      expect(back.scoring.firstCorrectBonus, 2);
      expect(back.currentActivity?.type, LiveActivityType.trueFalse);
    });

    test('reads a legacy classroom-only session doc', () {
      final back = LiveSession.fromJson({
        'classroom_id': 'old123',
        'teacher_profile_id': 'teacher1',
        'teacher_uid': 'uid9',
        'status': 'active',
        'started_at': '2026-05-31T10:00:00.000',
      });
      expect(back.sessionKey, 'old123');
      expect(back.ownerProfileId, 'teacher1');
      expect(back.ownerUid, 'uid9');
      expect(back.ownerKind, LiveSessionOwnerKind.classroom);
      expect(back.scoring, const LiveScoringRules());
    });
  });

  group('LiveActivitySet', () {
    test('round-trips its activities', () {
      final set = LiveActivitySet(
        id: 's1',
        title: 'Animals quiz',
        activities: [
          LiveActivity.multipleChoice(
            prompt: 'q1', options: const ['a', 'b'], correctIndex: 0),
          LiveActivity.trueFalse(statement: 'q2', correctValue: false),
        ],
        createdBy: 'teacher1',
        createdAt: DateTime.parse('2026-05-31T10:00:00.000'),
      );
      final back = LiveActivitySet.fromJson(set.toJson());
      expect(back.title, 'Animals quiz');
      expect(back.activities.length, 2);
      expect(back.activities.first.type, LiveActivityType.multipleChoice);
      expect(back.activities[1].type, LiveActivityType.trueFalse);
    });
  });

  group('LiveSessionService.aggregateScoreboard', () {
    test('sums stars + correct per profile, sorted by stars then correct', () {
      final responses = [
        LiveResponse(
          activityId: 'a1', profileId: 'p1', profileName: 'Ana',
          submittedAt: DateTime.now(), isCorrect: true, starsAwarded: 2),
        LiveResponse(
          activityId: 'a2', profileId: 'p1', profileName: 'Ana',
          submittedAt: DateTime.now(), isCorrect: true, starsAwarded: 3),
        LiveResponse(
          activityId: 'a1', profileId: 'p2', profileName: 'Bea',
          submittedAt: DateTime.now(), isCorrect: false, starsAwarded: 0),
      ];
      final board = LiveSessionService.aggregateScoreboard(responses);
      expect(board.first.profileId, 'p1');
      expect(board.first.stars, 5);
      expect(board.first.correct, 2);
      expect(board[1].profileId, 'p2');
      expect(board[1].stars, 0);
    });
  });
}
