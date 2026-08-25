import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../models/break_time_models.dart';
import '../widgets/breathing_break.dart';
import '../widgets/bubble_pop_break.dart';

/// Full-screen "I Need a Break" experience.
///
/// Flow: a calm chooser ("Breathe" or "Pop Bubbles") → the chosen no-fail
/// activity with a gentle ~1-minute timer → a soft "ready to go back?" prompt
/// (never forced — the student can stay longer). Closing at any point pops this
/// route, returning the student to the **exact** lesson / flashcard / game they
/// left (that screen is preserved underneath this route).
///
/// Pushed via `showBreakTime(context)` in `break_time.dart`.
///
/// Deliberately side-effect free: it reads accessibility settings but writes
/// nothing (no Hive, no analytics), so it's safe to open from anywhere and in
/// any usage scenario.
class BreakTimeScreen extends ConsumerStatefulWidget {
  const BreakTimeScreen({super.key});

  @override
  ConsumerState<BreakTimeScreen> createState() => _BreakTimeScreenState();
}

class _BreakTimeScreenState extends ConsumerState<BreakTimeScreen> {
  static const int _breakSeconds = 60;

  // Soft, vibrant-but-gentle palette (never harsh — matches the app's design).
  static const List<Color> _bubbleColors = [
    Color(0xFF4FC3F7), // light blue
    Color(0xFF4DD0E1), // cyan
    Color(0xFF9575CD), // lavender
    Color(0xFF81C784), // green
    Color(0xFFFFB74D), // soft orange
    Color(0xFFF06292), // pink
  ];
  static const Color _breatheColor = Color(0xFF4FC3F7);

