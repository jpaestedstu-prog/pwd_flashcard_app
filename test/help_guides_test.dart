import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/help/models/guides.dart';

/// The in-app guides (lib/features/help/models/guides.dart) must be complete
/// in both languages and must only point at screens and switches that exist:
/// every name below is looked for both in a guide and in the app's own
/// English text (app_en.arb), so renaming a screen without updating its guide
/// fails here.
void main() {
  final arbValues = (jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>)
      .entries
      .where((e) => !e.key.startsWith('@') && e.value is String)
      .map((e) => e.value as String)
      .toList();

  String allText({required bool filipino}) => [
        for (final g in allGuides) g.spokenText(filipino: filipino),
      ].join('\n');

  test('every guide is complete in English and Filipino', () {
    for (final g in allGuides) {
      expect(g.title.en.trim(), isNotEmpty, reason: g.id);
      expect(g.title.fil.trim(), isNotEmpty, reason: g.id);
      expect(g.summary.en.trim(), isNotEmpty, reason: g.id);
      expect(g.summary.fil.trim(), isNotEmpty, reason: g.id);
      expect(g.sections, isNotEmpty, reason: g.id);
      for (final s in g.sections) {
        expect(s.heading.en.trim().isNotEmpty && s.heading.fil.trim().isNotEmpty, isTrue,
            reason: '${g.id}: a heading');
        expect(s.lines, isNotEmpty, reason: '${g.id}: ${s.heading.en}');
        for (final line in s.lines) {
          expect(line.text.en.trim(), isNotEmpty, reason: '${g.id}: ${s.heading.en}');
          expect(line.text.fil.trim(), isNotEmpty, reason: '${g.id}: ${line.text.en}');
        }
      }
    }
  });

  test('guide ids are unique and each opens by id', () {
    final ids = [for (final g in allGuides) g.id];
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(guideById(id)?.id, id);
    }
    expect(guideById('no-such-guide'), isNull);
  });

  test('the guides asked for are all there', () {
    final ids = {for (final g in allGuides) g.id};
    expect(ids, containsAll(<String>[
      'students', 'teachers', 'parents', 'accessibility', 'gaze', 'voice',
      'controller', 'screenReader', 'keyboard', 'timeBreaks', 'tvCast', 'feedback',
    ]));
  });

  test('a learner sees no teacher or parent guides; an educator sees theirs first', () {
    final learner = guidesFor(educator: false);
    expect(learner.any((g) => g.audience == GuideAudience.educators), isFalse);
    expect(learner.first.id, 'students');
    final educator = guidesFor(educator: true);
    expect(educator.length, allGuides.length);
    final firstOther = educator.indexWhere((g) => g.audience != GuideAudience.educators);
    expect(educator.take(firstOther).every((g) => g.audience == GuideAudience.educators), isTrue);
    expect(educator.skip(firstOther).any((g) => g.audience == GuideAudience.educators), isFalse);
  });

  test('read aloud numbers the steps and keeps every line', () {
    final g = guideById('controller')!;
    final en = g.spokenText(filipino: false);
    expect(en, contains('Step 1. Pair the controller'));
    expect(en, contains('Step 3. Press “Practise the buttons”'));
    final fil = g.spokenText(filipino: true);
    expect(fil, contains('Hakbang 1.'));
    for (final s in g.sections) {
      for (final line in s.lines) {
        expect(en, contains(line.text.en.replaceAll(RegExp(r'[.!?]$'), '')));
      }
    }
  });

  // Names the guides send people to: each must be on a real screen.
  const realNames = <String>[
    'Gaze Control (Preview)', 'Enable Gaze Control', 'Try it now', 'Set resting position',
    'Look and hold to choose', 'How to choose', 'A switch or controller button', 'Scanning mode',
    'Sensitivity', 'Hold time', 'Smoothing', 'Read the highlight aloud', 'Voice commands',
    'Voice only (camera off)', 'Game Controller', 'Enable controller', 'Practise the buttons',
    'Say what is happening', 'Vibrate on each press', 'Ignore repeat presses within', 'Swap A and B',
    'Font Size', 'High Contrast Mode', 'Dark Mode', 'Dyslexia-friendly', 'Reduced Motion',
    'Voice-Guided Navigation', 'Text-to-Speech', 'Speech Speed', 'Adaptive Difficulty', 'Fullscreen',
    'Slow-Motion Mode', 'I Need a Break', 'Join a Class', 'Manage Classes', 'Manage Groups',
    'Accessibility needs', 'Time limits', 'Alarms', 'Routine', 'Unlock screen', 'View progress',
    'Assign Tasks', 'Track Progress', 'Class Report', 'Live session', 'TV Cast', 'Stop casting',
    'Parental Controls', 'Parent Notes', 'Share Code', 'Invite students', 'Invite your child',
    'Daily time limit', 'Allowed schedule', 'Warn before the lock', 'Remind them to take a break',
    'Take a break', 'Keep learning', 'Rate & Feedback', 'Help & Guides',
  ];

  test('every screen name the guides use is a real one', () {
    for (final name in realNames) {
      expect(arbValues.any((v) => v.contains(name)), isTrue,
          reason: '"$name" is not on any screen (app_en.arb)');
    }
  });

  test('…and the guides really use them', () {
    final text = allText(filipino: false);
    for (final name in realNames.where((n) => n != 'Help & Guides')) {
      expect(text.contains(name), isTrue, reason: '"$name" is in no guide');
    }
  });

  test('the voice guide lists the new app-wide commands in both languages', () {
    final en = guideById('voice')!.spokenText(filipino: false);
    final fil = guideById('voice')!.spokenText(filipino: true);
    for (final phrase in ['read the screen', 'say again', 'what can I say', 'stop listening', 'resume']) {
      expect(en, contains('“$phrase”'));
    }
    for (final phrase in ['basahin ang screen', 'sabihin ulit', 'ano ang masasabi ko', 'huwag makinig', 'ituloy']) {
      expect(fil, contains('“$phrase”'));
    }
  });
}
