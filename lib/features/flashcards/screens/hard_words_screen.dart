import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/rich_empty_states.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../../../data/models/models.dart';
import '../../../data/models/enums.dart';
import '../providers/hard_words_provider.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/fullscreen_host.dart';

class HardWordsScreen extends ConsumerWidget {
  const HardWordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hardWords = ref.watch(hardWordsProvider);
    final summary = ref.watch(srSummaryProvider);
    final hc = HCColor.of(context);

    return Scaffold(
      backgroundColor: hc.background,
      appBar: fullscreenBar(
        ref,
        AppBar(
          leading: const AppBackButton(),
          title: Text(
            'Hard Words',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (hardWords.isNotEmpty)
              TextButton.icon(
                onPressed: () => context.push('/smart-review'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Practice'),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── Summary Stats ──────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _StatChip(
                  label: 'Struggling',
                  value: '${summary.wordsStruggling}',
                  color: AppColors.error,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Attempted',
                  value: '${summary.totalAttempted}',
                  color: AppColors.secondary,
                  icon: Icons.quiz_rounded,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Correct',
                  value: '${summary.totalCorrect}',
                  color: AppColors.success,
                  icon: Icons.check_circle_rounded,
                ),
              ],
            ).animate().fadeIn(duration: 400.ms),
          ),

          // ─── Hard Words List ────────────────────
          Expanded(
            child: hardWords.isEmpty
                // Center the empty state, but let it scroll instead of
                // overflowing on a short viewport at a large font scale.
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: _EmptyState(),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: hardWords.length,
                    itemBuilder: (context, index) {
                      final (card, accuracy) = hardWords[index];
                      return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HardWordCard(
                              card: card,
                              accuracy: accuracy,
                              onTap: () => context.push(
                                '/flashcards/viewer/${card.category.index}',
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(
                            duration: 350.ms,
                            delay: Duration(milliseconds: 50 * index),
                          )
                          .slideX(begin: 0.05, end: 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const RichEmptyState(
      emoji: '🎉',
      title: 'No hard words!',
      description:
          'You\'re doing great! Keep playing games '
          'and words you struggle with will appear here.',
      accentColor: AppColors.success,
    );
  }
}

class _HardWordCard extends StatelessWidget {
  final Flashcard card;
  final WordAccuracy accuracy;
  final VoidCallback onTap;

  const _HardWordCard({
    required this.card,
    required this.accuracy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final pct = (accuracy.accuracy * 100).round();
    final catColor = card.category.color;

    // Color from red (0%) to amber (60%)
    final barColor = pct < 30
        ? AppColors.error
        : pct < 50
        ? AppColors.warning
        : Colors.amber;

    return Semantics(
      button: true,
      label:
          '${card.wordEnglish}, '
          '${card.wordFilipino}. '
          'Accuracy: $pct percent. '
          '${accuracy.correct} correct out of ${accuracy.total} attempts.',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Category indicator
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(card.category.icon, color: catColor, size: 22),
                ),
              ),
              const SizedBox(width: 12),

              // Word info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.wordEnglish,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    Text(
                      card.wordFilipino,
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Accuracy bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: accuracy.accuracy.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: hc.border,
                              color: barColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pct%',
                          style: AppTypography.labelSmall.copyWith(
                            color: barColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Attempt count
              Column(
                children: [
                  Text(
                    '${accuracy.correct}/${accuracy.total}',
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'correct',
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textHint,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
