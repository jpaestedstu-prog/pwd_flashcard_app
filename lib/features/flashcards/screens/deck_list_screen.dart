import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/flashcard_export_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';

class DeckListScreen extends ConsumerWidget {
  const DeckListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final progress = ref.watch(progressProvider);
    final padding = context.pagePadding;
    final isTeacherOrParent =
        profile?.role == UserRole.teacher || profile?.role == UserRole.parent;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.flashcardDecks, style: AppTypography.headlineLarge)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: -0.05, end: 0),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.chooseCategory,
                      style: AppTypography.bodyMedium.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                    if (isTeacherOrParent) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ActionChip(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Browse templates',
                            onTap: () => context.go('/flashcards/templates'),
                          ),
                          _ActionChip(
                            icon: Icons.file_upload_rounded,
                            label: AppLocalizations.of(context)!.importLabel,
                            onTap: () async {
                              final count =
                                  await FlashcardExportService.importCards();
                              if (!context.mounted) return;
                              if (count > 0) {
                                ref.invalidate(allFlashcardsProvider);
                                AppSnackBar.success(context, message: AppLocalizations.of(context)!.importedCards(count));
                              } else if (count == 0) {
                                AppSnackBar.info(context, message: AppLocalizations.of(context)!.noDuplicates);
                              } else {
                                AppSnackBar.error(context, message: AppLocalizations.of(context)!.importFailed);
                              }
                            },
                          ),
                          _ActionChip(
                            icon: Icons.file_download_rounded,
                            label: AppLocalizations.of(context)!.exportLabel,
                            onTap: () async {
                              await FlashcardExportService.exportCards();
                            },
                          ),
                        ],
                      ).animate().fadeIn(duration: 350.ms, delay: 200.ms),
                    ],
                  ],
                ),
              ),
            ),

            // ─── Category Decks ─────────────────
            SliverPadding(
              padding: EdgeInsets.all(padding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.gridColumns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  // Cards grow taller with text scale so the icon + two
                  // labels + stats row + progress bar can't overflow at XL.
                  childAspectRatio: ((context.isTablet ? 1.6 : 1.4) /
                          MediaQuery.textScalerOf(context).scale(1.0))
                      .clamp(0.9, 1.7),
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final category = FlashcardCategory.values[index];
                  final cards = SeedData.getByCategory(category);
                  final prog = progress.categoryProgress[category.label] ??
                      progress.categoryProgress[category.name] ??
                      0.0;

                  return _DeckCard(
                        category: category,
                        cardCount: cards.length,
                        progress: prog,
                        onTap: () =>
                            context.go('/flashcards/viewer/${category.index}'),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (200 + index * 80).ms)
                      .slideY(begin: 0.12, end: 0)
                      .scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1.0, 1.0),
                      );
                }, childCount: FlashcardCategory.values.length),
              ),
            ),
          ],
        ),
      ),
      // FAB for teacher/parent to create custom cards
      floatingActionButton: isTeacherOrParent
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/flashcards/create'),
              icon: const Icon(Icons.add_rounded),
              label: Text(AppLocalizations.of(context)!.createCard),
            ).animate().scale(
              begin: const Offset(0, 0),
              end: const Offset(1, 1),
              delay: 800.ms,
              duration: 400.ms,
              curve: Curves.elasticOut,
            )
          : null,
    );
  }
}

class _DeckCard extends StatefulWidget {
  final FlashcardCategory category;
  final int cardCount;
  final double progress;
  final VoidCallback onTap;

  const _DeckCard({
    required this.category,
    required this.cardCount,
    required this.progress,
    required this.onTap,
  });

  @override
  State<_DeckCard> createState() => _DeckCardState();
}

