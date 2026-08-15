import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_content_policy.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/messaging/models/friend_models.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/multiplayer_models.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/race_presentation.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/quiz_race_player.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/scramble_race_player.dart';

/// Filipino Sign Language inside a race, and invites that respect what the
/// *other* learner needs.

Flashcard _card(String id, String en, String fil) => Flashcard(
      id: id,
      wordEnglish: en,
      wordFilipino: fil,
      category: FlashcardCategory.animals,
    );

final _pool = [
  _card('c1', 'dog', 'aso'),
  _card('c2', 'cat', 'pusa'),
  _card('c3', 'bird', 'ibon'),
  _card('c4', 'fish', 'isda'),
];

final _hearing = RacePresentation.forProfile(
  DisabilityType.hearing,
  const AppSettings(),
);
final _cognitive = RacePresentation.forProfile(
  DisabilityType.cognitive,
  const AppSettings(),
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('every round knows which card it is about', () {
    test('word quiz rounds carry a sign card without becoming pictures', () {
      final qs = buildQuizQuestions(_pool, 4, Random(1));
      for (final q in qs) {
        expect(q.fslCardId, isNotNull, reason: 'a sign can be looked up');
        expect(q.cardId, isNull,
            reason: 'setting card_id would turn the text prompt into an image');
      }
    });

    test('true/false rounds carry a sign card', () {
      final qs = buildTrueFalseQuestions(_pool, 4, Random(1));
      expect(qs.every((q) => q.fslCardId != null), isTrue);
      expect(qs.every((q) => q.cardId == null), isTrue);
    });

    test('picture rounds keep their picture and resolve a sign', () {
      final qs = buildPictureQuestions(_pool, 4, Random(1), emojiFor: (_) => '🐶');
      for (final q in qs) {
        expect(q.cardId, isNotNull, reason: 'still renders pictorially');
        expect(q.fslCardId, q.cardId);
      }
    });

    test('the sign id survives the wire', () {
      const q = MpQuestion(
        prompt: 'dog',
        promptLabel: 'What is this in Filipino?',
        options: ['aso', 'pusa'],
        correctIndex: 0,
        signCardId: 'c1',
      );
      final back = MpQuestion.fromJson(q.toJson());
      expect(back.signCardId, 'c1');
      expect(back.cardId, isNull);
    });

    test('a peer on an older build simply offers no sign', () {
      final back = MpQuestion.fromJson(const {
        'prompt': 'dog',
        'prompt_label': 'What is this in Filipino?',
        'options': ['aso', 'pusa'],
        'correct_index': 0,
      });
      expect(back.fslCardId, isNull);
    });
  });

  group('who is offered the sign', () {
    test('the race never disagrees with the rest of the app', () {
      for (final t in DisabilityType.values) {
        expect(
          RacePresentation.forProfile(t, const AppSettings()).showFsl,
          AccessibilityContentPolicy.forType(t).showFsl,
          reason: '$t must match the Cards tab and the FSL dictionary',
        );
      }
    });

    test('a deaf learner signs; a cognitive one does not', () {
      expect(_hearing.showFsl, isTrue);
      expect(_cognitive.showFsl, isFalse);
    });
  });

  group('the sign control appears where it should', () {
    final questions = buildQuizQuestions(_pool, 2, Random(3));

    testWidgets('a signing learner gets it on a word round', (tester) async {
      final shown = <String>[];
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: questions,
        presentation: _hearing,
        onShowSign: shown.add,
        onFinished: (_) {},
      )));
      expect(find.text('Show the sign'), findsOneWidget);

      await tester.tap(find.text('Show the sign'));
      await tester.pump();
      expect(shown, hasLength(1));
      expect(shown.first, isNotEmpty, reason: 'a real card id was handed over');
    });

    testWidgets('a non-signing learner never sees it', (tester) async {
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: questions,
        presentation: _cognitive,
        onShowSign: (_) {},
        onFinished: (_) {},
      )));
      expect(find.text('Show the sign'), findsNothing);
    });

    testWidgets('nor does anyone when the screen supplies no handler',
        (tester) async {
      await tester.pumpWidget(_host(QuizRacePlayer(
        questions: questions,
        presentation: _hearing,
        onFinished: (_) {},
      )));
      expect(find.text('Show the sign'), findsNothing);
    });

    testWidgets('the scramble clue offers its sign too', (tester) async {
      final shown = <String>[];
      await tester.pumpWidget(_host(ScrambleRacePlayer(
        items: const [
          MpScrambleItem(
            prompt: 'dog',
            promptEmoji: '🐶',
            answer: 'aso',
            letters: ['o', 's', 'a'],
            cardId: 'c1',
          ),
        ],
        presentation: _hearing,
        onShowSign: shown.add,
        onFinished: (_) {},
      )));
      await tester.tap(find.text('Show the sign'));
      await tester.pump();
      expect(shown, ['c1']);
    });
  });

  group('invites respect the other learner', () {
    InviteFit fit(DisabilityType host, DisabilityType? guest, MpGameMode m) =>
        InviteFit.between(
          host: host,
          guest: guest,
          selected: m,
          hostNeedsFairPlay:
              RacePresentation.forProfile(host, const AppSettings())
                  .needsFairPlay,
        );

    test('a scramble invite is swapped for a friend who does not spell', () {
      final f = fit(DisabilityType.none, DisabilityType.cognitive,
          MpGameMode.scrambleRace);
      expect(f.selectedIsShared, isFalse);
      expect(f.sharedModes, isNot(contains(MpGameMode.scrambleRace)));
      expect(f.resolve(MpGameMode.scrambleRace),
          isNot(MpGameMode.scrambleRace));
    });

    test('a picture invite is swapped for a friend who cannot see it', () {
      final f = fit(DisabilityType.none, DisabilityType.visual,
          MpGameMode.pictureRace);
      expect(f.selectedIsShared, isFalse);
      expect(f.resolve(MpGameMode.pictureRace), isNot(MpGameMode.pictureRace));
    });

    test('a game they both play is left alone', () {
      final f = fit(DisabilityType.none, DisabilityType.visual,
          MpGameMode.quizRace);
      expect(f.selectedIsShared, isTrue);
      expect(f.resolve(MpGameMode.quizRace), MpGameMode.quizRace);
    });

    test('every pairing shares at least one game', () {
      for (final a in DisabilityType.values) {
        for (final b in DisabilityType.values) {
          final f = fit(a, b, MpGameMode.quizRace);
          expect(f.sharedModes, isNotEmpty, reason: '$a vs $b');
        }
      }
    });

    test('the guest can take the clock off the host', () {
      final f = fit(DisabilityType.none, DisabilityType.motor,
          MpGameMode.quizRace);
      expect(f.dropsTheClock, isTrue,
          reason: 'the host must be told before they invite');
    });

    test('two untimed-free learners keep the race timed', () {
      final f = fit(DisabilityType.none, DisabilityType.hearing,
          MpGameMode.quizRace);
      expect(f.dropsTheClock, isFalse);
    });

    test('a friend on an older build is assumed to play everything', () {
      final f = fit(DisabilityType.none, null, MpGameMode.scrambleRace);
      expect(f.selectedIsShared, isTrue, reason: 'assume nothing, change nothing');
      expect(f.dropsTheClock, isFalse);
    });

    test('an older peer never resurrects a game the host cannot play', () {
      final f = fit(DisabilityType.cognitive, null, MpGameMode.quizRace);
      expect(f.sharedModes,
          RacePresentation.modesFor(DisabilityType.cognitive));
    });
  });

  group('the directory carries the category', () {
    test('it round-trips', () {
      final e = DirectoryEntry(
        username: 'ana-1',
        profileId: 'p1',
        name: 'Ana',
        roleIndex: UserRole.student.index,
        disabilityIndex: DisabilityType.motor.index,
        ownerUid: 'u1',
        updatedAt: DateTime(2026, 8, 15),
      );
      final back = DirectoryEntry.fromJson(e.toJson());
      expect(back.disabilityIndex, DisabilityType.motor.index);
    });

    test('an entry written by an older build has none', () {
      final back = DirectoryEntry.fromJson(const {
        'username': 'ana-1',
        'profile_id': 'p1',
        'name': 'Ana',
        'role_index': 1,
        'owner_uid': 'u1',
      });
      expect(back.disabilityIndex, isNull);
    });
  });
}