  BreakActivity? _activity; // null = chooser stage
  Timer? _timer;
  int _remaining = _breakSeconds;
  bool _showReturnPrompt = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _choose(BreakActivity activity) {
    ref.read(hapticServiceProvider).lightTap();
    setState(() => _activity = activity);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _remaining = _breakSeconds;
      _showReturnPrompt = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _remaining = 0;
          _timer?.cancel();
          _showReturnPrompt = true;
        }
      });
    });
  }

  void _stayLonger() {
    ref.read(hapticServiceProvider).lightTap();
    _startTimer();
  }

  /// Open the mood check-in, tagged as a break-time reading.
  ///
  /// Navigates rather than recording inline, so this screen keeps the
  /// side-effect-free property described in the class doc — the mood screen
  /// owns the write, exactly as it does everywhere else.
  void _checkInMood() {
    ref.read(hapticServiceProvider).lightTap();
    // Push, so the learner lands back on the break when they are done and can
    // still choose to stay longer.
    context.push('/mood-check-in?ctx=break_time');
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isHc = hc.isDark; // dark / high-contrast theme
    final reducedMotion = ref.watch(
      settingsProvider.select((s) => s.reducedMotion),
    );
    final highContrast =
        isHc || ref.watch(settingsProvider.select((s) => s.highContrastMode));

    // Calm backdrop: a soft light gradient normally; a solid dark surface in
    // dark / high-contrast mode (where the glowing activity reads best).
    final BoxDecoration backdrop = isHc
        ? BoxDecoration(color: hc.background)
        : const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8F4FD), Color(0xFFF1ECFB)],
            ),
          );

    // The Android Back button simply pops this route and returns to the
    // lesson — the default behaviour, exactly what we want, so no PopScope.
    return Scaffold(
      body: DecoratedBox(
        decoration: backdrop,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _TopBar(
                    hc: hc,
                    remaining: _activity == null ? null : _remaining,
                    total: _breakSeconds,
                    onClose: _close,
                  ),
                  Expanded(
                    child: _activity == null
                        ? _ChooserView(hc: hc, onChoose: _choose)
                        : _ActivityView(
                            activity: _activity!,
                            hc: hc,
                            reducedMotion: reducedMotion,
                            highContrast: highContrast,
                            breatheColor: _breatheColor,
                            bubbleColors: _bubbleColors,
                            onPop: () =>
                                ref.read(hapticServiceProvider).selectionClick(),
                            onBack: _close,
                          ),
                  ),
                ],
              ),
              if (_showReturnPrompt)
                _ReturnPrompt(
                  hc: hc,
                  onBack: _close,
                  onStay: _stayLonger,
                  onCheckIn: _checkInMood,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Top bar (title + countdown + close) ───────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.hc,
    required this.remaining,
    required this.total,
    required this.onClose,
  });

  final HCColor hc;
  final int? remaining; // null on the chooser stage
  final int total;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Icon(Icons.spa_rounded, color: hc.primary, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Take a Break',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: hc.textPrimary,
              ),
            ),
          ),
          if (remaining != null) ...[
            _CountdownChip(remaining: remaining!, total: total, hc: hc),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: onClose,
            tooltip: 'Back to lesson',
            icon: Icon(Icons.close_rounded, color: hc.textPrimary),
            style: IconButton.styleFrom(
              backgroundColor: hc.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownChip extends StatelessWidget {
  const _CountdownChip({
    required this.remaining,
    required this.total,
    required this.hc,
  });

  final int remaining;
  final int total;
  final HCColor hc;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Counts UP as the break elapses (a calm "filling" ring), so it never
          // feels like a stressful countdown to zero.
          CircularProgressIndicator(
            value: total == 0 ? 0 : (total - remaining) / total,
            strokeWidth: 3,
            backgroundColor: hc.primary.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation(hc.primary),
          ),
          Text(
            '$remaining',
            style: AppTypography.labelSmall.copyWith(
              color: hc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chooser stage ─────────────────────────────────────

class _ChooserView extends StatelessWidget {
  const _ChooserView({required this.hc, required this.onChoose});

  final HCColor hc;
  final ValueChanged<BreakActivity> onChoose;

  // Per-activity accent for the chooser card.
  Color _accent(BreakActivity a) => switch (a) {
        BreakActivity.breathing => const Color(0xFF4FC3F7),
        BreakActivity.bubbles => const Color(0xFF4DD0E1),
      };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Let's take a calm break",
            textAlign: TextAlign.center,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick what feels good. You can go back to your lesson anytime.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 24),
          // Side-by-side on wider screens (tablets / landscape), stacked on
          // narrow phones — never overflows.
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                for (final a in BreakActivity.values)
                  _ActivityChooserCard(
                    activity: a,
                    accent: _accent(a),
                    hc: hc,
                    onTap: () => onChoose(a),
                  ),
              ];
              if (constraints.maxWidth >= 520) {
                // IntrinsicHeight gives the stretch Row a bounded cross-axis
                // extent (both cards match the taller one) even though it sits
                // in a vertical scroll view.
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[1]),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 16),
                  cards[1],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 16,
                color: hc.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  "Breaks are always okay. You'll go right back to where you were.",
                  textAlign: TextAlign.center,
                  style:
                      AppTypography.bodySmall.copyWith(color: hc.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityChooserCard extends StatelessWidget {
  const _ActivityChooserCard({
    required this.activity,
    required this.accent,
    required this.hc,
    required this.onTap,
  });

  final BreakActivity activity;
  final Color accent;
  final HCColor hc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${activity.label}. ${activity.description}',
      child: Material(
        color: hc.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accent.withValues(alpha: 0.45), width: 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.16),
                  accent.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    activity.emoji,
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activity.label,
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: hc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.description,
                        style: AppTypography.bodyMedium.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: hc.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Active break (breathing / bubbles) ────────────────

class _ActivityView extends StatelessWidget {
  const _ActivityView({
    required this.activity,
    required this.hc,
    required this.reducedMotion,
    required this.highContrast,
    required this.breatheColor,
    required this.bubbleColors,
    required this.onPop,
    required this.onBack,
  });

  final BreakActivity activity;
  final HCColor hc;
  final bool reducedMotion;
  final bool highContrast;
  final Color breatheColor;
  final List<Color> bubbleColors;
  final VoidCallback onPop;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (activity) {
      BreakActivity.breathing => BreathingBreak(
          color: breatheColor,
          textColor: hc.textPrimary,
          reducedMotion: reducedMotion,
          highContrast: highContrast,
        ),
      BreakActivity.bubbles => BubblePopBreak(
          colors: bubbleColors,
          reducedMotion: reducedMotion,
          onPop: onPop,
        ),
    };

    return Column(
      children: [
        Expanded(child: body),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to lesson'),
            style: OutlinedButton.styleFrom(
              foregroundColor: hc.primary,
              side: BorderSide(color: hc.primary.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Gentle "ready to go back?" prompt (never forced) ──

class _ReturnPrompt extends StatelessWidget {
  const _ReturnPrompt({
    required this.hc,
    required this.onBack,
    required this.onStay,
    required this.onCheckIn,
  });

  final HCColor hc;
  final VoidCallback onBack;
  final VoidCallback onStay;

  /// Opens the mood check-in, filed under the break-time context.
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Color(0x66000000)),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 14,
              color: hc.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      'Feeling calmer?',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Take your time. Head back when you're ready.",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back to lesson'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: onStay,
                        icon: const Icon(Icons.spa_rounded),
                        label: const Text('Stay a little longer'),
                      ),
                    ),
                    // Offered, never asked. This card already asks whether
                    // the learner feels calmer, which is the moment they are
                    // most able to name it — but a break is a place to
                    // regulate, not a survey, so recording it stays a choice
                    // and nothing here blocks the way back to the lesson.
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: onCheckIn,
                        icon: const Icon(Icons.favorite_border_rounded),
                        label: const Text('How are you feeling?'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
