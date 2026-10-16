import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'screens/break_time_screen.dart';
import '../../l10n/app_localizations.dart';

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
    this.tooltip,
  });

  /// Called just before the break opens — pause timers / media here.
  final VoidCallback? onBreakStart;

  /// Called after the student returns from the break — resume here. Guard with
  /// a `mounted` check in the host, since it runs after an `await`.
  final VoidCallback? onBreakEnd;

  /// Icon tint (defaults to the icon theme colour).
  final Color? color;

  /// Overrides the label. Null uses the localized "I need a break".
  final String? tooltip;

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

/// An always-visible "Break" pill for **gameplay**, so an overwhelmed student
/// can reach a calming break in one tap (the pause-menu option stays too).
/// Put it in the game's `Scaffold.bottomNavigationBar`: it is a lane of its
/// own under the game, so the game is laid out above it and nothing of the
/// game is ever underneath. (It used to float over the game, bottom-left, and
/// covered answer cards, buttons and puzzle pieces in 11 of 13 games on a
/// phone, some on a tablet too: a tap there opened a break instead.) When the
/// game is paused the pause overlay paints over it.
///
/// Tapping it [onHold]s the game (pause the timer + media without showing the
/// pause overlay), opens the break, then [onResume]s — so the student lands
/// straight back in the same round. Wire these to
/// `GamePauseMixin.holdForBreak` / `resumeFromBreak`.
///
/// Compatibility: a stadium pill with a `min` height of 48 (a comfortable touch
/// target on any phone), clear of the system's bottom bar, and a
/// high-contrast variant — so it reads and works on every Android phone,
/// tablet, and OS version, in any orientation.
class GameBreakBar extends StatelessWidget {
  const GameBreakBar({
    super.key,
    required this.onHold,
    required this.onResume,
  });

  /// Pause the game (timer + media) before the break opens.
  final VoidCallback onHold;

  /// Resume the game after the student returns from the break.
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    // A short screen gets the pill in its app bar instead (GameBreakAction).
    if (breakPillInAppBar(context)) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          heightFactor: 1,
          child: _BreakPill(
            onTap: () => _openBreak(context, onHold, onResume),
          ),
        ),
      ),
    );
  }
}

/// The same pill for a game's `AppBar.actions`, shown only on a short screen
/// (a phone held sideways), where the [GameBreakBar] lane would take a sixth
/// of the height the game needs and the app bar has width to spare. Every
/// game has both; exactly one of them shows.
class GameBreakAction extends StatelessWidget {
  const GameBreakAction({
    super.key,
    required this.onHold,
    required this.onResume,
  });

  final VoidCallback onHold;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    if (!breakPillInAppBar(context)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(
        child: _BreakPill(onTap: () => _openBreak(context, onHold, onResume)),
      ),
    );
  }
}

/// Whether the Break pill sits in the app bar rather than in its own lane
/// under the game: on a screen under 480 dp tall.
bool breakPillInAppBar(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 480;

Future<void> _openBreak(
  BuildContext context,
  VoidCallback onHold,
  VoidCallback onResume,
) async {
  onHold();
  await showBreakTime(context);
  onResume();
}

class _BreakPill extends StatelessWidget {
  const _BreakPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hc = HCColor.of(context);
    final bool highContrast = hc.hc;
    final Color bg = highContrast
        ? Colors.black
        : hc.fillFor(const Color(0xFF26A69A));
    final Color fg = highContrast ? const Color(0xFFFFEB3B) : Colors.white;

    return Semantics(
      button: true,
      label: l10n.iNeedABreakTooltip,
      child: Tooltip(
        message: l10n.iNeedABreakTooltip,
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
            onTap: onTap,
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
                      l10n.breakButton,
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
    );
  }
}
