import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart' show ResponsiveExtension;
import '../models/multiplayer_models.dart';

/// A self-contained, **star-free** vocabulary quiz runner for one player.
///
/// Drives a single racer through the shared [questions] and reports their live
/// score/progress via [onProgress] and the final tally via [onFinished]. It is
/// deliberately decoupled from connectivity: the same widget powers both the
/// same-device flow (run once per player) and the online flow (run once for
/// "me", the opponent watched separately).
///
/// Nothing here records stars, XP, streak, or progress — score is a plain
/// in-memory correct-answer count.
///
/// Overflow-proof at any tablet size / orientation / font scale: the body is
/// wrapped in [OverflowSafeBody], the answer grid uses
/// `shrinkWrap + NeverScrollableScrollPhysics` with a text-scale-aware
/// `childAspectRatio`, and all text uses `FittedBox` / ellipsis.
class QuizRacePlayer extends StatefulWidget {
  final List<MpQuestion> questions;
  final Color accentColor;
  final bool isFilipino;

  /// When true the player suspends its post-answer advance timer and ignores
  /// taps (the parent shows a pause overlay on top).
  final bool isPaused;

  /// Called after every answer with the running (score, questionsAnswered).
  final void Function(int score, int progress)? onProgress;

  /// Called once when the last question has been answered.
  final void Function(int score) onFinished;

  const QuizRacePlayer({
    super.key,
    required this.questions,
    required this.onFinished,
    this.onProgress,
    this.accentColor = AppColors.primary,
    this.isFilipino = false,
    this.isPaused = false,
  });

  @override
  State<QuizRacePlayer> createState() => _QuizRacePlayerState();
}

class _QuizRacePlayerState extends State<QuizRacePlayer> {
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _answered = false;
  bool _advancePending = false;
  Timer? _advanceTimer;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(QuizRacePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused && !oldWidget.isPaused) {
      // Freeze: cancel the pending advance but remember it's owed.
      _advanceTimer?.cancel();
    } else if (!widget.isPaused && oldWidget.isPaused && _advancePending) {
      // Resume: reschedule the owed advance from full duration.
      _scheduleAdvance();
    }
  }

  void _scheduleAdvance() {
    _advanceTimer?.cancel();
    _advancePending = true;
    _advanceTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _advancePending = false;
      if (_index + 1 >= widget.questions.length) {
        widget.onFinished(_score);
        return;
      }
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
    });
  }

  void _select(int idx) {
    if (_answered || widget.isPaused) return;
    final question = widget.questions[_index];
    final correct = idx == question.correctIndex;
    setState(() {
      _selected = idx;
      _answered = true;
      if (correct) _score++;
    });
    widget.onProgress?.call(_score, _index + 1);
    _scheduleAdvance();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const SizedBox.shrink();
    }
    final question = widget.questions[_index];
    final hc = HCColor.of(context);
    final total = widget.questions.length;

    // Always-scrolling body so the question + answer grid never overflow a
    // short landscape viewport at any font scale or tablet size.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          // ── Progress + live score ──
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_index + (_answered ? 1 : 0)) / total,
                    minHeight: 10,
                    backgroundColor: AppColors.border,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(widget.accentColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_index + 1}/$total',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: hc.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Question card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              children: [
                Text(
                  question.promptLabel,
                  style: AppTypography.labelMedium
                      .copyWith(color: hc.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    question.prompt,
                    style: AppTypography.displaySmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: hc.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (question.subtitle != null &&
                    question.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    question.subtitle!,
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Answer options ──
          // shrinkWrap + NeverScrollable so the grid sizes to its content
          // inside the OverflowSafeBody scroll wrapper. childAspectRatio
          // shrinks as text scales up so cells stay tall enough.
          GridView.count(
            crossAxisCount: context.responsiveTier<int>(
              phone: 2,
              tablet: 2,
              large: 2,
              xl: 3,
            ),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio:
                (2.4 / MediaQuery.textScalerOf(context).scale(1.0))
                    .clamp(1.2, 2.4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(question.options.length, (idx) {
              final isCorrect = idx == question.correctIndex;
              final isSelected = _selected == idx;

              Color bg = hc.surface;
              Color border = AppColors.border;
              Color fg = hc.textPrimary;
              if (_answered) {
                if (isCorrect) {
                  bg = AppColors.success.withValues(alpha: 0.15);
                  border = AppColors.success;
                  fg = AppColors.success;
                } else if (isSelected) {
                  bg = AppColors.error.withValues(alpha: 0.15);
                  border = AppColors.error;
                  fg = AppColors.error;
                }
              } else if (isSelected) {
                bg = widget.accentColor.withValues(alpha: 0.1);
                border = widget.accentColor;
              }

              return GestureDetector(
                onTap: _answered ? null : () => _select(idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      question.options[idx],
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
