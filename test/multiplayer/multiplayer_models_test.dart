import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/multiplayer_models.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/memory_race_player.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/scramble_race_player.dart';

List<Flashcard> _pool(int n) => List.generate(
      n,
      (i) => Flashcard(
        id: 'c$i',
        wordEnglish: 'english$i',
        wordFilipino: 'filipino$i',
        exampleSentence: 'sentence $i',
        category: FlashcardCategory.animals,
      ),
    );

/// Pool of short, single-token Filipino words eligible for the scramble race
/// (length 3–8, no spaces).
List<Flashcard> _scramblePool() => const [
      Flashcard(id: 's0', wordEnglish: 'dog', wordFilipino: 'aso', category: FlashcardCategory.animals),
      Flashcard(id: 's1', wordEnglish: 'cat', wordFilipino: 'pusa', category: FlashcardCategory.animals),
      Flashcard(id: 's2', wordEnglish: 'bird', wordFilipino: 'ibon', category: FlashcardCategory.animals),
      Flashcard(id: 's3', wordEnglish: 'fish', wordFilipino: 'isda', category: FlashcardCategory.animals),
      Flashcard(id: 's4', wordEnglish: 'house', wordFilipino: 'bahay', category: FlashcardCategory.animals),
      Flashcard(id: 's5', wordEnglish: 'sun', wordFilipino: 'araw', category: FlashcardCategory.animals),
    ];

