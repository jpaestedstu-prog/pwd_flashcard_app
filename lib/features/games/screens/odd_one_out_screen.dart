import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../widgets/tap_quiz_game.dart';

/// Odd One Out
///
/// Three or four words are shown; all but one share a category. The learner
/// taps the one that doesn't belong. Pure categorisation — no reading of a
/// sentence, no spelling, no timing — which is why it carries across every
/// roster except the two that already have richer alternatives.
///
/// The category hint is shown on Easy only; at Medium and Hard the grouping
/// has to be worked out from the words themselves.
class OddOneOutScreen extends TapQuizScreen {
  const OddOneOutScreen({
    super.key,
    super.difficulty,
    super.categories,
    super.timedMode,
  });

  @override
  ConsumerState<OddOneOutScreen> createState() => _OddOneOutScreenState();
}

/// The shared category of the three (or two) words that *do* belong together.
class _OddPayload {
  final FlashcardCategory groupCategory;
  const _OddPayload(this.groupCategory);
}

class _OddOneOutScreenState extends TapQuizState<OddOneOutScreen> {
  @override
  GameType get gameType => GameType.oddOneOut;

  @override
  String get gameTitle => 'Odd One Out';

  @override
  int get choiceColumns => 2;

  @override
  int get promptFlex => 2;

  @override
  int get choicesFlex => 4;

  /// Words on screen per round: 3 at Easy, 4 otherwise.
  int get _choiceCount => widget.difficulty == GameDifficulty.easy ? 3 : 4;

  bool get _showHint => widget.difficulty == GameDifficulty.easy;

  @override
  TapQuizRound? buildRound(
    Flashcard card,
    List<Flashcard> pool,
    Random random,
  ) {
    // `card` is the odd one out. The rest come from one *other* category, so
    // the grouping is unambiguous — never two plausible answers.
    final groupSize = _choiceCount - 1;
    final byCategory = <FlashcardCategory, List<Flashcard>>{};
    for (final c in pool) {
      if (c.category == card.category) continue;
      byCategory.putIfAbsent(c.category, () => []).add(c);
    }
    final viable = byCategory.entries
        .where((e) => e.value.length >= groupSize)
        .toList();
    // Only one category selected in the picker, so no contrasting group can be
    // formed — the base class turns an empty round list into a "not enough
    // words" screen.
    if (viable.isEmpty) return null;

    final chosen = viable[random.nextInt(viable.length)];
    final group = (chosen.value..shuffle(random)).take(groupSize).toList();
    final words = [card, ...group]..shuffle(random);

    return TapQuizRound(
      card: card,
      choices: [
        for (final w in words)
          TapChoice(label: w.wordEnglish, sublabel: w.wordFilipino),
      ],
      correctIndex: words.indexWhere((w) => w.id == card.id),
      payload: _OddPayload(chosen.key),
    );
  }

  _OddPayload _payload(TapQuizRound round) => round.payload as _OddPayload;

  @override
  String promptSemantics(TapQuizRound round) {
    final words = round.choices.map((c) => c.label).join(', ');
    final hint = _showHint
        ? ' ${_choiceCount - 1} of them are ${_payload(round).groupCategory.label}.'
        : '';
    return 'Question: which word does not belong? The words are $words.$hint';
  }

  @override
  Widget buildPrompt(BuildContext context, TapQuizRound round) {
    final hc = HCColor.of(context);
    final payload = _payload(round);
    return promptPanel(
      context,
      // Tinted to the *group's* category, not the odd word's — tinting to the
      // answer would hand it over before the learner reads a thing.
      payload.groupCategory.color,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Which one does not belong?',
            style: AppTypography.headlineSmall.copyWith(
              color: hc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          if (_showHint) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: payload.groupCategory.color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_choiceCount - 1} are ${payload.groupCategory.label}',
                style: AppTypography.labelLarge.copyWith(
                  color: payload.groupCategory.darkColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
