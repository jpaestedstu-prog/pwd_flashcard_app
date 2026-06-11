import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';

/// Animation state for the tutor avatar.
enum TutorAvatarState { idle, thinking, celebrate }

/// Visual + behavioral persona for the AI Tutor, adapted per profile role.
///
/// A **Child** gets a bigger, more playful, read-aloud-by-default buddy; a
/// **Student** gets a calmer "study buddy" with read-aloud opt-in. Both share
/// the same engine — only tone, sizing, and defaults differ.
class TutorPersona {
  /// Avatar glyph.
  final String emoji;

  /// Title shown in the app bar / header.
  final String titleEn;
  final String titleFil;

  /// Base avatar diameter in logical px (callers scale this by the text scaler,
  /// clamped, so it grows with the Font Size setting without runaway growth).
  final double avatarBaseSize;

  /// Auto-speak each tutor message via on-device TTS.
  final bool autoReadAloud;

  /// Extra-playful styling (more emoji, larger chips). Child = true.
  final bool playful;

  const TutorPersona({
    required this.emoji,
    required this.titleEn,
    required this.titleFil,
    required this.avatarBaseSize,
    required this.autoReadAloud,
    required this.playful,
  });

  String title(bool isFilipino) => isFilipino ? titleFil : titleEn;

  /// Resolve the persona for a profile [role]. Child profiles get the playful
  /// buddy; everyone else (student / player / null) gets the study buddy.
  static TutorPersona of(UserRole? role) =>
      role == UserRole.child ? child : student;

  static const TutorPersona child = TutorPersona(
    emoji: '🧸',
    titleEn: 'Buddy',
    titleFil: 'Kaibigan',
    avatarBaseSize: 40,
    autoReadAloud: true,
    playful: true,
  );

  static const TutorPersona student = TutorPersona(
    emoji: '🤖',
    titleEn: 'AI Tutor',
    titleFil: 'AI Tutor',
    avatarBaseSize: 32,
    autoReadAloud: false,
    playful: false,
  );
}

/// The tutor's animated avatar. Self-contained and overflow-safe: it occupies a
/// fixed [size] box and never imposes intrinsic constraints on its parent.
///
///   * [TutorAvatarState.idle] — a slow breathing pulse.
///   * [TutorAvatarState.thinking] — a gentle bob (shown while typing).
///   * [TutorAvatarState.celebrate] — a one-shot pop (correct answer / lesson).
class TutorAvatar extends StatelessWidget {
  final TutorPersona persona;
  final TutorAvatarState state;
  final double size;

  const TutorAvatar({
    super.key,
    required this.persona,
    this.state = TutorAvatarState.idle,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bannerAiTutorStart, AppColors.bannerAiTutorEnd],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: AppColors.bannerAiTutorEnd.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(persona.emoji, style: TextStyle(fontSize: size * 0.52)),
    );

    switch (state) {
      case TutorAvatarState.idle:
        return box
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              duration: 1800.ms,
              begin: const Offset(1, 1),
              end: const Offset(1.06, 1.06),
              curve: Curves.easeInOut,
            );
      case TutorAvatarState.thinking:
        return box
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(duration: 500.ms, begin: 0, end: -4, curve: Curves.easeInOut);
      case TutorAvatarState.celebrate:
        return box
            .animate(onPlay: (c) => c.repeat(reverse: true, period: 600.ms))
            .scale(
              duration: 300.ms,
              begin: const Offset(1, 1),
              end: const Offset(1.18, 1.18),
              curve: Curves.elasticOut,
            )
            .rotate(begin: -0.03, end: 0.03);
    }
  }
}
