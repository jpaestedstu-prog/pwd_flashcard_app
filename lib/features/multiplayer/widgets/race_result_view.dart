import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/multiplayer_models.dart';

/// Star-free head-to-head result screen shared by the local and online race
/// flows. Shows who won (or a draw), both scores, and Home / Rematch actions.
/// Awards nothing — purely a celebration of the match just played.
///
/// Overflow-proof: a single scroll view with `FittedBox` scores and a
/// two-card row that fits any width.
class RaceResultView extends StatelessWidget {
  final String player1Name;
  final int player1Score;
  final String player2Name;
  final int player2Score;
  final MpGameMode mode;
  final bool isFilipino;

  /// Shown only when non-null (local play + online host can rematch).
  final VoidCallback? onRematch;
  final VoidCallback onHome;

  const RaceResultView({
    super.key,
    required this.player1Name,
    required this.player1Score,
    required this.player2Name,
    required this.player2Score,
    required this.mode,
    required this.onHome,
    this.onRematch,
    this.isFilipino = false,
  });

  @override
  Widget build(BuildContext context) {
    final outcome = computeOutcome(player1Score, player2Score);
    final isDraw = outcome == MpOutcome.draw;
    final p1Wins = outcome == MpOutcome.player1;
    final winnerName = isDraw ? null : (p1Wins ? player1Name : player2Name);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(isDraw ? '🤝' : '🏆', style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isDraw
                    ? (isFilipino ? 'Tabla!' : "It's a draw!")
                    : (isFilipino ? '$winnerName ang panalo!' : '$winnerName wins!'),
                style: AppTypography.displaySmall.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${mode.emoji} ${isFilipino ? mode.labelFilipino : mode.label}',
              style: AppTypography.bodyMedium.copyWith(
                color: HCColor.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            // IntrinsicHeight gives the Row a bounded height inside the
            // vertical scroll view, so `stretch` can equalise the two cards
            // without hitting an infinite-height constraint.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ScoreCard(
                      name: player1Name,
                      score: player1Score,
                      color: AppColors.info,
                      isWinner: !isDraw && p1Wins,
                      isFilipino: isFilipino,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ScoreCard(
                      name: player2Name,
                      score: player2Score,
                      color: AppColors.error,
                      isWinner: !isDraw && !p1Wins,
                      isFilipino: isFilipino,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onHome,
                    icon: const Icon(Icons.home_rounded),
                    label: Text(isFilipino ? 'Tapos na' : 'Done'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                if (onRematch != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onRematch,
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(isFilipino ? 'Ulitin!' : 'Rematch!'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String name;
  final int score;
  final Color color;
  final bool isWinner;
  final bool isFilipino;

  const _ScoreCard({
    required this.name,
    required this.score,
    required this.color,
    required this.isWinner,
    required this.isFilipino,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWinner ? color.withValues(alpha: 0.12) : hc.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWinner ? color : AppColors.border,
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWinner)
            const Text('👑', style: TextStyle(fontSize: 26))
          else
            const SizedBox(height: 26),
          const SizedBox(height: 4),
          Text(
            name,
            style: AppTypography.titleSmall
                .copyWith(fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$score',
              style: AppTypography.displayMedium.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Text(
            isFilipino ? 'puntos' : 'points',
            style:
                AppTypography.labelSmall.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}
