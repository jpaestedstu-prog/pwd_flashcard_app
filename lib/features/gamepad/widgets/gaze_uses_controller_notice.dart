import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../gaze_control/providers/gaze_settings_provider.dart';

/// Says so on the Game Controller pages while **Gaze Control is using the
/// controller as its switch** — then any button picks what is lit and the
/// stick moves the highlight, which is not what those pages describe.
///
/// A learner at the tablet opened the controller's button guide (R1 opens, L1
/// goes back, A yes, B no) and the practice screen while switch scanning had
/// the controller, found that none of it matched what the buttons did, and
/// could not tell why. [practising]: the practice screen's wording — there a
/// press picks what is lit instead of being practised.
class GazeUsesControllerNotice extends ConsumerWidget {
  const GazeUsesControllerNotice({super.key, this.practising = false});

  final bool practising;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inUse = ref.watch(
      gazeSettingsProvider.select((s) => s.enabled && s.switchSelects),
    );
    if (!inUse) return const SizedBox.shrink();
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final color = HCColor.of(context).primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.visibility_rounded, color: color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.gpGazeUsesTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(practising ? t.gpGazeUsesPractice : t.gpGazeUsesBody),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
