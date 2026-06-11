import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/classroom.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/home_group.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/firestore_stream_helpers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../live_session/models/live_session_models.dart';
import '../../live_session/providers/live_activity_set_provider.dart';
import '../models/tv_cast_session.dart';
import '../providers/tv_cast_provider.dart';

/// Host-side control panel for the interactive "Live Activity" cast mode.
/// Lets a Teacher/Parent start a live session, configure star-scoring rules,
/// build & push quiz questions, watch responses + the live scoreboard, and
/// see (and clear) raised hands.
class TvCastLivePanel extends ConsumerWidget {
  final TvCastSession state;
  const TvCastLivePanel({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tvCastSessionProvider.notifier);
    if (!notifier.canHostLive) return const _NeedsCloudNotice();
    if (state.liveSessionKey == null) {
      return _SessionStarter(state: state);
    }
    return _RunningPanel(state: state);
  }
}

// ─── Needs-cloud notice ────────────────────────────────

class _NeedsCloudNotice extends StatelessWidget {
  const _NeedsCloudNotice();

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Live games & quizzes need an internet connection so learner '
              'devices can join in real time. Connect to Wi-Fi or mobile data '
              '(it stays on the free plan) and try again.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Session starter ───────────────────────────────────

class _SessionStarter extends ConsumerStatefulWidget {
  final TvCastSession state;
  const _SessionStarter({required this.state});

  @override
  ConsumerState<_SessionStarter> createState() => _SessionStarterState();
}

class _SessionStarterState extends ConsumerState<_SessionStarter> {
  String? _selectedKey;
  String? _selectedLabel;
  LiveSessionOwnerKind _selectedKind = LiveSessionOwnerKind.classroom;
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final profile = ref.watch(profileProvider);
    if (profile == null) return const SizedBox.shrink();

    final classrooms =
        ref.watch(classroomsByTeacherStreamProvider(profile.id)).valueOrNull ??
            const <Classroom>[];
    final homeGroups =
        ref.watch(homeGroupsByOwnerStreamProvider(profile.id)).valueOrNull ??
            const <HomeGroup>[];

    final options = <_OwnerOption>[
      for (final c in classrooms)
        _OwnerOption(c.id, c.name, LiveSessionOwnerKind.classroom),
      for (final g in homeGroups)
        _OwnerOption(g.id, g.name, LiveSessionOwnerKind.homeGroup),
    ];

    if (options.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hc.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Text(
          profile.role == UserRole.parent
              ? 'Create a home group first (Manage Family), then your child '
                  'can join the live activity from their own device.'
              : 'Create a classroom first (Manage Classes), then your students '
                  'can join the live activity from their own devices.',
          style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
        ),
      );
    }

