import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_context.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_summary.dart';
import 'package:pwdpwdpwd/features/mood_tracker/services/quick_mood_check_in.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_popup_schedule.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_catalog.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_templates.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_reminder_scheduler.dart';

/// Check-ins through the day: Mood Check-In joined to "My Day".
///
/// Two ways a question reaches a learner, both set by their educator:
///
///  * a **"Check-In Time" step** — at 9:00 a notification and a pop-up that say
///    "Please do your check-in now", and
///  * a step marked **"ask how they feel"** — "How do you feel after brushing
///    your teeth?" the moment it is ticked off.
///
/// Everything here is pure: the schedule that decides when a learner is
/// interrupted, the words they are asked, and how the answers are read back.
/// If one of these is wrong a child is interrupted mid-game, asked the same
/// question twice, or told their morning was fine when it was not.

RoutineStep _checkIn(String id, {int? hour = 9, int? minute = 0}) =>
    RoutineStep(
      id: id,
      activity: RoutineActivity.moodCheckIn,
      hour: hour,
      minute: minute,
    );

RoutineStep _task(String id, RoutineActivity a, {int hour = 7}) =>
    RoutineStep(id: id, activity: a, hour: hour, minute: 0);

RoutineDayLog _log(Set<String> done) => RoutineDayLog(
  profileId: 'p',
  day: DateTime(2026, 9, 12),
  completedStepIds: done,
  updatedAt: DateTime(2026, 9, 12),
);

DateTime _at(int h, [int m = 0]) => DateTime(2026, 9, 12, h, m);

MoodEntry _entry(
  MoodType mood, {
  MoodContext context = MoodContext.general,
  String? stepId,
  String? title,
  DateTime? at,
}) => MoodEntry(
  id: 'm-${mood.index}-${stepId ?? ''}-${context.index}-${at?.hour ?? 0}',
  profileId: 'p',
  mood: mood,
  timestamp: at ?? DateTime.now(),
  activityContext: context.storageKey,
  routineStepId: stepId,
  routineStepTitle: title,
);

