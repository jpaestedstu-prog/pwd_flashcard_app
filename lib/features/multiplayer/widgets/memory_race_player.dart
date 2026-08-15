import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart' show ResponsiveExtension;
import '../models/multiplayer_models.dart';
import '../models/race_presentation.dart';
import 'race_cursor.dart';
import '../../../widgets/flashcard_image.dart';

/// Final memory-race score from gameplay stats. Higher is better, so the
/// head-to-head [computeOutcome] picks the more efficient + faster player.
/// Pure + deterministic. Both players always clear the board, so efficiency
/// (fewer wasted flips) and speed are the differentiators.
///
/// [countTime] drops the speed bonus, leaving pure efficiency. Set false when
/// either racer's [RacePresentation] needs an untimed score — a stopwatch is
/// not a fair tie-breaker against a learner who cannot hurry.
int memoryRaceScore({
  required int pairs,
  required int moves,
  required int elapsedSeconds,
  bool countTime = true,
}) {
  final wasted = math.max(0, moves - pairs);
  final efficiency = pairs * 100 - wasted * 15;
  final timeBonus = countTime ? math.max(0, 90 - elapsedSeconds) : 0;
  return math.max(10, efficiency + timeBonus);
}

/// A self-contained, **star-free** memory match runner for one player.
///
/// Both racers receive the identical shuffled [layout]; each clears their own
/// board. Reports live progress (pairs found) via [onProgress] and the final
/// efficiency+speed score via [onFinished]. Records no stars/XP/streak.
///
/// Overflow-proof: the board lives in an [OverflowSafeBody] with a
/// `shrinkWrap` grid sized by `context.responsiveTier` columns, so it scrolls
/// rather than overflowing at any size / font scale.
class MemoryRacePlayer extends StatefulWidget {
  final List<MemoryCardSpec> layout;
  final Color accentColor;
  final bool isFilipino;

  /// When true, taps are ignored, pending flip-back/finish timers are
  /// suspended, and the elapsed-time clock is frozen (so a pause can't lower
  /// the player's score).
  final bool isPaused;

  /// Pacing / target-size policy for this racer. See [RacePresentation];
  /// defaults to the classic timed board.
  final RacePresentation presentation;

  /// Opens the Filipino Sign Language clip for a card. Wired to *matched*
  /// cards, which are otherwise inert — so a signing learner can collect the
  /// sign for each pair they clear without it ever interfering with play.
  final void Function(String cardId)? onShowSign;

  /// Hands-free cursor owned by the hosting screen's `GazeScope`. Null leaves
  /// the board touch-only.
  final RaceCursor? cursor;

  /// (runningScore, pairsFound) after each matched pair.
  final void Function(int score, int progress)? onProgress;

  /// Final score once every pair is found.
  final void Function(int score) onFinished;

  const MemoryRacePlayer({
    super.key,
    required this.layout,
    required this.onFinished,
    this.onProgress,
    this.accentColor = AppColors.primary,
    this.isFilipino = false,
    this.isPaused = false,
    this.presentation = RacePresentation.standard,
    this.onShowSign,
    this.cursor,
  });

  @override
  State<MemoryRacePlayer> createState() => _MemoryRacePlayerState();
}

class _MemoryRacePlayerState extends State<MemoryRacePlayer> {
  final Set<int> _flipped = {};
  final Set<int> _matched = {};
  int _moves = 0;
  bool _busy = false;
  DateTime? _start;
  Timer? _flipBackTimer;
  Timer? _finishTimer;

  // Pause bookkeeping so the elapsed clock excludes paused time and pending
  // timers resume cleanly.
  Duration _pausedTotal = Duration.zero;
  DateTime? _pauseStart;
  bool _flipBackPending = false;
  bool _finishedCalled = false;

  int get _pairs => widget.layout.length ~/ 2;
  int get _matchedPairs => _matched.length ~/ 2;