    _selectedKey ??= options.first.key;
    final selected = options
        .firstWhere((o) => o.key == _selectedKey, orElse: () => options.first);
    _selectedKind = selected.kind;
    _selectedLabel = selected.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Start a live activity',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Learners in the chosen class join from their own device, answer on '
          'screen, and earn stars. Their raised hands show on the TV.',
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedKey,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Class / group to host',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.groups_rounded),
          ),
          items: options
              .map(
                (o) => DropdownMenuItem(
                  value: o.key,
                  child: Text(
                    '${o.kind == LiveSessionOwnerKind.homeGroup ? '🏠' : '🏫'}  '
                    '${o.label}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedKey = v),
        ),
        const SizedBox(height: 14),
        Semantics(
          button: true,
          label: 'Start live activity session',
          child: FilledButton.icon(
            onPressed: _starting ? null : _start,
            icon: _starting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_circle_fill_rounded),
            label: Text(_starting ? 'Starting…' : 'Start live session'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: AppTypography.titleMedium,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _start() async {
    final key = _selectedKey;
    if (key == null) return;
    setState(() => _starting = true);
    final ok = await ref.read(tvCastSessionProvider.notifier).startLiveSession(
          sessionKey: key,
          ownerKind: _selectedKind,
          displayName: _selectedLabel,
        );
    if (!mounted) return;
    setState(() => _starting = false);
    if (!ok) {
      AppSnackBar.error(
        context,
        message: 'Could not start the live session. Check your connection.',
      );
    }
  }
}

class _OwnerOption {
  final String key;
  final String label;
  final LiveSessionOwnerKind kind;
  const _OwnerOption(this.key, this.label, this.kind);
}

// ─── Running panel ─────────────────────────────────────

class _RunningPanel extends ConsumerStatefulWidget {
  final TvCastSession state;
  const _RunningPanel({required this.state});

  @override
  ConsumerState<_RunningPanel> createState() => _RunningPanelState();
}

class _RunningPanelState extends ConsumerState<_RunningPanel> {
  LiveActivitySet? _runningSet;
  int _runningIndex = 0;

  TvCastSessionNotifier get _notifier =>
      ref.read(tvCastSessionProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final state = widget.state;
    final scoring = state.liveScoring ?? const LiveScoringRules();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusHeader(state: state, onEnd: _end),
        const SizedBox(height: 14),
        _ScoringEditor(
          rules: scoring,
          onChanged: (r) => _notifier.setLiveScoring(r),
        ),
        const SizedBox(height: 14),
        _CurrentQuestionCard(
          state: state,
          onClear: state.liveActivity == null
              ? null
              : () => _notifier.clearLiveActivity(),
        ),
        const SizedBox(height: 14),
        _RaisedHandsPanel(
          hands: state.raisedHands,
          onClear: (id) => _notifier.clearRaisedHand(id),
        ),
        const SizedBox(height: 14),
        _PushArea(
          runningSet: _runningSet,
          runningIndex: _runningIndex,
          onBuildAndPush: _buildAndPush,
          onRunSet: _runSet,
          onPushSetStep: _pushSetStep,
          onStopSet: () => setState(() => _runningSet = null),
        ),
        const SizedBox(height: 14),
        _ScoreboardCard(rows: state.liveScoreboard),
        const SizedBox(height: 6),
        Text(
          'Tip: the question, raised hands, and scoreboard all show on the TV. '
          'Learners answer on their own devices.',
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
      ],
    );
  }

  Future<void> _end() async {
    await _notifier.endLiveSession();
    if (!mounted) return;
    setState(() {
      _runningSet = null;
      _runningIndex = 0;
    });
  }

  Future<void> _buildAndPush() async {
    final activity = await showModalBottomSheet<LiveActivity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ActivityBuilderSheet(),
    );
    if (activity == null || !mounted) return;
    await _notifier.pushLiveActivity(activity);
    if (!mounted) return;
    AppSnackBar.success(context, message: 'Question sent to learners & TV');
  }

  void _runSet(LiveActivitySet set) {
    setState(() {
      _runningSet = set;
      _runningIndex = 0;
    });
    _pushSetStep(0);
  }

  Future<void> _pushSetStep(int index) async {
    final set = _runningSet;
    if (set == null || index < 0 || index >= set.activities.length) return;
    setState(() => _runningIndex = index);
    final activity = set.activities[index].forPush(
      questionNumber: index + 1,
      totalQuestions: set.activities.length,
    );
    await _notifier.pushLiveActivity(activity);
  }
}

// ─── Status header ─────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final TvCastSession state;
  final VoidCallback onEnd;
  const _StatusHeader({required this.state, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.podcasts_rounded, color: Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live session running',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: hc.textPrimary,
                  ),
                ),
                Text(
                  '${state.liveResponders} answered the current question',
                  style:
                      AppTypography.bodySmall.copyWith(color: hc.textSecondary),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'End live session',
            child: TextButton.icon(
              onPressed: onEnd,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('End'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scoring editor ────────────────────────────────────

class _ScoringEditor extends StatelessWidget {
  final LiveScoringRules rules;
  final ValueChanged<LiveScoringRules> onChanged;
  const _ScoringEditor({required this.rules, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Material(
      color: hc.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.star_rounded, color: Color(0xFFFFB300)),
        title: Text(
          'Star scoring',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        subtitle: Text(
          'Base ${rules.baseStars}★'
          '${rules.speedBonusEnabled ? ' • speed +${rules.speedBonusMax}' : ''}'
          '${rules.firstCorrectEnabled ? ' • first +${rules.firstCorrectBonus}' : ''}'
          '${rules.hasCap ? ' • cap ${rules.sessionCap}' : ''}',
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _Stepper(
            label: 'Stars per correct answer',
            value: rules.baseStars,
            min: 0,
            max: 10,
            onChanged: (v) => onChanged(rules.copyWith(baseStars: v)),
          ),
          _Stepper(
            label: 'Speed bonus (extra for fast answers)',
            value: rules.speedBonusMax,
            min: 0,
            max: 5,
            onChanged: (v) => onChanged(rules.copyWith(speedBonusMax: v)),
          ),
          if (rules.speedBonusEnabled)
            _Stepper(
              label: 'Speed window (seconds)',
              value: rules.speedWindowSec,
              min: 5,
              max: 60,
              step: 5,
              onChanged: (v) => onChanged(rules.copyWith(speedWindowSec: v)),
            ),
          _Stepper(
            label: 'First-correct bonus',
            value: rules.firstCorrectBonus,
            min: 0,
            max: 5,
            onChanged: (v) => onChanged(rules.copyWith(firstCorrectBonus: v)),
          ),
          _Stepper(
            label: 'Session star cap (0 = no cap)',
            value: rules.sessionCap,
            min: 0,
            max: 100,
            step: 5,
            onChanged: (v) => onChanged(rules.copyWith(sessionCap: v)),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
            ),
          ),
          IconButton(
            tooltip: 'Decrease $label',
            onPressed:
                value > min ? () => onChanged((value - step).clamp(min, max)) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: hc.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Increase $label',
            onPressed:
                value < max ? () => onChanged((value + step).clamp(min, max)) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

// ─── Current question card ─────────────────────────────

class _CurrentQuestionCard extends StatelessWidget {
  final TvCastSession state;
  final VoidCallback? onClear;
  const _CurrentQuestionCard({required this.state, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final activity = state.liveActivity;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(
            activity == null
                ? Icons.hourglass_empty_rounded
                : Icons.quiz_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity == null
                  ? 'No question on screen. Build & push one below.'
                  : _describe(activity),
              style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
            ),
          ),
          if (onClear != null)
            TextButton(onPressed: onClear, child: const Text('Clear')),
        ],
      ),
    );
  }

  String _describe(LiveActivity a) {
    switch (a.type) {
      case LiveActivityType.multipleChoice:
        return 'Multiple choice: ${a.prompt}';
      case LiveActivityType.trueFalse:
        return 'True or False: ${a.prompt}';
      case LiveActivityType.pictureChoice:
        return 'Picture choice (${a.options.length} options)';
      case LiveActivityType.fslSign:
        return a.selfReport
            ? 'FSL sign — self check'
            : 'FSL sign (${a.options.length} options)';
      case LiveActivityType.flashcard:
        return 'Flashcard';
    }
  }
}

// ─── Raised hands ──────────────────────────────────────

class _RaisedHandsPanel extends StatelessWidget {
  final List<RaisedHand> hands;
  final ValueChanged<String> onClear;
  const _RaisedHandsPanel({required this.hands, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hands.isEmpty
            ? hc.surface
            : const Color(0xFFFFB300).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hands.isEmpty
              ? hc.textSecondary.withValues(alpha: 0.2)
              : const Color(0xFFFFB300).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✋', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                hands.isEmpty
                    ? 'Raised hands'
                    : 'Raised hands (${hands.length})',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hands.isEmpty)
            Text(
              'No one is asking for help right now.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in hands)
                  Semantics(
                    label: '${h.profileName} raised their hand. '
                        'Activate to clear.',
                    button: true,
                    child: InputChip(
                      avatar: const Text('✋'),
                      label: Text(h.profileName),
                      onDeleted: () => onClear(h.profileId),
                      deleteIcon: const Icon(Icons.check_rounded, size: 18),
                      deleteButtonTooltipMessage: 'Mark handled',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Push area (build + saved quizzes) ─────────────────

class _PushArea extends ConsumerWidget {
  final LiveActivitySet? runningSet;
  final int runningIndex;
  final Future<void> Function() onBuildAndPush;
  final void Function(LiveActivitySet) onRunSet;
  final Future<void> Function(int) onPushSetStep;
  final VoidCallback onStopSet;

  const _PushArea({
    required this.runningSet,
    required this.runningIndex,
    required this.onBuildAndPush,
    required this.onRunSet,
    required this.onPushSetStep,
    required this.onStopSet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final sets = ref.watch(liveActivitySetProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Send a question',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (runningSet != null)
          _RunningSetControls(
            set: runningSet!,
            index: runningIndex,
            onPush: onPushSetStep,
            onStop: onStopSet,
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onBuildAndPush,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Build & push question'),
              ),
              OutlinedButton.icon(
                onPressed: () => _newQuiz(context, ref),
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('New quiz'),
              ),
            ],
          ),
          if (sets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Saved quizzes',
              style:
                  AppTypography.labelMedium.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 6),
            for (final set in sets)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.quiz_outlined),
                  title: Text(set.title),
                  subtitle: Text('${set.activities.length} questions'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Run this quiz',
                        icon: const Icon(Icons.play_arrow_rounded),
                        onPressed: set.activities.isEmpty
                            ? null
                            : () => onRunSet(set),
                      ),
                      IconButton(
                        tooltip: 'Delete quiz',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => ref
                            .read(liveActivitySetProvider.notifier)
                            .deleteSet(set.id),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Future<void> _newQuiz(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);
    final set = await showModalBottomSheet<LiveActivitySet>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SetBuilderSheet(createdBy: profile?.id ?? 'default'),
    );
    if (set == null) return;
    await ref.read(liveActivitySetProvider.notifier).saveSet(set);
  }
}

class _RunningSetControls extends StatelessWidget {
  final LiveActivitySet set;
  final int index;
  final Future<void> Function(int) onPush;
  final VoidCallback onStop;

  const _RunningSetControls({
    required this.set,
    required this.index,
    required this.onPush,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final total = set.activities.length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Running "${set.title}" — question ${index + 1} of $total',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: index > 0 ? () => onPush(index - 1) : null,
                icon: const Icon(Icons.skip_previous_rounded),
                label: const Text('Prev'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed:
                    index < total - 1 ? () => onPush(index + 1) : null,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Next'),
              ),
              const Spacer(),
              TextButton(onPressed: onStop, child: const Text('Stop')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Scoreboard ────────────────────────────────────────

class _ScoreboardCard extends StatelessWidget {
  final List<LiveScoreRow> rows;
  const _ScoreboardCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Live scoreboard',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              'No answers yet.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            )
          else
            for (var i = 0; i < rows.length && i < 8; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '#${i + 1}',
                        style: AppTypography.labelMedium
                            .copyWith(color: hc.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].name,
                        style: AppTypography.bodyMedium
                            .copyWith(color: hc.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${rows[i].correct}✓  ${rows[i].stars}⭐',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ─── Activity builder sheet (one question) ─────────────

/// Builds a single [LiveActivity] of any supported type. Pops the built
/// activity, or null on cancel.
class _ActivityBuilderSheet extends ConsumerStatefulWidget {
  const _ActivityBuilderSheet();

  @override
  ConsumerState<_ActivityBuilderSheet> createState() =>
      _ActivityBuilderSheetState();
}

class _ActivityBuilderSheetState extends ConsumerState<_ActivityBuilderSheet> {
  LiveActivityType _type = LiveActivityType.multipleChoice;

  // Multiple choice
  final _promptCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls =
      List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;

  // True / false
  final _statementCtrl = TextEditingController();
  bool _tfCorrect = true;

  // Picture / FSL
  Flashcard? _card;
  bool _fslSelfReport = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    _statementCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: hc.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'New question',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _typePicker(hc),
            const SizedBox(height: 16),
            ..._fieldsForType(hc),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _build,
                    child: const Text('Push to TV'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typePicker(HCColor hc) {
    final types = [
      (LiveActivityType.multipleChoice, 'Multiple choice', Icons.list_alt_rounded),
      (LiveActivityType.pictureChoice, 'Picture', Icons.image_rounded),
      (LiveActivityType.trueFalse, 'True / False', Icons.rule_rounded),
      (LiveActivityType.fslSign, 'FSL sign', Icons.sign_language_rounded),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((t) {
        final selected = _type == t.$1;
        return ChoiceChip(
          selected: selected,
          avatar: Icon(t.$3,
              size: 18, color: selected ? Colors.white : AppColors.primary),
          label: Text(t.$2),
          labelStyle: AppTypography.labelMedium.copyWith(
            color: selected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
          onSelected: (_) => setState(() => _type = t.$1),
        );
      }).toList(),
    );
  }

  List<Widget> _fieldsForType(HCColor hc) {
    switch (_type) {
      case LiveActivityType.multipleChoice:
        return [
          TextField(
            controller: _promptCtrl,
            decoration: const InputDecoration(
              labelText: 'Question',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          Text('Answer options (tap ✓ to mark the correct one)',
              style: AppTypography.labelMedium.copyWith(color: hc.textSecondary)),
          const SizedBox(height: 6),
          for (var i = 0; i < _optionCtrls.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Mark option ${i + 1} correct',
                    onPressed: () => setState(() => _correctIndex = i),
                    icon: Icon(
                      _correctIndex == i
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: _correctIndex == i
                          ? const Color(0xFF2E7D32)
                          : hc.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _optionCtrls[i],
                      decoration: InputDecoration(
                        labelText: 'Option ${i + 1}'
                            '${i >= 2 ? ' (optional)' : ''}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ];
      case LiveActivityType.trueFalse:
        return [
          TextField(
            controller: _statementCtrl,
            decoration: const InputDecoration(
              labelText: 'Statement',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('True'), icon: Icon(Icons.check)),
              ButtonSegment(value: false, label: Text('False'), icon: Icon(Icons.close)),
            ],
            selected: {_tfCorrect},
            onSelectionChanged: (s) => setState(() => _tfCorrect = s.first),
          ),
        ];
      case LiveActivityType.pictureChoice:
        return [
          _CardPicker(
            selected: _card,
            fslOnly: false,
            onPick: (c) => setState(() => _card = c),
          ),
          const SizedBox(height: 8),
          Text(
            'Learners pick the matching word from 4 options (auto-generated).',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
        ];
      case LiveActivityType.fslSign:
        return [
          _CardPicker(
            selected: _card,
            fslOnly: true,
            onPick: (c) => setState(() => _card = c),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _fslSelfReport,
            onChanged: (v) => setState(() => _fslSelfReport = v),
            title: Text('Self-check (learner taps "I got it")',
                style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary)),
            subtitle: Text(
              _fslSelfReport
                  ? 'No options — the learner judges their own sign.'
                  : 'Learners pick the matching word from options.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ),
        ];
      case LiveActivityType.flashcard:
        return const [];
    }
  }

  void _build() {
    final activity = _tryBuild();
    if (activity == null) {
      AppSnackBar.error(context, message: _validationMessage());
      return;
    }
    Navigator.pop(context, activity);
  }

  String _validationMessage() {
    switch (_type) {
      case LiveActivityType.multipleChoice:
        return 'Add a question and at least two options, and mark the correct one.';
      case LiveActivityType.trueFalse:
        return 'Type a statement.';
      case LiveActivityType.pictureChoice:
      case LiveActivityType.fslSign:
        return 'Pick a flashcard first.';
      case LiveActivityType.flashcard:
        return 'Unsupported.';
    }
  }

  LiveActivity? _tryBuild() {
    switch (_type) {
      case LiveActivityType.multipleChoice:
        final prompt = _promptCtrl.text.trim();
        final opts = _optionCtrls
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        // The correct option must be non-empty and survive the filter.
        final correctText = _optionCtrls[_correctIndex].text.trim();
        if (prompt.isEmpty || opts.length < 2 || correctText.isEmpty) {
          return null;
        }
        final correctIndex = opts.indexOf(correctText);
        return LiveActivity.multipleChoice(
          prompt: prompt,
          options: opts,
          correctIndex: correctIndex < 0 ? 0 : correctIndex,
        );
      case LiveActivityType.trueFalse:
        final s = _statementCtrl.text.trim();
        if (s.isEmpty) return null;
        return LiveActivity.trueFalse(statement: s, correctValue: _tfCorrect);
      case LiveActivityType.pictureChoice:
        final card = _card;
        if (card == null) return null;
        final (options, correctIndex) = _optionsFor(card);
        return LiveActivity.pictureChoice(
          flashcardId: card.id,
          options: options,
          correctIndex: correctIndex,
        );
      case LiveActivityType.fslSign:
        final card = _card;
        if (card == null) return null;
        if (_fslSelfReport) {
          return LiveActivity.fslSign(
            flashcardId: card.id,
            selfReport: true,
          );
        }
        final (options, correctIndex) = _optionsFor(card);
        return LiveActivity.fslSign(
          flashcardId: card.id,
          options: options,
          correctIndex: correctIndex,
        );
      case LiveActivityType.flashcard:
        return null;
    }
  }

  /// Builds 4 word options (the card's word + 3 distractors) and returns the
  /// shuffled options with the correct index.
  (List<String>, int) _optionsFor(Flashcard card) {
    final all = ref.read(allFlashcardsProvider);
    final correct = card.wordEnglish;
    final pool = all
        .where((f) => f.wordEnglish != correct)
        .map((f) => f.wordEnglish)
        .toSet()
        .toList()
      ..shuffle(Random());
    final sameCat = all
        .where((f) => f.category == card.category && f.wordEnglish != correct)
        .map((f) => f.wordEnglish)
        .toList()
      ..shuffle(Random());
    final distractors = <String>{...sameCat, ...pool}.take(3).toList();
    final options = [correct, ...distractors]..shuffle(Random());
    return (options, options.indexOf(correct));
  }
}

// ─── Set builder sheet (a quiz) ────────────────────────

/// Builds a reusable [LiveActivitySet] by adding questions one at a time
/// with [_ActivityBuilderSheet]. Pops the saved set, or null on cancel.
class _SetBuilderSheet extends StatefulWidget {
  final String createdBy;
  const _SetBuilderSheet({required this.createdBy});

  @override
  State<_SetBuilderSheet> createState() => _SetBuilderSheetState();
}

class _SetBuilderSheetState extends State<_SetBuilderSheet> {
  final _titleCtrl = TextEditingController();
  final List<LiveActivity> _activities = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'New quiz',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Quiz title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_activities.isEmpty)
              Text(
                'No questions yet. Add your first below.',
                style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
              )
            else
              for (var i = 0; i < _activities.length; i++)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 12, child: Text('${i + 1}')),
                  title: Text(_describe(_activities[i])),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => setState(() => _activities.removeAt(i)),
                  ),
                ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addQuestion,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add question'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: const Text('Save quiz'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSave =>
      _titleCtrl.text.trim().isNotEmpty && _activities.isNotEmpty;

  Future<void> _addQuestion() async {
    final activity = await showModalBottomSheet<LiveActivity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ActivityBuilderSheet(),
    );
    if (activity == null) return;
    setState(() => _activities.add(activity));
  }

  void _save() {
    final set = LiveActivitySet(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      activities: _activities,
      createdBy: widget.createdBy,
      createdAt: DateTime.now(),
    );
    Navigator.pop(context, set);
  }

  String _describe(LiveActivity a) {
    switch (a.type) {
      case LiveActivityType.multipleChoice:
        return a.prompt;
      case LiveActivityType.trueFalse:
        return 'T/F: ${a.prompt}';
      case LiveActivityType.pictureChoice:
        return 'Picture choice';
      case LiveActivityType.fslSign:
        return a.selfReport ? 'FSL self-check' : 'FSL sign';
      case LiveActivityType.flashcard:
        return 'Flashcard';
    }
  }
}

// ─── Flashcard picker ──────────────────────────────────

class _CardPicker extends ConsumerStatefulWidget {
  final Flashcard? selected;
  final bool fslOnly;
  final ValueChanged<Flashcard> onPick;
  const _CardPicker({
    required this.selected,
    required this.fslOnly,
    required this.onPick,
  });

  @override
  ConsumerState<_CardPicker> createState() => _CardPickerState();
}

class _CardPickerState extends ConsumerState<_CardPicker> {
  FlashcardCategory _category = FlashcardCategory.animals;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final all = ref.watch(allFlashcardsProvider);
    var cards = all.where((c) => c.category == _category).toList();
    if (widget.fslOnly) {
      cards =
          cards.where((c) => FslAssetsService.hasAnyVideoSource(c)).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<FlashcardCategory>(
          initialValue: _category,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.category_rounded),
          ),
          items: FlashcardCategory.values
              .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
              .toList(),
          onChanged: (c) {
            if (c != null) setState(() => _category = c);
          },
        ),
        const SizedBox(height: 8),
        if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              widget.fslOnly
                  ? 'No FSL signs in this category yet — try another.'
                  : 'No words in this category.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          )
        else
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final card = cards[i];
                final selected = widget.selected?.id == card.id;
                return ChoiceChip(
                  selected: selected,
                  label: Text(card.wordEnglish),
                  labelStyle: AppTypography.labelMedium.copyWith(
                    color: selected ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  onSelected: (_) => widget.onPick(card),
                );
              },
            ),
          ),
      ],
    );
  }
}
