import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/learner_support.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/models/post_test_readiness.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

/// The assessment module and the learner-support picker in Filipino.
///
/// The educator dashboards have been bilingual for a while; the instrument a
/// learner actually sits was English-only, and so was the block where a family
/// records which sign system they use. Those are the two surfaces where a
/// Filipino-speaking household is most likely to be reading.
///
/// Two halves here: the ARB files agree with each other, and the `...Of(l10n)`
/// getters actually reach them.
void main() {
  Map<String, dynamic> arb(String locale) {
    final file = File('lib/l10n/app_$locale.arb');
    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  late Map<String, dynamic> en;
  late Map<String, dynamic> fil;

  /// The keys that took every study screen bilingual: the research export
  /// (`rx`), generated question wording (`qp`), the test, its summary and
  /// the analytics (`test`, `sum`, `res`, `grade`), the Assessment Center
  /// (`hub`, `gain`, `banner`), assigning and tracking (`asg`, `title`,
  /// `trk`), class and home-group management (`gm`, `acp`), the sign clip
  /// and the back button; then the homes (`home`, `child`, `player`), the
  /// Cards, Stories and Progress tabs (`deck`, `viewer`, `catCard`, `prog`)
  /// and the level widgets (`level`). A capital must follow, so older keys
  /// that merely start the same way (`resetAllData`, `titles`) are not swept
  /// in.
  const studyScreensPattern =
      r'^(rx|qp|test|sum|res|grade|hub|gain|banner|asg|title|trk|gm|acp|clip|nav'
      r'|home|child|player|deck|viewer|catCard|prog|level)[A-Z0-9]';

  setUpAll(() {
    en = arb('en');
    fil = arb('fil');
  });

  /// Every key this feature added, by the prefixes it uses.
  Iterable<String> newKeys(Map<String, dynamic> source) => source.keys.where(
    (k) =>
        !k.startsWith('@') &&
        (k.startsWith('assess') ||
            // The in-app camera and the learner portfolio, which the
            // assessment module opens.
            k.startsWith('capture') ||
            k.startsWith('portfolio') ||
            k.startsWith('report') ||
            k.startsWith('support') ||
            k.startsWith('format') ||
            k == 'signQuestionPrompt' ||
            k == 'eduClassReport' ||
            RegExp(studyScreensPattern).hasMatch(k)),
  );

  group('the ARB files', () {
    test('every new English string has a Filipino one', () {
      final missing = newKeys(en).where((k) => !fil.containsKey(k)).toList();
      expect(
        missing,
        isEmpty,
        reason: 'untranslated keys fall back to English silently, which is '
            'how half an app ends up bilingual: $missing',
      );
    });

    test('no Filipino string is left as its English original', () {
      // Proper nouns are the honest exception: FSL, ASL and SEE are the names
      // of the systems, and "Profile" is already used as-is elsewhere.
      const properNouns = {
        'supportSignFsl',
        'supportSignAsl',
        'supportSignSee',
        'supportCuedSpeech',
        // Technical terms kept in the Filipino copy on purpose, as elsewhere
        // in the app ("Analytics", "Leaderboard"), and plain numbers.
        'gmAccessibility',
        'gmLeaderboard',
        'gmRoutine',
        'gm15min',
        'gm30min',
      };
      final untranslated = newKeys(en)
          .where((k) => !properNouns.contains(k))
          .where((k) => fil[k] == en[k])
          .toList();
      expect(untranslated, isEmpty);
    });

    test('placeholders survive translation', () {
      // A Filipino string that dropped {count} would throw at runtime rather
      // than merely read oddly.
      for (final key in newKeys(en)) {
        final english = en[key] as String;
        final filipino = fil[key] as String;
        // Not preceded by a word character or "=": `other{classes}` in a
        // select message is a branch, not a placeholder.
        final placeholders = RegExp(r'(?<![\w=])\{(\w+)\}')
            .allMatches(english)
            .map((m) => m.group(1))
            .toSet();
        for (final p in placeholders) {
          expect(
            filipino,
            contains('{$p}'),
            reason: '$key lost {$p} in translation',
          );
        }
      }
    });
  });

  group('the getters reach them', () {
    late AppLocalizations tl;

    setUpAll(() async {
      tl = await AppLocalizations.delegate.load(const Locale('fil'));
    });

    test('assessment types', () {
      expect(
        AssessmentType.preTest.labelOf(tl),
        isNot(AssessmentType.preTest.label),
      );
      for (final type in AssessmentType.values) {
        expect(type.labelOf(tl), isNotEmpty);
        expect(type.descriptionOf(tl), isNotEmpty);
      }
    });

    test('question formats, including the sign item', () {
      for (final format in QuestionFormat.values) {
        expect(format.labelOf(tl), isNotEmpty);
      }
      expect(
        QuestionFormat.signVideo.labelOf(tl),
        isNot(QuestionFormat.signVideo.label),
      );
    });

    test('every learner-support option', () {
      for (final option in LearnerSupportOption.values) {
        expect(option.labelOf(tl), isNotEmpty, reason: option.name);
        expect(option.descriptionOf(tl), isNotEmpty, reason: option.name);
      }
    });

    test('every support group, in every category', () {
      for (final type in DisabilityType.values) {
        for (final group in LearnerSupportCatalog.groupsFor(type)) {
          expect(group.titleOf(tl), isNotEmpty, reason: group.id);
          expect(group.descriptionOf(tl), isNotEmpty, reason: group.id);
          expect(
            group.titleOf(tl),
            isNot(group.title),
            reason: '${group.id} fell through to its English title',
          );
        }
      }
    });

    test('the post-test wait, including its plurals', () {
      final waiting = PostTestReadiness.evaluate(
        preTestAt: DateTime(2026, 9, 2),
        studyDates: const [],
        now: DateTime(2026, 9, 3),
      );
      expect(waiting.lockMessageOf(tl), isNotNull);
      expect(waiting.lockMessageOf(tl), isNot(waiting.lockMessage));
      expect(waiting.educatorSummaryOf(tl), isNot(waiting.educatorSummary));

      final oneDay = PostTestReadiness.evaluate(
        preTestAt: DateTime(2026, 9, 2),
        studyDates: [
          for (var d = 3; d < 7; d++) DateTime(2026, 9, d),
        ],
        now: DateTime(2026, 9, 8),
      );
      expect(oneDay.daysRemaining, 1);
      expect(oneDay.lockMessageOf(tl), isNotNull);
    });

    test('a null delegate falls back to English rather than crashing', () {
      // These strings sit inside semantics labels on screens that widget
      // tests build without the delegate. A `!` there would turn a missing
      // delegate into a crash instead of a word.
      expect(AssessmentType.preTest.labelOf(null), 'Pre-Test');
      expect(
        LearnerSupportOption.signFsl.labelOf(null),
        'Filipino Sign Language (FSL)',
      );
      expect(QuestionFormat.signVideo.labelOf(null), 'Watch the Sign');
      const none = PostTestReadiness(gate: PostTestGate.noPreTest);
      expect(none.lockMessageOf(null), 'Complete a Pre-Test first');
    });
  });
}
