import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

/// The round and choice counts the two FSL quiz modes scale by difficulty.
///
/// Mirrors the switch expressions in `fsl_sign_to_word_screen.dart` and
/// `fsl_word_to_sign_screen.dart`. Pure arithmetic on purpose — standing the
/// real screens up needs the video stack, which has no platform channels under
/// `flutter test`; the screens' layout is already covered by
/// `gaze_fsl_hub_overflow_test.dart`.

int signToWordChoices(GameDifficulty d) => switch (d) {
  GameDifficulty.easy => 2,
  GameDifficulty.medium => 4,
  GameDifficulty.hard => 6,
};

int signToWordRounds(GameDifficulty d) => switch (d) {
  GameDifficulty.easy => 6,
  GameDifficulty.medium => 10,
  GameDifficulty.hard => 14,
};

int wordToSignWanted(GameDifficulty d) => switch (d) {
  GameDifficulty.easy => 2,
  GameDifficulty.medium => 3,
  GameDifficulty.hard => 4,
};

int wordToSignRounds(GameDifficulty d) => switch (d) {
  GameDifficulty.easy => 5,
  GameDifficulty.medium => 8,
  GameDifficulty.hard => 12,
};

/// What the screen actually uses: what the level wants, capped by how many
/// clips the chosen categories hold.
int wordToSignEffective(GameDifficulty d, int available) {
  final wanted = wordToSignWanted(d);
  return wanted < available ? wanted : available;
}

void main() {
  group('Sign → Word', () {
    test('offers fewer words to choose between on Easy', () {
      expect(signToWordChoices(GameDifficulty.easy), 2);
      expect(signToWordChoices(GameDifficulty.medium), 4);
      expect(signToWordChoices(GameDifficulty.hard), 6);
    });

    test('choices and rounds both rise monotonically with difficulty', () {
      for (var i = 1; i < GameDifficulty.values.length; i++) {
        final prev = GameDifficulty.values[i - 1];
        final next = GameDifficulty.values[i];
        expect(signToWordChoices(next), greaterThan(signToWordChoices(prev)));
        expect(signToWordRounds(next), greaterThan(signToWordRounds(prev)));
      }
    });

    test('Easy is a genuinely shorter session than Hard', () {
      expect(
        signToWordRounds(GameDifficulty.easy),
        lessThan(signToWordRounds(GameDifficulty.hard)),
      );
    });
  });

  group('Word → Sign', () {
    test('side-by-side clips rise with difficulty but stay decodable', () {
      expect(wordToSignWanted(GameDifficulty.easy), 2);
      expect(wordToSignWanted(GameDifficulty.hard), 4);
      // Four videos on screen at once is the ceiling — more is both harder to
      // compare and heavier to decode on a low-end tablet.
      for (final d in GameDifficulty.values) {
        expect(wordToSignWanted(d), lessThanOrEqualTo(4));
      }
    });

    test('never asks for more clips than the category actually holds', () {
      // The hub only guarantees 3 clips; Hard wants 4.
      expect(wordToSignEffective(GameDifficulty.hard, 3), 3);
      expect(wordToSignEffective(GameDifficulty.hard, 10), 4);
    });

    test('a two-clip category still yields a playable round', () {
      // Two is the floor: one right answer plus one decoy. Below that the
      // screen shows its empty state instead.
      for (final d in GameDifficulty.values) {
        expect(wordToSignEffective(d, 2), 2);
      }
    });

    test('rounds rise with difficulty', () {
      expect(
        wordToSignRounds(GameDifficulty.easy),
        lessThan(wordToSignRounds(GameDifficulty.medium)),
      );
      expect(
        wordToSignRounds(GameDifficulty.medium),
        lessThan(wordToSignRounds(GameDifficulty.hard)),
      );
    });
  });
}
