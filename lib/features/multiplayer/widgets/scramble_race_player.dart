import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/multiplayer_models.dart';

/// Final word-scramble score. Higher is better: rewards words solved, penalises
/// wrong attempts, and adds a speed bonus. Pure + deterministic.
int scrambleScore({
  required int solved,
  required int wrong,
  required int elapsedSeconds,
}) {
  final timeBonus = math.max(0, 150 - elapsedSeconds);
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  void _check() {
    if (_built == _item.answer) {
      _solved++;
      setState(() => _result = _Result.correct);
      widget.onProgress?.call(
        scrambleScore(
            solved: _solved, wrong: _wrong, elapsedSeconds: _elapsedSeconds()),
        _index + 1,
      );
      _scheduleAction(_Pending.advance);
    } else {
      _wrong++;
      setState(() => _result = _Result.wrong);
      _scheduleAction(_Pending.clear);
    }
  }

  void _skip() {
    if (widget.isPaused || _result != _Result.none) return;
    _start ??= DateTime.now();
    _scheduleAction(_Pending.advance);
  }

  void _scheduleAction(_Pending action) {
    _pending = action;
    _timer?.cancel();
    final ms = action == _Pending.advance ? 700 : 600;
    _timer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      _pending = _Pending.none;
      if (action == _Pending.clear) {
        setState(() {
          _placed.clear();
          _result = _Result.none;
        });
        return;
      }
      // advance
      if (_index + 1 >= widget.items.length) {
        widget.onFinished(scrambleScore(
            solved: _solved,
            wrong: _wrong,
            elapsedSeconds: _elapsedSeconds()));
        return;
      }
      setState(() {
        _index++;
        _placed.clear();
        _result = _Result.none;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final hc = HCColor.of(context);
    final item = _item;
    final total = widget.items.length;
    final answerLen = item.answer.length;
    final placedSet = _placed.toSet();

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
                    value: (_index + (_result == _Result.correct ? 1 : 0)) /
                        total,
                    minHeight: 10,
                    backgroundColor: AppColors.border,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(widget.accentColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${_index + 1}/$total',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: hc.textSecondary,
                  )),
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
                Text(item.promptEmoji, style: const TextStyle(fontSize: 44)),
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
                  style: AppTypography.bodySmall
                      .copyWith(color: hc.textSecondary),
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
                  width: 46,
                  height: 52,
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
              return GestureDetector(
                onTap: used ? null : () => _place(i),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: used ? 0.25 : 1,
                  child: Container(
                    width: 50,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
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
              OutlinedButton.icon(
                onPressed:
                    _result == _Result.none && _placed.isNotEmpty
                        ? _clearPlaced
                        : null,
                icon: const Icon(Icons.backspace_outlined, size: 18),
                label: Text(widget.isFilipino ? 'Burahin' : 'Clear'),
              ),
              TextButton.icon(
                onPressed: _result == _Result.none ? _skip : null,
                icon: const Icon(Icons.skip_next_rounded, size: 18),
                label: Text(widget.isFilipino ? 'Laktawan' : 'Skip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
