import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/multiplayer_models.dart';
import '../models/race_presentation.dart';
import 'race_cursor.dart';
import '../../../widgets/flashcard_image.dart';

/// Final word-scramble score. Higher is better: rewards words solved, penalises
/// wrong attempts, and adds a speed bonus. Pure + deterministic.
///
/// [countTime] drops the speed bonus — see [memoryRaceScore] for why.
int scrambleScore({
  required int solved,
  required int wrong,
  required int elapsedSeconds,
  bool countTime = true,
}) {
  final timeBonus = countTime ? math.max(0, 150 - elapsedSeconds) : 0;
  return math.max(0, solved * 100 - wrong * 10 + timeBonus);
}

/// A self-contained, **star-free** word-scramble runner for one player.
///
/// The player taps scrambled letters to spell the Filipino word for the shown
/// English clue. Both racers solve the identical [items]. Reports live score /
/// progress and a final efficiency+speed score. Records no stars/XP/streak.
///
/// Overflow-proof: an always-scrolling body with letter [Wrap]s that reflow at
/// any width / font scale.
class ScrambleRacePlayer extends StatefulWidget {
  final List<MpScrambleItem> items;
  final Color accentColor;
  final bool isFilipino;
  final bool isPaused;

  /// Pacing / narration / target-size policy for this racer. See
  /// [RacePresentation]; defaults to the classic timed race.
  final RacePresentation presentation;

  /// Speaks [text] aloud. Injected by the screen so this widget stays pure.
  final void Function(String text)? speak;

  /// Opens the Filipino Sign Language clip for the clue word. Injected by the
  /// screen; null hides the control.
  final void Function(String cardId)? onShowSign;

  /// Hands-free cursor owned by the hosting screen's `GazeScope`. Null leaves
  /// the widget touch-only.
  final RaceCursor? cursor;

  final void Function(int score, int progress)? onProgress;
  final void Function(int score) onFinished;

