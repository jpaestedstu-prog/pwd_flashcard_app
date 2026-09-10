import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import '../services/routine_service.dart';
import '../widgets/routine_media.dart';
import '../widgets/routine_step_card.dart';
import '../widgets/routine_sync_feedback.dart';
import 'routine_step_editor_sheet.dart';

/// Builds and edits one routine: its name, the days it runs, and its steps.
///
/// Steps are added from the catalog picker (fourteen ready activities, each
/// arriving with its own time, duration, visual instructions and FSL cues) or
/// as a custom activity the educator writes themselves. Reordering is a drag
/// **and** a pair of menu actions — the drag is comfortable for most educators,
/// and the menu is the path for anyone who cannot hold a long-press steady.
///
/// Saving is explicit. An educator editing a learner's morning at 6 a.m. should
/// not have half-finished changes syncing to a device the child is already
/// holding, so nothing leaves this screen until Save.
class RoutineBuilderScreen extends ConsumerStatefulWidget {
  final Routine routine;
  final String learnerNoun;
  final String? learnerName;

  const RoutineBuilderScreen({
    super.key,
    required this.routine,
    this.learnerNoun = 'learner',
    this.learnerName,
  });

  @override
  ConsumerState<RoutineBuilderScreen> createState() =>
      _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends ConsumerState<RoutineBuilderScreen> {
  late Routine _draft = widget.routine;
  late final TextEditingController _name = TextEditingController(
    text: widget.routine.name,
  );
  late final TextEditingController _nameFil = TextEditingController(
    text: widget.routine.nameFilipino,
  );

  bool _dirty = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _nameFil.dispose();
    super.dispose();
  }

  void _mutate(Routine next) {
    setState(() {
      _draft = next;
      _dirty = true;
    });
  }

