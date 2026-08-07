import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/app_providers.dart';
import '../models/tv_cast_session.dart';
import '../providers/tv_cast_provider.dart';

/// Mounts the floating "still casting" pill above every screen.
///
/// Sits in `MaterialApp.builder` next to the other global hosts so it survives
/// navigation — which is the whole point: the cast server lives in a root
/// provider, so it keeps serving the TV long after the educator has walked away
/// from `/tv-cast` to check a roster. Before this, that was completely
/// invisible: the TV Cast tile looked identical whether or not a class was
/// watching, and the only way to pause the slideshow was to find your way back
/// through More → TV Cast.
class CastStatusHost extends StatelessWidget {
  final Widget child;
  const CastStatusHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // Deliberately NOT wrapped in Positioned.fill: [CastStatusPill]
        // supplies its own `Positioned`, and two Positioned widgets writing
        // StackParentData to the same render object is an "Incorrect use of
        // ParentDataWidget" error — one silently overwrites the other, so the
        // pill renders correctly or fills the entire screen depending on which
        // won. As a direct Stack child its own Positioned is the only one.
        const CastStatusPill(),
      ],
    );
  }
}

/// The pill itself. Renders nothing (and blocks no touches) unless a cast is
/// actually running, an educator is signed in, and we're somewhere other than
/// the cast screen.
class CastStatusPill extends ConsumerWidget {
  const CastStatusPill({super.key});

  /// Routes where an overlay would be wrong even mid-cast: the cast screen
  /// itself (it has the full controls), and the account-level surfaces where a
  /// floating educator control has no owner on screen.
  static const _suppressedRoutes = [
    '/tv-cast',
    '/profile-switcher',
    '/profile',
    '/onboarding',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning =
        ref.watch(tvCastSessionProvider.select((s) => s.isServerRunning));
    if (!isRunning) return const SizedBox.shrink();

    // Only the roles that can reach /tv-cast get the shortcut back to it —
    // tapping through to a route the router would bounce is worse than nothing.
    final profile = ref.watch(profileProvider);
    if (profile == null || !profile.role.isEducator) {
      return const SizedBox.shrink();
    }

    final router = ref.watch(routerProvider);

    // Rebuild on navigation. Same reasoning as the AI Companion overlay: watch
    // the delegate (an imperative pop() doesn't refresh routeInformation) and
    // read the *deepest* match, since the match list's own uri stays on the
    // shell location while something is pushed above it.
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final loc =
            router.routerDelegate.currentConfiguration.last.matchedLocation;
        if (_suppressedRoutes.any(loc.startsWith)) {
          return const SizedBox.shrink();
        }
        return _Pill(router: router);
      },
    );
  }
}

class _Pill extends ConsumerWidget {
  /// Passed in rather than reached for via `context.push`. This widget is
  /// mounted in MaterialApp.builder, *above* the Router, so there is no
  /// `InheritedGoRouter` in its context — `GoRouter.of(context)` asserts
  /// "No GoRouter found in context" and the tap silently does nothing.
  final GoRouter router;

  const _Pill({required this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tvCastSessionProvider);
    final notifier = ref.read(tvCastSessionProvider.notifier);
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    // Prev/pause/next only drive the slide modes — Live Activity pushes its own
    // questions and Progress has nothing to step through.
    final steppable = state.mode == CastMode.flashcards ||
        state.mode == CastMode.fslVideo ||
        state.mode == CastMode.story;

    return Positioned(
      left: 12,
      right: 12,
      // Clear of the bottom nav bar (~72) plus the system inset.
      bottom: safeBottom + 84,
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          container: true,
          label: 'Casting to TV. ${_modeLabel(state)}. '
              '${state.connectedViewers} '
              '${state.connectedViewers == 1 ? 'viewer' : 'viewers'} connected.',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(28),
                    ),
                    onTap: () => router.push('/tv-cast'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                      child: Row(
                        children: [
                          const _LiveDot(),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.isAway
                                      ? 'Casting — teacher is out'
                                      : 'Casting to TV',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${_modeLabel(state)} · '
                                  '${state.connectedViewers} watching',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (steppable) ...[
                  _PillButton(
                    icon: Icons.skip_previous_rounded,
                    label: 'Previous on TV',
                    onTap: notifier.prev,
                  ),
                  _PillButton(
                    icon: state.isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    label: state.isPaused ? 'Resume cast' : 'Pause cast',
                    onTap: notifier.togglePause,
                  ),
                  _PillButton(
                    icon: Icons.skip_next_rounded,
                    label: 'Next on TV',
                    onTap: notifier.next,
                  ),
                ],
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _modeLabel(TvCastSession state) => switch (state.mode) {
        CastMode.flashcards => 'Flashcards',
        CastMode.fslVideo => 'FSL signs',
        CastMode.story => 'Stories',
        CastMode.progress => 'Progress',
        CastMode.live => 'Live Activity',
        CastMode.idle => 'Nothing selected',
      };
}

/// Softly pulsing dot so the pill reads as *live* at a glance rather than as
/// one more static banner. Honours reduced motion by holding steady.
class _LiveDot extends ConsumerStatefulWidget {
  const _LiveDot();

  @override
  ConsumerState<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends ConsumerState<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        ref.watch(settingsProvider.select((s) => s.reducedMotion));
    if (reducedMotion) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }

    const dot = Icon(Icons.tv_rounded, size: 20, color: Colors.white);
    if (reducedMotion) return dot;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(_c),
      child: dot,
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      // Deliberately NO `tooltip:`. This pill is mounted in
      // MaterialApp.builder, which is *above* the Navigator — so there is no
      // Overlay in scope and a Tooltip throws `debugCheckHasOverlay`. The
      // accessible name goes on the Icon instead, which is what actually
      // matters here: a teacher on a tablet never hovers, but TalkBack reads
      // `semanticLabel`.
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, semanticLabel: label),
      // A 44dp target — these are one-handed taps a teacher makes while
      // facing a class, and the motor-impairment presets assume it.
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
