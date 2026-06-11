import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import 'app_colors.dart';

/// Per-role visual treatment for the onboarding & profile-setup surfaces.
///
/// Before this existed, the role colours and glyphs were duplicated as inline
/// `switch` statements and raw hex literals across the role picker and the two
/// setup screens. [RoleTheme] is the single source of truth: look it up with
/// [RoleTheme.of] and read [gradientColors] / [accent] / [icon].
///
/// Glyphs use the Material [IconData] from [UserRoleX.icon] rather than emoji
/// so the role identity renders identically on every Android version —
/// compound emoji such as 👩‍🏫 / 👨‍👩‍👧 degrade to "tofu" boxes or split into
/// separate glyphs on Android 10–12, which is exactly the range this app
/// supports (minSdk 29).
class RoleTheme {
  const RoleTheme({
    required this.role,
    required this.primary,
    required this.secondary,
  });

  final UserRole role;

  /// Start colour of the role gradient — also used as the accent / border
  /// colour for selected states.
  final Color primary;

  /// End colour of the role gradient.
  final Color secondary;

  /// Accent colour for borders, chips, and selected outlines.
  Color get accent => primary;

  /// Guaranteed-render Material glyph for this role (no emoji fallback risk).
  IconData get icon => role.icon;

  /// Two-stop gradient colours for cards / headers.
  List<Color> get gradientColors => [primary, secondary];

  /// Diagonal gradient used by selected role cards and setup headers.
  LinearGradient get gradient => LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static RoleTheme of(UserRole role) => switch (role) {
        UserRole.student => const RoleTheme(
            role: UserRole.student,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
          ),
        UserRole.teacher => const RoleTheme(
            role: UserRole.teacher,
            primary: AppColors.secondary,
            secondary: _teal,
          ),
        UserRole.parent => const RoleTheme(
            role: UserRole.parent,
            primary: AppColors.accent,
            secondary: _coral,
          ),
        UserRole.child => const RoleTheme(
            role: UserRole.child,
            primary: _tealDeep,
            secondary: _teal,
          ),
        UserRole.player => const RoleTheme(
            role: UserRole.player,
            primary: _violet,
            secondary: _violetLight,
          ),
      };

  // ── Centralised role-identity hues (previously inline hex literals in
  // profile_selection_screen / role_setup_screen). Kept here so the role
  // palette lives in exactly one place. ──
  static const Color _teal = Color(0xFF4DB6AC);
  static const Color _tealDeep = Color(0xFF26A69A);
  static const Color _coral = Color(0xFFFF8A65);
  static const Color _violet = Color(0xFF7E57C2);
  static const Color _violetLight = Color(0xFF9575CD);
}
