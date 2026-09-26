import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Measures the contrast a learner actually sees: the colour a piece of text
/// is painted in, against what is painted under it.
///
/// Built the way Flutter paints. Every widget that paints a background —
/// `Ink`, `ColoredBox`, `DecoratedBox`, a non-transparent `Material`, the
/// `Scaffold` — is recorded in paint order with the area it covers; the
/// background of a piece of text is whatever was painted last under its
/// centre before it, with translucent layers composited over the first
/// opaque one. That catches a card drawn as a sibling behind the text in a
/// `Stack`, which walking the text's ancestors misses. A linear gradient is
/// sampled where the text sits; text over a photo, and text that is not
/// visible (faded out, off screen), is not judged.
///
/// WCAG 2.x: 4.5:1 for text, 3:1 for large text (at least 24 px, or 18.66 px
/// bold).

/// The WCAG contrast ratio of two opaque colours, 1..21.
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// [top] painted over the opaque [bottom].
Color blend(Color top, Color bottom) {
  final a = top.a;
  return Color.from(
    alpha: 1,
    red: top.r * a + bottom.r * (1 - a),
    green: top.g * a + bottom.g * (1 - a),
    blue: top.b * a + bottom.b * (1 - a),
  );
}

/// Whether text in [style] counts as large for WCAG.
bool isLargeText(TextStyle style, double textScale) {
  final size = (style.fontSize ?? 14) * textScale;
  final bold = (style.fontWeight?.value ?? 400) >= 700;
  return size >= 24 || (bold && size >= 18.66);
}

/// One measured piece of text.
class ContrastReading {
  final String text;

  /// Where the widget that drew the text was created in the app, when
  /// widget-creation tracking is on (it is under `flutter test`).
  final String? source;
  final Color foreground;
  final Color background;
  final bool large;

  const ContrastReading({
    required this.text,
    this.source,
    required this.foreground,
    required this.background,
    required this.large,
  });

  double get ratio =>
      contrastRatio(blend(foreground, background), background);

  double get required => large ? 3.0 : 4.5;

  bool get passes => ratio >= required - 0.005;

  @override
  String toString() =>
      '"$text" ${ratio.toStringAsFixed(2)}:1 (needs ${required.toStringAsFixed(1)}) '
      'fg ${_hex(foreground)} on ${_hex(background)}'
      '${source == null ? '' : '  @ $source'}';
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

/// Something that paints a background: where, and how.
class _Painter {
  final int order;
  final Rect rect;
  final Color Function(Offset at)? colorAt;

  /// A photo or other image: nothing can be said about text over it.
  final bool opaqueUnknown;

  const _Painter(this.order, this.rect, this.colorAt, {this.opaqueUnknown = false});
}

/// The colour [d] paints at [at] inside [rect], or null when it paints none.
Color Function(Offset)? _decorationPaint(Decoration? d, Rect rect) {
  Gradient? gradient;
  Color? color;
  if (d is BoxDecoration) {
    gradient = d.gradient;
    color = d.color;
  } else if (d is ShapeDecoration) {
    gradient = d.gradient;
    color = d.color;
  } else {
    return null;
  }
  if (gradient != null) {
    final g = gradient;
    return (at) => _sampleGradient(g, rect, at);
  }
  if (color != null) {
    final c = color;
    return (_) => c;
  }
  return null;
}

Color _sampleGradient(Gradient g, Rect rect, Offset at) {
  if (g is LinearGradient) {
    final begin = g.begin.resolve(TextDirection.ltr).withinRect(rect);
    final end = g.end.resolve(TextDirection.ltr).withinRect(rect);
    final d = end - begin;
    final len2 = d.dx * d.dx + d.dy * d.dy;
    var t = len2 == 0
        ? 0.0
        : ((at.dx - begin.dx) * d.dx + (at.dy - begin.dy) * d.dy) / len2;
    t = t.clamp(0.0, 1.0);
    final stops = g.stops ??
        List<double>.generate(
          g.colors.length,
          (i) => g.colors.length == 1 ? 0 : i / (g.colors.length - 1),
        );
    for (var i = 0; i < stops.length - 1; i++) {
      if (t <= stops[i + 1]) {
        final span = stops[i + 1] - stops[i];
        final f = span == 0 ? 0.0 : (t - stops[i]) / span;
        return Color.lerp(g.colors[i], g.colors[i + 1], f)!;
      }
    }
    return g.colors.last;
  }
  // Radial and sweep: the middle stop is a fair stand-in for "under the text".
  return g.colors[g.colors.length ~/ 2];
}

List<_Painter> _collectPainters(Iterable<Element> elements) {
  final painters = <_Painter>[];
  var order = 0;
  for (final e in elements) {
    order++;
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.hasSize || !ro.attached) continue;
    final w = e.widget;
    Rect rect() => ro.localToGlobal(Offset.zero) & ro.size;
    Color Function(Offset)? paint;
    var image = false;
    if (w is Ink) {
      paint = _decorationPaint(w.decoration, rect());
      final d = w.decoration;
      image = d is BoxDecoration && d.image != null;
    } else if (w is ColoredBox) {
      final c = w.color;
      paint = (_) => c;
    } else if (w is DecoratedBox &&
        w.position == DecorationPosition.background) {
      paint = _decorationPaint(w.decoration, rect());
      final d = w.decoration;
      image = d is BoxDecoration && d.image != null;
    } else if (w is Material && w.type != MaterialType.transparency) {
      final theme = Theme.of(e);
      final c = w.color ??
          switch (w.type) {
            MaterialType.canvas => theme.canvasColor,
            MaterialType.card => theme.cardColor,
            _ => null,
          };
      if (c != null) paint = (_) => c;
    } else if (w is Scaffold) {
      final c = w.backgroundColor ?? Theme.of(e).scaffoldBackgroundColor;
      paint = (_) => c;
    } else if (w is Image || w is RawImage) {
      image = true;
    }
    if (paint == null && !image) continue;
    painters.add(_Painter(order, rect(), paint, opaqueUnknown: image));
  }
  return painters;
}

