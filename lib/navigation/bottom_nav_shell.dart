import 'package:flutter/material.dart';
import '../features/routine/widgets/routine_popup_watcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/models/enums.dart';
import '../core/theme/app_colors.dart';
import '../core/services/celebration_service.dart';
import '../core/utils/responsive_utils.dart';
import '../core/services/xp_level_service.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_providers.dart';
import '../providers/fullscreen_provider.dart';
import '../providers/level_up_provider.dart';
import '../providers/experiment_provider.dart';
import '../features/parent/models/educator_audience.dart';
import '../features/experiment/models/experiment_models.dart';
import '../features/gaze_control/controllers/gaze_controller.dart'
    show GazeStatus;
import '../features/gamepad/providers/gamepad_sections.dart';
import '../features/gaze_control/widgets/nav_gaze_scope.dart';
import '../widgets/level_up_celebration_screen.dart';
import '../features/assessment/widgets/learner_assignment_sync.dart';

/// Route prefixes that trigger immersive mode (bottom nav hidden).
/// Hub screens (/games, /flashcards, /stories, /home, /progress) are NOT
/// included — only the actual activity screens hide the nav bar.
const _immersiveRoutePrefixes = [
  '/games/word-match',
  '/games/spelling-bee',
  '/games/memory-match',
  '/games/drag-drop',
  '/games/flashcard-quiz',
  '/games/pronunciation',
  '/games/sentence-builder',
  '/games/tracing',
  '/games/fsl-practice/sign-to-word',
  '/games/fsl-practice/word-to-sign',
  '/games/fsl-practice/sign-it',
  '/flashcards/viewer/',
  '/flashcards/create',
  '/flashcards/templates',
];

bool _isImmersiveRoute(String location) {
  return _immersiveRoutePrefixes.any((prefix) => location.startsWith(prefix));
}

/// Bottom navigation shell that wraps the main tab screens.
/// Automatically hides (with animation) when navigating to game,
/// flashcard-viewer, or FSL-practice screens.
/// The educator bottom-nav destinations, in tab order.
///
/// Public because any surface that links to one of these must `go()` rather
/// than `push()`. Pushing a location that is already a live shell branch trips
/// Navigator's `!keyReservation.contains(key)` assertion, and the user sees the
/// global "Something went wrong" snackbar instead of navigating — which is
/// exactly what the dashboard's "See analytics" recommendation did.
const educatorTabPaths = <String>[
  '/home',
  '/multi-dashboard',
  '/teacher-analytics',
  '/weekly-reports',
];

/// Whether [location] addresses one of [educatorTabPaths].
///
/// Compares the path only, so a query string ("?name=Ana") does not hide a
/// tab route from the check.
bool isEducatorTabRoute(String location) =>
    educatorTabPaths.contains(location.split('?').first);

class BottomNavShell extends ConsumerStatefulWidget {
  final GoRouterState state;
  final Widget child;

  const BottomNavShell({super.key, required this.state, required this.child});

  @override
  ConsumerState<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends ConsumerState<BottomNavShell>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _heightFactor;
  late final Animation<double> _opacity;

  /// The level that triggered the celebration overlay, or null if hidden.
  PlayerLevel? _celebratingLevel;

  /// Stable identity for this shell's tenure as the publisher of
  /// [gamepadSections], so an outgoing shell disposing *after* an incoming
  /// one has published (which happens on a role switch) cannot wipe the newer
  /// tab set — the same ownership guard [gazeHomeGrid] uses.
  final Object _sectionsToken = Object();

  /// Tracks per-tab bounce animations triggered on tap.
  final Map<int, AnimationController> _bounceControllers = {};

