import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Makes every standard control in [theme] readable — the last step of
/// building each theme the app has.
///
/// The palettes are soft on purpose, and soft is right for backgrounds and
/// tints. It is wrong for anything that carries words: white on the pastel
/// purple button was 2.4:1, a selected chip's white label on its pale tint
/// 1.1:1, the purple text of a text button on the cream page 2.3:1 — where
/// WCAG AA asks 4.5:1, and this app's learners include people with low
/// vision. So each theme keeps its own hue, and this derives from it:
///
///  * an **ink** — the theme's primary, deepened (light themes) or lightened
///    (dark themes) only as far as it takes to read at 4.5:1 on every page,
///    card and field colour the theme paints, and to carry a black or white
///    label at 4.5:1 itself. It becomes the scheme's `primary`, so buttons,
///    tabs, focused fields, the navigation bar — and the many screens that
///    colour words and icons with `HCColor.primary` — all read.
///  * a **tint** for whatever is selected (a chip, a segment, the navigation
///    indicator): the ink, faint, over the surface, with the theme's own
///    text colour on it — the soft look, and a label you can read.
///
/// A theme whose colours already pass is left as it was.
ThemeData accessibleTheme(ThemeData theme) {
  final cs = theme.colorScheme;
  final page = theme.scaffoldBackgroundColor;
  final surface = cs.surface;
  final card = theme.cardTheme.color ?? theme.cardColor;
  final field = theme.inputDecorationTheme.fillColor ?? surface;
  final navBar = theme.navigationBarTheme.backgroundColor ?? surface;
  final darkPage = luminance(page) < 0.2;
  final grounds = [
    for (final c in [page, surface, card, field, navBar])
      if (c.a > 0.99) c else Color.alphaBlend(c, page),
  ];

  final text =
      _opaque(theme.textTheme.bodyMedium?.color, page) ??
      (darkPage ? Colors.white : const Color(0xFF212121));
  final quietText = readableOn(
    grounds,
    preferred: _opaque(theme.textTheme.bodySmall?.color, page) ?? text,
  );

  final ink = readableAccent(cs.primary, grounds, darkPage: darkPage);
  final onInk = bestOn(ink);

  final tint = Color.alphaBlend(
    ink.withValues(alpha: darkPage ? 0.34 : 0.18),
    surface.a > 0.99 ? surface : page,
  );
  final onTint = readableOn([tint], preferred: text);

  final fabBackground =
      theme.floatingActionButtonTheme.backgroundColor ?? cs.primaryContainer;
  final fab = readableAccent(fabBackground, grounds, darkPage: darkPage);
  final onFab = bestOn(fab);

  final disabledFill = cs.onSurface.withValues(alpha: 0.12);
  final disabledText = cs.onSurface.withValues(alpha: 0.38);

  WidgetStateProperty<Color?> states(Color enabled, Color disabled) =>
      WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? disabled : enabled,
      );

  ButtonStyle filled(ButtonStyle? existing) =>
      (existing ?? const ButtonStyle()).copyWith(
        backgroundColor: states(ink, disabledFill),
        foregroundColor: states(onInk, disabledText),
        iconColor: states(onInk, disabledText),
      );

  ButtonStyle onPage(ButtonStyle? existing, {bool outlined = false}) {
    final base = (existing ?? const ButtonStyle()).copyWith(
      foregroundColor: states(ink, disabledText),
      iconColor: states(ink, disabledText),
    );
    if (!outlined) return base;
    final width =
        existing?.side?.resolve(const <WidgetState>{})?.width ?? 1.5;
    return base.copyWith(
      side: WidgetStateProperty.resolveWith(
        (s) => BorderSide(
          color: s.contains(WidgetState.disabled) ? disabledFill : ink,
          width: width,
        ),
      ),
    );
  }

  // Chips: the tint when selected, the theme's text on it; unselected
  // labels on the chip's own background.
  final chipTheme = theme.chipTheme;
  final chipGround = _opaque(chipTheme.backgroundColor, surface) ?? surface;
  final chipText = readableOn([chipGround], preferred: text);
  final chipLabel =
      (chipTheme.labelStyle ?? theme.textTheme.labelLarge ?? const TextStyle())
          .copyWith(
            color: WidgetStateColor.resolveWith(
              (s) => s.contains(WidgetState.disabled)
                  ? disabledText
                  : s.contains(WidgetState.selected)
                  ? onTint
                  : chipText,
            ),
          );

  final segmentStyle = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? tint : null,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? disabledText
          : s.contains(WidgetState.selected)
          ? onTint
          : text,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? disabledText
          : s.contains(WidgetState.selected)
          ? onTint
          : text,
    ),
  ).merge(theme.segmentedButtonTheme.style);

  final nav = theme.navigationBarTheme;
  final navSelectedLabel = nav.labelTextStyle?.resolve({WidgetState.selected});
  final navLabel = nav.labelTextStyle?.resolve(const <WidgetState>{});
  final navSelectedIcon = nav.iconTheme?.resolve({WidgetState.selected});
  final navIcon = nav.iconTheme?.resolve(const <WidgetState>{});
  final navText = readableOn(
    [navBar.a > 0.99 ? navBar : Color.alphaBlend(navBar, page)],
    preferred: _opaque(navLabel?.color, navBar) ?? quietText,
  );

  return theme.copyWith(
    colorScheme: cs.copyWith(
      primary: ink,
      onPrimary: onInk,
      secondaryContainer: tint,
      onSecondaryContainer: onTint,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: filled(theme.filledButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: filled(theme.elevatedButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: onPage(theme.outlinedButtonTheme.style, outlined: true),
    ),
    textButtonTheme: TextButtonThemeData(
      style: onPage(theme.textButtonTheme.style),
    ),
    floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
      backgroundColor: fab,
      foregroundColor: onFab,
    ),
    chipTheme: chipTheme.copyWith(
      selectedColor: tint,
      secondarySelectedColor: tint,
      checkmarkColor: onTint,
      labelStyle: chipLabel,
      secondaryLabelStyle: chipLabel,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: segmentStyle,
      selectedIcon: theme.segmentedButtonTheme.selectedIcon,
    ),
    tabBarTheme: theme.tabBarTheme.copyWith(
      labelColor: ink,
      unselectedLabelColor: quietText,
      indicatorColor: ink,
    ),
    navigationBarTheme: nav.copyWith(
      indicatorColor: tint,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? (navSelectedLabel ?? const TextStyle()).copyWith(color: ink)
            : (navLabel ?? const TextStyle()).copyWith(color: navText),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? (navSelectedIcon ?? const IconThemeData()).copyWith(color: ink)
            : (navIcon ?? const IconThemeData()).copyWith(color: navText),
      ),
    ),
  );
}

