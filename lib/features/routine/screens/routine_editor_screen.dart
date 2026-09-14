import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/routine_provider.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/rich_empty_states.dart';
import '../models/routine_catalog.dart';
import '../models/routine_models.dart';
import '../models/routine_templates.dart';
import '../services/routine_service.dart';
import '../widgets/routine_copy_sheet.dart';
import '../widgets/routine_educator_actions.dart';
import '../widgets/routine_lock_status_line.dart';
import '../widgets/routine_ownership_banner.dart';
import '../widgets/routine_step_card.dart';
import '../widgets/routine_sync_feedback.dart';
import 'routine_builder_screen.dart';
import 'routine_history_screen.dart';
import 'routine_screen.dart';

/// The educator's routine manager for one learner.
///
/// Reached from the Routine button on the Teacher and Parent dashboards and
/// from the per-member menu in Manage Classes / Home Groups. Lists every
/// routine set for this learner with today's progress, and creates new ones
/// from a template or from scratch.
///
/// One screen for both educator roles: a parent building a home routine and a
/// teacher building a class routine are doing the same job on the same data,
/// and splitting them is exactly how the two educator surfaces drifted apart
/// before. The only role-dependent thing here is the word for the learner,
/// which arrives as [learnerNoun].
class RoutineEditorScreen extends ConsumerWidget {
  final String childProfileId;
  final String? childDisplayName;

  /// "student" / "child" — the audience's word for this learner, lowercase.
  final String learnerNoun;

  /// The learner's accessibility category, when the caller knows it. Drives
  /// the template suggestions and the learner preview.
  final DisabilityType? accessibility;