  /// Computes nav-bar dimensions from the *actual* icon + label + spacing
  /// needs at the current text scale and screen tier. Single source of truth
  /// for outer container, animated bar, pill, and item rendering — so the
  /// bar can never disagree with what its content needs, at any scale.
  _NavMetrics _computeMetrics(BuildContext context) {
    final iconSel = context.scaleIcon(context.responsiveSize(26));
    final iconUnsel = context.scaleIcon(context.responsiveSize(22));
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    // Label height for layout math (Text applies textScaler internally
    // when rendering; we mirror it here so the height calculation matches).
    final fontSel = context.responsiveSize(11.5) * scale;
    final gap = (4.0 * scale).clamp(3.0, 8.0);
    const dot = 5.0;
    // Selected item is the tallest: icon + gap + textLineHeight + gap + dot.
    // ~1.25 line-height fits Nunito at all weights without descender clipping.
    final content = iconSel + gap + fontSel * 1.25 + gap + dot;
    // 12dp vertical padding (6 top + 6 bottom) so content never touches edges.
    final bar = content + 12;
    return _NavMetrics(
      bar: bar,
      iconSelected: iconSel,
      iconUnselected: iconUnsel,
      gap: gap,
      dot: dot,
    );
  }

  static const _animDuration = Duration(milliseconds: 300);

