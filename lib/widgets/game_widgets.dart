import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/responsive_utils.dart';
import '../../data/models/enums.dart';
import '../../core/services/adaptive_difficulty_service.dart';
import 'animated_dialogs.dart';
import 'animated_score_reveal.dart';
import 'tilt_3d.dart';

// ─── Category Picker Bottom Sheet ───────────────────────

/// Shows a bottom sheet letting the user pick one or more categories
/// (or "All Categories"). Returns [null] if dismissed, otherwise the
/// selected list (empty list = all categories).
///
/// When [availableCategories] is provided, categories outside that set
/// are shown but disabled with a "Coming soon" pill, and "All Categories"
/// resolves to the available subset only. Used by the FSL games where
/// some categories don't have sign-language videos bundled yet.
Future<List<FlashcardCategory>?> showCategoryPicker(
  BuildContext context, {
  Set<FlashcardCategory>? availableCategories,
  String? unavailableLabel,
}) {
  return showAnimatedBottomSheet<List<FlashcardCategory>>(
    context,
    builder: (ctx) => _CategoryPickerSheet(
      availableCategories: availableCategories,
      unavailableLabel: unavailableLabel ?? 'Coming soon',
    ),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  final Set<FlashcardCategory>? availableCategories;
  final String unavailableLabel;

  const _CategoryPickerSheet({
    this.availableCategories,
    this.unavailableLabel = 'Coming soon',
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  bool _allSelected = true;
  final Set<FlashcardCategory> _selected = {};

  bool _isAvailable(FlashcardCategory cat) {
    final allowed = widget.availableCategories;
    return allowed == null || allowed.contains(cat);
  }

  void _toggleAll() {
    setState(() {
      _allSelected = true;
      _selected.clear();
    });
  }

  void _toggleCategory(FlashcardCategory cat) {
    if (!_isAvailable(cat)) return;
    setState(() {
      _allSelected = false;
      if (_selected.contains(cat)) {
        _selected.remove(cat);
        if (_selected.isEmpty) _allSelected = true;
      } else {
        _selected.add(cat);
        // "All Categories" only makes sense if every selectable category
        // is selected — match that against the playable set, not the full
        // enum, when an availability filter is in effect.
        final selectable = widget.availableCategories?.length ??
            FlashcardCategory.values.length;
        if (_selected.length == selectable) {
          _allSelected = true;
          _selected.clear();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final sheetBg = hc.surface;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fixed header
          Padding(
            // The sheet wrapper already draws a drag handle, so the header
            // starts at the title — no second handle, which also reclaims the
            // vertical space a short viewport needs at large font scales.
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(Icons.category_rounded,
                          color: AppColors.primary, size: context.scaleIcon(22)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Choose Categories',
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick which vocabulary to practice',
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Scrollable category list
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // All Categories option
                  _CategoryOptionCard(
                    label: 'All Categories',
                    icon: Icons.category_rounded,
                    color: AppColors.primary,
                    selected: _allSelected,
                    onTap: _toggleAll,
                  ),
                  const SizedBox(height: 10),

                  // Individual categories
                  ...FlashcardCategory.values.map((cat) {
                    final available = _isAvailable(cat);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CategoryOptionCard(
                        label: cat.label,
                        icon: cat.icon,
                        color: cat.darkColor,
                        selected: !_allSelected && _selected.contains(cat),
                        disabled: !available,
                        disabledLabel: widget.unavailableLabel,
                        onTap: () => _toggleCategory(cat),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Fixed confirm button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final availability = widget.availableCategories;
                  // When an availability filter is in effect, "All Categories"
                  // means "all available categories" — pass the explicit
                  // subset so callers don't have to filter on their side.
                  final result = _allSelected
                      ? (availability == null
                          ? <FlashcardCategory>[]
                          : availability.toList())
                      : _selected.toList();
                  Navigator.of(context).pop(result);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  _allSelected
                      ? 'Start with All Categories'
                      : 'Start with ${_selected.length} ${_selected.length == 1 ? "Category" : "Categories"}',
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rectangular category option card — matches the style of difficulty cards
/// in the game hub for consistent look.
class _CategoryOptionCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool disabled;
  final String disabledLabel;
  final VoidCallback onTap;

  const _CategoryOptionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.disabled = false,
    this.disabledLabel = 'Coming soon',
  });

  @override
  State<_CategoryOptionCard> createState() => _CategoryOptionCardState();
}

class _CategoryOptionCardState extends State<_CategoryOptionCard> {
  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final selected = widget.selected;
    final disabled = widget.disabled;
    final hc = HCColor.of(context);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.10)
            : hc.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? color.withValues(alpha: 0.6)
              : hc.border,
          width: selected ? 2.5 : 1.5,
        ),
      ),
      child: Row(
        children: [
          // Icon container ─ rectangular like game difficulty cards
          Container(
            width: context.responsiveSize(48),
            height: context.responsiveSize(48),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.18)
                  : color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: context.scaleIcon(24),
                color: selected ? color : color.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? color : null,
                  ),
                ),
                if (disabled) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: hc.textSecondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.disabledLabel,
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Selection indicator
          if (!disabled)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey('checked'),
                      size: context.scaleIcon(26),
                      color: color,
                    )
                  : Icon(
                      Icons.circle_outlined,
                      key: const ValueKey('unchecked'),
                      size: context.scaleIcon(26),
                      color: hc.textSecondary.withValues(alpha: 0.4),
                    ),
            )
          else
            Icon(
              Icons.lock_outline_rounded,
              size: context.scaleIcon(22),
              color: hc.textSecondary.withValues(alpha: 0.5),
            ),
        ],
      ),
    );

    if (disabled) {
      return Opacity(
        opacity: 0.55,
        child: Semantics(
          label: '${widget.label}, ${widget.disabledLabel}',
          enabled: false,
          child: card,
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Pressable3D(
        maxTilt: 0.04,
        child: card,
      ),
    );
  }
}

// ─── Difficulty Picker Bottom Sheet ─────────────────────

/// Return type for the difficulty picker.
typedef GamePickerResult = ({GameDifficulty difficulty, bool timedMode});

/// Shows a bottom sheet letting the user pick Easy / Medium / Hard / Auto
/// and optionally enable timed mode.
/// Returns the selected [GamePickerResult] or null if dismissed.
/// Pass [profileId] to enable the adaptive "Auto" difficulty option.
Future<GamePickerResult?> showDifficultyPicker(
  BuildContext context,
  GameType game, {
  String? profileId,
}) {
  return showAnimatedBottomSheet<GamePickerResult>(
    context,
    builder: (ctx) => _DifficultyPickerSheet(game: game, profileId: profileId),
  );
}

class _DifficultyPickerSheet extends StatefulWidget {
  final GameType game;
  final String? profileId;
  const _DifficultyPickerSheet({required this.game, this.profileId});

  @override
  State<_DifficultyPickerSheet> createState() => _DifficultyPickerSheetState();
}

class _DifficultyPickerSheetState extends State<_DifficultyPickerSheet> {
  bool _timedMode = false;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final sheetBg = hc.surface;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      // The card list can be taller than a short (landscape) viewport at large
      // font scales, so it must scroll inside the height-capped sheet rather
      // than overflow. The sheet wrapper already draws a drag handle, so this
      // body starts straight at the title.
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.game.icon, size: context.scaleIcon(28), color: widget.game.color),
              const SizedBox(width: 10),
              Text(
                widget.game.label,
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose your difficulty',
            style: AppTypography.bodyMedium.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Timed mode toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _timedMode
                  ? AppColors.warning.withValues(alpha: 0.12)
                  : hc.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _timedMode
                    ? AppColors.warning.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_rounded,
                  color: _timedMode ? AppColors.warning : AppColors.textHint,
                  size: context.scaleIcon(24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beat the Clock ⏱️',
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _timedMode
                              ? AppColors.warning
                              : hc.textPrimary,
                        ),
                      ),
                      Text(
                        '60 seconds to finish!',
                        style: AppTypography.labelSmall.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _timedMode,
                  activeTrackColor: AppColors.warning,
                  onChanged: (v) => setState(() => _timedMode = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Adaptive "Auto" difficulty card
          if (widget.profileId != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AutoDifficultyCard(
                profileId: widget.profileId!,
                gameType: widget.game,
                onTap: (suggested) => Navigator.of(context).pop(
                  (difficulty: suggested, timedMode: _timedMode),
                ),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),
            ),
          ],

          // Difficulty cards
          ...GameDifficulty.values.asMap().entries.map((entry) {
            final index = entry.key;
            final diff = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  _DifficultyCard(
                        difficulty: diff,
                        onTap: () => Navigator.of(context).pop(
                          (difficulty: diff, timedMode: _timedMode),
                        ),
                      )
                      .animate()
                      .fadeIn(
                        duration: 350.ms,
                        delay: Duration(milliseconds: 80 * index),
                      )
                      .slideY(begin: 0.1, end: 0),
            );
          }),
        ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatefulWidget {
  final GameDifficulty difficulty;
  final VoidCallback onTap;

  const _DifficultyCard({required this.difficulty, required this.onTap});

  @override
  State<_DifficultyCard> createState() => _DifficultyCardState();
}

class _DifficultyCardState extends State<_DifficultyCard> {
  @override
  Widget build(BuildContext context) {
    final diff = widget.difficulty;
    return GestureDetector(
      onTap: widget.onTap,
      child: Pressable3D(
        maxTilt: 0.04,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                diff.color.withValues(alpha: 0.10),
                diff.color.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: diff.color.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: diff.color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Difficulty icon
              Container(
                width: context.responsiveSize(52),
                height: context.responsiveSize(52),
                decoration: BoxDecoration(
                  color: diff.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: diff.color.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(diff.emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diff.label,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: diff.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      diff.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: HCColor.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: context.scaleIcon(18),
                color: diff.color.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adaptive "Auto" difficulty card that suggests a level based on the
/// student's recent performance in this specific game.
class _AutoDifficultyCard extends StatelessWidget {
  final String profileId;
  final GameType gameType;
  final void Function(GameDifficulty suggested) onTap;

  const _AutoDifficultyCard({
    required this.profileId,
    required this.gameType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final suggested = AdaptiveDifficultyService.suggestForGame(
      profileId: profileId,
      gameType: gameType,
    );
    final reason = AdaptiveDifficultyService.getSuggestionReasonForGame(
      profileId: profileId,
      gameType: gameType,
    );
    const autoColor = Color(0xFF7C4DFF);

    return GestureDetector(
      onTap: () => onTap(suggested),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              autoColor.withValues(alpha: 0.08),
              autoColor.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: autoColor.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: context.responsiveSize(52),
              height: context.responsiveSize(52),
              decoration: BoxDecoration(
                color: autoColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text('🤖', style: TextStyle(fontSize: context.responsiveSize(26))),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Auto',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: autoColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: suggested.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '→ ${suggested.label}',
                          style: AppTypography.labelSmall.copyWith(
                            color: suggested.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: AppTypography.bodySmall.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.auto_awesome_rounded,
              size: context.scaleIcon(22),
              color: autoColor.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated score display with number tick-up effect
class AnimatedScoreDisplay extends StatelessWidget {
  final int score;
  final int total;
  final Color? color;

  const AnimatedScoreDisplay({
    super.key,
    required this.score,
    required this.total,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: score),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$value',
                style: AppTypography.gameScore.copyWith(
                  color: color ?? AppColors.primary,
                ),
              ),
              TextSpan(
                text: ' / $total',
                style: AppTypography.headlineMedium.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Circular countdown timer with color transitions
class GameTimerWidget extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;
  final double size;

  const GameTimerWidget({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.size = 60,
  });

  Color get _timerColor {
    final ratio = remainingSeconds / totalSeconds;
    if (ratio > 0.5) return AppColors.success;
    if (ratio > 0.25) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final progress = remainingSeconds / totalSeconds;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _timerColor.withValues(alpha: 0.2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(_timerColor.withValues(alpha: 0.1)),
          ),
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 5,
            backgroundColor: _timerColor.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(_timerColor),
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Text(
              '$remainingSeconds',
              style: AppTypography.titleMedium.copyWith(
                color: _timerColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confetti + stars celebration overlay
class CelebrationOverlay extends StatefulWidget {
  final bool show;
  final Widget child;

  const CelebrationOverlay({
    super.key,
    required this.show,
    required this.child,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didUpdateWidget(CelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.show)
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 30,
              minBlastForce: 10,
              colors: const [
                AppColors.primary,
                AppColors.secondary,
                AppColors.accent,
                AppColors.warning,
                AppColors.success,
                AppColors.info,
              ],
            ),
            ),
          ),
      ],
    );
  }
}

/// Game result dialog shown at the end of each game
class GameResultDialog extends StatelessWidget {
  final int score;
  final int total;
  final int starsEarned;

  /// Performance rating (0–3 stars) shown by the result screen. When null
  /// it is derived from the score via [ratingForScore] — the same
  /// thresholds every game's star formula has always used. Single-round
  /// games (Word Hunt focus mode) pass it explicitly so a perfect round
  /// rates 3/3 even though it earns just 1 ⭐.
  final int? rating;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;
  final VoidCallback? onReview;

  const GameResultDialog({
    super.key,
    required this.score,
    required this.total,
    required this.starsEarned,
    this.rating,
    required this.onPlayAgain,
    required this.onExit,
    this.onReview,
  });

  /// Default 0–3 rating from the share of correct answers (≥90% → 3,
  /// ≥70% → 2, ≥50% → 1).
  static int ratingForScore(int score, int total) {
    if (total <= 0) return 0;
    final pct = score / total;
    if (pct >= 0.9) return 3;
    if (pct >= 0.7) return 2;
    if (pct >= 0.5) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScoreReveal(
      score: score,
      total: total,
      rating: rating ?? ratingForScore(score, total),
      starsEarned: starsEarned,
      onPlayAgain: onPlayAgain,
      onExit: onExit,
      onReview: onReview,
    );
  }
}

/// Star rating display
class StarRating extends StatelessWidget {
  final int stars;
  final int maxStars;
  final double size;

  const StarRating({
    super.key,
    required this.stars,
    this.maxStars = 3,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars out of $maxStars stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(maxStars, (index) {
          final earned = index < stars;
          return Container(
            decoration: earned
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  )
                : null,
            child: Icon(
              earned ? Icons.star_rounded : Icons.star_border_rounded,
              size: size,
              color: earned
                  ? AppColors.warning
                  : HCColor.of(context).textSecondary.withValues(alpha: 0.3),
            ),
          );
        }),
      ),
    );
  }
}
