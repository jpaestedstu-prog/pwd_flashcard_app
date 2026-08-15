import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../providers/app_providers.dart';
import '../models/recommendation_models.dart';
import '../providers/recommendation_provider.dart';
import '../../../widgets/app_back_button.dart';
import '../../../navigation/nav_extensions.dart';

/// Smart study recommendations screen that analyzes the student's data and
/// presents personalized, actionable suggestions on what to study next.
class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(recommendationProvider);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final hc = HCColor.of(context);
    final padding = context.pagePadding;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                child: Row(
                  children: [
                    AppBackButton(color: hc.textPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          isFilipino
                              ? 'Mga Rekomendasyon'
                              : 'What to Study Next',
                          style: AppTypography.headlineLarge.copyWith(
                            color: hc.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    // Refresh indicator
                    IconButton(
                      onPressed: () {
                        ref.invalidate(recommendationProvider);
                        final haptic = ref.read(hapticServiceProvider);
                        haptic.lightTap();
                      },
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: hc.textSecondary,
                      ),
                      tooltip: isFilipino ? 'I-refresh' : 'Refresh',
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
              ),
            ),

            // ─── Summary cards ───────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 12),
                child: snapshot.isNewUser
                    ? _NewUserBanner(isFilipino: isFilipino)
                    : _SummaryRow(snapshot: snapshot, isFilipino: isFilipino),
              ),
            ),

            // ─── Recommendation cards ────────────────
            if (snapshot.recommendations.isEmpty)
              SliverToBoxAdapter(child: _AllCaughtUp(isFilipino: isFilipino))
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
                sliver: SliverList.separated(
                  itemCount: snapshot.recommendations.length,
                  separatorBuilder: (context2, index2) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final rec = snapshot.recommendations[index];
                    return _RecommendationCard(
                      recommendation: rec,
                      isFilipino: isFilipino,
                      index: index,
                    );
                  },
                ),
              ),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Row ────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final RecommendationSnapshot snapshot;
  final bool isFilipino;

  const _SummaryRow({required this.snapshot, required this.isFilipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Row(
          children: [
            // Accuracy ring
            Expanded(
              child: _SummaryTile(
                child: Column(
                  children: [
                    CircularPercentIndicator(
                      radius: 30,
                      percent: snapshot.overallAccuracy.clamp(0, 1),
                      center: Text(
                        '${(snapshot.overallAccuracy * 100).round()}%',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: hc.textPrimary,
                        ),
                      ),
                      progressColor: AppColors.primary,
                      backgroundColor: hc.cardBackground,
                      circularStrokeCap: CircularStrokeCap.round,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isFilipino ? 'Accuracy' : 'Accuracy',
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Categories explored
            Expanded(
              child: _SummaryTile(
                child: Column(
                  children: [
                    Text(
                      '${snapshot.categoriesExplored}/${snapshot.totalCategories}',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFilipino ? 'Kategorya' : 'Categories',
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Words needing review
            Expanded(
              child: _SummaryTile(
                child: Column(
                  children: [
                    Text(
                      '${snapshot.wordsNeedingReview}',
                      style: AppTypography.headlineMedium.copyWith(
                        color: const Color(0xFFFFA726),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFilipino ? 'Balikan' : 'To Review',
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 100.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

class _SummaryTile extends StatelessWidget {
  final Widget child;
  const _SummaryTile({required this.child});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hc.border),
      ),
      child: child,
    );
  }
}

// ─── Recommendation Card ────────────────────────────────

class _RecommendationCard extends ConsumerWidget {
  final Recommendation recommendation;
  final bool isFilipino;
  final int index;

  const _RecommendationCard({
    required this.recommendation,
    required this.isFilipino,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final rec = recommendation;

    return GestureDetector(
          onTap: () => _navigate(context, ref),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hc.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: rec.priorityColor.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: rec.priorityColor.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Emoji circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: rec.priorityColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      rec.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Priority badge + title row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: rec.priorityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isFilipino
                                  ? rec.priorityLabelFilipino
                                  : rec.priorityLabel,
                              style: AppTypography.labelSmall.copyWith(
                                color: rec.priorityColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(rec.typeIcon, size: 14, color: hc.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isFilipino ? rec.titleFilipino : rec.title,
                        style: AppTypography.bodyLarge.copyWith(
                          color: hc.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFilipino ? rec.descriptionFilipino : rec.description,
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  color: rec.priorityColor.withValues(alpha: 0.6),
                  size: 24,
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: 150 + index * 80),
        )
        .slideX(begin: 0.05, end: 0);
  }

  void _navigate(BuildContext context, WidgetRef ref) {
    if (recommendation.route == null) return;

    try {
      final haptic = ref.read(hapticServiceProvider);
      haptic.lightTap();

      // Speak the title if TTS is enabled
      final settings = ref.read(settingsProvider);
      if (settings.ttsEnabled) {
        final tts = ref.read(ttsServiceProvider);
        final text = settings.locale == 'fil'
            ? recommendation.titleFilipino
            : recommendation.title;
        if (settings.locale == 'fil') {
          tts.speakFilipino(text).catchError((_) {});
        } else {
          tts.speakEnglish(text).catchError((_) {});
        }
      }

      final route = recommendation.route!;
      final params = recommendation.queryParams;

      // Push, so Back / back-swipe out of a recommended activity returns here
      // rather than dropping the learner on a hub. Every activity a
      // recommendation targets is either top-level or carries
      // `parentNavigatorKey: rootNavigatorKey` (the games and the flashcard
      // viewer), which is what makes pushing safe from outside the shell; the
      // one tab-root target ("Keep your streak" → /home) switches tabs instead.
      if (params != null && params.isNotEmpty) {
        final queryString = params.entries
            .map((e) => '${e.key}=${e.value}')
            .join('&');
        context.pushOrSwitchTab('$route?$queryString');
      } else {
        context.pushOrSwitchTab(route);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Recommendation navigation error: $e');
      }
    }
  }
}

// ─── New User Banner ────────────────────────────────────

class _NewUserBanner extends StatelessWidget {
  final bool isFilipino;
  const _NewUserBanner({required this.isFilipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.secondary.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const Text('🌟', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                isFilipino ? 'Maligayang Pagdating!' : 'Welcome!',
                style: AppTypography.headlineMedium.copyWith(
                  color: hc.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFilipino
                    ? 'Magsimula tayo sa iyong unang kategorya ng '
                          'bokabularyo. Piliin ang isa sa mga rekomendasyon '
                          'sa ibaba!'
                    : 'Let\'s get started with your first vocabulary '
                          'category. Pick one of the suggestions below!',
                style: AppTypography.bodyMedium.copyWith(
                  color: hc.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }
}

// ─── All Caught Up State ────────────────────────────────

class _AllCaughtUp extends StatelessWidget {
  final bool isFilipino;
  const _AllCaughtUp({required this.isFilipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            isFilipino ? 'Lahat ay Ayos Na!' : 'All Caught Up!',
            style: AppTypography.headlineMedium.copyWith(color: hc.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            isFilipino
                ? 'Natapos mo na ang lahat ng kasalukuyang '
                      'rekomendasyon. Magaling! Bumalik mamaya para '
                      'sa mga bagong mungkahi.'
                : 'You\'ve completed all current recommendations. '
                      'Great work! Check back later for new suggestions.',
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(duration: 600.ms),
    );
  }
}