  /// The router's **full** current location.
  ///
  /// [BottomNavShell.state] only describes the shell's own route match, which
  /// stops at the tab path (`/games`) whenever the page on top was *pushed*
  /// onto the root navigator — every game, FSL practice mode and story
  /// activity is. Checking that against [_immersiveRoutePrefixes] would report
  /// "not immersive" for a game opened from a learning-path step or Word Hunt,
  /// leaving [bottomNavVisibleProvider] true and the floating AI Companion
  /// drawn on top of the running game.
  ///
  /// `GoRouter.state` reports the top-most match for `go()` and `push()`
  /// alike, so immersive mode now engages identically however the activity was
  /// launched. Falls back to the shell's own match if no router is in scope
  /// (widget tests that build this shell directly).
  String get _location {
    try {
      return GoRouter.of(context).state.uri.toString();
    } catch (_) {
      return widget.state.uri.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    // `GoRouter.of` needs an inherited-widget lookup, which initState can't do
    // — but the first location is always reached with `go()`, so the shell's
    // own match is the full location here.
    _animController = AnimationController(
      vsync: this,
      duration: _animDuration,
      value: _isImmersiveRoute(widget.state.uri.toString()) ? 0.0 : 1.0,
    );
    _heightFactor = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _opacity = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
  }

  @override
  void didUpdateWidget(covariant BottomNavShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibility();
  }

  void _syncVisibility() {
    _applyVisibility(
      !_isImmersiveRoute(_location) && !ref.read(fullscreenModeProvider),
    );
  }

  /// Animates the bar to match [shouldShow] and publishes the same answer to
  /// [bottomNavVisibleProvider] for the widgets that key off it — chiefly the
  /// floating AI Companion, which must not cover a screen whose chrome has
  /// been taken away.
  ///
  /// Called from `build` as well as `didUpdateWidget`, because fullscreen mode
  /// can be toggled without navigating anywhere. That is also why the provider
  /// write is deferred to a microtask: mutating a provider synchronously
  /// during a build is not allowed. The equality check keeps the ordinary case
  /// (a rebuild that changes nothing) from scheduling one every frame.
  void _applyVisibility(bool shouldShow) {
    if (shouldShow) {
      _animController.forward();
    } else {
      _animController.reverse();
    }

    if (ref.read(bottomNavVisibleProvider) == shouldShow) return;
    Future.microtask(() {
      if (!mounted) return;
      ref.read(bottomNavVisibleProvider.notifier).state = shouldShow;
    });
  }

  @override
  void dispose() {
    gamepadSections.clear(owner: _sectionsToken);
    _animController.dispose();
    for (final c in _bounceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  UserRole? get _role => ref.read(profileProvider)?.role;
  bool get _isEducator => _role == UserRole.teacher || _role == UserRole.parent;
  bool get _isPlayer => _role == UserRole.player;

  /// Only *guest* players get the nav-less, single-button home. "Player (With
  /// Progress)" profiles (role == player, isGuestPlayer == false) keep their
  /// saved progress and navigate like a Student — Home / Cards / Games /
  /// Stories / Progress — so they fall through to the Student tab set.
  bool get _isGuestPlayer => ref.read(profileProvider)?.isGuestPlayer ?? false;

  // ─── Student tabs: Home, Cards, Games, Stories, Progress
  static const _studentPaths = [
    '/home',
    '/flashcards',
    '/games',
    '/stories',
    '/progress',
  ];
  // ─── Educator tabs: Home, Students, Analytics, Reports
  // Settings is reached from the top-right gear on the educator home (matching
  // the Student/Child surfaces), so it is intentionally not a nav tab.
  static const _educatorPaths = educatorTabPaths;

  List<String> get _activePaths {
    if (_isEducator) return _educatorPaths;
    // Child, Student, and "Player (With Progress)" learners share the same
    // five learner tabs. The Child keeps its own gamified Home screen; only the
    // tab set is unified so the Family Group matches the Classroom feature set.
    return _studentPaths;
  }

  int _currentIndex(String location) {
    final paths = _activePaths;
    for (int i = paths.length - 1; i >= 0; i--) {
      if (location.startsWith(paths[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Listen for level-up transitions (gated by experiment config)
    // Only a climb *by the same learner* is a level-up. Switching profiles also
    // moves this provider — see [LevelSnapshot] — and used to fire the
    // celebration for a level the incoming learner had earned days ago.
    ref.listen<LevelSnapshot>(levelUpProvider, (previous, next) {
      if (!next.isLevelUpFrom(previous)) return;
      final levelUpEnabled = ref.read(
        gamificationFeatureProvider(GamificationFeature.levelUp),
      );
      final celebrationsEnabled = ref.read(
        gamificationFeatureProvider(GamificationFeature.celebrations),
      );
      if (levelUpEnabled) {
        if (celebrationsEnabled) {
          ref
              .read(celebrationServiceProvider)
              .celebrate(CelebrationType.levelUp);
        }
        setState(() => _celebratingLevel = next.level);
      }
    });

    final location = _location;
    final currentIndex = _currentIndex(location);
    // Educator fullscreen hides the tab bar the same way an immersive route
    // does. Watched (not read) so toggling the mode reaches the bar
    // immediately — `_syncVisibility` only runs on navigation.
    final fullscreen = ref.watch(fullscreenModeProvider);
    final navShown = !_isImmersiveRoute(location) && !fullscreen;
    _applyVisibility(navShown);

    // Guest Player mode: skip the bottom nav entirely. The PlayerHomeScreen is
    // self-contained (one big "Start Learning" button); a tab bar would imply
    // more app surface than a guest actually has. "Player (With Progress)"
    // profiles fall through to the Student tab set (Home / Cards / Games /
    // Stories / Progress) below.
    //
    // Gaze + voice still apply: itemCount 0 tells [NavGazeScope] there is no
    // nav row, so the hands-free D-pad and spoken commands drive whatever grid
    // the visible screen publishes (the guest home's buttons, the Games / Cards
    // hub tiles) plus the global scroll / go-back commands.
    if (_isPlayer && _isGuestPlayer) {
      // A guest has no tab bar, so there are no sections to offer. The
      // gamepad still drives the home screen's buttons via the published grid.
      _publishSections(const [], 0);
      // The guest home opens Games and Cards with go(): they are tab roots and
      // cannot be pushed, so nothing sits behind them. Without a tab bar the
      // learner had no way back — system Back closed the app. Back from a hub
      // now returns to the guest home, and a Home button shows the way.
      final atHome = location.startsWith('/home');
      return PopScope(
        canPop: atHome,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/home');
        },
        child: NavGazeScope(
          currentIndex: 0,
          itemCount: 0,
          enabled: navShown,
          onCommit: (_) {},
          builder: (context, gaze) => Stack(
            children: [
              Scaffold(
                body: RepaintBoundary(child: widget.child),
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.startFloat,
                // "Home" in both languages — the app's Filipino UI calls that
                // screen Home too (see _studentNavItems).
                floatingActionButton: atHome || !navShown
                    ? null
                    : FloatingActionButton.extended(
                        heroTag: 'guest-home',
                        tooltip: AppLocalizations.of(context)?.nfGoHome,
                        onPressed: () => context.go('/home'),
                        icon: const Icon(Icons.home_rounded),
                        label: const Text('Home'),
                      ),
              ),
              if (_celebratingLevel != null)
                LevelUpCelebrationScreen(
                  newLevel: _celebratingLevel!,
                  reducedMotion: ref.read(settingsProvider).reducedMotion,
                  onDismiss: () => setState(() => _celebratingLevel = null),
                ),
            ],
          ),
        ),
      );
    }
    final items = _isEducator ? _educatorNavItems() : _studentNavItems();
    _publishSections([for (final item in items) item.label], currentIndex);
    // Whose assigned work to keep current. Watched so a profile switch swaps
    // the listener; null for educators, whose side is pulled elsewhere.
    final learnerId = ref.watch(
      profileProvider.select(
        (p) =>
            p == null ||
                p.isGuestPlayer ||
                p.role == UserRole.teacher ||
                p.role == UserRole.parent
            ? null
            : p.id,
      ),
    );

    // Hands-free bottom-nav: look ◀ ▶ to move the highlight, blink to open the
    // tab. Inert unless Gaze Control is enabled; runs the single camera only
    // while a nav-bar screen is on top (see [NavGazeScope]).
    return NavGazeScope(
      currentIndex: currentIndex,
      itemCount: items.length,
      navLabels: [for (final item in items) item.label],
      enabled: navShown,
      onCommit: (index) => _onTap(context, index),
      builder: (context, gaze) => Stack(
        children: [
          // The in-app half of a scheduled step: brings it to the learner at
          // its own time while they are on a hub — "It is lunch time", or
          // "Please do your check-in now" — and then asks how it felt.
          // Renders nothing, and is inert for educators and for any learner
          // with nothing scheduled today.
          RoutinePopupWatcher(location: location),
          // Live assigned work for the learner — see [LearnerAssignmentSync].
          // Here rather than on a home screen so it outlives tab switches and
          // scrolling. Renders nothing.
          if (learnerId != null)
            LearnerAssignmentSync(
              key: ValueKey('assignment-sync-$learnerId'),
              profileId: learnerId,
            ),
          Scaffold(
            body: RepaintBoundary(child: widget.child),
            bottomNavigationBar: Builder(
              builder: (context) {
                final hc = HCColor.of(context);
                final metrics = _computeMetrics(context);
                return AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: _heightFactor.value,
                        child: Opacity(opacity: _opacity.value, child: child),
                      ),
                    );
                  },
                  child: RepaintBoundary(
                    // SafeArea(top: false) lifts the bar above Android gesture-nav
                    // insets on Android 10+ — Scaffold's bottomNavigationBar slot
                    // does NOT auto-pad for the system gesture area.
                    child: SafeArea(
                      top: false,
                      child: Container(
                        height: metrics.bar,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                          border: Border(
                            top: BorderSide(
                              color: hc.primary.withValues(alpha: 0.08),
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: hc.primary.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, -6),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                          child: _AnimatedNavBar(
                            currentIndex: currentIndex,
                            gazeTargetIndex: gaze.active
                                ? gaze.targetIndex
                                : null,
                            items: items,
                            onTap: (index) => _onTap(context, index),
                            bounceControllers: _bounceControllers,
                            vsync: this,
                            metrics: metrics,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Gaze-navigation hint, sitting just above the bar while gaze nav runs.
          if (gaze.active)
            _GazeNavHint(
              ready: gaze.ready,
              faceVisible: gaze.faceVisible,
              status: gaze.status,
              featureTilesActive: gaze.featureTilesActive,
              bottomOffset:
                  _computeMetrics(context).bar +
                  MediaQuery.paddingOf(context).bottom,
            ),

          // Level-up celebration overlay
          if (_celebratingLevel != null)
            LevelUpCelebrationScreen(
              newLevel: _celebratingLevel!,
              reducedMotion: ref.read(settingsProvider).reducedMotion,
              onDismiss: () => setState(() => _celebratingLevel = null),
            ),
        ],
      ),
    );
  }

  List<_NavItem> _studentNavItems() {
    // Watched for the same reason as the educator tabs below. "Home" stays:
    // it is what the app's own Filipino UI calls that screen.
    final filipino = ref.watch(settingsProvider).locale == 'fil';
    return [
      const _NavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'Home',
      ),
      _NavItem(
        icon: Icons.style_outlined,
        selectedIcon: Icons.style_rounded,
        label: filipino ? 'Mga Kard' : 'Cards',
      ),
      _NavItem(
        icon: Icons.sports_esports_outlined,
        selectedIcon: Icons.sports_esports_rounded,
        label: filipino ? 'Mga Laro' : 'Games',
      ),
      _NavItem(
        icon: Icons.auto_stories_outlined,
        selectedIcon: Icons.auto_stories_rounded,
        label: filipino ? 'Mga Kwento' : 'Stories',
      ),
      _NavItem(
        icon: Icons.emoji_events_outlined,
        selectedIcon: Icons.emoji_events_rounded,
        label: filipino ? 'Progreso' : 'Progress',
      ),
    ];
  }

  List<_NavItem> _educatorNavItems() {
    // "Students" is a teacher's word. A parent's roster is their children, and
    // the tab is the first thing they read on every educator screen.
    final audience = _role == UserRole.parent
        ? EducatorAudience.parent
        : EducatorAudience.teacher;
    // `watch`, not `read`: this runs during build, and with `read` the tab
    // labels kept the language they were first built with — switching the
    // app to Filipino left "Children" sitting in the nav bar.
    final filipino = ref.watch(settingsProvider).locale == 'fil';
    final rosterLabel = audience.learnerNounPluralCapOf(
      filipino: filipino,
    );
    return [
      const _NavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        // "Home" is what the app's own Filipino UI calls this screen.
        label: 'Home',
      ),
      _NavItem(
        icon: Icons.people_outlined,
        selectedIcon: Icons.people_rounded,
        label: rosterLabel,
      ),
      const _NavItem(
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics_rounded,
        label: 'Analytics',
      ),
      _NavItem(
        icon: Icons.assessment_outlined,
        selectedIcon: Icons.assessment_rounded,
        label: filipino ? 'Mga Ulat' : 'Reports',
      ),
    ];
  }

  /// Tells the Bluetooth-gamepad host what the top-level sections are and how
  /// to switch between them.
  ///
  /// Deferred to a post-frame callback for the same reason [GazeHomeRegistrar]
  /// defers its publish: [gamepadSections] is a [ChangeNotifier], and notifying
  /// listeners while the tree is still building would mark the host dirty
  /// mid-build. Republished every frame so the [context] captured by the
  /// callback is never stale; the bridge itself de-dupes by content.
  void _publishSections(List<String> labels, int currentIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (labels.isEmpty) {
        gamepadSections.clear(owner: _sectionsToken);
        return;
      }
      gamepadSections.publish(
        labels: labels,
        currentIndex: currentIndex,
        onSelect: (index) {
          if (!mounted) return;
          _onTap(context, index);
        },
        owner: _sectionsToken,
      );
    });
  }

  void _onTap(BuildContext context, int index) {
    final paths = _activePaths;
    if (index >= 0 && index < paths.length) {
      context.go(paths[index]);
    }
  }
}

// ─── Data class for nav items ─────────────────────────

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Pre-computed nav-bar dimensions shared by the outer container, the
/// animated bar, the pill, and each item — so the bar's height and the
/// content laid out inside it can never disagree at any text scale.
class _NavMetrics {
  final double bar;
  final double iconSelected;
  final double iconUnselected;
  final double gap;
  final double dot;

  const _NavMetrics({
    required this.bar,
    required this.iconSelected,
    required this.iconUnselected,
    required this.gap,
    required this.dot,
  });
}

// ─── Custom Animated Nav Bar ──────────────────────────

class _AnimatedNavBar extends StatelessWidget {
  final int currentIndex;

  /// The tab the gaze cursor is resting on, drawn as a bright ring. Null when
  /// gaze navigation isn't active.
  final int? gazeTargetIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  final Map<int, AnimationController> bounceControllers;
  final TickerProvider vsync;
  final _NavMetrics metrics;

  const _AnimatedNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    required this.bounceControllers,
    required this.vsync,
    required this.metrics,
    this.gazeTargetIndex,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final primaryColor = hc.primary;
    // Pill scales with the selected icon so it always frames it cleanly,
    // even at XL font scale where the icon is much larger than 26dp.
    final pillWidth = metrics.iconSelected + context.responsiveSize(20);
    final pillHeight = metrics.iconSelected + 10;
    final barHeight = metrics.bar;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final itemWidth = totalWidth / items.length;
        final pillLeft = currentIndex * itemWidth + (itemWidth - pillWidth) / 2;
        // Vertically center the pill over the icon area (shifted slightly up
        // so it sits behind the icon, not the label).
        final pillTop = (barHeight - pillHeight) / 2 - 6;

        return SizedBox(
          height: barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bright gaze-cursor ring framing the highlighted tab — distinct
              // from the soft selection pill, so a learner can see where the
              // head-driven highlight is before blinking to open it.
              if (gazeTargetIndex != null)
                AnimatedPositioned(
                  left: gazeTargetIndex! * itemWidth + 4,
                  top: 4,
                  width: itemWidth - 8,
                  height: barHeight - 8,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.accent, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.45),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Sliding pill indicator behind the selected icon
              AnimatedPositioned(
                left: pillLeft,
                top: pillTop,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: pillWidth,
                  height: pillHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withValues(alpha: 0.22),
                        primaryColor.withValues(alpha: 0.10),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.12),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

              // Nav items row — stretch makes each Expanded child fill the
              // full barHeight, so items no longer need their own SizedBox.
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;
                  return Expanded(
                    child: _AnimatedNavItem(
                      item: item,
                      isSelected: isSelected,
                      index: index,
                      onTap: () => onTap(index),
                      bounceControllers: bounceControllers,
                      vsync: vsync,
                      metrics: metrics,
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedNavItem extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final int index;
  final VoidCallback onTap;
  final Map<int, AnimationController> bounceControllers;
  final TickerProvider vsync;
  final _NavMetrics metrics;

  const _AnimatedNavItem({
    required this.item,
    required this.isSelected,
    required this.index,
    required this.onTap,
    required this.bounceControllers,
    required this.vsync,
    required this.metrics,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem> {
  late final AnimationController _bounceCtrl;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = widget.bounceControllers[widget.index] ??=
        AnimationController(
          vsync: widget.vsync,
          duration: const Duration(milliseconds: 400),
        );
  }

  void _handleTap() {
    // Trigger bounce
    _bounceCtrl
      ..reset()
      ..forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final primaryColor = hc.primary;
    final unselectedColor = hc.textSecondary;
    final m = widget.metrics;

    return Semantics(
      button: true,
      label: widget.item.label,
      selected: widget.isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        // The parent Row stretches each Expanded child to barHeight, so no
        // explicit SizedBox here — the Column fills whatever height it gets.
        child: AnimatedBuilder(
          animation: _bounceCtrl,
          builder: (context, child) {
            // Bounce: quick scale up then back
            final t = _bounceCtrl.value;
            final bounceScale =
                1.0 + 0.12 * Curves.elasticOut.transform(t) * (1 - t);
            return Transform.scale(scale: bounceScale, child: child);
          },
          // 4dp horizontal padding keeps adjacent cells from kissing at XL
          // scale; 6dp vertical matches the +12 budget in _computeMetrics.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with animated transitions — size is pre-computed in
                // _NavMetrics so the bar and the icon can never disagree.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    widget.isSelected
                        ? widget.item.selectedIcon
                        : widget.item.icon,
                    key: ValueKey(widget.isSelected),
                    size: widget.isSelected ? m.iconSelected : m.iconUnselected,
                    color: widget.isSelected ? primaryColor : unselectedColor,
                  ),
                ),
                SizedBox(height: m.gap),

                // Label — FittedBox + maxLines:1 + softWrap:false guarantees
                // the label NEVER wraps (no vertical overflow) and NEVER
                // overflows its cell horizontally (scales down to fit if the
                // user's font scale would otherwise push it past the cell).
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: widget.isSelected
                            ? context.responsiveSize(11.5)
                            : context.responsiveSize(10.5),
                        fontWeight: widget.isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: widget.isSelected
                            ? primaryColor
                            : unselectedColor,
                        fontFamily: 'Nunito',
                        letterSpacing: widget.isSelected ? 0.2 : 0,
                      ),
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),

                // Active dot indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(top: m.gap),
                  width: widget.isSelected ? m.dot : 0,
                  height: widget.isSelected ? m.dot : 0,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: widget.isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Gaze-navigation hint ─────────────────────────────

/// A small instructional chip shown just above the bottom bar while gaze
/// navigation is active, telling the learner how to drive the tabs hands-free.
/// Purely informational ([IgnorePointer]) — touch falls straight through.
class _GazeNavHint extends StatelessWidget {
  final bool ready;
  final bool faceVisible;

  /// The D-pad is currently extended over the foreground hub's feature tiles, so
  /// the hint mentions the up/down moves too.
  final bool featureTilesActive;

  /// Distance from the bottom of the screen to the top of the nav bar, so the
  /// chip floats just above it at any text scale / device.
  final double bottomOffset;

  /// Why the camera isn't ready — drives the "permission needed" / "no front
  /// camera" wording instead of an endless "Starting gaze…".
  final GazeStatus status;

  const _GazeNavHint({
    required this.ready,
    required this.faceVisible,
    required this.bottomOffset,
    required this.status,
    this.featureTilesActive = false,
  });

  @override
  Widget build(BuildContext context) {
    // A camera that will never come up must say so. Reporting "Starting gaze…"
    // for a denied permission or a missing front lens leaves a hands-free
    // learner waiting on something that is never going to happen — the one
    // person who can least afford to guess. Same wording as `GazeOverlay`.
    final (IconData icon, String text) = switch (status) {
      GazeStatus.permissionDenied => (
        Icons.lock_rounded,
        'Gaze: camera permission needed',
      ),
      GazeStatus.noCamera => (
        Icons.videocam_off_rounded,
        'Gaze: no front camera',
      ),
      GazeStatus.failed => (Icons.error_outline_rounded, 'Gaze unavailable'),
      GazeStatus.initializing => (
        Icons.hourglass_top_rounded,
        'Starting gaze…',
      ),
      GazeStatus.ready =>
        !faceVisible
            ? (Icons.face_retouching_natural_rounded, 'Look at the screen')
            : (
                Icons.visibility_rounded,
                featureTilesActive
                    ? 'Look ◀ ▶ ▲ ▼ to choose · blink to open'
                    : 'Look ◀ ▶ to choose · blink to open',
              ),
    };
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomOffset + 8,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
