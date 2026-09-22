
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pro_surface.dart';
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
import '../../../core/utils/seeded_random.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

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

// ─── Shared button shapes ──────────────────────────────
//
// Same rectangle as the cast screen's action buttons (12px corners, 14px
// vertical rhythm) so the Live Activity panel reads as part of that screen
// rather than a component that wandered in.

final ButtonStyle _liveFilledButtonStyle = FilledButton.styleFrom(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: 14,
  ),
  shape: RoundedRectangleBorder(borderRadius: ProSurface.borderRadius),
);

/// Takes its accent from [HCColor] rather than [AppColors] so the outline
/// follows the high-contrast and dark schemes, like the panels around it.
ButtonStyle _liveOutlinedButtonStyle(HCColor hc) => OutlinedButton.styleFrom(
  foregroundColor: hc.primary,
  side: BorderSide(color: hc.primary.withValues(alpha: 0.4)),
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: 14,
  ),
  shape: RoundedRectangleBorder(borderRadius: ProSurface.borderRadius),
);

// ─── Needs-cloud notice ────────────────────────────────

class _NeedsCloudNotice extends StatelessWidget {
  const _NeedsCloudNotice();

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hc.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: hc.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t(context).tlpNeedsNet,
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
              ? _t(context).tlpNoGroup
              : _t(context).tlpNoClass,
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
          _t(context).tlpStartTitle,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _t(context).tlpStartBody,
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedKey,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _t(context).tlpHost,
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
          label: _t(context).tlpStartSem,
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
            label: Text(_starting ? _t(context).tcStarting : _t(context).tlpStart),
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
        message: _t(context).tlpStartFailed,
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
          _t(context).tlpTip,
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
      // Without this the dismiss barrier announces itself as "Scrim",
      // Material's untranslated default.
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ActivityBuilderSheet(),
    );
    if (activity == null || !mounted) return;
    await _notifier.pushLiveActivity(activity);
    if (!mounted) return;
    AppSnackBar.success(context, message: _t(context).tlpSent);
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
                  _t(context).tlpRunning,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: hc.textPrimary,
                  ),
                ),
                Text(
                  _t(context).tlpAnswered(state.liveResponders),
                  style:
                      AppTypography.bodySmall.copyWith(color: hc.textSecondary),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: _t(context).tlpEndSem,
            child: TextButton.icon(
              onPressed: onEnd,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(_t(context).tlpEnd),
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
      color: hc.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: ProSurface.borderRadius,
        side: BorderSide(color: hc.border),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.star_rounded, color: Color(0xFFFFB300)),
        title: Text(
          _t(context).tlpScoring,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        subtitle: Text(
          '${_t(context).tlpBase(rules.baseStars)}'
          '${rules.speedBonusEnabled ? _t(context).tlpSpeed(rules.speedBonusMax) : ''}'
          '${rules.firstCorrectEnabled ? _t(context).tlpFirst(rules.firstCorrectBonus) : ''}'
          '${rules.hasCap ? _t(context).tlpCap(rules.sessionCap) : ''}',
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _Stepper(
            label: _t(context).tlpPerCorrect,
            value: rules.baseStars,
            min: 0,
            max: 10,
            onChanged: (v) => onChanged(rules.copyWith(baseStars: v)),
          ),
          _Stepper(
            label: _t(context).tlpSpeedBonus,
            value: rules.speedBonusMax,
            min: 0,
            max: 5,
            onChanged: (v) => onChanged(rules.copyWith(speedBonusMax: v)),
          ),
          if (rules.speedBonusEnabled)
            _Stepper(
              label: _t(context).tlpSpeedWindow,
              value: rules.speedWindowSec,
              min: 5,
              max: 60,
              step: 5,
              onChanged: (v) => onChanged(rules.copyWith(speedWindowSec: v)),
            ),
          _Stepper(
            label: _t(context).tlpFirstBonus,
            value: rules.firstCorrectBonus,
            min: 0,
            max: 5,
            onChanged: (v) => onChanged(rules.copyWith(firstCorrectBonus: v)),
          ),
          _Stepper(
            label: _t(context).tlpSessionCap,
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
            tooltip: _t(context).tlpDecrease(label),
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
            tooltip: _t(context).tlpIncrease(label),
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
        border: Border.all(color: hc.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(
            activity == null
                ? Icons.hourglass_empty_rounded
                : Icons.quiz_rounded,
            color: hc.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity == null
                  ? _t(context).tlpNoQuestion
                  : _describe(context, activity),
              style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
            ),
          ),
          if (onClear != null)
            TextButton(onPressed: onClear, child: Text(_t(context).tcClear)),
        ],
      ),
    );
  }

  String _describe(BuildContext context, LiveActivity a) {
    switch (a.type) {
      case LiveActivityType.multipleChoice:
        return _t(context).tlpMc(a.prompt);
      case LiveActivityType.trueFalse:
        return _t(context).tlpTf(a.prompt);
      case LiveActivityType.pictureChoice:
        return _t(context).tlpPictureN(a.options.length);
      case LiveActivityType.fslSign:
        return a.selfReport
            ? _t(context).tlpFslSelf
            : _t(context).tlpFslN(a.options.length);
      case LiveActivityType.flashcard:
        return _t(context).tlpFlashcard;
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
                    ? _t(context).tlpHands
                    : _t(context).tlpHandsN(hands.length),
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
              _t(context).tlpNoHands,
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in hands)
                  Semantics(
                    label: _t(context).tlpHandSem(h.profileName),
                    button: true,
                    child: InputChip(
                      avatar: const Text('✋'),
                      label: Text(h.profileName),
                      onDeleted: () => onClear(h.profileId),
                      deleteIcon: const Icon(Icons.check_rounded, size: 18),
                      deleteButtonTooltipMessage: _t(context).tlpHandled,
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
          _t(context).tlpSend,
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
          // Equal cells, not a Wrap: "Build & push question" is three times
          // the width of "New quiz", so the pair used to sit as one long
          // button and one stub — and at a large font the second dropped to
          // its own line, leaving a half-empty row.
          ProButtonRow(
            minCellWidth: 160,
            maxPerRow: 2,
            children: [
              FilledButton.icon(
                style: _liveFilledButtonStyle,
                onPressed: onBuildAndPush,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  _t(context).tlpBuildPush,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
              OutlinedButton.icon(
                style: _liveOutlinedButtonStyle(hc),
                onPressed: () => _newQuiz(context, ref),
                icon: const Icon(Icons.playlist_add_rounded),
                label: Text(
                  _t(context).tlpNewQuiz,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (sets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _t(context).tlpSavedQuizzes,
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
                  subtitle: Text(_t(context).tlpQuestionsN(set.activities.length)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _t(context).tlpRunQuiz,
                        icon: const Icon(Icons.play_arrow_rounded),
                        onPressed: set.activities.isEmpty
                            ? null
                            : () => onRunSet(set),
                      ),
                      IconButton(
                        tooltip: _t(context).tlpDeleteQuiz,
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
      // Without this the dismiss barrier announces itself as "Scrim",
      // Material's untranslated default.
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
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
        color: hc.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hc.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(context).tlpRunningSet(set.title, index + 1, total),
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          // Three equal cells — the same shape as the cast screen's
          // prev/pause/next remote. As a raw Row with a Spacer this overflowed
          // once the labels grew with the Font Size setting.
          ProButtonRow(
            minCellWidth: 96,
            children: [
              OutlinedButton.icon(
                style: _liveOutlinedButtonStyle(hc),
                onPressed: index > 0 ? () => onPush(index - 1) : null,
                icon: const Icon(Icons.skip_previous_rounded),
                label: Text(_t(context).tbPrev, maxLines: 1),
              ),
              FilledButton.icon(
                style: _liveFilledButtonStyle,
                onPressed: index < total - 1 ? () => onPush(index + 1) : null,
                icon: const Icon(Icons.skip_next_rounded),
                label: Text(_t(context).next, maxLines: 1),
              ),
              OutlinedButton.icon(
                style: _liveOutlinedButtonStyle(hc),
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded),
                label: Text(_t(context).opStop, maxLines: 1),
              ),
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
        border: Border.all(color: hc.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.leaderboard_rounded, color: hc.primary),
              const SizedBox(width: 8),
              Text(
                _t(context).tlpScoreboard,
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
              _t(context).tlpNoAnswers,
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
              _t(context).tlpNewQuestion,
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
                    child: Text(_t(context).cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _build,
                    child: Text(_t(context).tlpPushTv),
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
      (LiveActivityType.multipleChoice, _t(context).tlpMcLabel, Icons.list_alt_rounded),
      (LiveActivityType.pictureChoice, _t(context).tlpPicture, Icons.image_rounded),
      (LiveActivityType.trueFalse, _t(context).tlpTfLabel, Icons.rule_rounded),
      (LiveActivityType.fslSign, _t(context).tlpFslSign, Icons.sign_language_rounded),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((t) {
        final selected = _type == t.$1;
        return ChoiceChip(
          selected: selected,
          avatar: Icon(t.$3,
              size: 18, color: selected ? Colors.white : hc.primary),
          label: Text(t.$2),
          labelStyle: AppTypography.labelMedium.copyWith(
            color: selected ? Colors.white : hc.primary,
            fontWeight: FontWeight.w700,
          ),
          selectedColor: hc.primary,
          backgroundColor: hc.primary.withValues(alpha: 0.08),
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
            decoration: InputDecoration(
              labelText: _t(context).tlpQuestion,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          Text(_t(context).tlpOptionsHint,
              style: AppTypography.labelMedium.copyWith(color: hc.textSecondary)),
          const SizedBox(height: 6),
          for (var i = 0; i < _optionCtrls.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _t(context).tlpMarkCorrect(i + 1),
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
                        labelText: '${_t(context).tlpOption(i + 1)}'
                            '${i >= 2 ? _t(context).tlpOptional : ''}',
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
            decoration: InputDecoration(
              labelText: _t(context).tlpStatement,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(_t(context).tlpTrue), icon: const Icon(Icons.check)),
              ButtonSegment(value: false, label: Text(_t(context).tlpFalse), icon: const Icon(Icons.close)),
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
            _t(context).tlpAutoOptions,
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
            title: Text(_t(context).tlpSelfCheck,
                style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary)),
            subtitle: Text(
              _fslSelfReport
                  ? _t(context).tlpSelfCheckNote
                  : _t(context).tlpPickOptions,
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
        return _t(context).tlpNeedOptions;
      case LiveActivityType.trueFalse:
        return _t(context).tlpNeedStatement;
      case LiveActivityType.pictureChoice:
      case LiveActivityType.fslSign:
        return _t(context).tlpNeedCard;
      case LiveActivityType.flashcard:
        return _t(context).tlpUnsupported;
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
      ..shuffle(contentRandom());
    final sameCat = all
        .where((f) => f.category == card.category && f.wordEnglish != correct)
        .map((f) => f.wordEnglish)
        .toList()
      ..shuffle(contentRandom());
    final distractors = <String>{...sameCat, ...pool}.take(3).toList();
    final options = [correct, ...distractors]..shuffle(contentRandom());
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
              _t(context).tlpNewQuiz,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: _t(context).tlpQuizTitle,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_activities.isEmpty)
              Text(
                _t(context).tlpNoQuestions,
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
              label: Text(_t(context).tlpAddQuestion),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(_t(context).cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: Text(_t(context).tlpSaveQuiz),
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
      // Without this the dismiss barrier announces itself as "Scrim",
      // Material's untranslated default.
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
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
        return _t(context).tlpTfShort(a.prompt);
      case LiveActivityType.pictureChoice:
        return _t(context).tlpPictureChoice;
      case LiveActivityType.fslSign:
        return a.selfReport ? _t(context).tlpFslSelfShort : _t(context).tlpFslSign;
      case LiveActivityType.flashcard:
        return _t(context).tlpFlashcard;
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
            labelText: _t(context).cfCategory,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.category_rounded),
          ),
          items: FlashcardCategory.values
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c.labelOf(_t(context))),
                ),
              )
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
                  ? _t(context).tlpNoFslCat
                  : _t(context).tcNoWords,
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
                    color: selected ? Colors.white : hc.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedColor: hc.primary,
                  backgroundColor: hc.primary.withValues(alpha: 0.08),
                  onSelected: (_) => widget.onPick(card),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