class _DeckCardState extends State<_DeckCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final catColor = widget.category.color;
    final darkColor = widget.category.darkColor;
    final isMastered = widget.progress >= 0.9;

    return Semantics(
      button: true,
      label:
          '${widget.category.label} deck. '
          '${widget.cardCount} cards. '
          '${(widget.progress * 100).round()} percent complete.',
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Card(
            elevation: _pressed ? 1 : 4,
            shadowColor: catColor.withValues(alpha: 0.35),
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                // ── Full gradient background ──
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [darkColor, catColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),

                // ── Wave decoration ──
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DeckWavePainter(
                      color: Colors.white.withValues(alpha: 0.10),
                      seed: widget.category.index,
                    ),
                  ),
                ),

                // ── Decorative blob (top-right) ──
                Positioned(
                  top: -18,
                  right: -18,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),

                // ── Decorative blob (bottom-left) ──
                Positioned(
                  bottom: -12,
                  left: -12,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),

                // ── Content ──
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Top section: icon + category label
                        Expanded(
                          flex: 3,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Frosted icon container
                              Flexible(
                                child: Container(
                                  width: context.scaleIcon(48),
                                  height: context.scaleIcon(48),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    widget.category.icon,
                                    size: context.scaleIcon(24),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.category.label,
                                    style: AppTypography.titleLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.category.labelFilipino,
                                    style: AppTypography.bodySmall.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bottom section: stats + progress
                        Expanded(
                          flex: 2,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Cards count + progress chip row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_stories_rounded,
                                          size: context.scaleIcon(14),
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '${widget.cardCount} cards',
                                            style: AppTypography.labelSmall
                                                .copyWith(
                                              color: Colors.white
                                                  .withValues(alpha: 0.9),
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Progress chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isMastered) ...[
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: context.scaleIcon(12),
                                            color: Colors.white.withValues(alpha: 0.9),
                                          ),
                                          const SizedBox(width: 3),
                                        ],
                                        Text(
                                          '${(widget.progress * 100).round()}%',
                                          style: AppTypography.labelSmall.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Glowing progress bar
                              SizedBox(
                                height: 6,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: Stack(
                                    children: [
                                      Container(
                                        color: Colors.white.withValues(alpha: 0.15),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: widget.progress.clamp(0, 1),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(3),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withValues(alpha: 0.4),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wave painter for deck cards — similar to EnhancedCategoryCard.
class _DeckWavePainter extends CustomPainter {
  _DeckWavePainter({required this.color, required this.seed});

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final phase = seed * 0.7;
    final amplitude = size.height * (0.10 + (seed % 3) * 0.03);

    // Primary wave
    final path1 = Path()..moveTo(0, size.height * 0.55);
    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height * 0.55 +
          amplitude * math.sin((x / size.width * 2 * math.pi) + phase);
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint);

    // Secondary wave (softer)
    final paint2 = Paint()
      ..color = color.withValues(alpha: color.a * 0.5)
      ..style = PaintingStyle.fill;

    final path2 = Path()..moveTo(0, size.height * 0.65);
    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height * 0.65 +
          amplitude *
              0.6 *
              math.sin((x / size.width * 2.5 * math.pi) + phase + 1.8);
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);

    // Decorative dots
    final dotPaint = Paint()..color = color.withValues(alpha: color.a * 0.4);
    final rng = math.Random(seed);
    for (int i = 0; i < 4; i++) {
      final dx = size.width * (0.05 + rng.nextDouble() * 0.35);
      final dy = size.height * (0.05 + rng.nextDouble() * 0.25);
      final r = 1.5 + rng.nextDouble() * 2.5;
      canvas.drawCircle(Offset(dx, dy), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_DeckWavePainter oldDelegate) => false;
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label custom flashcards',
      child: ActionChip(
        avatar: Icon(icon, size: context.scaleIcon(18), color: AppColors.primary),
        label: Text(label,
            style: AppTypography.labelMedium
                .copyWith(color: AppColors.primary)),
        backgroundColor: AppColors.primaryLight,
        side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        onPressed: onTap,
      ),
    );
  }
}