  const ScrambleRacePlayer({
    super.key,
    required this.items,
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
  State<ScrambleRacePlayer> createState() => _ScrambleRacePlayerState();
}

enum _Result { none, correct, wrong }

enum _Pending { none, advance, clear }

class _ScrambleRacePlayerState extends State<ScrambleRacePlayer> {
  int _index = 0;
  int _solved = 0;
  int _wrong = 0;
  final List<int> _placed = []; // letter indices placed, in order
  _Result _result = _Result.none;
  _Pending _pending = _Pending.none;
  Timer? _timer;

  DateTime? _start;
  Duration _pausedTotal = Duration.zero;
  DateTime? _pauseStart;

  MpScrambleItem get _item => widget.items[_index];

  RacePresentation get _p => widget.presentation;

  @override
  void initState() {
    super.initState();
    if (widget.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _narrate());
    }
  }

  /// Read the clue aloud. The scrambled letters themselves are spoken too —
  /// without them a learner who cannot see the tiles has no letter bank.
  void _narrate() {
    if (!_p.speakPrompts || widget.speak == null) return;
    widget.speak!(_spokenClue());
  }

  String _spokenClue() {
    final letters = _item.letters.join(', ');
    return widget.isFilipino
        ? '${_item.prompt}. Mga letra: $letters.'
        : '${_item.prompt}. Letters: $letters.';
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.cursor?.detach();
    super.dispose();
  }

  // ─── Hands-free targets ───────────────────────────────
  // One flat list so a single left/right/choose gaze cursor reaches the whole
  // screen: the letter bank first (in the order they are drawn), then Clear,
  // then Skip, then the self-paced advance when one is owed.

  int get _letterCount => _item.letters.length;
  int get _clearTarget => _letterCount;
  int get _skipTarget => _letterCount + 1;
  int get _advanceTarget => _letterCount + 2;

  bool get _hasAdvanceTarget => _p.selfPaced && _pending != _Pending.none;

  void _attachCursor() {
    final cursor = widget.cursor;
    if (cursor == null) return;
    final idle = _result == _Result.none;
    cursor.attach(
      count: _letterCount + (_hasAdvanceTarget ? 3 : 2),
      enabled: !widget.isPaused,
      onChoose: () => _chooseTarget(cursor.index),
      isEnabledAt: (i) {
        if (i < _letterCount) return idle && !_placed.contains(i);
        if (i == _clearTarget) return idle && _placed.isNotEmpty;
        if (i == _skipTarget) return idle;
        return _hasAdvanceTarget;
      },
    );
  }

  /// Ring a control the hands-free highlight is resting on.
  Widget _focusRing(bool focused, Widget child) {
    if (!focused) return child;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.warning, width: 4),
      ),
      child: child,
    );
  }

  void _chooseTarget(int i) {
    if (i < _letterCount) {
      _place(i);
    } else if (i == _clearTarget) {
      _clearPlaced();
    } else if (i == _skipTarget) {
      _skip();
    } else {
      _runPending();
    }
  }

  @override
  void didUpdateWidget(ScrambleRacePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused && !oldWidget.isPaused) {
      _pauseStart = DateTime.now();
      _timer?.cancel();
    } else if (!widget.isPaused && oldWidget.isPaused) {
      if (_pauseStart != null) {
        _pausedTotal += DateTime.now().difference(_pauseStart!);
        _pauseStart = null;
      }
      if (_pending != _Pending.none) _scheduleAction(_pending);
    }
  }

  int _elapsedSeconds() => _start == null
      ? 0
      : DateTime.now().difference(_start!).inSeconds - _pausedTotal.inSeconds;

  void _place(int letterIndex) {
    if (widget.isPaused || _result != _Result.none) return;
    _start ??= DateTime.now();
    setState(() => _placed.add(letterIndex));
    if (_placed.length == _item.answer.length) _check();
  }

  void _removeAt(int slot) {
    if (widget.isPaused || _result != _Result.none) return;
    setState(() => _placed.removeAt(slot));
  }

  void _clearPlaced() {
    if (widget.isPaused || _result != _Result.none) return;
    setState(_placed.clear);
  }

  String get _built => _placed.map((i) => _item.letters[i]).join();

  int _score() => scrambleScore(
        solved: _solved,
        wrong: _wrong,
        elapsedSeconds: _elapsedSeconds(),
        countTime: _p.timeScoring,
      );

  void _check() {
    if (_built == _item.answer) {
      _solved++;
      setState(() => _result = _Result.correct);
      if (_p.haptics) {
        // ignore: discarded_futures
        HapticFeedback.mediumImpact();
      }
      widget.onProgress?.call(_score(), _index + 1);
      _scheduleAction(_Pending.advance);
    } else {
      _wrong++;
      setState(() => _result = _Result.wrong);
      if (_p.haptics) {
        // ignore: discarded_futures
        HapticFeedback.heavyImpact();
      }
      _scheduleAction(_Pending.clear);
    }
  }

  void _skip() {
    if (widget.isPaused || _result != _Result.none) return;
    _start ??= DateTime.now();
    // Report the skipped word as progress, otherwise an online opponent's
    // strip stalls on the last solved word for the rest of the match.
    widget.onProgress?.call(_score(), _index + 1);
    _scheduleAction(_Pending.advance);
  }

  /// Run the owed action now (self-paced profiles drive this from a button
  /// instead of a timer).
  void _runPending() {
    if (widget.isPaused || _pending == _Pending.none) return;
    final action = _pending;
    _timer?.cancel();
    _pending = _Pending.none;
    _apply(action);
  }

  void _scheduleAction(_Pending action) {
    _pending = action;
    _timer?.cancel();
    // Self-paced: hold the feedback on screen until the learner taps.
    if (_p.selfPaced) {
      setState(() {});
      return;
    }
    final ms = action == _Pending.advance ? 700 : 600;
    _timer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      _pending = _Pending.none;
      _apply(action);
    });
  }

  void _apply(_Pending action) {
    if (action == _Pending.clear) {
      setState(() {
        _placed.clear();
        _result = _Result.none;
      });
      return;
    }
    // advance
    if (_index + 1 >= widget.items.length) {
      widget.onFinished(_score());
      return;
    }
    setState(() {
      _index++;
      _placed.clear();
      _result = _Result.none;
    });
    widget.cursor?.reset();
    _narrate();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final hc = HCColor.of(context);
    final item = _item;
    final total = widget.items.length;
    final answerLen = item.answer.length;
    final placedSet = _placed.toSet();
    _attachCursor();
    final cursor = widget.cursor;

    final feedbackColor = switch (_result) {
      _Result.correct => AppColors.success,
      _Result.wrong => AppColors.error,
      _Result.none => widget.accentColor,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          // ── Progress ──
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value:
                        (_index + (_result == _Result.correct ? 1 : 0)) / total,
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

          // ── Clue card ──
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
                FlashcardPictureById(
                  cardId: item.cardId,
                  fallback: item.promptEmoji,
                  extent: 52,
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.prompt,
                    style: AppTypography.displaySmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: hc.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isFilipino
                      ? 'Ayusin ang salitang Filipino'
                      : 'Spell it in Filipino',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Answer slots (tap a placed letter to remove it) ──
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: List.generate(answerLen, (slot) {
              final hasLetter = slot < _placed.length;
              final letter = hasLetter ? _item.letters[_placed[slot]] : '';
              return GestureDetector(
                onTap: hasLetter ? () => _removeAt(slot) : null,
                child: Container(
                  width: _p.bigTargets ? 58 : 46,
                  height: _p.bigTargets ? 66 : 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasLetter
                        ? feedbackColor.withValues(alpha: 0.15)
                        : hc.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasLetter ? feedbackColor : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      letter.toUpperCase(),
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        color: feedbackColor,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // ── Scrambled letter bank ──
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: List.generate(item.letters.length, (i) {
              final used = placedSet.contains(i);
              // Hands-free highlight: which letter a blink would place.
              final focused = cursor?.isFocused(i) ?? false;
              return GestureDetector(
                onTap: used ? null : () => _place(i),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: used ? 0.25 : 1,
                  child: Container(
                    width: _p.bigTargets ? 64 : 50,
                    height: _p.bigTargets ? 72 : 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: focused
                          ? Border.all(color: AppColors.warning, width: 4)
                          : null,
                      boxShadow: AppColors.softShadow,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.letters[i].toUpperCase(),
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // ── Controls ──
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              _focusRing(
                cursor?.isFocused(_clearTarget) ?? false,
                OutlinedButton.icon(
                  onPressed: _result == _Result.none && _placed.isNotEmpty
                      ? _clearPlaced
                      : null,
                  icon: const Icon(Icons.backspace_outlined, size: 18),
                  label: Text(widget.isFilipino ? 'Burahin' : 'Clear'),
                ),
              ),
              _focusRing(
                cursor?.isFocused(_skipTarget) ?? false,
                TextButton.icon(
                  onPressed: _result == _Result.none ? _skip : null,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: Text(widget.isFilipino ? 'Laktawan' : 'Skip'),
                ),
              ),
              if (_p.canSpeak && widget.speak != null)
                TextButton.icon(
                  onPressed: () => widget.speak!(_spokenClue()),
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  label: Text(
                      widget.isFilipino ? 'Pakinggan ulit' : 'Hear it again'),
                ),
              if (_p.showFsl && widget.onShowSign != null && item.cardId != null)
                TextButton.icon(
                  onPressed: () => widget.onShowSign!(item.cardId!),
                  icon: const Icon(Icons.sign_language_rounded, size: 18),
                  label: Text(widget.isFilipino
                      ? 'Ipakita ang senyas'
                      : 'Show the sign'),
                ),
            ],
          ),

          // ── Self-paced advance ──
          if (_p.selfPaced && _pending != _Pending.none) ...[
            const SizedBox(height: 16),
            _focusRing(
              cursor?.isFocused(_advanceTarget) ?? false,
              SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.isPaused ? null : _runPending,
                icon: Icon(
                  _pending == _Pending.clear
                      ? Icons.refresh_rounded
                      : (_index + 1 >= total
                          ? Icons.flag_rounded
                          : Icons.arrow_forward_rounded),
                  size: 24,
                ),
                label: Text(
                  _pending == _Pending.clear
                      ? (widget.isFilipino ? 'Subukan ulit' : 'Try again')
                      : (_index + 1 >= total
                          ? (widget.isFilipino ? 'Tapusin' : 'Finish')
                          : (widget.isFilipino ? 'Susunod' : 'Next')),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: feedbackColor,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
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
