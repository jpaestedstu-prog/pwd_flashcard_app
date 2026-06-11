import 'package:flutter/material.dart';
import '../../data/models/enums.dart';

/// Avatar options for user profiles — fun animal-themed icons plus
/// role-specific avatars for educators (teachers, parents).
///
/// Indices 0–11 are the original animal set. Indices 12–15 are appended
/// role-themed avatars so existing stored `avatarIndex` values keep
/// resolving correctly.
class AvatarData {
  AvatarData._();

  static const List<AvatarOption> avatars = [
    AvatarOption(emoji: '🐶', label: 'Dog', color: Color(0xFFFFCC80)),
    AvatarOption(emoji: '🐱', label: 'Cat', color: Color(0xFFEF9A9A)),
    AvatarOption(emoji: '🐰', label: 'Bunny', color: Color(0xFFF48FB1)),
    AvatarOption(emoji: '🐼', label: 'Panda', color: Color(0xFFB0BEC5)),
    AvatarOption(emoji: '🦊', label: 'Fox', color: Color(0xFFFFAB91)),
    AvatarOption(emoji: '🐸', label: 'Frog', color: Color(0xFFA5D6A7)),
    AvatarOption(emoji: '🦋', label: 'Butterfly', color: Color(0xFFCE93D8)),
    AvatarOption(emoji: '🐢', label: 'Turtle', color: Color(0xFF80CBC4)),
    AvatarOption(emoji: '🦁', label: 'Lion', color: Color(0xFFFFD54F)),
    AvatarOption(emoji: '🐧', label: 'Penguin', color: Color(0xFF90CAF9)),
    AvatarOption(emoji: '🦉', label: 'Owl', color: Color(0xFFBCAAA4)),
    AvatarOption(emoji: '🌟', label: 'Star', color: Color(0xFFB39DDB)),
    // ─── Role-themed avatars (appended to preserve existing indices) ───
    AvatarOption(emoji: '👨‍🏫', label: 'Male Teacher', color: Color(0xFF64B5F6)),
    AvatarOption(emoji: '👩‍🏫', label: 'Female Teacher', color: Color(0xFFF8BBD0)),
    AvatarOption(emoji: '👨‍👦', label: 'Father', color: Color(0xFF81C784)),
    AvatarOption(emoji: '👩‍👧', label: 'Mother', color: Color(0xFFFFAB91)),
  ];

  /// Get avatar by index (safe, wraps around)
  static AvatarOption getAvatar(int index) =>
      avatars[index.clamp(0, avatars.length - 1)];

  /// Role-appropriate avatars paired with their global index.
  ///
  /// Teacher → Male/Female Teacher. Parent → Father/Mother.
  /// All other roles (and null) → the 12 animal avatars.
  static List<(int, AvatarOption)> avatarsForRole(UserRole? role) {
    switch (role) {
      case UserRole.teacher:
        return [(12, avatars[12]), (13, avatars[13])];
      case UserRole.parent:
        return [(14, avatars[14]), (15, avatars[15])];
      default:
        return List.generate(12, (i) => (i, avatars[i]));
    }
  }

  /// Default avatar index for a role — used when initializing or resetting
  /// the picker selection so it always lands on a role-valid avatar.
  static int defaultIndexForRole(UserRole? role) => switch (role) {
        UserRole.teacher => 12,
        UserRole.parent => 14,
        _ => 0,
      };
}

class AvatarOption {
  final String emoji;
  final String label;
  final Color color;

  const AvatarOption({
    required this.emoji,
    required this.label,
    required this.color,
  });
}
