import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'progress_theme.dart';

/// The catalogue of selectable Progress dashboard skins.
///
/// `classic` reproduces the current look and is the default, so existing
/// users see no change until they pick another skin.
class ProgressThemes {
  ProgressThemes._();

  static const ProgressTheme classic = ProgressTheme(
    id: 'classic',
    displayName: 'Classic',
    emoji: '🎨',
    headerGradient: [AppColors.primary, AppColors.secondary],
    accent: AppColors.primary,
    cardTint: AppColors.surfaceVariant,
  );

  static const ProgressTheme ocean = ProgressTheme(
    id: 'ocean',
    displayName: 'Ocean',
    emoji: '🌊',
    headerGradient: [Color(0xFF4FC3F7), Color(0xFF0277BD)],
    accent: Color(0xFF0288D1),
    cardTint: Color(0xFFE1F5FE),
  );

  static const ProgressTheme sunset = ProgressTheme(
    id: 'sunset',
    displayName: 'Sunset',
    emoji: '🌅',
    headerGradient: [Color(0xFFFF8A65), Color(0xFFEC407A)],
    accent: Color(0xFFE64A19),
    cardTint: Color(0xFFFFF3E0),
  );

  static const ProgressTheme forest = ProgressTheme(
    id: 'forest',
    displayName: 'Forest',
    emoji: '🌳',
    headerGradient: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
    accent: Color(0xFF2E7D32),
    cardTint: Color(0xFFE8F5E9),
  );

  static const ProgressTheme candy = ProgressTheme(
    id: 'candy',
    displayName: 'Candy',
    emoji: '🍭',
    headerGradient: [Color(0xFFF8BBD0), Color(0xFFCE93D8)],
    accent: Color(0xFFAD1457),
    cardTint: Color(0xFFFCE4EC),
    darkHeaderText: true, // light gradient → dark text reads better
  );

  static const ProgressTheme night = ProgressTheme(
    id: 'night',
    displayName: 'Night',
    emoji: '🌙',
    headerGradient: [Color(0xFF5C6BC0), Color(0xFF303F9F)],
    accent: Color(0xFF7C4DFF),
    cardTint: Color(0xFFE8EAF6),
  );

  static const ProgressTheme lavender = ProgressTheme(
    id: 'lavender',
    displayName: 'Lavender',
    emoji: '🪻',
    headerGradient: [Color(0xFFB39DDB), Color(0xFF7E57C2)],
    accent: Color(0xFF673AB7),
    cardTint: Color(0xFFEDE7F6),
  );

  static const ProgressTheme mint = ProgressTheme(
    id: 'mint',
    displayName: 'Mint',
    emoji: '🌿',
    headerGradient: [Color(0xFF80CBC4), Color(0xFF00897B)],
    accent: Color(0xFF00796B),
    cardTint: Color(0xFFE0F2F1),
  );

  static const ProgressTheme bubblegum = ProgressTheme(
    id: 'bubblegum',
    displayName: 'Bubblegum',
    emoji: '🍬',
    headerGradient: [Color(0xFFFF9EC4), Color(0xFFFF5FA2)],
    accent: Color(0xFFD81B60),
    cardTint: Color(0xFFFCE4EC),
  );

  static const ProgressTheme galaxy = ProgressTheme(
    id: 'galaxy',
    displayName: 'Galaxy',
    emoji: '🪐',
    headerGradient: [Color(0xFF3A1C71), Color(0xFF5F2C82)],
    accent: Color(0xFF7C4DFF),
    cardTint: Color(0xFFEDE7F6),
  );

  static const ProgressTheme autumn = ProgressTheme(
    id: 'autumn',
    displayName: 'Autumn',
    emoji: '🍂',
    headerGradient: [Color(0xFFFF9966), Color(0xFFD2691E)],
    accent: Color(0xFFBF360C),
    cardTint: Color(0xFFFFF3E0),
  );

  static const ProgressTheme aqua = ProgressTheme(
    id: 'aqua',
    displayName: 'Aqua',
    emoji: '💧',
    headerGradient: [Color(0xFF6FE7FF), Color(0xFF00B8D4)],
    accent: Color(0xFF00838F),
    cardTint: Color(0xFFE0F7FA),
    darkHeaderText: true, // bright cyan → dark text reads better
  );

  static const ProgressTheme rainbow = ProgressTheme(
    id: 'rainbow',
    displayName: 'Rainbow',
    emoji: '🌈',
    headerGradient: [
      Color(0xFFFF6B6B),
      Color(0xFFFFD93D),
      Color(0xFF6BCB77),
      Color(0xFF4D96FF),
    ],
    accent: Color(0xFF7B2FF7),
    cardTint: Color(0xFFF3E5F5),
  );

  static const ProgressTheme cocoa = ProgressTheme(
    id: 'cocoa',
    displayName: 'Cocoa',
    emoji: '🍫',
    headerGradient: [Color(0xFFA1887F), Color(0xFF6D4C41)],
    accent: Color(0xFF5D4037),
    cardTint: Color(0xFFEFEBE9),
  );

  /// Default applied when a profile hasn't chosen a skin.
  static const ProgressTheme defaultTheme = classic;

  /// All themes in picker order.
  static const List<ProgressTheme> all = [
    classic,
    ocean,
    sunset,
    forest,
    candy,
    night,
    lavender,
    mint,
    bubblegum,
    galaxy,
    autumn,
    aqua,
    rainbow,
    cocoa,
  ];

  /// Resolve a stored id back to a theme, falling back to [defaultTheme].
  static ProgressTheme byId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => defaultTheme);
}
