import 'package:flutter/material.dart';

import '../../../core/accessibility/learner_support.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/fit_text.dart';
import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../onboarding/widgets/learner_support_picker.dart';
import 'accessibility_category_picker.dart';

/// One learner's accessibility needs, as their Teacher or Parent picks them.
typedef LearnerAccessibilityChoice = ({
  DisabilityType type,
  Set<LearnerSupportOption> supports,
});

/// Lets a Teacher or a Parent set one learner's accessibility needs from
/// Manage Classes or Home Groups: the category, which shapes the learner's
/// content and themes, and the supports within it — the sign system they
/// use, how they use the screen, what they need in a test. These are what
/// the learner's own setup wizard used to ask; a Student's or a Child's are
/// their educator's to manage now.
///
/// Opens on [type] and [supports], the learner's current needs. Returns the
/// choice, or null when cancelled. Saving an unchanged choice is allowed: it
/// sets the learner up afresh, the way re-running setup did.
Future<LearnerAccessibilityChoice?> showLearnerAccessibilityDialog(
  BuildContext context, {
  required String learnerName,
  required DisabilityType type,
  required Set<LearnerSupportOption> supports,
}) {
  return showDialog<LearnerAccessibilityChoice>(
    context: context,
    builder: (_) => LearnerAccessibilityDialog(
      learnerName: learnerName,
      type: type,
      supports: supports,
    ),
  );
}

/// The dialog [showLearnerAccessibilityDialog] opens; public so its layout
/// can be checked on its own.
class LearnerAccessibilityDialog extends StatefulWidget {
  const LearnerAccessibilityDialog({
    super.key,
    required this.learnerName,
    required this.type,
    required this.supports,
  });

  final String learnerName;
  final DisabilityType type;
  final Set<LearnerSupportOption> supports;

  @override
  State<LearnerAccessibilityDialog> createState() =>
      _LearnerAccessibilityDialogState();
}

class _LearnerAccessibilityDialogState
    extends State<LearnerAccessibilityDialog> {
  late DisabilityType _type = widget.type;
  late Set<LearnerSupportOption> _supports =
      LearnerSupportCatalog.normalize(widget.type, widget.supports);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final title = t.lamTitle(widget.learnerName);
    final pickers = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccessibilityCategoryPicker(
          selected: _type,
          caption: t.lamCaption(widget.learnerName),
          // The supports on offer change with the category; keep what
          // still applies and fill the rest from the category defaults,
          // as Edit Profile does.
          onChanged: (type) => setState(() {
            _type = type;
            _supports = LearnerSupportCatalog.normalize(type, _supports);
          }),
        ),
        const SizedBox(height: 16),
        LearnerSupportPicker(
          disabilityType: _type,
          selected: _supports,
          dense: true,
          onChanged: (next) => setState(() => _supports = next),
        ),
        const SizedBox(height: 12),
        Text(
          t.lamApplyNote(widget.learnerName),
          style: AppTypography.bodySmall.copyWith(
            color: HCColor.of(context).textSecondary,
          ),
        ),
      ],
    );
    void save() =>
        Navigator.of(context).pop((type: _type, supports: _supports));
    final headingStyle =
        AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700);

    // On a phone the pickers need the screen's whole width — Edit Profile's
    // gutters, where they are proven at the largest text size. Inside a
    // dialog's margins their words broke ("Lan / guage").
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
            actions: [
              TextButton(onPressed: save, child: Text(t.gmSave)),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Whole words, however long the name: at a large text
                  // size a plain title broke "access / ibility".
                  Semantics(
                    header: true,
                    child: FitText(title, maxLines: null, style: headingStyle),
                  ),
                  const SizedBox(height: 16),
                  pickers,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      // Title, pickers and note scroll together; the buttons stay put.
      scrollable: true,
      // A plain Text: a dialog measures its title's intrinsic width, which a
      // FitText cannot give; from 600 dp up a whole word fits anyway.
      title: Text(title, style: headingStyle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: pickers,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.hubCancel),
        ),
        FilledButton(onPressed: save, child: Text(t.gmSave)),
      ],
    );
  }
}
