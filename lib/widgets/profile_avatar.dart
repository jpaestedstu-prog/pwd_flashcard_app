import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/avatar_data.dart';
import '../core/theme/app_colors.dart';
import '../data/models/models.dart';
import '../data/models/shop_data.dart';
import '../providers/app_providers.dart';

/// A profile avatar that respects equipped shop items (avatar + border).
///
/// When an equipped shop avatar exists, its emoji/color is shown instead
/// of the default [AvatarData] avatar. When a border is equipped, a
/// decorative frame wraps the avatar circle.
class ProfileAvatar extends ConsumerWidget {
  /// The profile to display. If null, shows a '?' placeholder.
  final UserProfile? profile;

  /// Radius of the inner [CircleAvatar].
  final double radius;

  /// Override font size for the emoji. Defaults to [radius].
  final double? fontSize;

  const ProfileAvatar({
    super.key,
    required this.profile,
    this.radius = 28,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profile == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceContainerHighest,
        child: Text('?', style: TextStyle(fontSize: fontSize ?? radius)),
      );
    }

    // Resolve avatar: equipped shop avatar first, then default
    final progressNotifier = ref.read(progressProvider.notifier);
    final equippedAvatarId =
        progressNotifier.getEquippedItemId(ShopItemType.avatar);
    final equippedAvatar =
        equippedAvatarId != null ? ShopData.findById(equippedAvatarId) : null;

    final String emoji;
    final Color bgColor;

    if (equippedAvatar != null) {
      emoji = equippedAvatar.emoji;
      bgColor = equippedAvatar.color;
    } else {
      final defaultAvatar = AvatarData.getAvatar(profile!.avatarIndex);
      emoji = defaultAvatar.emoji;
      bgColor = defaultAvatar.color;
    }

    // Resolve border: equipped shop border
    final equippedBorderId =
        progressNotifier.getEquippedItemId(ShopItemType.border);

    final avatarWidget = CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(emoji, style: TextStyle(fontSize: fontSize ?? radius)),
    );

    if (equippedBorderId == null) return avatarWidget;

    return _BorderWrapper(
      borderId: equippedBorderId,
      radius: radius,
      child: avatarWidget,
    );
  }
}

/// Wraps a [CircleAvatar] with a decorative border based on the shop item.
class _BorderWrapper extends StatelessWidget {
  final String borderId;
  final double radius;
  final Widget child;

  const _BorderWrapper({
    required this.borderId,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final borderWidth = radius * 0.14;
    final outerRadius = radius + borderWidth + 2;

    switch (borderId) {
      case 'border_rainbow':
        return Container(
          padding: EdgeInsets.all(borderWidth),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Color(0xFFFF0000),
                Color(0xFFFF9900),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF0099FF),
                Color(0xFF6633FF),
                Color(0xFFFF0000),
              ],
            ),
          ),
          child: child,
        );
      case 'border_sparkle':
        return Container(
          padding: EdgeInsets.all(borderWidth),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFD700),
                Color(0xFFFFF8DC),
                Color(0xFFFFD700),
                Color(0xFFFFF8DC),
                Color(0xFFFFD700),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      case 'border_crown':
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.all(borderWidth),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFE082),
                    Color(0xFFFFB300),
                  ],
                ),
              ),
              child: child,
            ),
            Positioned(
              top: -(outerRadius * 0.3),
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '👑',
                  style: TextStyle(fontSize: outerRadius * 0.4),
                ),
              ),
            ),
          ],
        );
      default:
        return child;
    }
  }
}
