import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'screens/break_time_screen.dart';

/// Opens the full-screen "I Need a Break" experience and resolves when the
/// student returns to their lesson.
///
/// Pushes an **opaque full-screen route on the root navigator**, so it covers
/// everything (including the bottom navigation) while the underlying lesson /
/// flashcard / game stays alive in the stack — popping it returns the student
/// to the exact same place, in the exact same state. Works the same on every
/// Android phone, tablet, and OS version (pure Flutter navigation, no plugins).
///
/// Callers that run their own timers / media (e.g. flashcard auto-play, a timed
/// game) should pause before awaiting this and resume after, so the lesson is
/// truly on hold during the break. [BreakButton] wires that up via its
/// [BreakButton.onBreakStart] / [BreakButton.onBreakEnd] hooks.
Future<void> showBreakTime(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      barrierColor: Colors.black,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => const BreakTimeScreen(),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

/// A visible "I Need a Break" button students can tap whenever they feel
/// overwhelmed. Renders as an [IconButton] (drop it into an `AppBar`'s actions,
/// or anywhere an icon button fits) with a calming self-care icon.
///
/// Opening the break runs [onBreakStart] (pause the lesson), shows the break,
/// then runs [onBreakEnd] (resume) — so the student lands back exactly where
/// they left off. Both hooks are optional; surfaces with nothing to pause (a
/// static flashcard) can omit them.
class BreakButton extends StatelessWidget {
  const BreakButton({
    super.key,
    this.onBreakStart,
    this.onBreakEnd,
    this.color,
    this.tooltip = 'I need a break',
  });

  /// Called just before the break opens — pause timers / media here.
  final VoidCallback? onBreakStart;

  /// Called after the student returns from the break — resume here. Guard with
  /// a `mounted` check in the host, since it runs after an `await`.
  final VoidCallback? onBreakEnd;

  /// Icon tint (defaults to the icon theme colour).
  final Color? color;

  final String tooltip;

  Future<void> _open(BuildContext context) async {
    onBreakStart?.call();
    await showBreakTime(context);
    onBreakEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(Icons.self_improvement_rounded, color: color),
      onPressed: () => _open(context),
    );
  }
}

/// An always-visible floating "Break" pill for **gameplay**, so an overwhelmed
/// student can reach a calming break in one tap (the pause-menu option stays
/// too). Drop it into a game's full-screen `Stack` — it returns a
/// [Positioned.fill] that anchors a compact pill to the bottom-left inside the
/// safe area, and only the pill itself absorbs taps (the rest of the game stays
/// interactive). When the game is paused the pause overlay paints over it.
///
/// Tapping it [onHold]s the game (pause the timer + media without showing the
/// pause overlay), opens the break, then [onResume]s — so the student lands
/// straight back in the same round. Wire these to
/// `GamePauseMixin.holdForBreak` / `resumeFromBreak`.
///
/// Compatibility: a stadium pill with a `min` height of 48 (a comfortable touch
/// target on any phone), safe-area insets on every side it touches, and a
/// high-contrast variant — so it reads and works on every Android phone,
/// tablet, and OS version, in any orientation.
class GameBreakButton extends StatelessWidget {
  const GameBreakButton({
    super.key,
    required this.onHold,
    required this.onResume,
  });

  /// Pause the game (timer + media) before the break opens.
  final VoidCallback onHold;

  /// Resume the game after the student returns from the break.
  final VoidCallback onResume;

  Future<void> _open(BuildContext context) async {
    onHold();
    await showBreakTime(context);
    onResume();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final bool highContrast = hc.hc;
    final Color bg = highContrast ? Colors.black : const Color(0xFF26A69A);
    final Color fg = highContrast ? const Color(0xFFFFEB3B) : Colors.white;

    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Semantics(
              button: true,
              label: 'I need a break',
              child: Tooltip(
                message: 'I need a break',
                child: Material(
                  color: bg,
                  elevation: 6,
                  shadowColor: Colors.black54,
                  shape: StadiumBorder(
                    side: highContrast
                        ? const BorderSide(color: Color(0xFFFFEB3B), width: 2)
                        : BorderSide(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => _open(context),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.self_improvement_rounded,
                              color: fg,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Break',
                              style: TextStyle(
                                color: fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
