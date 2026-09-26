import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/accessible_theme.dart';
import 'package:pwdpwdpwd/core/theme/app_colors.dart';

/// The helpers every screen now uses to colour words: they must always reach
/// WCAG AA, keep the colour's own hue, and leave a colour that already reads
/// exactly as it was.
void main() {
  const cream = AppColors.background;
  const dark = Color(0xFF121218);
  const pastels = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    AppColors.success,
    AppColors.error,
    AppColors.warning,
    AppColors.info,
  ];

  double hue(Color c) => HSLColor.fromColor(c).hue;

  test('a pastel as words on cream is deepened to 4.5:1, same hue', () {
    for (final c in pastels) {
      final ink = readableOn([cream, Colors.white], preferred: c);
      expect(contrastOf(ink, cream), greaterThanOrEqualTo(4.5), reason: '$c');
      expect(contrastOf(ink, Colors.white), greaterThanOrEqualTo(4.5));
      expect((hue(ink) - hue(c)).abs(), lessThan(1.5), reason: 'hue of $c');
    }
  });

  test('on a dark page the same colour is lightened instead', () {
    const deep = AppColors.primaryDark;
    final ink = readableOn([dark], preferred: deep);
    expect(contrastOf(ink, dark), greaterThanOrEqualTo(4.5));
    expect(luminance(ink), greaterThan(luminance(deep)));
  });

  test('a colour that already reads is returned untouched', () {
    expect(readableOn([cream], preferred: AppColors.textPrimary),
        AppColors.textPrimary);
    expect(readableFill(const Color(0xFF1B5E20)), const Color(0xFF1B5E20));
  });

  test('a fill carrying white words is deepened to 4.5:1', () {
    for (final c in pastels) {
      final fill = readableFill(c);
      expect(contrastOf(Colors.white, fill), greaterThanOrEqualTo(4.5),
          reason: '$c');
    }
    // A dark label pushes the fill lighter instead.
    const label = Color(0xFF1A1A1A);
    final light = readableFill(const Color(0xFF455A64), label: label);
    expect(contrastOf(label, light), greaterThanOrEqualTo(4.5));
  });

  test('the same question gives the same answer (it is remembered)', () {
    final a = readableOn([cream], preferred: AppColors.info);
    final b = readableOn([cream], preferred: AppColors.info);
    expect(identical(a, b) || a == b, isTrue);
  });
}