bool _hidden(Element e) {
  var hidden = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    // A disabled control is exempt from the contrast rule (WCAG 1.4.3) and is
    // meant to look faint.
    if ((w is ButtonStyleButton && !w.enabled) ||
        (w is RawChip && !(w.isEnabled)) ||
        (w is Semantics && w.properties.enabled == false) ||
        // Painted through a gradient mask: its colour is not what shows.
        w is ShaderMask ||
        (w is Opacity && w.opacity < 0.05) ||
        (w is FadeTransition && w.opacity.value < 0.05) ||
        (w is Offstage && w.offstage) ||
        (w is Visibility && !w.visible)) {
      hidden = true;
      return false;
    }
    return true;
  });
  return hidden;
}

/// Every visible piece of text on screen, read. Text over a photo is left
/// out: there is no single colour behind it to judge.
List<ContrastReading> readAllText(WidgetTester tester) {
  final all = collectAllElementsFrom(
    tester.binding.rootElement!,
    skipOffstage: true,
  ).toList();
  final painters = _collectPainters(all);
  final screen = Offset.zero &
      (tester.view.physicalSize / tester.view.devicePixelRatio);
  final scale = tester.view.platformDispatcher.textScaleFactor;
  final out = <ContrastReading>[];
  var order = 0;
  for (final e in all) {
    order++;
    final w = e.widget;
    if (w is! RichText) continue;
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.hasSize || ro.size.isEmpty || !ro.attached) {
      continue;
    }
    final style = w.text.style;
    final color = style?.color;
    if (style == null || color == null || color.a < 0.05) continue;
    if (style.foreground != null) continue;
    final text = w.text.toPlainText().trim();
    if (text.isEmpty || !RegExp(r'[A-Za-z0-9]').hasMatch(text)) continue;
    // An emoji keycap ("2️⃣") draws its own colours.
    if (RegExp('^[0-9#*]️?⃣\$').hasMatch(text)) continue;
    final rect = ro.localToGlobal(Offset.zero) & ro.size;
    if (!screen.overlaps(rect) || _hidden(e)) continue;
    final at = rect.center;

    final layers = <Color>[];
    var unknown = false;
    for (final p in painters.reversed) {
      if (p.order >= order || !p.rect.contains(at)) continue;
      if (p.opaqueUnknown) {
        unknown = true;
        break;
      }
      final c = p.colorAt!(at);
      if (c.a < 0.001) continue;
      layers.add(c);
      if (c.a >= 0.999) break;
    }
    if (unknown) continue;
    // Nothing opaque recorded under it: the page itself — a custom-painted
    // background (the app's animated gradients) is the theme's page colour
    // in spirit, and white would misjudge every dark theme.
    var bg = layers.isNotEmpty && layers.last.a >= 0.999
        ? layers.removeLast()
        : Theme.of(e).scaffoldBackgroundColor;
    for (final c in layers.reversed) {
      bg = blend(c, bg);
    }
    final reading = ContrastReading(
      text: text,
      foreground: color,
      background: bg,
      large: isLargeText(style, scale),
    );
    // Only a failure needs its source found — the lookup is not cheap.
    out.add(
      reading.passes
          ? reading
          : ContrastReading(
              text: text,
              source: appSourceOf(e),
              foreground: color,
              background: bg,
              large: reading.large,
            ),
    );
  }
  return out;
}

/// The reading for the text [label], which must be on screen.
ContrastReading readLabel(WidgetTester tester, String label) =>
    readAllText(tester).firstWhere((r) => r.text == label);

/// The file and line in the app (lib/) where the nearest widget above
/// [element] was created — the `Text` a report should point at.
String? appSourceOf(Element element) {
  final service = WidgetInspectorService.instance;
  if (!service.isWidgetCreationTracked()) return null;
  String? found;
  void check(Element e) {
    if (found != null) return;
    final json = e.toDiagnosticsNode().toJsonMap(
      InspectorSerializationDelegate(service: service),
    );
    final loc = json['creationLocation'];
    if (loc is Map) {
      final file = loc['file']?.toString() ?? '';
      final i = file.indexOf('/lib/');
      if (i != -1 && !file.contains('/flutter/packages/')) {
        found = '${file.substring(i + 1)}:${loc['line']}';
      }
    }
  }
  check(element);
  element.visitAncestorElements((a) {
    check(a);
    return found == null;
  });
  return found;
}
