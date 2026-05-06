import 'dart:ui';

/// Normalized waypoints for uppercase letters (0.0–1.0 coordinate system).
///
/// Each letter is defined as a list of strokes, where each stroke is a list
/// of waypoints. The path is scaled at runtime to match the canvas size.
class LetterPaths {
  LetterPaths._();

  /// Returns the strokes for a given character (uppercase or lowercase).
  /// Each stroke is a list of [Offset] waypoints normalized to 0.0–1.0.
  /// Returns empty list if the character is not mapped (e.g. spaces).
  static List<List<Offset>> forChar(String char) {
    final upper = char.toUpperCase();
    return _uppercase[upper] ?? [];
  }

  /// Returns all strokes for a full word, positioned side by side.
  /// Each character occupies a normalized width based on the word length.
  static List<List<Offset>> forWord(String word) {
    final chars = word.toUpperCase().split('');
    final result = <List<Offset>>[];
    final charWidth = 1.0 / chars.length;

    for (var i = 0; i < chars.length; i++) {
      final charStrokes = forChar(chars[i]);
      final offsetX = i * charWidth;

      for (final stroke in charStrokes) {
        result.add(stroke
            .map((p) => Offset(
                  offsetX + p.dx * charWidth * 0.85 + charWidth * 0.075,
                  p.dy * 0.85 + 0.075,
                ))
            .toList());
      }
    }
    return result;
  }

  /// Generates evenly-spaced guide dots along all strokes.
  /// [density] controls how many dots per stroke segment.
  static List<Offset> guideDots(List<List<Offset>> strokes,
      {int density = 8}) {
    final dots = <Offset>[];
    for (final stroke in strokes) {
      if (stroke.length < 2) {
        dots.addAll(stroke);
        continue;
      }
      for (var i = 0; i < stroke.length - 1; i++) {
        final a = stroke[i];
        final b = stroke[i + 1];
        for (var t = 0; t < density; t++) {
          final frac = t / density;
          dots.add(Offset(
            a.dx + (b.dx - a.dx) * frac,
            a.dy + (b.dy - a.dy) * frac,
          ));
        }
      }
      dots.add(stroke.last);
    }
    return dots;
  }

  // ─── Uppercase letter waypoints (normalized 0.0–1.0) ──────────