  RacePresentation get _p => widget.presentation;

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    _finishTimer?.cancel();
    widget.cursor?.detach();
    super.dispose();
  }

  /// Publish the board's hands-free targets: every face-down card, with
  /// cleared pairs and the card already turned this turn skipped, so the
  /// highlight only ever rests somewhere a blink does something.
  void _attachCursor() {
    widget.cursor?.attach(
      count: widget.layout.length,
      enabled: !widget.isPaused && !_busy,
      onChoose: () => _tap(widget.cursor!.index),
      isEnabledAt: (i) => !_matched.contains(i) && !_flipped.contains(i),
    );
  }

  @override
  void didUpdateWidget(MemoryRacePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused && !oldWidget.isPaused) {
      _pauseStart = DateTime.now();
      _flipBackTimer?.cancel();
      _finishTimer?.cancel();
    } else if (!widget.isPaused && oldWidget.isPaused) {
      if (_pauseStart != null) {
        _pausedTotal += DateTime.now().difference(_pauseStart!);
        _pauseStart = null;
      }
      if (_flipBackPending) _scheduleFlipBack();
      if (_matchedPairs >= _pairs && _pairs > 0 && !_finishedCalled) {
        _scheduleFinish();
      }
    }
  }

  void _tap(int i) {
    // A cleared card is inert to play, so re-tapping it is free to mean
    // "show me this sign" for a learner whose primary modality is FSL.
    if (_matched.contains(i)) {
      if (_p.showFsl && widget.onShowSign != null) {
        widget.onShowSign!(widget.layout[i].cardId);
      }
      return;
    }
    if (widget.isPaused || _busy || _flipped.contains(i)) {
      return;
    }
    _start ??= DateTime.now();

    setState(() => _flipped.add(i));
    if (_flipped.length < 2) return;

    _moves++;
    final pair = _flipped.toList();
    final isMatch =
        widget.layout[pair[0]].cardId == widget.layout[pair[1]].cardId;

    if (isMatch) {
      setState(() {
        _matched.addAll(pair);
        _flipped.clear();
      });
      if (_p.haptics) {
        // ignore: discarded_futures
        HapticFeedback.mediumImpact();
      }
      widget.onProgress?.call(
        memoryRaceScore(
          pairs: _matchedPairs,
          moves: _moves,
          elapsedSeconds: _elapsedSeconds(),
          countTime: _p.timeScoring,
        ),
        _matchedPairs,
      );
      if (_matchedPairs >= _pairs) _scheduleFinish();
    } else {
      setState(() => _busy = true);
      if (_p.haptics) {
        // ignore: discarded_futures
        HapticFeedback.lightImpact();
      }
      _scheduleFlipBack();
    }
  }

  void _scheduleFlipBack() {
    _flipBackPending = true;
    _flipBackTimer?.cancel();
    // A much longer look for profiles that need processing time — the board
    // still auto-recovers (it would otherwise lock), just not in a blink.
    _flipBackTimer = Timer(_p.flipBackDelay, () {
      if (!mounted) return;
      setState(() {
        _flipped.clear();
        _busy = false;
        _flipBackPending = false;
      });
    });
  }

  void _scheduleFinish() {
    _finishTimer?.cancel();
    _finishTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _finishedCalled) return;
      _finishedCalled = true;
      widget.onFinished(
        memoryRaceScore(
          pairs: _pairs,
          moves: _moves,
          elapsedSeconds: _elapsedSeconds(),
          countTime: _p.timeScoring,
        ),
      );
    });
  }

  int _elapsedSeconds() => _start == null
      ? 0
      : DateTime.now().difference(_start!).inSeconds - _pausedTotal.inSeconds;

  @override
  Widget build(BuildContext context) {
    if (widget.layout.isEmpty) return const SizedBox.shrink();
    final hc = HCColor.of(context);
    _attachCursor();
    final cursor = widget.cursor;

    // Always-scrolling board so a 16-card grid never overflows a short
    // viewport at any font scale or tablet size.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          // ── Header: pairs found + moves ──
          // Wrap (not Row) so the two pills drop to a second line at large
          // font scales instead of overflowing a narrow tablet width.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _statPill(
                context,
                emoji: '🧩',
                label: widget.isFilipino ? 'Pares' : 'Pairs',
                value: '$_matchedPairs/$_pairs',
                color: widget.accentColor,
              ),
              _statPill(
                context,
                emoji: '🔁',
                label: widget.isFilipino ? 'Galaw' : 'Moves',
                value: '$_moves',
                color: hc.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Card board ──
          GridView.count(
            // One column fewer for profiles that need a bigger tap area — the
            // board scrolls, so the cards simply grow.
            crossAxisCount: _p.columnsFrom(
              context.responsiveTier<int>(
                phone: 3,
                tablet: 4,
                large: 5,
                xl: 6,
              ),
            ),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(widget.layout.length, (i) {
              final spec = widget.layout[i];
              final isUp = _flipped.contains(i) || _matched.contains(i);
              final isMatched = _matched.contains(i);
              // Hands-free highlight: which card a blink would turn over.
              final focused = cursor?.isFocused(i) ?? false;
              return GestureDetector(
                onTap: () => _tap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isUp
                        ? (isMatched
                              ? AppColors.success.withValues(alpha: 0.15)
                              : hc.surface)
                        : widget.accentColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: focused
                          ? AppColors.warning
                          : isMatched
                          ? AppColors.success
                          : isUp
                          ? widget.accentColor
                          : Colors.transparent,
                      width: focused ? 5 : 2,
                    ),
                    boxShadow: AppColors.softShadow,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(6),
                  child: isUp
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: FlashcardPictureById(
                                  cardId: spec.cardId,
                                  fallback: spec.emoji,
                                  extent: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              spec.label,
                              style: AppTypography.labelSmall.copyWith(
                                color: hc.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('❓', style: TextStyle(fontSize: 32)),
                        ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _statPill(
    BuildContext context, {
    required String emoji,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: AppTypography.labelSmall.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: color == HCColor.of(context).textSecondary
                  ? HCColor.of(context).textPrimary
                  : color,
            ),
          ),
        ],
      ),
    );
  }
}
