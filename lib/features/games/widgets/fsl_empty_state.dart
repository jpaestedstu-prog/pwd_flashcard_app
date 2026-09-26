import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/fullscreen_host.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
            tooltip: l10n.close,
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
                child: Icon(
                  Icons.sign_language_rounded,
                  size: 48,
                  color: HCColor.of(context).primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _t(context).feSoon,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _t(context).feRecording,
                style: AppTypography.bodyMedium.copyWith(
                  color: hc.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (readyCategories.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  _t(context).feReady,
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
                              cat.labelOf(l10n),
                              style: AppTypography.labelMedium.copyWith(
                                color: HCColor.of(context).readableOver(cat.darkColor, cat.darkColor.withValues(alpha: 0.4)),
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
                child: Text(_t(context).feChooseAnother),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
