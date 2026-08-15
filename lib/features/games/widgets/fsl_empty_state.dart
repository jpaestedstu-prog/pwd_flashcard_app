import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/fullscreen_host.dart';

/// Friendly empty state shown when an FSL game can't run with the user's
/// chosen categories — usually because that category doesn't have enough
/// FSL videos bundled yet.
///
/// Lists the categories that *are* ready so the user has a clear next
/// step instead of just "Go Back".
class FslEmptyStateScaffold extends ConsumerWidget {
  /// Game title shown in the AppBar.
  final String title;

  /// Called when the user taps Close or the "Go Back" button. Should
  /// return to the FSL practice hub.
  final VoidCallback onClose;

  const FslEmptyStateScaffold({
    super.key,
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final availability = ref.watch(fslAvailabilityProvider);

    final readyCategories = availability.maybeWhen(
      data: (a) =>
          a.playableCategories().toList()
            ..sort((x, y) => x.label.compareTo(y.label)),
      orElse: () => const <FlashcardCategory>[],
    );

    return Scaffold(
      appBar: fullscreenBar(
        ref,
        AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: onClose,
          ),
          title: Text(title),
        ),
      ),
      body: Center(
        // Scrolls when the category chips outgrow a short viewport (phone
        // landscape, large font scales) instead of overflowing.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sign_language_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'FSL videos coming soon',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "We're still recording sign-language videos for these "
                'categories. Practice with the flashcards in the meantime!',
                style: AppTypography.bodyMedium.copyWith(
                  color: hc.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (readyCategories.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Ready to practice now:',
                  style: AppTypography.labelLarge.copyWith(
                    color: hc.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final cat in readyCategories)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cat.darkColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: cat.darkColor.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 16, color: cat.darkColor),
                            const SizedBox(width: 6),
                            Text(
                              cat.label,
                              style: AppTypography.labelMedium.copyWith(
                                color: cat.darkColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onClose,
                child: const Text('Choose another category'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
