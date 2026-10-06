import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// The font a generated PDF draws its text with.
///
/// Without a theme the pdf package falls back to its built-in Helvetica,
/// which covers Latin-1 only: the app's own curly apostrophe, dash and
/// bullet ("Ana’s Learning Portfolio", "Page 1 of 2  •  …") came out as
/// empty boxes. The bundled Noto Sans draws them, and every Filipino letter.
class PdfTheme {
  PdfTheme._();

  /// Noto Sans regular + bold, or null when the fonts cannot be loaded — the
  /// document then falls back to the built-in font instead of failing.
  ///
  /// No italic Noto Sans is bundled, so italic text uses the upright faces;
  /// left unset it would quietly fall back to Helvetica-Oblique, in another
  /// typeface and with the same empty boxes.
  static Future<pw.ThemeData?> unicode() async {
    try {
      final regular = pw.Font.ttf(
          await rootBundle.load('google_fonts/NotoSans-Regular.ttf'));
      final bold =
          pw.Font.ttf(await rootBundle.load('google_fonts/NotoSans-Bold.ttf'));
      return pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: regular,
        boldItalic: bold,
      );
    } catch (_) {
      return null;
    }
  }
}
