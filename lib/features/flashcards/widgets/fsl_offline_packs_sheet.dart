import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../providers/fsl_offline_packs.dart';

/// Opens the "Offline Signs" manager — per-category download / clear for the
/// FSL clips the dictionary plays.
Future<void> showFslOfflinePacksSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const FslOfflinePacksSheet(),
  );
}

/// Lets a learner or teacher put sign videos on the tablet before they need
/// them, and give the space back afterwards.
///
/// See [FslOfflinePacksNotifier] for why this exists: no clip ships with the
/// app, so without a pack the dictionary is only as good as the connection.
class FslOfflinePacksSheet extends ConsumerStatefulWidget {
  const FslOfflinePacksSheet({super.key});

  @override
  ConsumerState<FslOfflinePacksSheet> createState() =>
      _FslOfflinePacksSheetState();
}

class _FslOfflinePacksSheetState extends ConsumerState<FslOfflinePacksSheet> {
  @override
  void initState() {
    super.initState();
    // Scan on open rather than keeping a running total honest across evictions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fslOfflinePacksProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final state = ref.watch(fslOfflinePacksProvider);
    final notifier = ref.read(fslOfflinePacksProvider.notifier);
    final scanned = state.byCategory.isNotEmpty;

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: hc.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    _header(context, hc),
                    const SizedBox(height: 20),
                    if (!scanned)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      _summary(context, hc, state, notifier),
                      const SizedBox(height: 20),
                      Text(
                        'By category',
                        style: AppTypography.labelMedium.copyWith(
                          color: hc.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final category in FlashcardCategory.values)
                        _CategoryRow(
                          category: category,
                          coverage:
                              state.byCategory[category] ??
                              const FslPackCoverage(),
                          state: state,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, HCColor hc) => Row(
    children: [
      Icon(
        Icons.download_for_offline_rounded,
        color: AppColors.secondaryDark,
        size: context.scaleIcon(28),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Offline Signs', style: AppTypography.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Save sign videos to this device so they play without internet.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _summary(
    BuildContext context,
    HCColor hc,
    FslOfflinePacksState state,
    FslOfflinePacksNotifier notifier,
  ) {
    final ready = state.totalReady;
    final total = state.totalDownloadable;
    final allDone = total > 0 && ready >= total;
    // A whole-library run shows its progress here; a single-category run shows
    // it on that category's own row instead.
    final runningHere = state.isBusy && state.busyCategory == null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$ready of $total signs saved',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            state.totalBytes > 0
                ? 'Using ${formatPackBytes(state.totalBytes)} on this device'
                : 'Nothing saved yet',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 12),
          if (runningHere) ...[
            LinearProgressIndicator(
              value: state.fraction,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              'Saving "${state.label}"… ${state.done} of ${state.total}',
              style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: notifier.cancel,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop'),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                // Disabled while a single category runs, so two download loops
                // can never race for the same clips.
                onPressed: state.isBusy || allDone
                    ? null
                    : notifier.downloadAll,
                icon: Icon(
                  allDone ? Icons.check_circle_rounded : Icons.download_rounded,
                ),
                label: Text(
                  allDone ? 'All signs saved' : 'Save all ${total - ready}',
                ),
              ),
            ),
          if (state.failed > 0 && !state.isBusy) ...[
            const SizedBox(height: 8),
            Text(
              "${state.failed} couldn't be saved — check the connection and "
              'try again. Those words still work online.',
              style: AppTypography.labelSmall.copyWith(color: hc.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  final FlashcardCategory category;
  final FslPackCoverage coverage;
  final FslOfflinePacksState state;

  const _CategoryRow({
    required this.category,
    required this.coverage,
    required this.state,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final notifier = ref.read(fslOfflinePacksProvider.notifier);
    final busyHere = state.isBusy && state.busyCategory == category;
    // No sign has been recorded for any word here yet (Actions, today) — there
    // is nothing to offer, and a dead download button would just mislead.
    final nothingToOffer = coverage.downloadable == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            category.icon,
            color: category.color,
            size: context.scaleIcon(20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nothingToOffer
                      ? 'No signs recorded yet'
                      : busyHere
                      ? 'Saving "${state.label}"… ${state.done} of ${state.total}'
                      : '${coverage.ready} of ${coverage.downloadable} saved'
                            '${coverage.bytes > 0 ? ' · ${formatPackBytes(coverage.bytes)}' : ''}',
                  style: AppTypography.labelSmall.copyWith(
                    color: coverage.isComplete && !busyHere
                        ? hc.success
                        : hc.textSecondary,
                  ),
                ),
                if (busyHere) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: state.fraction,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ],
            ),
          ),
          if (!nothingToOffer) ...[
            const SizedBox(width: 8),
            if (busyHere)
              IconButton(
                onPressed: notifier.cancel,
                icon: const Icon(Icons.stop_circle_rounded),
                tooltip: 'Stop',
                color: hc.warning,
              )
            else ...[
              if (!coverage.isComplete)
                IconButton(
                  onPressed: state.isBusy
                      ? null
                      : () => notifier.downloadCategory(category),
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Save ${category.label} offline',
                  color: AppColors.secondary,
                ),
              if (!coverage.isEmpty)
                IconButton(
                  onPressed: state.isBusy
                      ? null
                      : () => notifier.clearCategory(category),
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Remove ${category.label} downloads',
                  color: hc.textSecondary,
                ),
            ],
          ],
        ],
      ),
    );
  }
}