  static const Map<String, List<List<Offset>>> _uppercase = {
    'A': [
      // Left stroke
      [Offset(0.5, 0.0), Offset(0.0, 1.0)],
      // Right stroke
      [Offset(0.5, 0.0), Offset(1.0, 1.0)],
      // Crossbar
      [Offset(0.2, 0.55), Offset(0.8, 0.55)],
    ],
    'B': [
      // Vertical
      [Offset(0.1, 0.0), Offset(0.1, 1.0)],
      // Upper bump
      [Offset(0.1, 0.0), Offset(0.7, 0.0), Offset(0.85, 0.15), Offset(0.7, 0.45), Offset(0.1, 0.45)],
      // Lower bump
      [Offset(0.1, 0.45), Offset(0.75, 0.45), Offset(0.9, 0.65), Offset(0.75, 1.0), Offset(0.1, 1.0)],
    ],
    'C': [
      [Offset(0.9, 0.15), Offset(0.6, 0.0), Offset(0.25, 0.0), Offset(0.0, 0.25),
       Offset(0.0, 0.75), Offset(0.25, 1.0), Offset(0.6, 1.0), Offset(0.9, 0.85)],
    ],
    'D': [
      [Offset(0.1, 0.0), Offset(0.1, 1.0)],
      [Offset(0.1, 0.0), Offset(0.6, 0.0), Offset(0.9, 0.25), Offset(0.9, 0.75),
       Offset(0.6, 1.0), Offset(0.1, 1.0)],
    ],
    'E': [
      [Offset(0.85, 0.0), Offset(0.1, 0.0), Offset(0.1, 1.0), Offset(0.85, 1.0)],
      [Offset(0.1, 0.5), Offset(0.65, 0.5)],
    ],
    'F': [
      [Offset(0.85, 0.0), Offset(0.1, 0.0), Offset(0.1, 1.0)],
      [Offset(0.1, 0.5), Offset(0.65, 0.5)],
    ],
    'G': [
      [Offset(0.85, 0.15), Offset(0.6, 0.0), Offset(0.25, 0.0), Offset(0.0, 0.25),
       Offset(0.0, 0.75), Offset(0.25, 1.0), Offset(0.6, 1.0), Offset(0.85, 0.75),
       Offset(0.85, 0.5), Offset(0.5, 0.5)],
    ],
    'H': [
      [Offset(0.1, 0.0), Offset(0.1, 1.0)],
      [Offset(0.9, 0.0), Offset(0.9, 1.0)],
      [Offset(0.1, 0.5), Offset(0.9, 0.5)],
    ],
    'I': [
      [Offset(0.3, 0.0), Offset(0.7, 0.0)],
      [Offset(0.5, 0.0), Offset(0.5, 1.0)],
      [Offset(0.3, 1.0), Offset(0.7, 1.0)],
    ],
    'J': [
      [Offset(0.3, 0.0), Offset(0.7, 0.0)],
      [Offset(0.55, 0.0), Offset(0.55, 0.8), Offset(0.4, 1.0), Offset(0.15, 1.0)],
    ],
    'K': [
      [Offset(0.1, 0.0), Offset(0.1, 1.0)],
      [Offset(0.85, 0.0), Offset(0.1, 0.5)],
      [Offset(0.1, 0.5), Offset(0.85, 1.0)],
    ],
    'L': [
      [Offset(0.15, 0.0), Offset(0.15, 1.0), Offset(0.85, 1.0)],
    ],
    'M': [
      [Offset(0.0, 1.0), Offset(0.0, 0.0), Offset(0.5, 0.55), Offset(1.0, 0.0), Offset(1.0, 1.0)],
    ],
    'N': [
      [Offset(0.1, 1.0), Offset(0.1, 0.0), Offset(0.9, 1.0), Offset(0.9, 0.0)],
    ],
    'O': [
      [Offset(0.5, 0.0), Offset(0.15, 0.0), Offset(0.0, 0.25), Offset(0.0, 0.75),
       Offset(0.15, 1.0), Offset(0.85, 1.0), Offset(1.0, 0.75), Offset(1.0, 0.25),
       Offset(0.85, 0.0), Offset(0.5, 0.0)],
    ],
    'P': [
      [Offset(0.1, 1.0), Offset(0.1, 0.0)],
      [Offset(0.1, 0.0), Offset(0.7, 0.0), Offset(0.85, 0.15), Offset(0.85, 0.35),
       Offset(0.7, 0.5), Offset(0.1, 0.5)],
    ],
    'Q': [
      [Offset(0.5, 0.0), Offset(0.15, 0.0), Offset(0.0, 0.25), Offset(0.0, 0.75),
       Offset(0.15, 1.0), Offset(0.85, 1.0), Offset(1.0, 0.75), Offset(1.0, 0.25),
       Offset(0.85, 0.0), Offset(0.5, 0.0)],
      [Offset(0.65, 0.75), Offset(0.95, 1.0)],
    ],
    'R': [
      [Offset(0.1, 1.0), Offset(0.1, 0.0)],
      [Offset(0.1, 0.0), Offset(0.7, 0.0), Offset(0.85, 0.15), Offset(0.85, 0.35),
       Offset(0.7, 0.5), Offset(0.1, 0.5)],
      [Offset(0.5, 0.5), Offset(0.9, 1.0)],
    ],
    'S': [
      [Offset(0.85, 0.15), Offset(0.6, 0.0), Offset(0.3, 0.0), Offset(0.1, 0.15),
       Offset(0.1, 0.4), Offset(0.3, 0.5), Offset(0.7, 0.5), Offset(0.9, 0.6),
       Offset(0.9, 0.85), Offset(0.7, 1.0), Offset(0.4, 1.0), Offset(0.15, 0.85)],
    ],
    'T': [
      [Offset(0.0, 0.0), Offset(1.0, 0.0)],
      [Offset(0.5, 0.0), Offset(0.5, 1.0)],
    ],
    'U': [
      [Offset(0.1, 0.0), Offset(0.1, 0.75), Offset(0.25, 1.0), Offset(0.75, 1.0),
       Offset(0.9, 0.75), Offset(0.9, 0.0)],
    ],
    'V': [
      [Offset(0.0, 0.0), Offset(0.5, 1.0)],
      [Offset(0.5, 1.0), Offset(1.0, 0.0)],
    ],
    'W': [
      [Offset(0.0, 0.0), Offset(0.25, 1.0), Offset(0.5, 0.4), Offset(0.75, 1.0), Offset(1.0, 0.0)],
    ],
    'X': [
      [Offset(0.0, 0.0), Offset(1.0, 1.0)],
      [Offset(1.0, 0.0), Offset(0.0, 1.0)],
    ],
    'Y': [
      [Offset(0.0, 0.0), Offset(0.5, 0.5)],
      [Offset(1.0, 0.0), Offset(0.5, 0.5)],
      [Offset(0.5, 0.5), Offset(0.5, 1.0)],
    ],
    'Z': [
      [Offset(0.0, 0.0), Offset(1.0, 0.0), Offset(0.0, 1.0), Offset(1.0, 1.0)],
    ],

    // ─── Digits ─────────────────────────────────────────
    '0': [
      [Offset(0.5, 0.0), Offset(0.15, 0.0), Offset(0.0, 0.25), Offset(0.0, 0.75),
       Offset(0.15, 1.0), Offset(0.85, 1.0), Offset(1.0, 0.75), Offset(1.0, 0.25),
       Offset(0.85, 0.0), Offset(0.5, 0.0)],
    ],
    '1': [
      [Offset(0.3, 0.2), Offset(0.5, 0.0), Offset(0.5, 1.0)],
      [Offset(0.25, 1.0), Offset(0.75, 1.0)],
    ],
    '2': [
      [Offset(0.1, 0.2), Offset(0.3, 0.0), Offset(0.7, 0.0), Offset(0.9, 0.2),
       Offset(0.9, 0.4), Offset(0.1, 1.0), Offset(0.9, 1.0)],
    ],
    '3': [
      [Offset(0.1, 0.0), Offset(0.7, 0.0), Offset(0.9, 0.15), Offset(0.7, 0.45),
       Offset(0.4, 0.5)],
      [Offset(0.4, 0.5), Offset(0.7, 0.55), Offset(0.9, 0.75), Offset(0.7, 1.0),
       Offset(0.1, 1.0)],
    ],
    '4': [
      [Offset(0.6, 1.0), Offset(0.6, 0.0), Offset(0.1, 0.65), Offset(0.9, 0.65)],
    ],
    '5': [
      [Offset(0.8, 0.0), Offset(0.15, 0.0), Offset(0.1, 0.45), Offset(0.6, 0.4),
       Offset(0.85, 0.55), Offset(0.85, 0.8), Offset(0.6, 1.0), Offset(0.15, 1.0)],
    ],
    '6': [
      [Offset(0.8, 0.1), Offset(0.55, 0.0), Offset(0.2, 0.0), Offset(0.0, 0.3),
       Offset(0.0, 0.75), Offset(0.2, 1.0), Offset(0.7, 1.0), Offset(0.9, 0.8),
       Offset(0.9, 0.6), Offset(0.7, 0.45), Offset(0.0, 0.45)],
    ],
    '7': [
      [Offset(0.0, 0.0), Offset(0.9, 0.0), Offset(0.35, 1.0)],
    ],
    '8': [
      [Offset(0.5, 0.5), Offset(0.15, 0.4), Offset(0.1, 0.15), Offset(0.3, 0.0),
       Offset(0.7, 0.0), Offset(0.9, 0.15), Offset(0.85, 0.4), Offset(0.5, 0.5),
       Offset(0.1, 0.65), Offset(0.1, 0.85), Offset(0.3, 1.0), Offset(0.7, 1.0),
       Offset(0.9, 0.85), Offset(0.9, 0.65), Offset(0.5, 0.5)],
    ],
    '9': [
      [Offset(0.9, 0.55), Offset(0.7, 0.55), Offset(0.1, 0.55), Offset(0.1, 0.2),
       Offset(0.3, 0.0), Offset(0.7, 0.0), Offset(0.9, 0.2), Offset(0.9, 0.75),
       Offset(0.7, 1.0), Offset(0.3, 1.0), Offset(0.15, 0.9)],
    ],

    // ─── Special characters ──────────────────────────────
    '-': [
      [Offset(0.2, 0.5), Offset(0.8, 0.5)],
    ],
    ' ': [], // space – no strokes
  };
}
