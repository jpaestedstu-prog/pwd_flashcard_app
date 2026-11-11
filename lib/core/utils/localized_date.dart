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

  /// The weekday in full: "Wednesday" / "Miyerkules" — a calendar day as a
  /// screen reader says it, where the column's letter cannot be heard.
  static String weekdayLong(DateTime date, AppLocalizations? l10n) =>
      _format(date, l10n, (l) => DateFormat.EEEE(l));

  /// Short weekday name for an ISO weekday (1 = Monday): "Mon" / "Lun".
  static String weekdayShort(int isoDay, AppLocalizations? l10n) =>
      _format(DateTime(2024, 1, isoDay), l10n, (l) => DateFormat.E(l));

  /// A month's short name, January = 1: "Sep" / "Set".
  static String monthShort(int month, AppLocalizations? l10n) =>
      _format(DateTime(2024, month), l10n, (l) => DateFormat.MMM(l));

  /// [monthDay], for code that knows the language but has no
  /// [AppLocalizations] at hand.
  static String monthDayIn(DateTime date, {required bool filipino}) =>
      _formatIn(date, filipino ? 'fil' : 'en', (l) => DateFormat.MMMd(l));

  static String _format(
    DateTime date,
    AppLocalizations? l10n,
    DateFormat Function(String? locale) pattern,
  ) =>
      _formatIn(date, l10n?.localeName, pattern);

  static String _formatIn(
    DateTime date,
    String? locale,
    DateFormat Function(String? locale) pattern,
  ) {
    try {
      return pattern(locale).format(date);
    } catch (_) {
      // No date data loaded for that locale — a PDF built outside the widget
      // tree, or a plain unit test. intl's own default (en_US) ships built in.
      return pattern(null).format(date);
    }
  }
}

/// Lengths of time in words, as a voice should say them.
///
/// Screens showed "4m 30s", "5m ago" and "3d left", which a speech engine
/// reads as "4 meters 30 s" (found reviewing what TalkBack is told, 29 Oct).
/// What is drawn can stay short; what is said comes from here.
class LocalizedDuration {
  const LocalizedDuration._();

  /// "1 hour 5 minutes", "4 minutes 30 seconds", "30 seconds" ("1 oras 5
  /// minuto"). Seconds are left out once there are hours.
  static String long(Duration d, AppLocalizations l10n) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return [
      if (h > 0) l10n.hoursCount(h),
      if (m > 0) l10n.minutesCount(m),
      if (h == 0 && (s > 0 || m == 0)) l10n.secondsCount(s),
    ].join(' ');
  }

  /// How long ago [elapsed] was: "just now", "5 minutes ago" ("5 minuto ang
  /// nakaraan"), up to "6 days ago" — null from a week on, when a date says
  /// it better.
  static String? ago(Duration elapsed, {required bool filipino}) {
    if (elapsed.inDays >= 7) return null;
    if (elapsed.inMinutes < 1) return filipino ? 'ngayon lang' : 'just now';
    final (n, en, fil) = elapsed.inHours < 1
        ? (elapsed.inMinutes, 'minute', 'minuto')
        : elapsed.inDays < 1
        ? (elapsed.inHours, 'hour', 'oras')
        : (elapsed.inDays, 'day', 'araw');
    return filipino
        ? '$n $fil ang nakaraan'
        : '$n $en${n == 1 ? '' : 's'} ago';
  }
}
