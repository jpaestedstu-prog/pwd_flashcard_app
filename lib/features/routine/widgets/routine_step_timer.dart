import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// The countdown for one routine step — "brush for two minutes" as something
/// the learner can watch rather than guess.
///
/// Shared by the step screen and the routine **lock** screen, which is where
/// it matters most: a lock that says "brush for two minutes" and then asks the
/// learner to self-report after an interval nobody measured is not teaching
/// the routine, it is only interrupting it.
///
/// Owns its own ticker so both hosts stay simple, and counts down against a
/// wall-clock deadline as well as its one-second tick. The tick alone drifts
/// whenever Android throttles a backgrounded app — a learner who puts the
/// tablet down to brush would come back to a timer that had barely moved —
/// while the deadline alone does not advance under a widget test's fake clock.
/// Taking whichever says *less* time is left is right in both.
///
/// It never gates the way out. The timer is guidance: a learner who brushed
/// without starting it, or whose tablet stayed in the other room, must still
/// be able to say they did it.
class RoutineStepTimer extends StatefulWidget {
  const RoutineStepTimer({
    super.key,
    required this.durationMinutes,
    required this.asBar,
    required this.filipino,
    this.enabled = true,
    this.onFinished,
  });

  final int durationMinutes;

  /// Show a shrinking bar instead of `mm:ss` — the concrete form for learners
  /// who do not read a clock yet (`RoutinePresentation.timerAsBar`).
  final bool asBar;

  final bool filipino;

  /// False in an educator preview: the timer is shown, but nobody can run it
  /// on the learner's behalf.
  final bool enabled;

  /// Fired once when the countdown reaches zero, for the host's sound, speech
  /// or haptic cue — which differ by accessibility profile, so the host owns
  /// them rather than this widget guessing.
  final VoidCallback? onFinished;

  @override
  State<RoutineStepTimer> createState() => RoutineStepTimerState();
}

/// Public so tests and hosts can read the state without a finder dance.
class RoutineStepTimerState extends State<RoutineStepTimer> {
  Timer? _ticker;
  late int _secondsLeft = _total;
  bool _running = false;
  DateTime? _endsAt;

  int get _total => widget.durationMinutes * 60;

  bool get isRunning => _running;
  int get secondsLeft => _secondsLeft;
  bool get isFinished => _secondsLeft == 0;

  @override
  void didUpdateWidget(covariant RoutineStepTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durationMinutes != widget.durationMinutes) _reset();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _ticker?.cancel();
      setState(() {
        _running = false;
        _endsAt = null;
      });
      return;
    }
    if (_secondsLeft <= 0) _secondsLeft = _total;
    setState(() {
      _running = true;
      _endsAt = DateTime.now().add(Duration(seconds: _secondsLeft));
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) => _tick());
  }

  void _tick() {
    if (!mounted) {
      _ticker?.cancel();
      return;
    }
    final byTick = _secondsLeft - 1;
    final endsAt = _endsAt;
    final byClock = endsAt == null
        ? byTick
        : (endsAt.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    final next = math.max(0, math.min(byTick, byClock));
    setState(() => _secondsLeft = next);
    if (next == 0) {
      _ticker?.cancel();
      setState(() {
        _running = false;
        _endsAt = null;
      });
      widget.onFinished?.call();
    }
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _endsAt = null;
      _secondsLeft = _total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = widget.filipino;
    final total = _total;
    final fraction =
        total == 0 ? 0.0 : (_secondsLeft / total).clamp(0.0, 1.0);
    final mm = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (_secondsLeft % 60).toString().padLeft(2, '0');
    final done = _secondsLeft == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done
              ? AppColors.success
              : hc.textHint.withValues(alpha: 0.25),
          width: done ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.timer_rounded, size: 20, color: hc.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t(context).rsTimer,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.asBar)
            // A shrinking bar is concrete in a way "03:41" is not — the
            // configuration for learners who do not read a clock yet.
            Semantics(
              label: l
                  ? '$mm minuto at $ss segundo ang natitira'
                  : '$mm minutes $ss seconds left',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 18,
                    backgroundColor: hc.textHint.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(
                      fraction > 0.25 ? hc.primary : AppColors.warning,
                    ),
                  ),
                ),
              ),
            )
          else
            Text(
              '$mm:$ss',
              textAlign: TextAlign.center,
              style: AppTypography.displaySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: done ? AppColors.success : hc.textPrimary,
              ),
            ),
          if (done) ...[
            const SizedBox(height: 8),
            Text(
              l ? 'Tapos na ang oras — magaling!' : 'Time is up — well done!',
              textAlign: TextAlign.center,
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: widget.enabled ? _toggle : null,
                icon: Icon(
                  _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(
                  _running
                      ? (l ? 'I-pause' : 'Pause')
                      : (l ? 'Simulan' : 'Start'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.enabled ? _reset : null,
                icon: const Icon(Icons.replay_rounded),
                label: Text(l ? 'I-reset' : 'Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
