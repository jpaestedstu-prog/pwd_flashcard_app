import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../navigation/nav_bar_sizes.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/animated_mascot_buddy.dart';
import '../controllers/companion_controller.dart';
import '../models/companion_presentation.dart';

/// The AI Buddy's floating button: where it rests, and how big it is.
///
/// One source of these numbers for the overlay that draws it ([CompanionHost])
/// and for everything that keeps clear of it: the hubs' room at the end of
/// their lists ([CompanionClearanceSliver]), the floating messages that rise
/// above it, and the chat panel that opens over it.
///
/// It floats in the bottom-right corner, above the tab bar (a Guest, who has
/// none, above the bottom of the safe area), clear of the system's gesture
/// area and of a camera cutout at the side, as a floating action button does.
/// It never sits in the navigation bar: the owner asked for exactly that on
/// 10 Nov, after a trial build docked it at the end of the tabs. Nor does a
/// hub keep an empty band or column for it (round 8 did, and the cards were
/// cut off above the band): the hubs run under it, and each keeps room at the
/// end of its list so that whatever it rests over can be scrolled clear.
abstract final class CompanionFab {
  /// Its distance from the right edge of the window and from the top of the
  /// tab bar (or the bottom of the safe area): a floating action button's
  /// 16 dp on a phone, 24 on a tablet or a computer.
  static double margin(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600 ? 24 : 16;

  /// The button's side: [CompanionPresentation.launcherSize] (60 dp; 68 for
  /// motor, visual and multiple needs) grown with the text, to 1.25x: big
  /// enough to find and to hit, small enough to cover little of a page.
  static double size(
    BuildContext context,
    CompanionPresentation presentation,
  ) =>
      presentation.launcherSize *
      MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.25);

  /// Where the button rests in the window: [hasTabBar] for a learner with
  /// tabs, false for a Guest.
  static Rect rect(
    BuildContext context,
    CompanionPresentation presentation, {
    required bool hasTabBar,
  }) {
    final media = MediaQuery.of(context);
    final side = size(context, presentation);
    final gap = margin(context);
    final bar = hasTabBar ? NavBarSizes.of(context).bar : 0.0;
    return Rect.fromLTWH(
      media.size.width - media.padding.right - gap - side,
      media.size.height - media.padding.bottom - bar - gap - side,
      side,
      side,
    );
  }

  /// The room a page keeps at its bottom edge so that its last row can be
  /// scrolled clear of the button: the button and the gap above it, measured
  /// from the top of the tab bar (or the bottom of the safe area).
  static double clearance(
    BuildContext context,
    CompanionPresentation presentation,
  ) =>
      size(context, presentation) + margin(context) + 8;

  /// How far the tab bar is shown: 0 while it is away (a game, the card
  /// viewer), 1 in place. The shell's own animation, shared so that the
  /// button rises and fades with its bar, instead of waiting in the corner
  /// for a bar still on its way up.
  static final ValueNotifier<double> reveal = ValueNotifier(1);
}

/// The column a page can keep beside the AI Buddy's floating button, and the
/// room to leave above the bottom of the page when no column can.
///
/// For the guest home: a short page of a few big buttons, the guest's whole
/// menu, where the button resting on one of them is plain to see. On a phone at
/// the largest text "How was it?" sat under it (9 Nov). Where a column a
/// little narrower than [column] (but at least [narrowest]) clears the button,
/// the column narrows to that and the page keeps its full height (a tablet,
/// any phone held sideways). Where it cannot (a phone held upright), the page
/// stops [CompanionRoom.bottom] above its bottom edge, just over the button,
/// so nothing can scroll under it. The hubs, long lists and grids, run under
/// it instead and keep room at the end ([companionClearance]).
///
/// [width] is the page's width and [rightInset] the window's inset at its
/// right edge (the button is placed from the window's edge, the page inside
/// it). [button] is its side and [margin] its distance from the window's
/// right edge and from the bottom of the safe area ([CompanionFab.margin]).
/// [bottomInset] is any system inset the page still has at its bottom.
CompanionRoom roomBesideBuddy({
  required double width,
  required double column,
  required double button,
  required double margin,
  double rightInset = 0,
  double bottomInset = 0,
  double gap = 8,
  double narrowest = 360,
}) {
  final buttonLeft = width + rightInset - margin - button;
  final clearColumn = 2 * (buttonLeft - gap) - width;
  if (column <= clearColumn) return CompanionRoom(column: column, bottom: 0);
  if (clearColumn >= narrowest) {
    return CompanionRoom(column: clearColumn, bottom: 0);
  }
  return CompanionRoom(
    column: column,
    bottom: button + margin + gap + bottomInset,
  );
}

/// What [roomBesideBuddy] leaves a page: its column's width, and the room at
/// its bottom that the content keeps out of.
@immutable
class CompanionRoom {
  const CompanionRoom({required this.column, required this.bottom});

  final double column;
  final double bottom;

  @override
  String toString() => 'CompanionRoom(column: $column, bottom: $bottom)';
}

/// The room a hub leaves at the end of its list, so that its last row can be
/// scrolled clear of whatever floats in the bottom-right corner: the AI
/// Buddy's button, or the owl mascot when the buddy is switched off
/// ([AnimatedMascotBuddy.shownFor]). A little air when neither is there.
double companionClearance(BuildContext context, WidgetRef ref) {
  if (ref.watch(companionVisibleProvider)) {
    return CompanionFab.clearance(
      context,
      ref.watch(companionPresentationProvider),
    );
  }
  final owl = AnimatedMascotBuddy.shownFor(
    ref.watch(settingsProvider),
    ref.watch(profileProvider.select((p) => p?.role)),
  );
  final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5);
  return owl ? 68 * scale + 32 : 16;
}

/// [companionClearance], as the last sliver of a hub's list.
class CompanionClearanceSliver extends ConsumerWidget {
  const CompanionClearanceSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SliverToBoxAdapter(
    child: SizedBox(height: math.max(0, companionClearance(context, ref))),
  );
}
