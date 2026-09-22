import '../../../data/models/enums.dart';
import '../../../l10n/app_localizations.dart';
import 'assessment_models.dart';

/// Shows a generated question in the reader's language.
///
/// Generated questions are stored in English — "What is the Filipino word for
/// “Dog”?" — and they have to stay that way: the stored text is part of a
/// learner's pre-test template, and the post-test, the Class Report and the
/// research export all line up against it. A Filipino-mode learner used to
/// read those English sentences in the middle of a Filipino screen.
///
/// So the wording is translated where it is *shown*, never where it is kept:
/// each generator's sentence is recognised and rebuilt from the ARB, with the
/// words inside it unchanged. Anything not recognised — a question a teacher
/// typed into a custom assessment — is shown exactly as written.
class QuestionPrompt {
  const QuestionPrompt._();

  static final _patterns =
      <(RegExp, String Function(AppLocalizations, List<String>))>[
        (
          RegExp(r'^What is the Filipino word for “(.+)”\?$'),
          (l, m) => l.qpFilipinoWordFor(m[0]),
        ),
        (
          RegExp(r'^What is the English word for “(.+)”\?$'),
          (l, m) => l.qpEnglishWordFor(m[0]),
        ),
        (
          RegExp(
            r'^Fill in the blank: The Filipino translation of “(.+)” is _____\.$',
          ),
          (l, m) => l.qpFillBlank(m[0]),
        ),
        (
          RegExp(r'^True or False: “(.+)” is “(.+)” in Filipino\.$'),
          (l, m) => l.qpTrueFalse(m[0], m[1]),
        ),
        (
          RegExp(r'^“(.+)” in Filipino is “(.+)”$'),
          (l, m) => l.qpInFilipinoIs(m[0], m[1]),
        ),
        (
          RegExp(r'^Match: “(.+)” → \?$'),
          (l, m) => l.qpMatch(m[0]),
        ),
        (
          RegExp(r'^Type the Filipino word for “(.+)”:$'),
          (l, m) => l.qpTypeFilipino(m[0]),
        ),
        (
          RegExp(r'^Type the English word for “(.+)”:$'),
          (l, m) => l.qpTypeEnglish(m[0]),
        ),
        (
          RegExp(r'^Watch the sign\. Which word is it\?$'),
          (l, m) => l.signQuestionPrompt,
        ),
        // The Class Report names a sign item's word after the prompt.
        (
          RegExp(r'^Watch the sign\. Which word is it\? \(“(.+)”\)$'),
          (l, m) => '${l.signQuestionPrompt} (“${m[0]}”)',
        ),
      ];

  /// [text] in the language of [l10n]; unchanged when nothing matches or
  /// there is no delegate.
  static String localize(String text, AppLocalizations? l10n) {
    if (l10n == null) return text;
    for (final (pattern, build) in _patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      return build(l10n, [
        for (var i = 1; i <= match.groupCount; i++) match.group(i)!,
      ]);
    }
    return text;
  }

  /// A generated test's stored title — "Pre-Test — All Categories", "Animals
  /// Mastery Test" — in the reader's language. A title an educator typed is
  /// shown as written.
  static String title(String stored, AppLocalizations? l10n) {
    if (l10n == null) return stored;
    final mastery = RegExp(r'^(.+) Mastery Test$').firstMatch(stored);
    if (mastery != null) {
      return l10n.titleMastery(categoryName(mastery.group(1)!, l10n));
    }
    final halves = RegExp(r'^(.+) — (.+)$').firstMatch(stored);
    if (halves != null) {
      for (final type in AssessmentType.values) {
        if (type.label != halves.group(1)) continue;
        final rest = halves.group(2)!;
        final scope = rest == 'All Categories'
            ? l10n.titleAllCategories
            : rest.split(', ').map((c) => categoryName(c, l10n)).join(', ');
        return '${type.labelOf(l10n)} — $scope';
      }
    }
    return stored;
  }

  /// A category stored by its English name (as `categoryScores` keys are),
  /// shown in the reader's language.
  static String categoryName(String stored, AppLocalizations? l10n) {
    if (l10n == null) return stored;
    for (final c in FlashcardCategory.values) {
      if (c.label == stored || c.name == stored) return c.labelOf(l10n);
    }
    return stored;
  }

  /// A stored answer as the learner reads it — "True" / "False" become
  /// "Tama" / "Mali"; every other answer is a word and stays as given.
  static String answer(String value, AppLocalizations? l10n) {
    if (l10n == null) return value;
    return switch (value) {
      'True' => l10n.qpTrue,
      'False' => l10n.qpFalse,
      _ => value,
    };
  }

  /// A choice as the learner reads it. Only a True/False item's two answers
  /// change — "Tama" / "Mali" — while the stored answer stays "True" /
  /// "False", which is what marking and every export compare against.
  static String choice(
    AssessmentQuestion question,
    String value,
    AppLocalizations? l10n,
  ) {
    if (l10n == null || question.format != QuestionFormat.trueFalse) {
      return value;
    }
    return switch (value) {
      'True' => l10n.qpTrue,
      'False' => l10n.qpFalse,
      _ => value,
    };
  }
}