  Future<void> _save(bool filipino) async {
    setState(() => _saving = true);
    final write = await const RoutineService().save(
      _draft.copyWith(
        name: _name.text.trim(),
        nameFilipino: _nameFil.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() {
      _dirty = false;
      _saving = false;
    });
    // The save always lands in Hive, so the screen closes either way — but
    // the educator is told when it stopped there.
    reportRoutineSync(
      context,
      write.outcome,
      filipino: filipino,
      subject: filipino ? 'routine' : 'routine',
    );
    Navigator.of(context).maybePop();
  }

  Future<bool> _confirmDiscard(bool l) async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l ? 'Itapon ang mga pagbabago?' : 'Discard changes?'),
        content: Text(
          l
              ? 'Hindi pa nase-save ang mga pagbabago sa routine na ito.'
              : 'Your changes to this routine have not been saved yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l ? 'Bumalik' : 'Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l ? 'Itapon' : 'Discard'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = ref.watch(settingsProvider).locale == 'fil';
    final steps = _draft.editorSteps;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard(l) && mounted) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: AnimatedGradientBackground(
        intensity: 0.2,
        preset: GradientPreset.assessment,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              l ? 'Ayusin ang Routine' : 'Edit Routine',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: _saving || !_dirty ? null : () => _save(l),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(l ? 'I-save' : 'Save'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add_rounded),
            label: Text(l ? 'Magdagdag' : 'Add activity'),
            onPressed: () => _addStep(l),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                // ── Name & recurrence ──
                ProPanel(
                  title: l ? 'Tungkol sa Routine' : 'About this routine',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        onChanged: (_) => setState(() => _dirty = true),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: l ? 'Pangalan (English)' : 'Name',
                          hintText: l ? 'hal. Umaga' : 'e.g. Morning',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameFil,
                        onChanged: (_) => setState(() => _dirty = true),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: l
                              ? 'Pangalan sa Filipino'
                              : 'Filipino name (optional)',
                          hintText: 'hal. Rutina sa Umaga',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l ? 'Anong mga araw?' : 'Which days?',
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: hc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DayPicker(
                        days: _draft.daysOfWeek,
                        filipino: l,
                        onChanged: (d) =>
                            _mutate(_draft.copyWith(daysOfWeek: d)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ProSectionHeader(
                  title: l ? 'Mga Hakbang' : 'Steps',
                  subtitle: steps.isEmpty
                      ? (l
                            ? 'Magdagdag ng unang gawain'
                            : 'Add the first activity')
                      : (l
                            ? '${steps.length} hakbang · i-drag para ayusin'
                            : '${steps.length} steps · drag to reorder'),
                ),
                const SizedBox(height: 8),

                if (steps.isEmpty)
                  _EmptySteps(filipino: l, onAdd: () => _addStep(l))
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: steps.length,
                    onReorderItem: (oldIndex, newIndex) =>
                        _reorder(oldIndex, newIndex, adjusted: true),
                    itemBuilder: (context, i) {
                      final step = steps[i];
                      return _StepTile(
                        // The key must follow the *step*, not the index, or a
                        // reorder animates the wrong row.
                        key: ValueKey(step.id),
                        index: i,
                        step: step,
                        filipino: l,
                        canMoveUp: i > 0,
                        canMoveDown: i < steps.length - 1,
                        onEdit: () => _editStep(step, l),
                        onDelete: () => _deleteStep(step),
                        onMoveUp: () => _reorder(i, i - 1, adjusted: true),
                        onMoveDown: () => _reorder(i, i + 1, adjusted: true),
                        onToggleEnabled: (v) =>
                            _replaceStep(step.copyWith(enabled: v)),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Moves the step at [oldIndex] to [newIndex].
  ///
  /// [adjusted] means [newIndex] is already the destination *after* the item
  /// has been lifted out — the contract of `onReorderItem`, and the natural
  /// reading of "one row down" from the menu. The older `onReorder` contract
  /// (an index measured before the removal) needs the extra subtraction.
  void _reorder(int oldIndex, int newIndex, {bool adjusted = false}) {
    final steps = List<RoutineStep>.from(_draft.steps);
    if (oldIndex < 0 || oldIndex >= steps.length) return;
    if (!adjusted && newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, steps.length - 1);
    if (newIndex == oldIndex) return;
    final moved = steps.removeAt(oldIndex);
    steps.insert(newIndex, moved);
    _mutate(_draft.copyWith(steps: steps));
  }

  void _replaceStep(RoutineStep step) {
    final steps = [for (final s in _draft.steps) s.id == step.id ? step : s];
    _mutate(_draft.copyWith(steps: steps));
  }

  void _deleteStep(RoutineStep step) {
    _mutate(
      _draft.copyWith(
        steps: _draft.steps.where((s) => s.id != step.id).toList(),
      ),
    );
  }

  Future<void> _addStep(bool l) async {
    final activity = await showModalBottomSheet<RoutineActivity>(
      context: context,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityPicker(filipino: l),
    );
    if (activity == null || !mounted) return;

    final info = RoutineCatalog.infoFor(activity);
    final fresh = RoutineStep(
      id: const RoutineService().newId(),
      activity: activity,
      hour: info.defaultHour,
      minute: info.defaultMinute,
      durationMinutes: info.defaultDurationMinutes,
    );
    // A custom activity has no catalog content to inherit, so it goes straight
    // into the editor — an unnamed "Custom Activity" row would be useless.
    if (activity.isCustom) {
      final edited = await openRoutineStepEditor(
        context,
        step: fresh,
        filipino: l,
      );
      if (edited == null || !mounted) return;
      _mutate(_draft.copyWith(steps: [..._draft.steps, edited]));
      return;
    }
    _mutate(_draft.copyWith(steps: [..._draft.steps, fresh]));
  }

  Future<void> _editStep(RoutineStep step, bool l) async {
    final edited = await openRoutineStepEditor(
      context,
      step: step,
      filipino: l,
    );
    if (edited == null || !mounted) return;
    _replaceStep(edited);
  }
}

class _DayPicker extends StatelessWidget {
  final Set<int> days;
  final bool filipino;
  final ValueChanged<Set<int>> onChanged;

  const _DayPicker({
    required this.days,
    required this.filipino,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final labels = filipino
        ? const {
            1: 'Lun',
            2: 'Mar',
            3: 'Miy',
            4: 'Huw',
            5: 'Biy',
            6: 'Sab',
            7: 'Lin',
          }
        : const {
            1: 'Mon',
            2: 'Tue',
            3: 'Wed',
            4: 'Thu',
            5: 'Fri',
            6: 'Sat',
            7: 'Sun',
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap, not Row: seven chips at a large font scale are wider than a
        // phone, and a fixed row would overflow rather than wrap.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(labels[d]!),
                selected: days.contains(d),
                onSelected: (on) {
                  final next = Set<int>.from(days);
                  on ? next.add(d) : next.remove(d);
                  // All seven selected means the same thing as none: every
                  // day. Normalising keeps one representation in storage.
                  onChanged(next.length == 7 ? <int>{} : next);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.event_repeat_rounded, size: 16, color: hc.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                days.isEmpty
                    ? (filipino ? 'Tumatakbo araw-araw' : 'Runs every day')
                    : (filipino
                          ? 'Tumatakbo tuwing ${formatDays(days, filipino: true)}'
                          : 'Runs on ${formatDays(days, filipino: false)}'),
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ),
            if (days.isNotEmpty)
              TextButton(
                onPressed: () => onChanged(<int>{}),
                child: Text(filipino ? 'Araw-araw' : 'Every day'),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final RoutineStep step;
  final bool filipino;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<bool> onToggleEnabled;

  const _StepTile({
    super.key,
    required this.index,
    required this.step,
    required this.filipino,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = filipino;
    final title = RoutineCatalog.titleFor(step, filipino: l);
    final media = step.suppliedMedia;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: step.enabled
              ? hc.surface
              : Color.alphaBlend(
                  hc.textHint.withValues(alpha: 0.12),
                  hc.surface,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hc.textHint.withValues(alpha: 0.3)),
        ),
        // The Material goes *inside* the decoration, not outside it: a
        // tappable ListTile paints its ink on the nearest Material ancestor,
        // and a DecoratedBox between the two makes Flutter assert that the
        // splash will be invisible.
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            onTap: onEdit,
            leading: ReorderableDragStartListener(
              index: index,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.drag_indicator_rounded, color: hc.textHint),
                  const SizedBox(width: 4),
                  Text(
                    RoutineCatalog.emojiFor(step),
                    style: const TextStyle(fontSize: 26),
                  ),
                ],
              ),
            ),
            title: Text(
              title,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: hc.textPrimary,
                decoration: step.enabled ? null : TextDecoration.lineThrough,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (step.isScheduled)
                      formatStepTime(step)
                    else
                      (l ? 'Walang oras' : 'No set time'),
                    if (step.hasTimer)
                      l
                          ? '${step.durationMinutes} minuto'
                          : '${step.durationMinutes} min',
                  ].join(' · '),
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                if (media.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final k in media)
                          Icon(
                            RoutineMediaStyle.of(k).icon,
                            size: 14,
                            color: RoutineMediaStyle.of(k).color,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              tooltip: l ? 'Mga aksyon' : 'Step actions',
              icon: Icon(Icons.more_vert_rounded, color: hc.textSecondary),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    onEdit();
                  case 'up':
                    onMoveUp();
                  case 'down':
                    onMoveDown();
                  case 'hide':
                    onToggleEnabled(!step.enabled);
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => [
                _item('edit', Icons.edit_rounded, l ? 'I-edit' : 'Edit'),
                // The keyboard/switch path to reordering. The drag handle is
                // the fast way; this is the one that works for an educator who
                // cannot hold a long-press.
                if (canMoveUp)
                  _item(
                    'up',
                    Icons.arrow_upward_rounded,
                    l ? 'Itaas' : 'Move up',
                  ),
                if (canMoveDown)
                  _item(
                    'down',
                    Icons.arrow_downward_rounded,
                    l ? 'Ibaba' : 'Move down',
                  ),
                _item(
                  'hide',
                  step.enabled
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  step.enabled
                      ? (l ? 'Itago sa bata' : 'Hide from learner')
                      : (l ? 'Ipakita muli' : 'Show again'),
                ),
                _item(
                  'delete',
                  Icons.delete_outline_rounded,
                  l ? 'Burahin' : 'Delete',
                  color: AppColors.error,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: color == null ? null : TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySteps extends StatelessWidget {
  final bool filipino;
  final VoidCallback onAdd;

  const _EmptySteps({required this.filipino, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.textHint.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('🧩', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            filipino ? 'Wala pang hakbang' : 'No steps yet',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filipino
                ? 'Magdagdag ng gawain gaya ng pagsisipilyo o almusal.'
                : 'Add an activity like brushing teeth or breakfast.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(filipino ? 'Magdagdag' : 'Add activity'),
          ),
        ],
      ),
    );
  }
}

/// The activity picker: the fourteen built-in activities plus a custom one.
class _ActivityPicker extends StatelessWidget {
  final bool filipino;

  const _ActivityPicker({required this.filipino});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = filipino;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        // The sheet's own decoration sits between these tappable ListTiles and
        // the Scaffold's Material, which makes Flutter assert that their ink
        // splashes will be invisible. A transparent Material here is the
        // nearest ancestor they need.
        child: Material(
          type: MaterialType.transparency,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hc.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l ? 'Pumili ng gawain' : 'Choose an activity',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              for (final info in RoutineCatalog.pickable)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(
                    info.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  title: Text(
                    info.labelOf(filipino: l),
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hc.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    info.blurbOf(filipino: l),
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  trailing: info.signCues.isEmpty
                      ? null
                      : Tooltip(
                          message: l
                              ? 'May FSL na senyas'
                              : 'Has Filipino Sign Language',
                          child: const Icon(
                            Icons.sign_language_rounded,
                            size: 20,
                            color: AppColors.secondaryDark,
                          ),
                        ),
                  onTap: () => Navigator.pop(context, info.activity),
                ),
              const Divider(height: 28),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Text('⭐', style: TextStyle(fontSize: 28)),
                title: Text(
                  l ? 'Sariling gawain' : 'Custom activity',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hc.textPrimary,
                  ),
                ),
                subtitle: Text(
                  l
                      ? 'Kayo ang bahala sa pangalan, larawan at tunog.'
                      : 'You choose the name, picture and sound.',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                onTap: () => Navigator.pop(context, RoutineActivity.custom),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
