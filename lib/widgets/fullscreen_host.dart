import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/fullscreen_provider.dart';
import 'app_icon_button.dart';

/// Height of the slim bar shown in fullscreen mode.
///
/// 48dp, not less: that is the app's minimum tap target (see the global
/// `iconButtonTheme`), and the two controls the bar still carries — the
/// screen's own back/close button and [_ExitFullscreenButton] — are exactly
/// that tall. Shaving the bar any thinner would squeeze the one affordance a
/// motor-impaired learner needs most, to buy 8 logical pixels.
const double kFullscreenToolbarHeight = 48.0;

/// Wraps a screen's [AppBar] so it collapses when fullscreen ("presentation")
/// mode is on — see [fullscreenModeProvider].
///
/// Call it in place of the bar itself:
///
/// ```dart
/// Scaffold(
///   appBar: fullscreenBar(ref, AppBar(title: Text('Spelling Bee'))),
///   body: ...,
/// )
/// ```
///
/// With the mode **off** (the default) [bar] is returned untouched, so every
/// screen looks and behaves exactly as it would without this call.
///
/// With the mode **on** the bar shrinks to a 48dp strip. Only the **title** is
/// dropped; the screen's leading control, its [AppBar.actions] and its
/// [AppBar.bottom] all survive, and an exit-fullscreen button is appended to
/// the actions.
///
/// Keeping the actions is the whole difference between a presentation mode and
/// a trap. App-bar actions in this app are not decoration: the flashcard
/// viewer's "I Need a Break" is how an overwhelmed student stops the lesson,
/// and its auto-play toggle is how they control pacing. A learner does not
/// stop needing either because a teacher put the tablet on a projector. The
/// title is the one thing that is purely a label, so the title is what goes.
///
/// [AppBar.bottom] survives for the same reason: the one screen that uses it,
/// Smart Review, puts its progress bar there, and that is the learner's only
/// sense of how far through the deck they are. It costs 4dp.
///
/// Together with [BottomNavShell] — which hides the tab bar for the same
/// provider — this is what makes the mode fullscreen rather than merely tidy.
PreferredSizeWidget fullscreenBar(WidgetRef ref, AppBar bar) {
  // watch, not read: toggling the mode must rebuild the hosting screen so the
  // bar swaps immediately, the same way the nav bar animates away.
  if (!ref.watch(fullscreenModeProvider)) return bar;

  return _SlimFullscreenBar(
    leading: bar.leading,
    automaticallyImplyLeading: bar.automaticallyImplyLeading,
    actions: bar.actions,
    bottom: bar.bottom,
  );
}

/// The collapsed bar: the screen's leading control on the left, its own
/// actions plus "exit fullscreen" on the right, and no title between them.
class _SlimFullscreenBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _SlimFullscreenBar({
    required this.leading,
    required this.automaticallyImplyLeading,
    required this.actions,
    required this.bottom,
  });

  /// The wrapped bar's own leading widget, carried over verbatim so each
  /// screen keeps *its* exit route (close vs. back, and the fallback route an
  /// [AppBackButton] was given) rather than a generic one.
  final Widget? leading;

  /// Carried over too, so a screen that passed no [leading] still gets the
  /// automatic back button it would normally have.
  final bool automaticallyImplyLeading;

  /// The wrapped bar's own actions, kept ahead of the exit button. These are
  /// controls the learner may need mid-activity — see [fullscreenBar].
  final List<Widget>? actions;

  /// The wrapped bar's [AppBar.bottom] — kept, and counted in
  /// [preferredSize], so a screen that shows progress there keeps showing it.
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
    kFullscreenToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: kFullscreenToolbarHeight,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      bottom: bottom,
      // Matches the page underneath instead of the usual bar colour, so the
      // strip reads as part of the content rather than as remaining chrome.
      // Using the surface colour (rather than transparent) also keeps AppBar's
      // automatic status-bar icon contrast correct in both light and dark.
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        // One cluster, not a plain action list, because adding the exit button
        // beside a screen's own actions can outgrow a narrow phone: with the
        // viewer's three actions the row overflowed by 22px at 360dp × 2.0x.
        //
        // What overflows is *text*, not controls. The viewer's card-counter
        // pill grows with the font scale while the icon buttons stay 48dp — it
        // measures 198dp wide at 2.0x against 129dp at 1.3x. Clamping the
        // cluster to 1.3x therefore frees ~69dp, three times the overrun, by
        // shrinking only a short status label: the pill is still 30% larger
        // than default, and every piece of body content on the screen keeps
        // the learner's full scale.
        //
        // Doing it this way keeps the buttons at their full 48dp, because the
        // row now fits outright and nothing has to be scaled to make it. That
        // is the point — for motor-impaired learners, who are also the ones
        // most likely to be running 2.0x, the tap target is the last thing
        // that should give.
        Flexible(
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            // Backstop for a screen whose actions are wide for some other
            // reason, so an unusual bar degrades instead of throwing. The
            // overflow matrix covers what actually ships.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                // Exit goes last, so it lands in the same corner on every
                // screen rather than shifting with the action count.
                children: [...?actions, const _ExitFullscreenButton()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Leaves fullscreen mode. The only way out from a learner-facing screen, so
/// it is on every collapsed bar — the educator who turned the mode on may not
/// be the person holding the tablet when it needs to come off.
class _ExitFullscreenButton extends ConsumerWidget {
  const _ExitFullscreenButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppIconButton(
      icon: Icons.fullscreen_exit_rounded,
      tooltip:
          AppLocalizations.of(context)?.exitFullscreen ?? 'Exit Fullscreen',
      onPressed: () => ref.read(fullscreenModeProvider.notifier).state = false,
    );
  }
}
