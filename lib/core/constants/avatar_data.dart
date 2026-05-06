import 'package:flutter/material.dart';

/// Avatar options for user profiles — fun animal-themed icons
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
  ];

  /// Get avatar by index (safe, wraps around)
  static AvatarOption getAvatar(int index) =>
      avatars[index.clamp(0, avatars.length - 1)];
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