void main() {
  group('wire enums', () {
    test('MpGameMode round-trips', () {
      for (final m in MpGameMode.values) {
        expect(MpGameModeX.fromWire(m.wire), m);
      }
      expect(MpGameModeX.fromWire('garbage'), MpGameMode.quizRace);
    });

    test('GameRoomStatus round-trips', () {
      for (final s in GameRoomStatus.values) {
        expect(GameRoomStatusX.fromWire(s.wire), s);
      }
      expect(GameRoomStatusX.fromWire(null), GameRoomStatus.waiting);
    });
  });

  group('JSON round-trips', () {
    test('MpQuestion', () {
      const q = MpQuestion(
        prompt: 'dog',
        promptLabel: 'What is this in Filipino?',
        subtitle: 'The dog runs.',
        options: ['aso', 'pusa', 'ibon', 'isda'],
        correctIndex: 0,
      );
      final back = MpQuestion.fromJson(q.toJson());
      expect(back.prompt, q.prompt);
      expect(back.promptLabel, q.promptLabel);
      expect(back.subtitle, q.subtitle);
      expect(back.options, q.options);
      expect(back.correctIndex, q.correctIndex);
    });

    test('GameRoom with content + guest', () {
      final now = DateTime.now();
      final room = GameRoom(
        id: 'room-1',
        hostProfileId: 'host',
        hostName: 'Ana',
        hostUid: 'uidA',
        hostAvatarIndex: 2,
        guestProfileId: 'guest',
        guestName: 'Ben',
        guestAvatarIndex: 5,
        invitedProfileId: 'guest',
        mode: MpGameMode.quizRace,
        status: GameRoomStatus.active,
        rounds: 6,
        questions: const [
          MpQuestion(
            prompt: 'dog',
            promptLabel: 'q',
            options: ['aso', 'pusa', 'ibon', 'isda'],
            correctIndex: 0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        ownerUid: 'uidA',
      );
      final back = GameRoom.fromJson(room.toJson());
      expect(back.id, room.id);
      expect(back.hostProfileId, room.hostProfileId);
      expect(back.guestProfileId, room.guestProfileId);
      expect(back.guestAvatarIndex, room.guestAvatarIndex);
      expect(back.invitedProfileId, room.invitedProfileId);
      expect(back.mode, room.mode);
      expect(back.status, room.status);
      expect(back.rounds, room.rounds);
      expect(back.questions.length, 1);
      expect(back.questions.first.options, room.questions.first.options);
      expect(back.hasGuest, isTrue);
      expect(back.opponentNameFor('host'), 'Ben');
      expect(back.opponentNameFor('guest'), 'Ana');
    });

    test('GameRoom without guest', () {
      final now = DateTime.now();
      final room = GameRoom(
        id: 'r',
        hostProfileId: 'host',
        hostName: 'Ana',
        hostUid: 'u',
        hostAvatarIndex: 0,
        invitedProfileId: 'someone',
        mode: MpGameMode.memoryRace,
        status: GameRoomStatus.waiting,
        rounds: 6,
        memoryLayout: const [
          MemoryCardSpec(cardId: 'c0', emoji: '🐶', label: 'dog'),
          MemoryCardSpec(cardId: 'c0', emoji: '🐶', label: 'dog'),
        ],
        createdAt: now,
        updatedAt: now,
        ownerUid: 'u',
      );
      final back = GameRoom.fromJson(room.toJson());
      expect(back.hasGuest, isFalse);
      expect(back.guestProfileId, isNull);
      expect(back.memoryLayout.length, 2);
      expect(back.memoryLayout.first.emoji, '🐶');
      // No guest yet → opponent name falls back gracefully.
      expect(back.opponentNameFor('host'), 'Friend');
    });

    test('MpPlayerState', () {
      final s = MpPlayerState(
        profileId: 'p',
        name: 'Ana',
        avatarIndex: 3,
        score: 42,
        progress: 4,
        finished: true,
        ownerUid: 'u',
        updatedAt: DateTime.now(),
      );
      final back = MpPlayerState.fromJson(s.toJson());
      expect(back.profileId, s.profileId);
      expect(back.name, s.name);
      expect(back.avatarIndex, s.avatarIndex);
      expect(back.score, s.score);
      expect(back.progress, s.progress);
      expect(back.finished, s.finished);
    });
  });

  group('computeOutcome', () {
    test('higher score wins', () {
      expect(computeOutcome(5, 3), MpOutcome.player1);
      expect(computeOutcome(2, 8), MpOutcome.player2);
      expect(computeOutcome(4, 4), MpOutcome.draw);
    });
  });

  group('buildQuizQuestions', () {
    test('produces the requested count with valid options', () {
      final qs = buildQuizQuestions(_pool(8), 6, Random(1));
      expect(qs.length, 6);
      for (final q in qs) {
        expect(q.options.length, 4);
        expect(q.correctIndex, inInclusiveRange(0, 3));
        expect(q.options[q.correctIndex], isNotEmpty);
        expect(q.options.toSet().length, 4); // no duplicate options
        expect(q.prompt, isNotEmpty);
      }
    });

    test('returns empty when the pool is too small', () {
      expect(buildQuizQuestions(_pool(3), 6, Random(1)), isEmpty);
    });
  });

  group('buildMemoryLayout', () {
    test('produces pairs*2 cards, each id exactly twice', () {
      final layout =
          buildMemoryLayout(_pool(8), 6, Random(2), emojiFor: (_) => '⭐');
      expect(layout.length, 12);
      final counts = <String, int>{};
      for (final c in layout) {
        counts[c.cardId] = (counts[c.cardId] ?? 0) + 1;
        expect(c.emoji, '⭐'); // emojiFor applied
      }
      expect(counts.length, 6); // 6 distinct pairs
      expect(counts.values.every((v) => v == 2), isTrue);
    });

    test('returns empty when the pool has fewer than the pairs', () {
      expect(buildMemoryLayout(_pool(3), 6, Random(2)), isEmpty);
    });
  });

  group('memoryRaceScore', () {
    test('rewards efficiency and stays positive', () {
      final perfect =
          memoryRaceScore(pairs: 6, moves: 6, elapsedSeconds: 10);
      final sloppy =
          memoryRaceScore(pairs: 6, moves: 14, elapsedSeconds: 10);
      expect(perfect, greaterThan(sloppy));
      expect(sloppy, greaterThanOrEqualTo(10));
    });

    test('faster finishes score higher, all else equal', () {
      final fast = memoryRaceScore(pairs: 6, moves: 8, elapsedSeconds: 5);
      final slow = memoryRaceScore(pairs: 6, moves: 8, elapsedSeconds: 80);
      expect(fast, greaterThan(slow));
    });
  });

  group('buildPictureQuestions', () {
    test('emoji prompt with four English-word options', () {
      final qs = buildPictureQuestions(_pool(8), 5, Random(3),
          emojiFor: (_) => '🐾');
      expect(qs.length, 5);
      for (final q in qs) {
        expect(q.prompt, '🐾');
        expect(q.options.length, 4);
        expect(q.correctIndex, inInclusiveRange(0, 3));
        expect(q.options[q.correctIndex], isNotEmpty);
      }
    });
  });

  group('buildTrueFalseQuestions', () {
    test('two localisable options with a valid correct index', () {
      final qs = buildTrueFalseQuestions(_pool(8), 6, Random(4),
          yesLabel: 'Tama', noLabel: 'Mali');
      expect(qs.length, 6);
      for (final q in qs) {
        expect(q.options, ['Tama', 'Mali']);
        expect(q.correctIndex, anyOf(0, 1));
        expect(q.prompt, contains('='));
      }
    });
  });

  group('buildScrambleItems', () {
    test('letters are a permutation of the answer', () {
      final items = buildScrambleItems(_scramblePool(), 4, Random(5),
          emojiFor: (_) => '🔤');
      expect(items.length, 4);
      for (final it in items) {
        expect(it.promptEmoji, '🔤');
        expect(it.letters.length, it.answer.length);
        expect(it.letters.toList()..sort(), it.answer.split('')..sort());
        expect(it.prompt, isNotEmpty);
      }
    });

    test('returns empty when no word qualifies (too long / has spaces)', () {
      // _pool words are "filipino0".. (length 9) → all excluded.
      expect(buildScrambleItems(_pool(8), 4, Random(5), emojiFor: (_) => 'x'),
          isEmpty);
    });
  });

  group('scrambleScore', () {
    test('more solved scores higher; wrong attempts and time lower it', () {
      expect(
        scrambleScore(solved: 5, wrong: 0, elapsedSeconds: 10),
        greaterThan(scrambleScore(solved: 3, wrong: 0, elapsedSeconds: 10)),
      );
      expect(
        scrambleScore(solved: 5, wrong: 0, elapsedSeconds: 10),
        greaterThan(scrambleScore(solved: 5, wrong: 6, elapsedSeconds: 10)),
      );
      expect(scrambleScore(solved: 0, wrong: 99, elapsedSeconds: 999),
          greaterThanOrEqualTo(0));
    });
  });

  group('scramble JSON + GameRoom integration', () {
    test('MpScrambleItem round-trips', () {
      const item = MpScrambleItem(
        prompt: 'dog',
        promptEmoji: '🐶',
        answer: 'aso',
        letters: ['s', 'a', 'o'],
      );
      final back = MpScrambleItem.fromJson(item.toJson());
      expect(back.prompt, item.prompt);
      expect(back.promptEmoji, item.promptEmoji);
      expect(back.answer, item.answer);
      expect(back.letters, item.letters);
    });

    test('GameRoom carries scramble items and reports totalSteps by mode', () {
      final now = DateTime.now();
      final room = GameRoom(
        id: 'r',
        hostProfileId: 'h',
        hostName: 'Ana',
        hostUid: 'u',
        hostAvatarIndex: 0,
        invitedProfileId: 'g',
        mode: MpGameMode.scrambleRace,
        status: GameRoomStatus.waiting,
        rounds: 2,
        scrambleItems: const [
          MpScrambleItem(
              prompt: 'dog', promptEmoji: '🐶', answer: 'aso', letters: ['a', 's', 'o']),
          MpScrambleItem(
              prompt: 'cat', promptEmoji: '🐱', answer: 'pusa', letters: ['p', 'u', 's', 'a']),
        ],
        createdAt: now,
        updatedAt: now,
        ownerUid: 'u',
      );
      final back = GameRoom.fromJson(room.toJson());
      expect(back.mode, MpGameMode.scrambleRace);
      expect(back.scrambleItems.length, 2);
      expect(back.scrambleItems.first.answer, 'aso');
      expect(back.totalSteps, 2);
    });

    test('totalSteps follows the mode', () {
      GameRoom base({
        required MpGameMode mode,
        List<MpQuestion> questions = const [],
        List<MemoryCardSpec> layout = const [],
        List<MpScrambleItem> scramble = const [],
      }) {
        final now = DateTime.now();
        return GameRoom(
          id: 'r',
          hostProfileId: 'h',
          hostName: 'A',
          hostUid: 'u',
          hostAvatarIndex: 0,
          invitedProfileId: 'g',
          mode: mode,
          status: GameRoomStatus.waiting,
          rounds: 0,
          questions: questions,
          memoryLayout: layout,
          scrambleItems: scramble,
          createdAt: now,
          updatedAt: now,
          ownerUid: 'u',
        );
      }

      const q = MpQuestion(
          prompt: 'p', promptLabel: 'l', options: ['a', 'b'], correctIndex: 0);
      const card = MemoryCardSpec(cardId: 'c', emoji: 'x', label: 'l');
      expect(
          base(mode: MpGameMode.quizRace, questions: [q, q, q]).totalSteps, 3);
      expect(
          base(mode: MpGameMode.memoryRace, layout: [card, card]).totalSteps,
          1);
    });
  });
}