  const RoutineEditorScreen({
    super.key,
    required this.childProfileId,
    this.childDisplayName,
    this.learnerNoun = 'learner',
    this.accessibility,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final l = ref.watch(settingsProvider).locale == 'fil';
    final routinesAsync = ref.watch(routineListProvider(childProfileId));
    final today = DateTime.now();
    // The joined day, so an approval made here shows as done at once and a
    // reset clears the card without waiting for the learner's device.
    final log = ref
        .watch(routineDayViewProvider(routineDayKey(childProfileId, today)))
        .effectiveLog;

    return AnimatedGradientBackground(
      intensity: 0.22,
      preset: GradientPreset.assessment,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const AppBackButton(),
          title: Text(
            childDisplayName == null
                ? (l ? 'Mga Routine' : 'Routines')
                : (l
                    ? 'Mga Routine ni $childDisplayName'
                    : 'Routines — $childDisplayName'),
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              tooltip: l ? 'Kasaysayan' : 'History',
              icon: Icon(Icons.insights_rounded, color: hc.textSecondary),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RoutineHistoryScreen(
                    childProfileId: childProfileId,
                    childDisplayName: childDisplayName,
                    learnerNoun: learnerNoun,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: l
                  ? 'Tingnan ang nakikita ng bata'
                  : 'Preview what the $learnerNoun sees',
              icon: Icon(Icons.visibility_rounded, color: hc.textSecondary),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RoutineScreen(
                    profileId: childProfileId,
                    displayName: childDisplayName,
                    accessibility: accessibility,
                    readOnly: true,
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add_rounded),
          label: Text(l ? 'Bagong routine' : 'New routine'),
          onPressed: () => _create(context, ref, l),
        ),
        body: SafeArea(
          child: routinesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l ? 'Hindi ma-load: $e' : 'Could not load: $e',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.error),
                ),
              ),
            ),
            data: (routines) {
              if (routines.isEmpty) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: RoutineOwnershipBanner(
                          educatorProfileId: ref.watch(profileProvider)?.id,
                          filipino: l,
                        ),
                      ),
                      RichEmptyState(
                    emoji: '🗓️',
                    title: l ? 'Wala pang routine' : 'No routines yet',
                    description: l
                        ? 'Gumawa ng pang-araw-araw na routine para kay '
                            '${childDisplayName ?? 'bata'}. Puwedeng magsimula '
                            'sa handang template at baguhin ang bawat hakbang.'
                        : 'Build a daily routine for '
                            '${childDisplayName ?? 'this $learnerNoun'}. Start '
                            'from a ready-made template and change any step.',
                    actionLabel:
                        l ? 'Gumawa ng routine' : 'Create a routine',
                        actionIcon: Icons.add_rounded,
                        onAction: () => _create(context, ref, l),
                      ),
                    ],
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  // Before anything else: if this device can no longer sync
                  // the signed-in educator, say so here rather than letting
                  // them build a routine that will never leave the tablet.
                  RoutineOwnershipBanner(
                    educatorProfileId: ref.watch(profileProvider)?.id,
                    filipino: l,
                  ),
                  _TodayCard(
                    routines: routines,
                    log: log,
                    filipino: l,
                    onReset: () => _resetToday(context, ref, l),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: RoutineLearnerLockStatus(
                      profileId: childProfileId,
                      filipino: l,
                      actionsFor: (context, status) => RoutineStepActionBar(
                        childProfileId: childProfileId,
                        learnerName: childDisplayName ??
                            (l ? 'ang bata' : 'this $learnerNoun'),
                        status: status,
                        filipino: l,
                      ),
                      undoFor: (context, status) => RoutineUndoMarkButton(
                        childProfileId: childProfileId,
                        status: status,
                        filipino: l,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProSectionHeader(
                    title: l ? 'Mga Routine' : 'Routines',
                    subtitle: l
                        ? '${routines.length} nakatakda'
                        : '${routines.length} set up',
                  ),
                  const SizedBox(height: 8),
                  for (final r in routines)
                    _RoutineCard(
                      routine: r,
                      log: log,
                      filipino: l,
                      onEdit: () => _edit(context, r),
                      onToggle: (v) async {
                        final write = await const RoutineService()
                            .save(r.copyWith(enabled: v));
                        if (!context.mounted) return;
                        reportRoutineSync(
                          context,
                          write.outcome,
                          filipino: l,
                          subject: l ? 'pagbabago' : 'change',
                        );
                      },
                      onDelete: () => _confirmDelete(context, r, l),
                      // An educator's tool: a Player planning their own day
                      // has nobody to copy it to.
                      onCopy: ref.watch(profileProvider)?.role.isEducator ==
                              true
                          ? () => showRoutineCopySheet(
                                context,
                                ref,
                                routine: r,
                                filipino: l,
                              )
                          : null,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref, bool l) async {
    final choice = await showModalBottomSheet<_CreateChoice>(
      context: context,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateSheet(
        filipino: l,
        accessibility: accessibility ?? DisabilityType.none,
      ),
    );
    if (choice == null || !context.mounted) return;

    final setter = ref.read(profileProvider);
    const service = RoutineService();
    final now = DateTime.now();
    final template = choice.templateId == null
        ? null
        : RoutineTemplates.byId(choice.templateId!);

    final draft = Routine(
      id: '',
      childProfileId: childProfileId,
      setterProfileId: setter?.id ?? '',
      setterRole: setter?.role ?? UserRole.parent,
      name: template?.name ?? (l ? 'Bagong routine' : 'New routine'),
      nameFilipino: template?.nameFilipino ?? '',
      daysOfWeek: template?.daysOfWeek ?? const <int>{},
      steps: template?.buildSteps((i) => '${service.newId()}_$i') ??
          const <RoutineStep>[],
      createdAt: now,
      updatedAt: now,
    );
    final write = await service.save(draft);
    if (!context.mounted) return;
    reportRoutineSync(
      context,
      write.outcome,
      filipino: l,
      subject: l ? 'routine' : 'routine',
    );
    await _edit(context, write.routine);
  }

  Future<void> _edit(BuildContext context, Routine routine) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoutineBuilderScreen(
          routine: routine,
          learnerNoun: learnerNoun,
          learnerName: childDisplayName,
        ),
      ),
    );
  }

