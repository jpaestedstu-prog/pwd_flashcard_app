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

/// Yes or No
///
/// A picture and a word are shown together; the learner decides whether they
/// match. Two permanently-placed, oversized targets — Yes on the left, No on
/// the right — so the answer never moves between rounds. That stability is the
/// point: it is the lowest-precision game in the app, which is what makes it
/// the lead game for the Motor and Multiple Disabilities rosters.
class YesOrNoScreen extends TapQuizScreen {
  const YesOrNoScreen({
    super.key,
    super.difficulty,
    super.categories,
    super.timedMode,
    super.resume,
  });

  @override
  ConsumerState<YesOrNoScreen> createState() => _YesOrNoScreenState();
}

class _YesOrNoScreenState extends TapQuizState<YesOrNoScreen> {
  @override
  GameType get gameType => GameType.yesOrNo;

  @override
  int get choiceColumns => 2;

  // The picture needs the room here; the two buttons are wide, not tall.
  @override
  int get promptFlex => 4;

  @override
  int get choicesFlex => 2;

  @override
  TapQuizRound? buildRound(
    Flashcard card,
    List<Flashcard> pool,
    Random random,
  ) {
    // Half the rounds show the true word, half a decoy — otherwise "Yes" alone
    // would score 100%.
    final isMatch = random.nextBool();
    Flashcard? decoy;
    if (!isMatch) {
      // Prefer a decoy from another category: at Easy the mismatch should be
      // obvious rather than a near-miss between two animals.
      final crossCategory = pool
          .where((c) => c.category != card.category)
          .toList();
      final source = widget.difficulty == GameDifficulty.easy
          ? (crossCategory.isNotEmpty ? crossCategory : pool)
          : pool;
      if (source.isEmpty) return null;
      decoy = source[random.nextInt(source.length)];
    }
    final shown = decoy ?? card;
    return TapQuizRound(
      card: card,
      // `labelOf` rather than `label`: rounds are built in initState, which
      // is too early to look up AppLocalizations.
      choices: [
        TapChoice(
          labelOf: (l10n) => l10n.answerYes,
          icon: Icons.check_circle_rounded,
          tint: AppColors.successLight,
        ),
        TapChoice(
          labelOf: (l10n) => l10n.answerNo,
          icon: Icons.cancel_rounded,
          tint: AppColors.errorLight,
        ),
      ],
      correctIndex: isMatch ? 0 : 1,
      payload: shown,
    );
  }

  Flashcard _shown(TapQuizRound round) => round.payload as Flashcard;

  @override
  String promptSemantics(AppLocalizations l10n, TapQuizRound round) =>
      l10n.yesNoQuestion(
        round.card.wordEnglish,
        _shown(round).wordEnglish,
        _shown(round).wordFilipino,
      );

  @override
  Widget buildPrompt(BuildContext context, TapQuizRound round) {
    final l10n = AppLocalizations.of(context)!;
    final hc = HCColor.of(context);
    final shown = _shown(round);
    return promptPanel(
      context,
      // Tint by the pictured card, never by the word on show — a decoy from
      // another category would otherwise recolour the panel and give the
      // answer away before the learner reads anything.
      round.card.category.color,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FlashcardImage(card: round.card, size: 96),
          const SizedBox(height: 16),
          Text(
            l10n.isThisPrompt,
            style: AppTypography.titleMedium.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            shown.wordEnglish,
            style: AppTypography.headlineMedium.copyWith(
              color: round.card.category.darkColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            shown.wordFilipino,
            style: AppTypography.bodyLarge.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}
