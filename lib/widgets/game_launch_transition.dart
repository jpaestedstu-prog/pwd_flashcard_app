import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../data/models/enums.dart';

/// A full-screen hero-animated launch transition shown before entering a game.
///
/// Displays the game icon expanding into view, the game name, a pulsing
/// countdown (3→2→1→GO!), then calls [onComplete] to navigate to the game.
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(PageRouteBuilder(
///   pageBuilder: (_, __, ___) => GameLaunchTransition(
///     game: GameType.spellingBee,
///     onComplete: () => context.go('/games/spelling-bee?...'),
///   ),
/// ));
/// ```
class GameLaunchTransition extends StatefulWidget {
  final GameType game;
  final VoidCallback onComplete;
  final bool reducedMotion;

  const GameLaunchTransition({
    super.key,
    required this.game,
    required this.onComplete,
    this.reducedMotion = false,
  });

  @override
  State<GameLaunchTransition> createState() => _GameLaunchTransitionState();
}

class _GameLaunchTransitionState extends State<GameLaunchTransition>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _iconController;
  late final AnimationController _countdownController;
  late final AnimationController _ringController;

  late final Animation<double> _bgScale;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconRotation;

  int _countdownValue = 3;
  bool _showGo = false;

  @override
  void initState() {
    super.initState();

    // Background radial expansion
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bgScale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeOutCubic),
    );

    // Icon entrance: scale up with slight rotation
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_iconController);
    _iconRotation = Tween(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeOutBack),
    );

    // Countdown tick (drives each number)
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Expanding ring pulse per tick
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    if (widget.reducedMotion) {
      // Skip animation entirely
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) widget.onComplete();
      return;
    }

    // Phase 1: Background expand
    _bgController.forward();
    await Future.delayed(const Duration(milliseconds: 400));

    // Phase 2: Icon entrance
    if (!mounted) return;
    _iconController.forward();
    await Future.delayed(const Duration(milliseconds: 700));

    // Phase 3: Countdown
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      _countdownController
        ..reset()
        ..forward();
      _ringController
        ..reset()
        ..forward();
      await Future.delayed(const Duration(milliseconds: 700));
    }

    // Phase 4: GO!
    if (!mounted) return;
    setState(() => _showGo = true);
    _countdownController
      ..reset()
      ..forward();
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _iconController.dispose();
    _countdownController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameColor = widget.game.color;
    final darkerColor = HSLColor.fromColor(gameColor)
        .withLightness(0.3)
        .toColor();

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.5 * _bgScale.value,
                colors: [gameColor, darkerColor],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Game icon with scale + rotation entrance
                AnimatedBuilder(
                  animation: _iconController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _iconScale.value,
                      child: Transform.rotate(
                        angle: _iconRotation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gameColor.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.game.icon,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Game name
                AnimatedBuilder(
                  animation: _iconController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _iconController.value.clamp(0.0, 1.0),
                      child: child,
                    );
                  },
                  child: Text(
                    widget.game.label,
                    style: AppTypography.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Countdown or GO!
                SizedBox(
                  height: 120,
                  width: 120,
                  child: AnimatedBuilder(
                    animation: _countdownController,
                    builder: (context, _) {
                      final t = _countdownController.value;
                      final scale = 1.0 + 0.3 * Curves.easeOut.transform(t) * (1 - t);

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Expanding ring
                          AnimatedBuilder(
                            animation: _ringController,
                            builder: (context, _) {
                              final ringT = _ringController.value;
                              return Container(
                                width: 100 + (40 * ringT),
                                height: 100 + (40 * ringT),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.4 * (1 - ringT)),
                                    width: 3,
                                  ),
                                ),
                              );
                            },
                          ),

                          // Number/GO text
                          Transform.scale(
                            scale: scale,
                            child: Text(
                              _showGo ? 'GO!' : '$_countdownValue',
                              style: AppTypography.gameScore.copyWith(
                                fontSize: _showGo ? 48 : 64,
                                color: AppColors.textOnPrimary,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Decorative dots
                AnimatedBuilder(
                  animation: _bgController,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _bgScale.value,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: _countdownValue <= (3 - i) || _showGo
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
