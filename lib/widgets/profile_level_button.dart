import 'package:flutter/material.dart';

import '../core/services/xp_level_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../data/models/models.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import 'profile_avatar.dart';

/// The learner's avatar as the door to their **Player Profile**, with their
/// level drawn around and on it.
///
/// Home used to carry three separate level surfaces stacked down the page: the
/// avatar (decorative, not tappable), the XP bar card, and a full-width
/// "Player Profile" gradient button. All three said the same thing and pushed
/// the learner's actual day below the fold. This is the one control that
/// replaces them — a profile icon in the top-left corner, which is where a
/// person looks for their own account.
///
/// * the **ring** is progress through the current level band (the same
///   fraction the XP bar used to fill),
/// * the **badge** is the level number,
/// * the **semantic label** is the whole XP sentence, so a screen-reader user
///   loses nothing by the bar being gone.
class ProfileLevelButton extends StatelessWidget {
  const ProfileLevelButton({
    super.key,
    required this.profile,
    required this.progress,
    required this.onTap,
    this.radius = 24,
  });

  final UserProfile? profile;
  final LearningProgress progress;
  final VoidCallback onTap;

  /// Radius of the avatar circle. The ring and badge are sized from it.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final xp = XpService.calculateXp(progress);
    final level = XpService.currentLevel(progress);
    final next = XpService.nextLevel(progress);
    final fraction = XpService.progressToNextLevel(progress);
    final toNext = XpService.xpToNextLevel(progress);
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final filipino = t.localeName.startsWith('fil');

    // The ring sits outside the avatar, so the button is wider than the face.
    final diameter = radius * 2 + 8;
    final badge = (radius * 0.85).clamp(18.0, 26.0);

    return Semantics(
      button: true,
      label: t.homeLevelSemantics(
        level.level,
        level.titleOf(filipino: filipino),
        xp,
        toNext != null
            ? t.homeXpToLevel(
                toNext,
                next!.level,
                next.titleOf(filipino: filipino),
              )
            : t.homeMaxLevel,
      ),
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    strokeWidth: 3.5,
                    backgroundColor: hc.border,
                    valueColor: AlwaysStoppedAnimation<Color>(hc.primary),
                  ),
                ),
                ProfileAvatar(profile: profile, radius: radius),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: badge,
                    height: badge,
                    decoration: BoxDecoration(
                      gradient: hc.heroGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: hc.surface, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${level.level}',
                        // Fixed scale: the badge is a fixed-size chip on a
                        // fixed-size avatar, so a 2.0x font setting would
                        // otherwise push the number straight out of it.
                        textScaler: const TextScaler.linear(1.0),
                        style: AppTypography.labelSmall.copyWith(
                          color: hc.textOnPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
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