void main() {
  group('when the "Please do your check-in now" pop-up appears', () {
    final steps = [
      _task('wake', RoutineActivity.morningRoutine, hour: 6),
      _checkIn('ci-9'),
      _checkIn('ci-15', hour: 15),
    ];

    test('not before its time', () {
      expect(
        RoutinePopupSchedule.due(todaysSteps: steps, log: _log({}), now: _at(8, 59)),
        isNull,
      );
    });

    test('at its time', () {
      expect(
        RoutinePopupSchedule.due(todaysSteps: steps, log: _log({}), now: _at(9))?.id,
        'ci-9',
      );
    });

    test('still, later in the day, if it was never answered', () {
      // The app was closed at 9:00. Opening it at noon should still ask:
      // the question has not been answered, and it has not stopped mattering.
      expect(
        RoutinePopupSchedule.due(todaysSteps: steps, log: _log({}), now: _at(12))
            ?.id,
        'ci-9',
      );
    });

    test('never once it has been answered', () {
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: steps,
          log: _log({'ci-9'}),
          now: _at(12),
        ),
        isNull,
      );
    });

    test('with two due, the earliest is asked first — one pop-up at a time',
        () {
      expect(
        RoutinePopupSchedule.due(todaysSteps: steps, log: _log({}), now: _at(16))
            ?.id,
        'ci-9',
      );
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: steps,
          log: _log({'ci-9'}),
          now: _at(16),
        )?.id,
        'ci-15',
      );
    });

    test('"Later" puts it off for fifteen minutes, then asks again', () {
      final snooze = {'ci-9': _at(9, 15)};
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: steps,
          log: _log({}),
          now: _at(9, 10),
          snoozedUntil: snooze,
        ),
        isNull,
      );
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: steps,
          log: _log({}),
          now: _at(9, 15),
          snoozedUntil: snooze,
        )?.id,
        'ci-9',
      );
      expect(RoutinePopupSchedule.snoozeFor, const Duration(minutes: 15));
    });

    test('an ordinary step never pops up, however late it is', () {
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: [_task('wake', RoutineActivity.morningRoutine)],
          log: _log({}),
          now: _at(23),
        ),
        isNull,
      );
    });

    test('a check-in with no time never pops up on its own', () {
      expect(
        RoutinePopupSchedule.due(
          todaysSteps: [_checkIn('ci', hour: null, minute: null)],
          log: _log({}),
          now: _at(23),
        ),
        isNull,
      );
    });

    group('a tapped notification', () {
      test('is honoured before its time and through a snooze', () {
        // The learner tapped "Please do your check-in now" — they asked.
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: steps,
            log: _log({}),
            now: _at(8),
            snoozedUntil: {'ci-9': _at(10)},
            requestedStepId: 'ci-9',
          )?.id,
          'ci-9',
        );
      });

      test('never re-asks a check-in already answered', () {
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: steps,
            log: _log({'ci-9'}),
            now: _at(8),
            requestedStepId: 'ci-9',
          ),
          isNull,
        );
      });

      test('can name any of today\'s steps — a chore as well as a question',
          () {
        // "Please have your lunch now" is as much a tap as "Please do your
        // check-in now", so a task step is honoured too — and honoured past
        // the freshness window, because the learner asked for it.
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: steps,
            log: _log({}),
            now: _at(8),
            requestedStepId: 'wake',
          )?.id,
          'wake',
        );
      });

      test('cannot name a step already done, or one that is not today\'s',
          () {
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: steps,
            log: _log({'wake'}),
            now: _at(8),
            requestedStepId: 'wake',
          ),
          isNull,
        );
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: steps,
            log: _log({}),
            now: _at(8),
            requestedStepId: 'someone-elses-step',
          ),
          isNull,
        );
      });
    });

    group('a task step', () {
      final lunch = [_task('lunch', RoutineActivity.lunch, hour: 12)];

      test('comes to the learner at its time', () {
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: lunch,
            log: _log({}),
            now: _at(12),
          )?.id,
          'lunch',
        );
      });

      test('not a minute early', () {
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: lunch,
            log: _log({}),
            now: _at(11, 59),
          ),
          isNull,
        );
      });

      test('is still raised within the hour', () {
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: lunch,
            log: _log({}),
            now: _at(12, 59),
          )?.id,
          'lunch',
        );
      });

      test('goes stale rather than nagging in the evening', () {
        // "Time to eat lunch!" at eight at night is not a reminder, it is a
        // mistake — the moment has passed, and the step can still be ticked
        // from the list.
        expect(RoutinePopupSchedule.taskFreshness, const Duration(hours: 1));
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: lunch,
            log: _log({}),
            now: _at(20),
          ),
          isNull,
        );
      });

      test('a check-in, by contrast, never goes stale', () {
        // A chore has a moment; "how do you feel?" is worth asking whenever
        // it is answered.
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: [_checkIn('ci-9')],
            log: _log({}),
            now: _at(23),
          )?.id,
          'ci-9',
        );
      });

      test('a step already done is never raised', () {
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: lunch,
            log: _log({'lunch'}),
            now: _at(12),
          ),
          isNull,
        );
      });

      test('a step with no time on it is never raised', () {
        // An "any time today" step has no moment to interrupt at.
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: const [
              RoutineStep(id: 'anytime', activity: RoutineActivity.lunch),
            ],
            log: _log({}),
            now: _at(12),
          ),
          isNull,
        );
      });

      test('the earliest due step wins, chore or question', () {
        // One pop-up at a time, oldest first — whichever kind it is.
        final mixed = [
          _checkIn('ci-9'),
          _task('lunch', RoutineActivity.lunch, hour: 12),
        ];
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: mixed,
            log: _log({}),
            now: _at(12, 30),
          )?.id,
          'ci-9',
        );
        expect(
          RoutinePopupSchedule.due(
            todaysSteps: mixed,
            log: _log({'ci-9'}),
            now: _at(12, 30),
          )?.id,
          'lunch',
        );
      });
    });
  });

  group('where a pop-up may interrupt', () {
    test('the hubs and My Day are calm', () {
      for (final path in [
        '/home',
        '/home?tab=0',
        '/flashcards',
        '/games',
        '/stories',
        '/progress',
        '/routine',
      ]) {
        expect(RoutinePopupSchedule.isCalmLocation(path), isTrue, reason: path);
      }
    });

    test('a game, a quiz, a card viewer or a check-in screen is not', () {
      // A question landing mid-game costs the learner the game. It waits, and
      // is asked the moment they are back on a hub.
      for (final path in [
        '/games/word-match',
        '/games/fsl-practice/sign-it',
        '/flashcards/viewer/3',
        '/stories/read/1',
        '/assessment/take/abc',
        '/mood-check-in',
        '/lock',
      ]) {
        expect(RoutinePopupSchedule.isCalmLocation(path), isFalse, reason: path);
      }
    });
  });

  group('the Check-In Time activity', () {
    test('is appended after custom, so no stored step is re-labelled', () {
      // Activities persist by index. Inserting anywhere but the end would turn
      // every stored custom step into something else.
      expect(RoutineActivity.custom.index, 14);
      expect(RoutineActivity.moodCheckIn.index, 15);
      expect(RoutineActivity.fromIndex(15), RoutineActivity.moodCheckIn);
      expect(RoutineActivity.fromIndex(14), RoutineActivity.custom);
    });

    test('the catalog still falls back to custom, by name', () {
      // `infoFor` used to fall back to `all.last`. Adding an activity after
      // custom would have quietly changed what "unknown" means.
      final info = RoutineCatalog.infoFor(RoutineActivity.moodCheckIn);
      expect(info.activity, RoutineActivity.moodCheckIn);
      expect(info.defaultHour, 9);
      expect(info.defaultMinute, 0);
      expect(
        RoutineCatalog.infoFor(RoutineActivity.custom).activity,
        RoutineActivity.custom,
      );
    });

    test('an educator can pick it', () {
      expect(
        RoutineCatalog.pickable.map((i) => i.activity),
        contains(RoutineActivity.moodCheckIn),
      );
    });

    test('its notification asks rather than names a chore', () {
      final routine = Routine(
        id: 'r',
        childProfileId: 'p',
        setterProfileId: 't',
        setterRole: UserRole.teacher,
        name: 'Day',
        steps: [_checkIn('ci')],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final en = RoutineReminderScheduler.plan([routine], filipino: false);
      expect(en.single.title, 'Check-in time 💬');
      expect(en.single.body, 'Please do your check-in now. How are you feeling?');
      expect(en.single.hour, 9);

      final fil = RoutineReminderScheduler.plan([routine], filipino: true);
      expect(fil.single.title, 'Oras na ng check-in 💬');
      expect(fil.single.body, startsWith('Pakigawa na ang iyong check-in'));
    });

    test('it never also asks "how do you feel after" itself', () {
      final step = _checkIn('ci').copyWith(askMood: true);
      expect(step.askMood, isTrue);
      expect(step.asksMoodAfter, isFalse);
    });
  });

  group('the question each step asks', () {
    String q(RoutineActivity a, {bool fil = false}) =>
        RoutineCatalog.moodQuestionFor(
          RoutineStep(id: 'x', activity: a),
          filipino: fil,
        );

    test('the two from the brief, word for word', () {
      expect(
        q(RoutineActivity.morningRoutine),
        'How did you feel when you woke up?',
      );
      expect(
        q(RoutineActivity.brushingTeeth),
        'How do you feel after brushing your teeth?',
      );
    });

    test('every activity has its own, in both languages', () {
      for (final a in RoutineActivity.values) {
        final en = q(a);
        final fil = q(a, fil: true);
        expect(en, endsWith('?'), reason: '$a EN');
        expect(fil, endsWith('?'), reason: '$a FIL');
        expect(fil, isNot(en), reason: '$a is not translated');
      }
    });

    test('a custom step asks about itself by name', () {
      const step = RoutineStep(
        id: 'c',
        activity: RoutineActivity.custom,
        title: 'Feed the dog',
        titleFilipino: 'Pakainin ang aso',
      );
      expect(
        RoutineCatalog.moodQuestionFor(step, filipino: false),
        'How do you feel after Feed the dog?',
      );
      expect(
        RoutineCatalog.moodQuestionFor(step, filipino: true),
        contains('Pakainin ang aso'),
      );
    });
  });

  group('the per-step "ask how they feel" switch', () {
    test('round-trips through storage', () {
      final step = _task('b', RoutineActivity.brushingTeeth)
          .copyWith(askMood: true);
      final back = RoutineStep.fromJson(step.toJson());
      expect(back.askMood, isTrue);
      expect(back.asksMoodAfter, isTrue);
    });

    test('is off for every step written before it existed', () {
      final json = _task('b', RoutineActivity.brushingTeeth).toJson()
        ..remove('ask_mood');
      expect(RoutineStep.fromJson(json).askMood, isFalse);
    });

    test('the Morning template asks the two questions from the brief', () {
      final t = RoutineTemplates.byId('morning')!;
      final steps = t.buildSteps((i) => 's$i');
      final asking = {
        for (final s in steps)
          if (s.askMood) s.activity,
      };
      expect(asking, {
        RoutineActivity.morningRoutine,
        RoutineActivity.brushingTeeth,
      });
    });

    test('the Full Day template carries a 9:00 check-in', () {
      final steps = RoutineTemplates.byId('full_day')!.buildSteps((i) => 's$i');
      final checkIn = steps.where((s) => s.activity.isMoodCheckIn).single;
      expect((checkIn.hour, checkIn.minute), (9, 0));
    });

    test('the templates for fewer interruptions ask nothing', () {
      // Self-Care Basics and Calm Day exist for learners who need fewer
      // transitions. A question after every step is the opposite.
      for (final id in ['self_care', 'calm_day']) {
        final steps = RoutineTemplates.byId(id)!.buildSteps((i) => 's$i');
        expect(steps.any((s) => s.askMood), isFalse, reason: id);
        expect(
          steps.any((s) => s.activity.isMoodCheckIn),
          isFalse,
          reason: id,
        );
      }
    });
  });

  group('a mood entry remembers its step', () {
    test('and round-trips', () {
      final e = _entry(
        MoodType.sad,
        context: MoodContext.afterStep,
        stepId: 'brush',
        title: 'Brushing Teeth',
      ).copyWith(mood: MoodType.happy);
      final back = MoodEntry.fromJson(e.toJson());
      expect(back.routineStepId, 'brush');
      expect(back.routineStepTitle, 'Brushing Teeth');
      expect(back.mood, MoodType.happy,
          reason: 'correcting the face keeps the step');
      expect(back.isAboutRoutineStep, isTrue);
    });

    test('an entry about no step stores exactly the old shape', () {
      final json = _entry(MoodType.happy).toJson();
      expect(json.containsKey('routineStepId'), isFalse);
      expect(json.containsKey('routineActivity'), isFalse);
      expect(json.containsKey('routineStepTitle'), isFalse);
      expect(MoodEntry.fromJson(json).isAboutRoutineStep, isFalse);
    });
  });

  group('asking the same question twice', () {
    test('answering one step does not answer another', () {
      final entries = [
        _entry(MoodType.happy, context: MoodContext.afterStep, stepId: 'wake'),
      ];
      expect(
        hasCheckedInFor(entries, MoodContext.afterStep, routineStepId: 'wake'),
        isTrue,
      );
      expect(
        hasCheckedInFor(entries, MoodContext.afterStep, routineStepId: 'brush'),
        isFalse,
      );
    });
  });

  group('reading the answers back', () {
    final now = DateTime.now();
    final summary = MoodSummary.fromEntries([
      _entry(MoodType.sad,
          context: MoodContext.afterStep,
          stepId: 'brush',
          title: 'Brushing Teeth',
          at: now),
      _entry(MoodType.sad,
          context: MoodContext.afterStep,
          stepId: 'brush',
          title: 'Brushing Teeth',
          at: now.subtract(const Duration(days: 1))),
      _entry(MoodType.happy,
          context: MoodContext.afterStep,
          stepId: 'wake',
          title: 'Morning Routine',
          at: now),
      _entry(MoodType.neutral,
          context: MoodContext.checkIn,
          stepId: 'ci',
          title: 'Check-In Time',
          at: now),
      _entry(MoodType.tired, context: MoodContext.afterRoutine, at: now),
      _entry(MoodType.excited, at: now), // not about the routine at all
    ], now: now);

    test('every routine question counts; the general check-in does not', () {
      expect(summary.entryCount, 6);
      expect(summary.routineCount, 5);
    });

    test('one row per moment, busiest first', () {
      expect(summary.stepMoods.first.title, 'Brushing Teeth');
      expect(summary.stepMoods.first.count, 2);
      expect(summary.stepMoods.first.dominant, MoodType.sad);
      expect(
        summary.stepMoods.map((s) => s.labelOf(isFilipino: false)),
        containsAll([
          'Brushing Teeth',
          'Morning Routine',
          'Check-In Time',
          'Finishing the day',
        ]),
      );
    });

    test('the hardest moment is named — and only a low one qualifies', () {
      expect(summary.hardestStep?.title, 'Brushing Teeth');
      expect(
        summary.hardestStepLabelOf(isFilipino: false),
        'Hardest: Brushing Teeth (mostly Sad)',
      );

      final fine = MoodSummary.fromEntries([
        _entry(MoodType.neutral,
            context: MoodContext.afterStep, stepId: 'b', title: 'Breakfast'),
      ]);
      expect(fine.hardestStep, isNull,
          reason: '"Hardest: breakfast (mostly Okay)" points at nothing');
    });
  });
}
