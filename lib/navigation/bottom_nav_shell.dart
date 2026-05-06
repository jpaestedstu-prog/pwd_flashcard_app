import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/models/enums.dart';
import '../core/theme/app_colors.dart';
import '../core/services/celebration_service.dart';
import '../core/utils/responsive_utils.dart';
import '../core/services/xp_level_service.dart';
import '../providers/app_providers.dart';
import '../providers/level_up_provider.dart';
import '../providers/experiment_provider.dart';
import '../features/experiment/models/experiment_models.dart';
import '../widgets/level_up_celebration_screen.dart';

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
  '/flashcards/viewer/',
  '/flashcards/create',
];

bool _isImmersiveRoute(String location) {
  return _immersiveRoutePrefixes.any((prefix) => location.startsWith(prefix));
}

/// Bottom navigation shell that wraps the main tab screens.
/// Automatically hides (with animation) when navigating to game,
/// flashcard-viewer, or FSL-practice screens.
class BottomNavShell extends ConsumerStatefulWidget {
  final GoRouterState state;
  final Widget child;

  const BottomNavShell({
    super.key,
    required this.state,
    required this.child,
  });

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

  /// Tracks per-tab bounce animations triggered on tap.
  final Map<int, AnimationController> _bounceControllers = {};

  static const _navHeight = 80.0;
  static const _animDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: _animDuration,
      value: _isImmersiveRoute(widget.state.uri.toString()) ? 0.0 : 1.0,
    );
    _heightFactor = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _opacity = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
  }

  @override
  void didUpdateWidget(covariant BottomNavShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncVisibility();
  }

  void _syncVisibility() {
    final location = widget.state.uri.toString();
    final shouldShow = !_isImmersiveRoute(location);

    // Update the Riverpod provider so other widgets can react too
    Future.microtask(() {
      ref.read(bottomNavVisibleProvider.notifier).state = shouldShow;
    });

    if (shouldShow) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final c in _bounceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  UserRole? get _role => ref.read(profileProvider)?.role;
  bool get _isEducator =>
      _role == UserRole.teacher || _role == UserRole.parent;
  bool get _isChild => _role == UserRole.child;
  bool get _isPlayer => _role == UserRole.player;

  // ─── Student tabs: Home, Cards, Games, Stories, Progress
  static const _studentPaths = [
    '/home',
    '/flashcards',
    '/games',
    '/stories',
    '/progress'
  ];
  // ─── Educator tabs: Home, Students, Analytics, Reports, Settings
  static const _educatorPaths = [
    '/home',
    '/multi-dashboard',
    '/teacher-analytics',
    '/weekly-reports',
    '/settings'
  ];
  // ─── Child tabs: Home, Games, Stories, Stickers (gamified, smaller set)
  static const _childPaths = [
    '/home',
    '/games',
    '/stories',
    '/sticker-album',
  ];

  List<String> get _activePaths {
    if (_isEducator) return _educatorPaths;
    if (_isChild) return _childPaths;
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
    ref.listen<PlayerLevel>(levelUpProvider, (previous, next) {
      if (previous != null && next.level > previous.level) {
        final levelUpEnabled = ref.read(gamificationFeatureProvider(GamificationFeature.levelUp));
        final celebrationsEnabled = ref.read(gamificationFeatureProvider(GamificationFeature.celebrations));
        if (levelUpEnabled) {
          if (celebrationsEnabled) {
            ref.read(celebrationServiceProvider).celebrate(CelebrationType.levelUp);
          }
          setState(() => _celebratingLevel = next);
        }
      }
    });

    final currentIndex = _currentIndex(widget.state.uri.toString());

    // Player mode: skip the bottom nav entirely. The PlayerHomeScreen is
    // self-contained (one big "Start Learning" button); a tab bar would
    // imply more app surface than the role actually has.
    if (_isPlayer) {
      return Stack(
        children: [
          Scaffold(body: RepaintBoundary(child: widget.child)),
          if (_celebratingLevel != null)
            LevelUpCelebrationScreen(
              newLevel: _celebratingLevel!,
              reducedMotion: ref.read(settingsProvider).reducedMotion,
              onDismiss: () => setState(() => _celebratingLevel = null),
            ),
        ],
      );
    }

    return Stack(
      children: [
        Scaffold(
          body: RepaintBoundary(child: widget.child),
          bottomNavigationBar: Builder(
            builder: (context) {
              final hc = HCColor.of(context);
              return AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: _heightFactor.value,
                      child: Opacity(
                        opacity: _opacity.value,
                        child: child,
                      ),
                    ),
                  );
                },
                child: RepaintBoundary(
                  child: Container(
                    height: _navHeight,
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
                        items: _isEducator
                            ? _educatorNavItems()
                            : _isChild
                                ? _childNavItems()
                                : _studentNavItems(),
                        onTap: (index) => _onTap(context, index),
                        bounceControllers: _bounceControllers,
                        vsync: this,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
    ),

        // Level-up celebration overlay
        if (_celebratingLevel != null)
          LevelUpCelebrationScreen(
            newLevel: _celebratingLevel!,
            reducedMotion: ref.read(settingsProvider).reducedMotion,
            onDismiss: () => setState(() => _celebratingLevel = null),
          ),
      ],
    );
  }

  List<_NavItem> _studentNavItems() {
    return const [
      _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.style_outlined, selectedIcon: Icons.style_rounded, label: 'Cards'),
      _NavItem(icon: Icons.sports_esports_outlined, selectedIcon: Icons.sports_esports_rounded, label: 'Games'),
      _NavItem(icon: Icons.auto_stories_outlined, selectedIcon: Icons.auto_stories_rounded, label: 'Stories'),
      _NavItem(icon: Icons.emoji_events_outlined, selectedIcon: Icons.emoji_events_rounded, label: 'Progress'),
    ];
  }

  List<_NavItem> _educatorNavItems() {
    return const [
      _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.people_outlined, selectedIcon: Icons.people_rounded, label: 'Students'),
      _NavItem(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics_rounded, label: 'Analytics'),
      _NavItem(icon: Icons.assessment_outlined, selectedIcon: Icons.assessment_rounded, label: 'Reports'),
      _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: 'Settings'),
    ];
  }

  List<_NavItem> _childNavItems() {
    return const [
      _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.sports_esports_outlined, selectedIcon: Icons.sports_esports_rounded, label: 'Games'),
      _NavItem(icon: Icons.auto_stories_outlined, selectedIcon: Icons.auto_stories_rounded, label: 'Stories'),
      _NavItem(icon: Icons.star_border_rounded, selectedIcon: Icons.star_rounded, label: 'Stickers'),
    ];
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