  Future<void> _resetToday(
    BuildContext context,
    WidgetRef ref,
    bool l,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l ? 'Simulan muli ang araw na ito?' : 'Start today over?'),
        content: Text(
          l
              ? 'Aalisin ang lahat ng markang tapos para sa araw na ito, at '
                  'ang mga hakbang na pinalaktaw ng nakatatanda ay muling mala-lock. Hindi mababago ang '
                  'routine mismo.'
              : 'Every tick for today will be cleared, and any step an adult '
                  'waved past goes back to locking. The routine itself is not '
                  'changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l ? 'Kanselahin' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l ? 'Simulan muli' : 'Start over'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final by = ref.read(profileProvider);
    if (by == null) return;
    final today = DateTime.now();
    // Written to the educator's own actions document as well as the local
    // log, so it reaches a learner on a different device — and it is the undo
    // for "Ask a grown-up" as much as for the ticks: an excuse granted by a
    // maths question a distracted adult answered by mistake lasts the whole
    // day otherwise.
    final outcome = await const RoutineService().resetDayForLearner(
      childProfileId: childProfileId,
      day: today,
      by: by,
    );
    final key = routineDayKey(childProfileId, today);
    ref.invalidate(routineDayLogProvider(key));
    ref.invalidate(routineDayActionsProvider(key));
    if (context.mounted) {
      reportRoutineSync(
        context,
        outcome,
        filipino: l,
        subject: l ? 'pagbabago' : 'change',
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Routine routine,
    bool l,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l ? 'Burahin ang “${routine.name}”?' : 'Delete “${routine.name}”?',
        ),
        content: Text(
          l
              ? 'Mawawala ito sa device ng bata. Hindi na ito maibabalik.'
              : 'It will disappear from the $learnerNoun’s device. This '
                  'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l ? 'Kanselahin' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l ? 'Burahin' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final outcome = await const RoutineService().delete(routine.id);
    if (!context.mounted) return;
    reportRoutineSync(
      context,
      outcome,
      filipino: l,
      subject: l ? 'pagbura' : 'deletion',
    );
  }
}

/// What the "new routine" sheet returns: a template id, or null for a blank
/// routine the educator will fill in themselves.
class _CreateChoice {
  final String? templateId;
  const _CreateChoice(this.templateId);
}

class _TemplateSheet extends StatelessWidget {
  final bool filipino;
  final DisabilityType accessibility;

  const _TemplateSheet({
    required this.filipino,
    required this.accessibility,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = filipino;
    final templates = RoutineTemplates.suggestedFor(accessibility);
    final tailored =
        templates.where((t) => t.suitedTo.contains(accessibility)).toList();

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
              l ? 'Magsimula sa…' : 'Start from…',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l
                  ? 'Isang handang plano — mababago ang bawat hakbang pagkatapos.'
                  : 'A ready-made plan — every step stays editable afterwards.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 16),
            if (tailored.isNotEmpty) ...[
              Text(
                l
                    ? 'Iminumungkahi para sa ${accessibility.label}'
                    : 'Suggested for ${accessibility.label}',
                style: AppTypography.labelMedium.copyWith(
                  color: hc.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
            ],
            for (final t in templates)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TemplateTile(
                  template: t,
                  filipino: l,
                  highlighted: t.suitedTo.contains(accessibility),
                  onTap: () => Navigator.pop(context, _CreateChoice(t.id)),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, const _CreateChoice(null)),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(
                l ? 'Magsimula sa blangko' : 'Start from a blank routine',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final RoutineTemplate template;
  final bool filipino;
  final bool highlighted;
  final VoidCallback onTap;

  const _TemplateTile({
    required this.template,
    required this.filipino,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: highlighted
                ? Color.alphaBlend(
                    hc.primary.withValues(alpha: 0.10),
                    hc.surface,
                  )
                : hc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted
                  ? hc.primary.withValues(alpha: 0.5)
                  : hc.textHint.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(template.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.nameOf(filipino: filipino),
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      template.descriptionOf(filipino: filipino),
                      style: AppTypography.bodySmall
                          .copyWith(color: hc.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      filipino
                          ? '${template.activities.length} hakbang · '
                              '${formatDays(template.daysOfWeek, filipino: true)}'
                          : '${template.activities.length} steps · '
                              '${formatDays(template.daysOfWeek, filipino: false)}',
                      style: AppTypography.labelSmall
                          .copyWith(color: hc.textHint),
                    ),
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

class _TodayCard extends StatelessWidget {
  final List<Routine> routines;
  final RoutineDayLog log;
  final bool filipino;
  final VoidCallback onReset;

  const _TodayCard({
    required this.routines,
    required this.log,
    required this.filipino,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final today = DateTime.now();
    final live =
        routines.where((r) => r.enabled && r.runsOn(today)).toList();
    final steps = [for (final r in live) ...r.orderedSteps];
    final done =
        steps.where((s) => log.completedStepIds.contains(s.id)).length;

    return ProPanel(
      title: filipino ? 'Ngayong Araw' : 'Today',
      subtitle: live.isEmpty
          ? (filipino
              ? 'Walang routine na nakatakda ngayon'
              : 'No routine scheduled today')
          : (filipino
              ? '$done sa ${steps.length} gawain ang tapos'
              : '$done of ${steps.length} activities done'),
      trailing: steps.isEmpty
          ? null
          : IconButton(
              tooltip: filipino ? 'Simulan muli ang araw' : 'Start today over',
              icon: Icon(Icons.restart_alt_rounded, color: hc.textSecondary),
              onPressed: onReset,
            ),
      child: steps.isEmpty
          ? Text(
              filipino
                  ? 'Piliin ang mga araw sa loob ng routine para lumabas ito dito.'
                  : 'Set the days inside a routine and it will appear here.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: steps.isEmpty ? 0 : done / steps.length,
                    minHeight: 10,
                    backgroundColor: hc.textHint.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(
                      done == steps.length ? AppColors.success : hc.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in steps.take(8))
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Text(
                          log.completedStepIds.contains(s.id) ? '✅' : '⬜',
                        ),
                        label: Text(
                          RoutineCatalog.titleFor(s, filipino: filipino),
                          style: AppTypography.labelSmall,
                        ),
                      ),
                    if (steps.length > 8)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '+${steps.length - 8}',
                          style: AppTypography.labelSmall,
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final RoutineDayLog log;
  final bool filipino;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  /// Null hides "Copy to other learners".
  final VoidCallback? onCopy;

  const _RoutineCard({
    required this.routine,
    required this.log,
    required this.filipino,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = filipino;
    final name = l && routine.nameFilipino.isNotEmpty
        ? routine.nameFilipino
        : routine.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProPanel(
        onTap: onEdit,
        accent: routine.enabled ? hc.primary : hc.textHint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty ? (l ? 'Walang pangalan' : 'Untitled') : name,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                    ),
                  ),
                ),
                Switch(
                  value: routine.enabled,
                  onChanged: onToggle,
                ),
                PopupMenuButton<String>(
                  tooltip: l ? 'Mga aksyon sa routine' : 'Routine actions',
                  icon: Icon(Icons.more_horiz_rounded,
                      color: hc.textSecondary),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                    if (v == 'copy') onCopy?.call();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_rounded, size: 18),
                          const SizedBox(width: 10),
                          Flexible(child: Text(l ? 'I-edit' : 'Edit')),
                        ],
                      ),
                    ),
                    if (onCopy != null)
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            const Icon(Icons.copy_all_rounded, size: 18),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                l
                                    ? 'Kopyahin sa ibang bata'
                                    : 'Copy to other learners',
                              ),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppColors.error),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              l ? 'Burahin' : 'Delete',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${routine.stepCount} '
              '${l ? 'hakbang' : 'steps'} · '
              '${formatDays(routine.daysOfWeek, filipino: l)}',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
            // A routine that holds the learner's device says so on its card.
            // This is the strongest thing an educator can switch on here and
            // it lives two screens deep; without a mark at this level the
            // only way to know is to open every routine and look.
            if (routine.lockingSteps.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.lock_clock_rounded,
                    size: 15,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l
                          ? 'Mala-lock ang app sa ${routine.lockingSteps.length} '
                                'hakbang'
                          : 'Locks the app at '
                                '${routine.lockingSteps.length} '
                                '${routine.lockingSteps.length == 1 ? 'step' : 'steps'}',
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in routine.orderedSteps.take(10))
                  Tooltip(
                    message: RoutineCatalog.titleFor(s, filipino: l),
                    child: Text(
                      RoutineCatalog.emojiFor(s),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                if (routine.orderedSteps.length > 10)
                  Text(
                    '+${routine.orderedSteps.length - 10}',
                    style: AppTypography.labelSmall
                        .copyWith(color: hc.textSecondary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
