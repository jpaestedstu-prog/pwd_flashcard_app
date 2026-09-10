import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_catalog.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_templates.dart';

/// Pure model tests for the Routine feature — no Flutter, no Hive, so they
/// run in milliseconds and the rules can be read straight off the
/// expectations.

RoutineStep _step(
  String id, {
  RoutineActivity activity = RoutineActivity.custom,
  int? hour,
  int? minute,
  bool enabled = true,
  int duration = 0,
}) =>
    RoutineStep(
      id: id,
      activity: activity,
      hour: hour,
      minute: minute,
      enabled: enabled,
      durationMinutes: duration,
    );

Routine _routine({
  List<RoutineStep> steps = const [],
  Set<int> days = const {},
  bool enabled = true,
}) =>
    Routine(
      id: 'r1',
      childProfileId: 'child',
      setterProfileId: 'adult',
      setterRole: UserRole.parent,
      name: 'Morning',
      daysOfWeek: days,
      steps: steps,
      enabled: enabled,
      createdAt: DateTime(2026, 9),
      updatedAt: DateTime(2026, 9),
    );

void main() {
  group('RoutineStep', () {
    test('a step with only an hour is not scheduled', () {
      // Half a time is no time — an hour with no minute used to decode as
      // "on the hour" and sort as though the educator had set 07:00.
      final decoded = RoutineStep.fromJson({
        'id': 's',
        'activity': RoutineActivity.breakfast.index,
        'hour': 7,
      });
      expect(decoded.isScheduled, isFalse);
      expect(decoded.hour, isNull);
      expect(decoded.minutesOfDay, isNull);
    });

    test('clearTime removes both halves of the time', () {
      final s = _step('a', hour: 7, minute: 30).copyWith(clearTime: true);
      expect(s.isScheduled, isFalse);
      expect(s.minute, isNull);
    });

    test('media slots round-trip and report themselves', () {
      var s = _step('a');
      expect(s.suppliedMedia, isEmpty);
      for (final kind in RoutineMediaKind.values) {
        s = s.withMedia(kind, 'https://example.test/${kind.name}');
      }
      expect(s.suppliedMedia, RoutineMediaKind.values);
      expect(s.urlFor(RoutineMediaKind.gif),
          'https://example.test/gif');
      // Whitespace is not media.
      expect(_step('b').withMedia(RoutineMediaKind.photo, '   ')
          .hasMedia(RoutineMediaKind.photo), isFalse);
    });

    test('json survives a full round trip', () {
      const original = RoutineStep(
        id: 's1',
        activity: RoutineActivity.bathTime,
        title: 'Wash up',
        titleFilipino: 'Maligo',
        emoji: '🛁',
        hour: 17,
        minute: 45,
        durationMinutes: 12,
        note: 'Use the blue towel',
        photoUrl: 'assets/x.png',
        videoUrl: 'https://v',
        signWord: 'Water',
        enabled: false,
      );
      final decoded = RoutineStep.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.id, original.id);
      expect(decoded.activity, original.activity);
      expect(decoded.titleFilipino, 'Maligo');
      expect(decoded.hour, 17);
      expect(decoded.minute, 45);
      expect(decoded.durationMinutes, 12);
      expect(decoded.photoUrl, 'assets/x.png');
      expect(decoded.signWord, 'Water');
      expect(decoded.enabled, isFalse);
    });

    test('an unknown activity index degrades to custom, not a crash', () {
      // A routine written by a newer build and synced down to an older one.
      final decoded = RoutineStep.fromJson({'id': 's', 'activity': 9999});
      expect(decoded.activity, RoutineActivity.custom);
    });

    test('an out-of-range clock is dropped rather than clamped', () {
      final decoded =
          RoutineStep.fromJson({'id': 's', 'hour': 47, 'minute': 12});
      expect(decoded.isScheduled, isFalse);
    });
  });

  group('Routine.orderedSteps', () {
    test('scheduled steps sort by time, unscheduled sink below in order', () {
      final r = _routine(steps: [
        _step('late', hour: 18, minute: 0),
        _step('loose1'),
        _step('early', hour: 6, minute: 30),
        _step('loose2'),
        _step('mid', hour: 12, minute: 0),
      ]);
      expect(
        r.orderedSteps.map((s) => s.id),
        ['early', 'mid', 'late', 'loose1', 'loose2'],
      );
    });

    test('same-minute steps keep their authored order', () {
      final r = _routine(steps: [
        _step('first', hour: 7, minute: 0),
        _step('second', hour: 7, minute: 0),
      ]);
      expect(r.orderedSteps.map((s) => s.id), ['first', 'second']);
    });

    test('disabled steps are hidden from the learner but kept in the editor',
        () {
      final r = _routine(steps: [
        _step('on', hour: 7, minute: 0),
        _step('off', hour: 8, minute: 0, enabled: false),
      ]);
      expect(r.orderedSteps.map((s) => s.id), ['on']);
      expect(r.editorSteps.length, 2);
      expect(r.stepCount, 1);
    });
  });

  group('Routine.runsOn', () {
    test('an empty day set means every day', () {
      final r = _routine();
      for (var d = 0; d < 7; d++) {
        expect(r.runsOn(DateTime(2026, 9, 7).add(Duration(days: d))), isTrue);
      }
    });

    test('a day set restricts to those ISO weekdays', () {
      // 2026-09-07 is a Monday.
      final r = _routine(days: {1, 3, 5});
      expect(r.runsOn(DateTime(2026, 9, 7)), isTrue); // Mon
      expect(r.runsOn(DateTime(2026, 9, 8)), isFalse); // Tue
      expect(r.runsOn(DateTime(2026, 9, 9)), isTrue); // Wed
      expect(r.runsOn(DateTime(2026, 9, 12)), isFalse); // Sat
    });

    test('json round trip keeps days, steps and role', () {
      final r = _routine(
        days: {2, 4},
        steps: [_step('a', hour: 7, minute: 0)],
      ).copyWith(setterRole: UserRole.teacher);
      final decoded = Routine.fromJson(
        jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.daysOfWeek, {2, 4});
      expect(decoded.steps.single.id, 'a');
      expect(decoded.setterRole, UserRole.teacher);
      expect(decoded.childProfileId, 'child');
    });

    test('one malformed step does not cost the learner the routine', () {
      // Round-tripped through JSON first so the steps list is `List<dynamic>`
      // and can hold the junk row a corrupt document would really carry.
      final json = jsonDecode(
        jsonEncode(_routine(steps: [_step('good', hour: 7, minute: 0)]).toJson()),
      ) as Map<String, dynamic>;
      (json['steps'] as List).insert(0, 'not a map');
      (json['steps'] as List).insert(1, {'id': 'odd', 'hour': 'seven'});
      final decoded = Routine.fromJson(json);
      // The non-map row is dropped; the row with a nonsense clock survives as
      // an unscheduled step, because a step an educator can still see and fix
      // beats a step that silently vanished.
      expect(decoded.steps.map((s) => s.id), ['odd', 'good']);
      expect(decoded.steps.first.isScheduled, isFalse);
    });
  });

  group('RoutineDayLog', () {
    test('toggle adds then removes', () {
      var log = RoutineDayLog.empty('p', DateTime(2026, 9, 10));
      log = log.toggle('a');
      expect(log.isDone('a'), isTrue);
      log = log.toggle('a');
      expect(log.isDone('a'), isFalse);
    });

    test('progress counts only live steps', () {
      final r = _routine(steps: [
        _step('a', hour: 7, minute: 0),
        _step('b', hour: 8, minute: 0),
        _step('hidden', hour: 9, minute: 0, enabled: false),
      ]);
      var log = RoutineDayLog.empty('p', DateTime(2026, 9, 10));
      log = log.toggle('a');
      expect(log.doneCountFor(r), 1);
      expect(log.progressFor(r), closeTo(0.5, 0.001));
      log = log.toggle('b');
      expect(log.progressFor(r), 1.0);
    });

    test('an empty routine reads as 0 progress, never as complete', () {
      // A full ring for a plan with nothing in it would be a reward the child
      // did not earn.
      final log = RoutineDayLog.empty('p', DateTime(2026, 9, 10));
      expect(log.progressFor(_routine()), 0.0);
    });

    test('the day key is built from local calendar fields', () {
      final key = dayKeyFor('abc', DateTime(2026, 1, 5, 23, 59));
      expect(key, 'abc_2026-01-05');
      expect(dayStampOf(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('json round trip keeps the ticks and the day', () {
      final log = RoutineDayLog.empty('p', DateTime(2026, 9, 10))
          .toggle('x')
          .toggle('y');
      final decoded = RoutineDayLog.fromJson(
        jsonDecode(jsonEncode(log.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.completedStepIds, {'x', 'y'});
      expect(decoded.day, DateTime(2026, 9, 10));
      expect(decoded.profileId, 'p');
    });
  });

  group('RoutineCatalog', () {
    test('every activity has an entry with content', () {
      for (final a in RoutineActivity.values) {
        final info = RoutineCatalog.infoFor(a);
        expect(info.activity, a, reason: '$a resolved to the wrong entry');
        expect(info.emoji, isNotEmpty, reason: '$a');
        expect(info.label, isNotEmpty, reason: '$a');
        expect(info.labelFilipino, isNotEmpty, reason: '$a');
        expect(info.blurbFilipino, isNotEmpty, reason: '$a');
        // Audio is the primary channel for a learner with a visual
        // disability; it is never allowed to be empty.
        expect(info.audioCue, isNotEmpty, reason: '$a');
        expect(info.audioCueFilipino, isNotEmpty, reason: '$a');
        expect(info.defaultHour, inInclusiveRange(0, 23), reason: '$a');
        expect(info.defaultMinute, inInclusiveRange(0, 59), reason: '$a');
      }
    });

    test('the brief’s fourteen activities are all pickable', () {
      expect(RoutineCatalog.pickable.length, RoutineActivity.values.length - 1);
      expect(
        RoutineCatalog.pickable.any((i) => i.activity.isCustom),
        isFalse,
        reason: 'custom has its own affordance, not a catalog row',
      );
    });

    test('every built-in activity carries visual instructions', () {
      for (final info in RoutineCatalog.pickable) {
        expect(info.instructions, isNotEmpty,
            reason: '${info.activity} has no visual instructions');
        for (final step in info.instructions) {
          expect(step.emoji, isNotEmpty);
          expect(step.text, isNotEmpty);
          expect(step.textFilipino, isNotEmpty,
              reason: '${info.activity}: "${step.text}" is English-only');
        }
      }
    });

    test('every built-in activity carries at least one FSL cue', () {
      for (final info in RoutineCatalog.pickable) {
        expect(info.signCues, isNotEmpty,
            reason: '${info.activity} would show a Deaf learner no signs');
        for (final cue in info.signCues) {
          expect(cue.word, isNotEmpty);
          expect(cue.category, isNotNull,
              reason: 'built-in cues must disambiguate their category');
        }
      }
    });

    test('titleFor prefers the override, then the other language, then the '
        'catalog', () {
      final plain = _step('a', activity: RoutineActivity.lunch);
      expect(RoutineCatalog.titleFor(plain, filipino: false), 'Lunch');
      expect(RoutineCatalog.titleFor(plain, filipino: true), 'Tanghalian');

      final overridden = plain.copyWith(title: 'Big lunch');
      expect(RoutineCatalog.titleFor(overridden, filipino: false), 'Big lunch');
      // Only English supplied: a Filipino reader gets the English rather
      // than the generic catalog word, because the educator meant that.
      expect(RoutineCatalog.titleFor(overridden, filipino: true), 'Big lunch');

      // A custom step with no title at all still renders something.
      expect(
        RoutineCatalog.titleFor(_step('c'), filipino: false),
        'Custom Activity',
      );
    });

    test('emojiFor prefers the override', () {
      expect(
        RoutineCatalog.emojiFor(_step('a', activity: RoutineActivity.bedtime)),
        '🌙',
      );
      expect(
        RoutineCatalog.emojiFor(
          _step('a', activity: RoutineActivity.bedtime).copyWith(emoji: '🦉'),
        ),
        '🦉',
      );
    });

    test('audioCueFor prefers the educator’s note', () {
      final s = _step('a', activity: RoutineActivity.dinner);
      expect(
        RoutineCatalog.audioCueFor(s, filipino: false),
        RoutineCatalog.infoFor(RoutineActivity.dinner).audioCue,
      );
      expect(
        RoutineCatalog.audioCueFor(
          s.copyWith(note: 'Sit with Lola'),
          filipino: false,
        ),
        'Sit with Lola',
      );
    });

    test('a sign override replaces the catalog cues and drops the category',
        () {
      final s = _step('a', activity: RoutineActivity.lunch)
          .copyWith(signWord: 'Juice');
      final cues = RoutineCatalog.signCuesFor(s);
      expect(cues.single.word, 'Juice');
      expect(cues.single.category, isNull);
    });
  });

  group('RoutineTemplates', () {
    test('every template builds usable steps', () {
      for (final t in RoutineTemplates.all) {
        expect(t.activities, isNotEmpty, reason: t.id);
        expect(t.nameFilipino, isNotEmpty, reason: t.id);
        expect(t.descriptionFilipino, isNotEmpty, reason: t.id);
        final steps = t.buildSteps((i) => '${t.id}_$i');
        expect(steps.length, t.activities.length, reason: t.id);
        expect(
          steps.map((s) => s.id).toSet().length,
          steps.length,
          reason: '${t.id} produced duplicate step ids',
        );
        for (final s in steps) {
          expect(s.isScheduled, isTrue,
              reason: '${t.id}: template steps arrive with a time');
        }
      }
    });

    test('template ids are unique and resolvable', () {
      final ids = RoutineTemplates.all.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(RoutineTemplates.byId(id), isNotNull);
      }
      expect(RoutineTemplates.byId('nope'), isNull);
    });

    test('suggestions lead with the tailored ones and never come back empty',
        () {
      for (final type in DisabilityType.values) {
        final suggested = RoutineTemplates.suggestedFor(type);
        expect(suggested, isNotEmpty, reason: '$type');
        final tailoredCount =
            RoutineTemplates.all.where((t) => t.suitedTo.contains(type)).length;
        for (var i = 0; i < tailoredCount; i++) {
          expect(suggested[i].suitedTo.contains(type), isTrue,
              reason: '$type: tailored templates must come first');
        }
      }
    });

    test('the school-day template runs on weekdays only', () {
      final t = RoutineTemplates.byId('school_day')!;
      expect(t.daysOfWeek, {1, 2, 3, 4, 5});
    });
  });
}
