import 'package:flutter/material.dart';

/// Characters that survive `trim` but read as nothing.
final RegExp _invisible = RegExp('[​-‍⁠﻿]');

/// Something a voice can actually pronounce.
final RegExp _pronounceable = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// The name a learner should hear for a focused control — shared by the
/// Bluetooth game controller (which speaks every move) and Gaze Control's
/// spoken highlight (which speaks every scan step and head move).
///
/// Prefers an explicit [Semantics] label (what a screen reader would say),
/// then falls back to the first piece of visible text inside the control —
/// which for a Material button, list tile or dialog action is exactly its
/// caption. Found on the tablet the hard way: a Material control's subtree
/// runs fifteen elements or more before its caption, a label often sits on a
/// wrapper a dozen elements *above* the focused node, and scraping text too
/// far up reads the app-bar title out for every control on the screen.
abstract final class FocusedLabel {
  /// How far up to look for an explicit `Semantics` / `Tooltip` label.
  static const int labelAncestorHops = 14;

  /// How far up to look for *scraped* text — deliberately much shorter.
  static const int labelTextHops = 3;

  /// The name for the control whose element is [context], or null when it
  /// has none a voice could say.
  static String? of(BuildContext? context) {
    if (context is! Element) return null;

    // The focused widget itself is the best answer when it has one. Searched
    // deep: a Material control's subtree (InkWell → Semantics → Padding → Row →
    // Text …) routinely runs fifteen elements or more before reaching its
    // caption, and a shallow cap silently reported every button as unnamed.
    final own = within(context, maxDepth: 30);
    if (own != null) return own;

    // Walking up, two different kinds of evidence get two different budgets.
    //
    // An **explicit** `Semantics(label:)` is a deliberate statement about the
    // whole subtree, so it is trusted a long way up: a settings row wraps its
    // icon, title, subtitle *and* its Switch in one label, and the Switch that
    // takes focus sits a dozen elements below it.
    //
    // **Scraped text** is a guess, so it stays close: hop far enough and the
    // search escapes into the page scaffold and reads the app-bar title out
    // for every control on the screen.
    String? found;
    var hops = 0;
    context.visitAncestorElements((ancestor) {
      hops++;
      if (hops > labelAncestorHops) return false;
      final own = _ofWidget(ancestor.widget);
      if (own != null) {
        found = own;
        return false;
      }
      if (hops <= labelTextHops) {
        found = within(ancestor, maxDepth: 12);
        if (found != null) return false;
      }
      return true;
    });
    return found;
  }

  /// A label carried by the widget itself, if it declares one.
  static String? _ofWidget(Widget widget) {
    String? candidate;
    if (widget is Semantics) candidate = widget.properties.label;
    if (widget is Tooltip) candidate = widget.message;
    if (candidate == null) return null;
    final text = candidate.replaceAll(_invisible, '').trim();
    if (text.isEmpty || !_pronounceable.hasMatch(text)) return null;
    return text;
  }

  /// First readable name inside [root]'s subtree: an explicit [Semantics]
  /// label (what a screen reader would say) or the first visible [Text].
  /// Depth-bounded so a search that starts high in the tree cannot walk the
  /// entire page.
  static String? within(Element root, {required int maxDepth}) {
    String? found;

    void take(String? value) {
      if (found != null) return;
      if (value == null) return;
      // Zero-width characters survive `trim`, so a spacer `Text` reads as a
      // perfectly valid label and then announces absolutely nothing.
      final text = value.replaceAll(_invisible, '').trim();
      if (text.isEmpty) return;
      // Must contain something a voice can pronounce. Plenty of captions are
      // decorative — a flag emoji on a banner, a bare chevron — and speaking
      // one is indistinguishable from silence to the learner it matters to.
      if (!_pronounceable.hasMatch(text)) return;
      found = text;
    }

    void visit(Element element, int depth) {
      if (found != null || depth > maxDepth) return;
      final widget = element.widget;
      // In preference order: what a screen reader would say, then a tooltip,
      // then whatever is actually written on the control.
      if (widget is Semantics) take(widget.properties.label);
      if (widget is Tooltip) take(widget.message);
      if (widget is Text) take(widget.data ?? widget.textSpan?.toPlainText());
      // Text ultimately builds a RichText; screens that style a caption with
      // spans have no plain `Text` widget to find at all.
      if (widget is RichText) take(widget.text.toPlainText());
      if (widget is Icon) take(widget.semanticLabel);
      if (widget is Image) take(widget.semanticLabel);
      if (found != null) return;
      element.visitChildren((child) => visit(child, depth + 1));
    }

    root.visitChildren((child) => visit(child, 1));
    return found;
  }
}
