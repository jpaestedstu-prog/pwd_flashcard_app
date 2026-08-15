import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart' show ResponsiveExtension;
import '../models/multiplayer_models.dart';
import '../models/race_presentation.dart';
import 'race_cursor.dart';
import '../../../widgets/flashcard_image.dart';

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

  /// How this racer's accessibility profile wants the round presented —
  /// pacing, narration, haptics, target size. Defaults to
  /// [RacePresentation.standard], i.e. the classic timed race.
  final RacePresentation presentation;

  /// Speaks [text] aloud. Injected by the screen (which owns the Riverpod
  /// ref) so this widget stays pure and testable. Narration is skipped when
  /// null, whatever the presentation says.
  final void Function(String text)? speak;

  /// Opens the Filipino Sign Language clip for the flashcard the round is
  /// about. Injected by the screen (which owns the resolver and the sheet);
  /// null hides the control, as does a round with no card behind it.
  final void Function(String cardId)? onShowSign;

  /// Hands-free cursor owned by the hosting screen's `GazeScope`. Null leaves
  /// the widget touch-only; see [RaceCursor] for why it lives on the screen.
  final RaceCursor? cursor;

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
    this.presentation = RacePresentation.standard,
    this.speak,
    this.onShowSign,
    this.cursor,
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

  RacePresentation get _p => widget.presentation;

  @override
  void initState() {
    super.initState();
    if (widget.questions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _narrate());
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    widget.cursor?.detach();
    super.dispose();
  }

  /// Publish this round's hands-free targets. Before answering they are the
  /// options; after answering they are the one Next button a self-paced
  /// learner still has to press (a timed race advances itself, so there is
  /// nothing left to aim at).
  void _attachCursor(MpQuestion question) {
    final cursor = widget.cursor;
    if (cursor == null) return;
    if (!_answered) {
      cursor.attach(
        count: question.options.length,
        enabled: !widget.isPaused,
        onChoose: () => _select(cursor.index),
      );
    } else {
      cursor.attach(
        count: _p.selfPaced ? 1 : 0,
        enabled: _p.selfPaced && !widget.isPaused,
        onChoose: _advance,
      );
    }
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

  /// Read the round aloud for a profile whose primary channel is audio. The
  /// options are part of the prompt here — a learner who cannot see the grid
  /// has no other way to know what they are choosing between.
  void _narrate() {
    if (!_p.speakPrompts || widget.speak == null) return;
    widget.speak!(_spokenRound());
  }

  String _spokenRound() {
    final q = widget.questions[_index];
    // A picture round has an emoji/image as its prompt, so lead with the
    // question text alone rather than reading a glyph name.
    final head = q.cardId != null ? q.promptLabel : '${q.promptLabel} ${q.prompt}';
    final choices = widget.isFilipino ? 'Mga pagpipilian' : 'Choices';
    return '$head. $choices: ${q.options.join(', ')}.';
  }

  void _scheduleAdvance() {
    _advanceTimer?.cancel();
    _advancePending = true;
    _advanceTimer = Timer(_p.answerDelay, () {
      if (!mounted) return;
      _advancePending = false;
      _advance();
    });
  }

  void _advance() {
    if (_index + 1 >= widget.questions.length) {
      widget.onFinished(_score);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _answered = false;
    });
    widget.cursor?.reset();
    _narrate();
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
    if (_p.haptics) {
      // ignore: discarded_futures
      correct ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
    }
    if (_p.speakPrompts && widget.speak != null) {
      widget.speak!(correct
          ? (widget.isFilipino ? 'Tama' : 'Correct')
          : (widget.isFilipino ? 'Mali' : 'Not quite'));
    }
    widget.onProgress?.call(_score, _index + 1);
    // Self-paced profiles advance with the explicit button instead — no timer
    // can take the answer off the screen before they are done with it.
    if (!_p.selfPaced) _scheduleAdvance();
  }

  /// The optional "another way to reach this round" controls: hear it spoken,
  /// or watch it signed. Each appears only when the learner's policy asks for
  /// that channel *and* the screen supplied the handler.
  List<Widget> _mediaControls(MpQuestion question) {
    final signCardId = question.fslCardId;
    return [
      if (_p.canSpeak && widget.speak != null)
        TextButton.icon(
          onPressed: () => widget.speak!(_spokenRound()),
          icon: const Icon(Icons.volume_up_rounded, size: 20),
          label: Text(widget.isFilipino ? 'Pakinggan ulit' : 'Hear it again'),
        ),
      if (_p.showFsl && widget.onShowSign != null && signCardId != null)
        TextButton.icon(
          onPressed: () => widget.onShowSign!(signCardId),
          icon: const Icon(Icons.sign_language_rounded, size: 20),
          label: Text(widget.isFilipino ? 'Ipakita ang senyas' : 'Show the sign'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const SizedBox.shrink();
    }
    final question = widget.questions[_index];
    final hc = HCColor.of(context);
    final total = widget.questions.length;
    _attachCursor(question);
    final cursor = widget.cursor;

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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.accentColor,
                    ),
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
          // A live region for profiles that read the screen: the round changes
          // under the learner without any navigation, so the screen reader has
          // to be told rather than waiting to be asked.
          Semantics(
            liveRegion: _p.announce,
            label: _p.announce ? _spokenRound() : null,
            container: _p.announce,
            child: Container(
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
                  style: AppTypography.labelMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  // Picture rounds carry a card id; the other round types
                  // (true/false, translation) keep their text prompt.
                  child: question.cardId != null
                      ? FlashcardPictureById(
                          cardId: question.cardId,
                          fallback: question.prompt,
                          extent: 104,
                        )
                      : Text(
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
          ),

          // ── Other ways in: hear it, or see it signed ──
          // Both are optional channels onto the same round, so they share a
          // Wrap and reflow instead of overflowing a narrow tablet.
          if (_mediaControls(question).isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: _mediaControls(question),
            ),
          ],
          const SizedBox(height: 20),

          // ── Answer options ──
          // shrinkWrap + NeverScrollable so the grid sizes to its content
          // inside the OverflowSafeBody scroll wrapper. childAspectRatio
          // shrinks as text scales up so cells stay tall enough, and again for
          // profiles that need a bigger tap area.
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
                ((_p.bigTargets ? 1.7 : 2.4) /
                        MediaQuery.textScalerOf(context).scale(1.0))
                    .clamp(1.0, 2.4),
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

              // Hands-free highlight: where a blink (or look-down) would land.
              final focused = !_answered && (cursor?.isFocused(idx) ?? false);
              if (focused) border = widget.accentColor;

              return GestureDetector(
                onTap: _answered ? null : () => _select(idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: border,
                      width: focused ? 5 : 2,
                    ),
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

          // ── Self-paced advance ──
          // No timer takes the answer away; the learner moves on when ready.
          if (_p.selfPaced && _answered) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              decoration: (cursor?.isFocused(0) ?? false)
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: widget.accentColor, width: 5),
                    )
                  : null,
              child: FilledButton.icon(
                onPressed: widget.isPaused ? null : _advance,
                icon: Icon(
                  _index + 1 >= total
                      ? Icons.flag_rounded
                      : Icons.arrow_forward_rounded,
                  size: 24,
                ),
                label: Text(
                  _index + 1 >= total
                      ? (widget.isFilipino ? 'Tapusin' : 'Finish')
                      : (widget.isFilipino ? 'Susunod' : 'Next'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
