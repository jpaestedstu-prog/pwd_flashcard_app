import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'spoken_words.dart';

/// [inner], with the pictures taken out of the words a browser's screen
/// reader is given — as [SpokenWordsUpdateBuilder] does on the phone.
ui.SemanticsUpdateBuilder spokenWordsBuilder(ui.SemanticsUpdateBuilder inner) =>
    WebSpokenWordsUpdateBuilder(inner);

/// The browser's twin of the phone's builder (`spoken_words_native.dart`).
///
/// The web's `updateNode` takes a nullable tooltip and link, an optional
/// text direction and a nullable traversal parent. Declared exactly so, it
/// overrides the phone's signature as well (each type is as wide or wider),
/// so the analyzer, which reads the phone's `dart:ui`, accepts it; the call
/// onwards is dynamic for the same reason — on the phone's types it would
/// not check, and in a browser it is the web's own method. Only a browser
/// build ever runs this file (the import in `spoken_words.dart`).
@visibleForTesting
class WebSpokenWordsUpdateBuilder implements ui.SemanticsUpdateBuilder {
  WebSpokenWordsUpdateBuilder(this._inner);

  final ui.SemanticsUpdateBuilder _inner;

  /// [text] without its pictures — unless it carries attributes (a locale, a
  /// spelled-out span), whose character ranges must not move.
  static String _spoken(String text, List<ui.StringAttribute> attributes) =>
      attributes.isEmpty ? SpokenWords.withoutPictures(text) : text;

  /// As [_spoken], for a stop's label: a picture with nothing to press says
  /// nothing ([SpokenWords.forStop]).
  static String _stopLabel(
    String text,
    List<ui.StringAttribute> attributes,
    int actions,
  ) =>
      attributes.isEmpty ? SpokenWords.forStop(text, actions) : text;

  @override
  void updateNode({
    required int id,
    required ui.SemanticsFlags flags,
    required int actions,
    required int maxValueLength,
    required int currentValueLength,
    required int textSelectionBase,
    required int textSelectionExtent,
    required int platformViewId,
    required int scrollChildren,
    required int scrollIndex,
    required int? traversalParent,
    required double scrollPosition,
    required double scrollExtentMax,
    required double scrollExtentMin,
    required ui.Rect rect,
    required String identifier,
    required String label,
    required List<ui.StringAttribute> labelAttributes,
    required String value,
    required List<ui.StringAttribute> valueAttributes,
    required String increasedValue,
    required List<ui.StringAttribute> increasedValueAttributes,
    required String decreasedValue,
    required List<ui.StringAttribute> decreasedValueAttributes,
    required String hint,
    required List<ui.StringAttribute> hintAttributes,
    String? tooltip,
    ui.TextDirection? textDirection,
    required Float64List transform,
    required Float64List hitTestTransform,
    required Int32List childrenInTraversalOrder,
    required Int32List childrenInHitTestOrder,
    required Int32List additionalActions,
    int headingLevel = 0,
    String? linkUrl,
    ui.SemanticsRole role = ui.SemanticsRole.none,
    required List<String>? controlsNodes,
    ui.SemanticsValidationResult validationResult =
        ui.SemanticsValidationResult.none,
    ui.SemanticsHitTestBehavior hitTestBehavior =
        ui.SemanticsHitTestBehavior.defer,
    required ui.SemanticsInputType inputType,
    required ui.Locale? locale,
    required String minValue,
    required String maxValue,
  }) {
    final spoken = _stopLabel(label, labelAttributes, actions);
    (_inner as dynamic).updateNode(
      id: id,
      flags: flags,
      actions: actions,
      maxValueLength: maxValueLength,
      currentValueLength: currentValueLength,
      textSelectionBase: textSelectionBase,
      textSelectionExtent: textSelectionExtent,
      platformViewId: platformViewId,
      scrollChildren: scrollChildren,
      scrollIndex: scrollIndex,
      traversalParent: traversalParent,
      scrollPosition: scrollPosition,
      scrollExtentMax: scrollExtentMax,
      scrollExtentMin: scrollExtentMin,
      rect: rect,
      identifier: identifier,
      label: spoken,
      labelAttributes: labelAttributes,
      value: value,
      valueAttributes: valueAttributes,
      increasedValue: increasedValue,
      increasedValueAttributes: increasedValueAttributes,
      decreasedValue: decreasedValue,
      decreasedValueAttributes: decreasedValueAttributes,
      hint: _spoken(hint, hintAttributes),
      hintAttributes: hintAttributes,
      tooltip: tooltip == null ? null : SpokenWords.withoutPictures(tooltip),
      textDirection: textDirection,
      transform: transform,
      hitTestTransform: hitTestTransform,
      childrenInTraversalOrder: childrenInTraversalOrder,
      childrenInHitTestOrder: childrenInHitTestOrder,
      additionalActions: additionalActions,
      headingLevel: headingLevel,
      linkUrl: linkUrl,
      role: role,
      controlsNodes: controlsNodes,
      validationResult: validationResult,
      hitTestBehavior: hitTestBehavior,
      inputType: inputType,
      // A vocabulary word in English on a Filipino screen.
      locale: SpokenWords.localeFor(spoken, locale),
      minValue: minValue,
      maxValue: maxValue,
    );
  }

  @override
  void updateCustomAction({
    required int id,
    String? label,
    String? hint,
    int overrideId = -1,
  }) {
    _inner.updateCustomAction(
      id: id,
      label: label == null ? null : SpokenWords.withoutPictures(label),
      hint: hint == null ? null : SpokenWords.withoutPictures(hint),
      overrideId: overrideId,
    );
  }

  @override
  ui.SemanticsUpdate build() => _inner.build();
}
