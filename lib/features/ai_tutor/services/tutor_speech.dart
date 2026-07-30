/// Turns a tutor chat message into something worth listening to.
///
/// Bubble text is written for the eye: emoji carry tone ("🎉", "❌"), blank
/// lines separate the header from the question, and "Lesson 1/3" reads as a
/// fraction. Handed straight to a screen reader that becomes "party popper
/// Lesson one third … red question mark ornament" — noise in front of every
/// single prompt, and worst for exactly the learner who has nothing but the
/// audio.
///
/// This strips the decoration and leaves the sentence. Pure and locale-aware
/// so the whole thing is unit-testable.
class TutorSpeech {
  TutorSpeech._();

  /// Emoji, pictographs, dingbats, symbol arrows, variation selectors and the
  /// zero-width joiner. Deliberately broad: anything decorative should go, and
  /// nothing in these ranges carries meaning the sentence doesn't already say.
  static final RegExp _decoration = RegExp(
    r'[\u{1F000}-\u{1FAFF}'
    r'\u{2100}-\u{21FF}'
    r'\u{2300}-\u{23FF}'
    r'\u{2460}-\u{24FF}'
    r'\u{25A0}-\u{27BF}'
    r'\u{2B00}-\u{2BFF}'
    r'\u{FE00}-\u{FE0F}'
    r'\u{200D}\u{20E3}\u{00A9}\u{00AE}]',
    unicode: true,
  );

  /// "1/3" → "1 of 3", so a position reads as a position and not a fraction.
  static final RegExp _fraction = RegExp(r'(\d+)\s*/\s*(\d+)');

  /// Leftover punctuation stranded at the start of a line once its emoji is
  /// gone (e.g. "— paborito mo!").
  static final RegExp _leadingJunk = RegExp(r'^[\s\-—–:,.!?]+');

  /// Collapses any run of whitespace containing a newline into one break.
  static final RegExp _lineBreaks = RegExp(r'\s*\n+\s*');

  static final RegExp _spaces = RegExp(r'[ \t]{2,}');

  /// Doubled sentence punctuation created by joining lines ("Quiz!. What…").
  static final RegExp _doubledStops = RegExp(r'([.!?])\s*\.');

  /// The spoken form of [content].
  ///
  /// Returns an empty string when nothing speakable remains (a bubble that was
  /// only emoji), so callers can skip the utterance entirely rather than make
  /// the device click.
  static String forSpeech(String content, {bool isFilipino = false}) {
    var text = content.replaceAll(_decoration, ' ');

    // Position before the line join, so "Lesson 1/3" is still one unit.
    text = text.replaceAllMapped(
      _fraction,
      (m) => isFilipino ? '${m[1]} sa ${m[2]}' : '${m[1]} of ${m[2]}',
    );

    // Blank lines are visual paragraphing; spoken, they are a full stop.
    text = text.replaceAll(_lineBreaks, '. ');
    text = text.replaceAll(_doubledStops, r'$1');

    // Tidy each sentence's start now that the emoji are gone.
    text = text
        .split('. ')
        .map((part) => part.replaceFirst(_leadingJunk, ''))
        .where((part) => part.trim().isNotEmpty)
        .join('. ');

    text = text.replaceAll(_spaces, ' ').trim();
    // A trailing separator left by a stripped final emoji.
    text = text.replaceFirst(RegExp(r'[\s.]+$'), '');
    return text.isEmpty ? '' : '$text.';
  }
}
