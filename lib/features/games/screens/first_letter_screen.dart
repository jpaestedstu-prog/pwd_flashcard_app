import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../widgets/flashcard_image.dart';
import '../widgets/tap_quiz_game.dart';
import '../../../l10n/app_localizations.dart';

/// First Letter
///
/// A picture and its word are shown; the learner taps the letter the English
/// word begins with. Phonics practice that needs one tap on a very large
/// target and reads aloud cleanly, so it works for learners who can't manage
/// Tracing or Spelling Bee's letter tiles.
class FirstLetterScreen extends TapQuizScreen {
  const FirstLetterScreen({
    super.key,
    super.difficulty,
    super.categories,
    super.timedMode,
    super.resume,
  });

  @override
  ConsumerState<FirstLetterScreen> createState() => _FirstLetterScreenState();
}

class _FirstLetterScreenState extends TapQuizState<FirstLetterScreen> {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  @override
  GameType get gameType => GameType.firstLetter;

  // Letter tiles are narrow, so Hard's six fit three-up in two rows rather
  // than stacking into three rows of shallow, hard-to-hit cells.
  @override
  int get choiceColumns => _choiceCount >= 6 ? 3 : 2;

  @override
  int get promptFlex => 4;

  @override
  int get choicesFlex => 3;

  /// Letters offered per round: 2 at Easy, 4 at Medium, 6 at Hard.
  int get _choiceCount => switch (widget.difficulty) {
    GameDifficulty.easy => 2,
    GameDifficulty.medium => 4,
    GameDifficulty.hard => 6,
  };

  @override
  TapQuizRound? buildRound(
    Flashcard card,
    List<Flashcard> pool,
    Random random,
  ) {
    final word = card.wordEnglish.trim();
    if (word.isEmpty) return null;
    final answer = word[0].toUpperCase();
    if (!_alphabet.contains(answer)) return null;

    // Distractors come from the first letters of other real words where
    // possible, so the wrong options stay plausible instead of random noise.
    final fromWords = <String>{
      for (final c in pool)
        if (c.wordEnglish.trim().isNotEmpty)
          c.wordEnglish.trim()[0].toUpperCase(),
    }..remove(answer);
    final distractors = fromWords.where(_alphabet.contains).toList()
      ..shuffle(random);
    if (distractors.length < _choiceCount - 1) {
      final spare = _alphabet.split('')
        ..remove(answer)
        ..removeWhere(distractors.contains)
        ..shuffle(random);
      distractors.addAll(spare);
    }

    final letters = [answer, ...distractors.take(_choiceCount - 1)]
      // Alphabetical, not shuffled: a stable, predictable order is easier to
      // scan for the learners this game is aimed at, and the answer's position
      // still varies round to round.
      ..sort();

    return TapQuizRound(
      card: card,
      choices: [for (final l in letters) TapChoice(label: l)],
      correctIndex: letters.indexOf(answer),
    );
  }

  @override
  String promptSemantics(AppLocalizations l10n, TapQuizRound round) =>
      l10n.firstLetterQuestion(round.card.wordEnglish);

  @override
  Widget buildPrompt(BuildContext context, TapQuizRound round) {
    final l10n = AppLocalizations.of(context)!;
    final hc = HCColor.of(context);
    return promptPanel(
      context,
      round.card.category.color,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlashcardImage(card: round.card, size: 88),
          const SizedBox(height: 14),
          Text(
            round.card.wordEnglish,
            style: AppTypography.headlineMedium.copyWith(
              color: round.card.category.darkColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.startsWithWhichLetter,
            style: AppTypography.titleMedium.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}
