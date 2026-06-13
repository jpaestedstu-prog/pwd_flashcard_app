import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/responsive_utils.dart';
import '../l10n/app_localizations.dart';
import 'app_action_bar.dart';

/// A pair of large, single-tap "listen" buttons — one per language — that let a
/// learner hear the current word read aloud in the language they understand.
///
/// This is the accessible alternative to a shake / device-motion gesture:
/// motion actuation is unreliable for motor-impaired learners and is
/// discouraged by WCAG 2.1 Success Criterion 2.5.4. Showing BOTH languages
/// explicitly — rather than hiding the language behind the card's flip state —
/// means a student who only understands one language can always reach it
/// directly, in a single tap.
///
/// Laid out with [AppActionBar] in equal-width mode, so the two buttons share
/// the width and stack vertically on a narrow tablet / large font scale instead
/// of overflowing — keeping it safe on every Android tablet and font size.
class LanguageReplayBar extends StatelessWidget {
  /// Called when the learner taps the English button. Caller should speak the
  /// English word via the TTS service.
  final VoidCallback onEnglish;

  /// Called when the learner taps the Filipino button. Caller should speak the
  /// Filipino word via the TTS service.
  final VoidCallback onFilipino;

  const LanguageReplayBar({
    super.key,
    required this.onEnglish,
    required this.onFilipino,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AppActionBar(
      equalWidth: true,
      children: [
        // English — blue, matching the English listen affordances elsewhere.
        _LanguageButton(
          label: l.english,
          color: AppColors.info,
          onTap: onEnglish,
        ),
        // Filipino — the secondary (warm) colour, matching the card-back
        // Filipino listen button.
        _LanguageButton(
          label: l.filipino,
          color: AppColors.secondary,
          onTap: onFilipino,
        ),
      ],
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      // e.g. "Replay, English" / "Replay, Filipino" so the purpose and the
      // language are both announced to screen-reader users.
      label: '${l.replay}, $label',
      child: ExcludeSemantics(
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            // 56dp floor keeps the target comfortably above the 48dp
            // accessibility minimum; the icon + label still grow with the
            // Font Size setting.
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: Icon(Icons.volume_up_rounded, size: context.scaleIcon(22)),
          // FilledButton.icon already wraps the label in a Flexible, so we pass
          // a bare Text; maxLines + ellipsis let a long translation shrink to
          // fit instead of throwing a horizontal RenderFlex overflow.
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