// ─── Colour arithmetic ───────────────────────────────

double luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// The WCAG contrast ratio of two opaque colours.
double contrastOf(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Black or white, whichever reads better on [c].
Color bestOn(Color c) => contrastOf(c, Colors.white) >= contrastOf(c, Colors.black)
    ? Colors.white
    : const Color(0xFF1A1A1A);

/// [preferred] when it reads at 4.5:1 (or [target]) on every one of
/// [grounds]; otherwise the nearest of it, darkened or lightened, that does.
Color readableOn(
  List<Color> grounds, {
  required Color preferred,
  double target = 4.6,
}) {
  // Asked from build methods on every frame, with a handful of distinct
  // inputs per theme: remember the answers.
  final key = Object.hashAll([
    'on',
    preferred.toARGB32(),
    target,
    for (final g in grounds) g.toARGB32(),
  ]);
  return _memo.putIfAbsent(key, () => _readableOn(grounds, preferred, target));
}

Color _readableOn(List<Color> grounds, Color preferred, double target) {
  bool ok(Color c) => grounds.every((g) => contrastOf(c, g) >= target);
  if (ok(preferred)) return preferred;
  final darkGround = grounds.map(luminance).reduce(math.max) < 0.2;
  return _shift(preferred, towardLight: darkGround, until: ok) ??
      (darkGround ? Colors.white : const Color(0xFF1A1A1A));
}

/// A fill that [label] reads on at 4.5:1: [fill] itself when it already
/// does, otherwise the same hue deepened (a light label) or lightened (a
/// dark one) until it does. For the coloured pills, badges and tiles that
/// carry white words — keeps their colour, fixes their contrast.
Color readableFill(
  Color fill, {
  Color label = Colors.white,
  double target = 4.6,
}) {
  final key = Object.hash('fill', fill.toARGB32(), label.toARGB32(), target);
  return _memo.putIfAbsent(key, () => _readableFill(fill, label, target));
}

Color _readableFill(Color fill, Color label, double target) {
  final solid = fill.a > 0.99 ? fill : Color.alphaBlend(fill, Colors.white);
  bool ok(Color c) => contrastOf(label, c) >= target;
  if (ok(solid)) return solid;
  final lightLabel = luminance(label) > 0.5;
  return _shift(solid, towardLight: !lightLabel, until: ok) ??
      (lightLabel ? const Color(0xFF1A1A1A) : Colors.white);
}

/// [accent], moved only as far as it must be to read at 4.5:1 on every one
/// of [grounds] and to carry a black or white label at 4.5:1 itself.
Color readableAccent(
  Color accent,
  List<Color> grounds, {
  required bool darkPage,
}) {
  bool ok(Color c) =>
      grounds.every((g) => contrastOf(c, g) >= 4.6) &&
      contrastOf(c, bestOn(c)) >= 4.6;
  final solid = accent.a > 0.99 ? accent : Color.alphaBlend(accent, grounds.first);
  if (ok(solid)) return solid;
  return _shift(solid, towardLight: darkPage, until: ok) ??
      (darkPage ? Colors.white : const Color(0xFF1A1A1A));
}

Color? _shift(
  Color c, {
  required bool towardLight,
  required bool Function(Color) until,
}) {
  final hsl = HSLColor.fromColor(c);
  var l = hsl.lightness;
  for (var i = 0; i < 100; i++) {
    l = towardLight ? l + 0.01 : l - 0.01;
    if (l < 0 || l > 1) return null;
    final next = hsl.withLightness(l).toColor();
    if (until(next)) return next;
  }
  return null;
}

/// Answers already worked out, bounded so a long session cannot grow it.
final Map<int, Color> _memo = _BoundedMemo();

class _BoundedMemo extends MapBase<int, Color> {
  final Map<int, Color> _inner = {};

  @override
  Color? operator [](Object? key) => _inner[key];

  @override
  void operator []=(int key, Color value) {
    if (_inner.length >= 2048) _inner.clear();
    _inner[key] = value;
  }

  @override
  void clear() => _inner.clear();

  @override
  Iterable<int> get keys => _inner.keys;

  @override
  Color? remove(Object? key) => _inner.remove(key);
}

Color? _opaque(Color? c, Color over) {
  if (c == null) return null;
  return c.a > 0.99 ? c : Color.alphaBlend(c, over);
}