// ─── Custom Animated Nav Bar ──────────────────────────

class _AnimatedNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  final Map<int, AnimationController> bounceControllers;
  final TickerProvider vsync;

  const _AnimatedNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    required this.bounceControllers,
    required this.vsync,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final primaryColor = hc.primary;
    final pillWidth = context.responsiveSize(60);
    final pillHeight = context.responsiveSize(36);
    final barHeight = context.responsiveSize(80);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final itemWidth = totalWidth / items.length;
        final pillLeft = currentIndex * itemWidth + (itemWidth - pillWidth) / 2;
        // Vertically center the pill over the icon area (shifted slightly up)
        final pillTop = (barHeight - pillHeight) / 2 - 6;

        return SizedBox(
          height: barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
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

              // Nav items row
              Row(
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

  const _AnimatedNavItem({
    required this.item,
    required this.isSelected,
    required this.index,
    required this.onTap,
    required this.bounceControllers,
    required this.vsync,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem> {
  late final AnimationController _bounceCtrl;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = widget.bounceControllers[widget.index] ??= AnimationController(
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

    return Semantics(
      button: true,
      label: widget.item.label,
      selected: widget.isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: SizedBox(
          height: 80,
          child: AnimatedBuilder(
            animation: _bounceCtrl,
            builder: (context, child) {
              // Bounce: quick scale up then back
              final t = _bounceCtrl.value;
              final bounceScale =
                  1.0 + 0.12 * Curves.elasticOut.transform(t) * (1 - t);
              return Transform.scale(
                scale: bounceScale,
                child: child,
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with animated transitions
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
                    size: widget.isSelected
                        ? context.responsiveSize(26)
                        : context.responsiveSize(22),
                    color: widget.isSelected
                        ? primaryColor
                        : unselectedColor,
                  ),
                ),
                const SizedBox(height: 4),

                // Label with animated color & weight
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: widget.isSelected
                        ? context.responsiveSize(11.5)
                        : context.responsiveSize(10.5),
                    fontWeight:
                        widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isSelected
                        ? primaryColor
                        : unselectedColor,
                    fontFamily: 'Nunito',
                    letterSpacing: widget.isSelected ? 0.2 : 0,
                  ),
                  child: Text(widget.item.label),
                ),

                // Active dot indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(top: 4),
                  width: widget.isSelected ? 5 : 0,
                  height: widget.isSelected ? 5 : 0,
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
