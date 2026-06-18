import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/local/seed_stories.dart' show Story;
import '../../../data/models/enums.dart';
import '../../../widgets/depth_3d.dart';
import '../../../widgets/tilt_3d.dart';
import 'story_meta.dart';

/// A themed, vertical "cover" card for a single story.
///
/// Designed to live inside a fixed-height grid cell (see
/// `StoryListScreen`), so it is overflow-safe by construction: the cover
/// band is the only flexible region, while the text content below is
/// capped to a few ellipsised lines.
///
/// [kidMode] renders a bigger, simpler card for the Child profile — larger
/// medallion, no Filipino subtitle, no metadata chips.
class StoryCoverCard extends StatefulWidget {
  final Story story;
  final bool unlocked;

  /// Whether the learner has finished reading this story.
  final bool read;

  /// Best quiz star score for this story (0–3). 0 hides the star badge.
  final int stars;

  final bool kidMode;
  final VoidCallback? onTap;

  const StoryCoverCard({
    super.key,
    required this.story,
    required this.unlocked,
    this.read = false,
    this.stars = 0,
    this.kidMode = false,
    this.onTap,
  });

  @override
  State<StoryCoverCard> createState() => _StoryCoverCardState();
}

class _StoryCoverCardState extends State<StoryCoverCard> {
  Color _difficultyColor(HCColor hc) => switch (widget.story.difficulty) {
    StoryDifficulty.easy => hc.success,
    StoryDifficulty.medium => hc.warning,
    StoryDifficulty.hard => hc.error,
  };

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final story = widget.story;
    final locked = !widget.unlocked;
    final accent = story.category.color;
    final kid = widget.kidMode;

    return Semantics(
      button: widget.unlocked,
      label: locked
          ? '${story.titleEn} — locked'
          : '${story.titleEn} — tap to read'
                '${widget.read ? ', read' : ''}',
      child: GestureDetector(
        onTap: widget.unlocked ? () => widget.onTap?.call() : null,
        // Pressable3D adds the press-scale + gentle tilt (reduced-motion aware);
        // disabled on locked cards so they stay completely static.
        child: Pressable3D(
          enabled: widget.unlocked,
          child: Container(
            decoration: BoxDecoration(
              color: hc.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: locked
                    ? AppColors.border
                    : (hc.hc
                          ? AppColors.hcPrimary
                          : accent.withValues(alpha: 0.4)),
                width: 1.5,
              ),
              boxShadow: locked
                  ? null
                  : [
                      // Layered: category-tinted glow + soft neutral drop.
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Column(
                children: [
                  // ─── Cover band (the only flexible region) ──────────
                  Expanded(
                    child: _CoverBand(
                      story: story,
                      locked: locked,
                      read: widget.read,
                      stars: widget.stars,
                      kid: kid,
                      hc: hc,
                    ),
                  ),
                  // ─── Text content (bounded, ellipsised) ─────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      kid ? 14 : 12,
                      kid ? 12 : 10,
                      kid ? 14 : 12,
                      kid ? 14 : 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.titleEn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              (kid
                                      ? AppTypography.titleMedium
                                      : AppTypography.titleSmall)
                                  .copyWith(
                                    color: locked
                                        ? hc.textSecondary
                                        : hc.textPrimary,
                                  ),
                        ),
                        if (!kid) ...[
                          const SizedBox(height: 2),
                          Text(
                            story.titleFil,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: hc.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MetaChips(
                            story: story,
                            locked: locked,
                            difficultyColor: _difficultyColor(hc),
                            hc: hc,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The gradient cover with the emoji/lock medallion and completion badges.
class _CoverBand extends StatelessWidget {
  final Story story;
  final bool locked;
  final bool read;
  final int stars;
  final bool kid;
  final HCColor hc;

  const _CoverBand({
    required this.story,
    required this.locked,
    required this.read,
    required this.stars,
    required this.kid,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    final accent = story.category.color;
    final medallion = context.scaleIcon(kid ? 64 : 52);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient backdrop — vibrant & dimensional when unlocked, muted grey
        // when locked.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: locked
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.border.withValues(alpha: 0.35),
                      AppColors.border.withValues(alpha: 0.15),
                    ],
                  )
                : Depth3D.vibrantGradient(accent),
          ),
        ),
        // Floating bubbles + glossy sheen (unlocked only)
        if (!locked) ...[
          const Positioned(
            top: -14,
            right: -12,
            child: DepthBubble(size: 56, light: 0.18),
          ),
          const Positioned(
            bottom: -10,
            left: -10,
            child: DepthBubble(size: 38, light: 0.13),
          ),
          const Positioned.fill(child: GlossySheen()),
        ],
        // Medallion — raised 3D coin
        Center(
          child: locked
              ? Container(
                  width: medallion,
                  height: medallion,
                  decoration: BoxDecoration(
                    color: hc.surface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: hc.textSecondary,
                      size: medallion * 0.5,
                    ),
                  ),
                )
              : Badge3D(
                  size: medallion,
                  emoji: story.emoji,
                  iconSize: medallion * 0.52,
                ),
        ),
        // Read badge (top-right)
        if (read && !locked)
          Positioned(
            top: 8,
            right: 8,
            child: _Pill(
              icon: Icons.check_circle_rounded,
              color: hc.success,
              label: 'Read',
            ),
          ),
        // Stars (bottom-left)
        if (stars > 0 && !locked)
          Positioned(left: 8, bottom: 8, child: _StarRow(stars: stars)),
      ],
    );
  }
}

/// Difficulty + estimated read-time chips.
class _MetaChips extends StatelessWidget {
  final Story story;
  final bool locked;
  final Color difficultyColor;
  final HCColor hc;

  const _MetaChips({
    required this.story,
    required this.locked,
    required this.difficultyColor,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    final muted = hc.textSecondary;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Chip(
          icon: Icons.signal_cellular_alt_rounded,
          label: story.difficulty.label,
          color: locked ? muted : difficultyColor,
        ),
        _Chip(
          icon: Icons.schedule_rounded,
          label: '${story.estimatedMinutes} min',
          color: muted,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTypography.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _Pill({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int stars;
  const _StarRow({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Icon(
            i < stars ? Icons.star_rounded : Icons.star_border_rounded,
            size: 14,
            color: const Color(0xFFFFD54F),
          ),
        ),
      ),
    );
  }
}
