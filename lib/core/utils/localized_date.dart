import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// Dates as the reader writes them: "Sep 21, 2026" in English, "Set 21, 2026"
/// in Filipino.
///
/// Screens built their own `['Jan', 'Feb', …]` lists, so a Filipino screen
/// still said "Sep". The month names come from the locale data the app's
/// localizations delegate loads; without it (a widget test with no delegate)
/// this falls back to English rather than throwing.
class LocalizedDate {
  const LocalizedDate._();

  /// "Sep 21" / "Set 21".
  static String monthDay(DateTime date, AppLocalizations? l10n) =>
      _format(date, l10n, (locale) => DateFormat.MMMd(locale));

  /// "21 Sep" / "21 Set" — day first, where a list is told apart by date.
  static String dayMonth(DateTime date, AppLocalizations? l10n) =>
      _format(date, l10n, (locale) => DateFormat('d MMM', locale));

  /// "Sep 21, 2026" / "Set 21, 2026".
  static String monthDayYear(DateTime date, AppLocalizations? l10n) =>
      _format(date, l10n, (locale) => DateFormat.yMMMd(locale));

  /// "September 21, 2026" / "Setyembre 21, 2026".
  static String monthDayYearLong(DateTime date, AppLocalizations? l10n) =>
      _format(date, l10n, (locale) => DateFormat.yMMMMd(locale));

  /// "September 2026" / "Setyembre 2026" — a calendar's heading.
  static String monthYear(DateTime date, AppLocalizations? l10n) =>
      _format(date, l10n, (locale) => DateFormat.yMMMM(locale));

  /// One-letter weekday headings, Monday first: "M T W T F S S" in English.
  static List<String> weekdayInitials(AppLocalizations? l10n) => [
    // 1 January 2024 was a Monday.
    for (var i = 0; i < 7; i++)
      _format(DateTime(2024, 1, 1 + i), l10n, (l) => DateFormat('EEEEE', l)),
  ];

  /// Short weekday name for an ISO weekday (1 = Monday): "Mon" / "Lun".
  static String weekdayShort(int isoDay, AppLocalizations? l10n) =>
      _format(DateTime(2024, 1, isoDay), l10n, (l) => DateFormat.E(l));

  static String _format(
    DateTime date,
    AppLocalizations? l10n,
    DateFormat Function(String? locale) pattern,
  ) {
    try {
      return pattern(l10n?.localeName).format(date);
    } catch (_) {
      // No date data loaded for that locale — a PDF built outside the widget
      // tree, or a plain unit test. intl's own default (en_US) ships built in.
      return pattern(null).format(date);
    }
  }
}
