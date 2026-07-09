import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';

/// Shows a modal that lets a teacher / parent change the accessibility
/// category for an existing class or home group.
///
/// Returns the newly-chosen [DisabilityType], or `null` if the educator
/// cancelled or kept the same value. Affects future joiners only — already
/// enrolled learners keep the profile they were assigned (called out in the
/// dialog copy).
Future<DisabilityType?> showAccessibilityCategoryDialog(
  BuildContext context, {
  required DisabilityType current,
}) {
  return showDialog<DisabilityType>(
    context: context,
    builder: (_) => _AccessibilityCategoryDialog(current: current),
  );
}

/// Small pill showing the accessibility audience assigned to a class /
/// home group. Shared between the classroom and home-group roster screens.
class AccessibilityCategoryChip extends StatelessWidget {
  final DisabilityType type;

  const AccessibilityCategoryChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: type.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${type.emoji} ${type.label}',
        style: AppTypography.labelMedium.copyWith(
          color: type.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AccessibilityCategoryDialog extends StatefulWidget {
  final DisabilityType current;
  const _AccessibilityCategoryDialog({required this.current});

  @override
  State<_AccessibilityCategoryDialog> createState() =>
      _AccessibilityCategoryDialogState();
}

class _AccessibilityCategoryDialogState
    extends State<_AccessibilityCategoryDialog> {
  late DisabilityType _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Accessibility'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccessibilityCategoryPicker(
              selected: _selected,
              onChanged: (t) => setState(() => _selected = t),
            ),
            const SizedBox(height: 12),
            Text(
              'Applies to learners who join from now on. Anyone already '
              'enrolled keeps their current setup.',
              style: AppTypography.bodySmall.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected == widget.current
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Compact accessibility-category selector shown when a teacher / parent
/// creates or edits a class or home group.
///
/// The chosen [DisabilityType] is stored on the Classroom / HomeGroup and
/// auto-assigned to every learner who joins via the code (see
/// `post_join_setup_screen.dart`), so PWD students / children never have to
/// self-classify in a wizard. Reuses the labels / emoji / colours that
/// already live on [DisabilityTypeX] so this stays in lockstep with the
/// rest of the app's accessibility surfaces.
class AccessibilityCategoryPicker extends StatelessWidget {
  final DisabilityType selected;
  final ValueChanged<DisabilityType> onChanged;

  /// When false the chips render disabled (e.g. while a save is in flight).
  final bool enabled;

  const AccessibilityCategoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.accessibility_new_rounded, size: 18),
            const SizedBox(width: 6),
            Text(
              'Accessibility',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Students who join this code get this version of the app '
          'automatically — no setup needed on their side.',
          style: AppTypography.bodySmall.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in DisabilityType.values)
              ChoiceChip(
                label: Text('${type.emoji}  ${type.label}'),
                selected: selected == type,
                onSelected:
                    enabled ? (_) => onChanged(type) : null,
                labelStyle: AppTypography.labelMedium.copyWith(
                  color: selected == type ? type.color : null,
                  fontWeight:
                      selected == type ? FontWeight.w700 : FontWeight.w500,
                ),
                selectedColor: type.color.withValues(alpha: 0.16),
                side: BorderSide(
                  color: selected == type
                      ? type.color
                      : Colors.grey.withValues(alpha: 0.4),
                ),
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          selected.description,
          style: AppTypography.bodySmall.copyWith(
            color: Colors.grey.shade700,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
