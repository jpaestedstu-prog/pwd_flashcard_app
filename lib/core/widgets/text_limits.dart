import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';

/// How long what a person types may be, in one place for the whole app.
///
/// 62 of the app's 84 text boxes had no limit, and the ones that had disagreed
/// on the same thing: a name typed into the setup form could be any length,
/// but Edit Profile stopped at 30, and showed a longer one as "45/30" in red.
/// Whatever is typed here is shown elsewhere (a class list, a top bar, a
/// routine card), so these are also the lengths every layout is tested at.
///
/// A search box, a pasted code or address, and a note's body are the only
/// boxes without one (`text_limits_guard_test.dart` keeps the list).
abstract final class TextLimits {
  /// A person's name: a profile, a name in a class list, what a child calls
  /// a grown-up, someone to find.
  static const personName = 30;

  /// A player's name on a shared screen, beside another's.
  static const playerName = 20;

  /// A tag on a profile.
  static const tag = 20;

  /// A short name: a class, a routine, a step, an alarm, a card's word.
  static const label = 40;

  /// A title or a short answer: a note, a test, a choice in a question.
  static const title = 80;

  /// One sentence: a card's example, a hint, a step's note, a live question.
  static const sentence = 150;

  /// A few sentences: a question, a description, instructions.
  static const paragraph = 300;

  /// Something to say to someone.
  static const message = 500;

  static const email = 254;
  static const password = 128;

  /// Share of the limit at which the count appears. Before that it would only
  /// be one more thing on the form; a name is rarely near 30.
  static const _showFrom = 0.8;

  /// The count under a box, once it is close to the limit ("24/30", read as
  /// "24 of 30 letters"). For a box's `buildCounter`.
  static Widget? counter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    if (maxLength == null || currentLength < maxLength * _showFrom) return null;
    final t = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return Text(
      '$currentLength/$maxLength',
      semanticsLabel: t.fieldCountOf(currentLength, maxLength),
    );
  }
}
