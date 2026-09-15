import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_templates.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_wait_cues.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_editor_screen.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_sign_launcher.dart';

void main() {
  group('"Please wait" cues per accessibility category', () {
    test('every learner gets the picture timer', () {
      for (final type in DisabilityType.values) {
        final cues = RoutineWaitCues.forType(type);
        expect(cues.showTimer, isTrue, reason: '$type');
        expect(cues.timerSize, greaterThanOrEqualTo(96), reason: '$type');
      }
    });

    test('signs for the learners who sign, speech for those who listen', () {
      final hearing = RoutineWaitCues.forType(DisabilityType.hearing);
      expect(hearing.signs, isNotEmpty);
      expect(hearing.speakMilestones, isFalse,
          reason: 'speech a Deaf learner cannot hear only reaches the room');

      final visual = RoutineWaitCues.forType(DisabilityType.visual);
      expect(visual.speakMilestones, isTrue);
      expect(visual.signs, isEmpty);

      final cognitive = RoutineWaitCues.forType(DisabilityType.cognitive);
      expect(cognitive.firstThen, isTrue);
      expect(cognitive.speakMilestones, isTrue);

      final multiple = RoutineWaitCues.forType(DisabilityType.multiple);
      expect(multiple.firstThen, isTrue);
      expect(multiple.signs, isNotEmpty);
      expect(multiple.speakMilestones, isTrue);
    });

    test('the wait signs are real cards in the app’s own dictionary', () {
      for (final cue in RoutineWaitCues.waitSigns) {
        expect(RoutineSignLauncher.cardFor(cue), isNotNull, reason: cue.word);
      }
    });

    test('milestones are spoken only when the step is longer than them', () {
      expect(
        RoutineWaitCues.milestoneFor(minutesLeft: 5, totalMinutes: 10),
        5,
      );
      expect(
        RoutineWaitCues.milestoneFor(minutesLeft: 5, totalMinutes: 5),
        isNull,
      );
      expect(
        RoutineWaitCues.milestoneFor(minutesLeft: 1, totalMinutes: 5),
        1,
      );
      expect(
        RoutineWaitCues.milestoneFor(minutesLeft: 3, totalMinutes: 10),
        isNull,
      );
    });
  });

  group('templates come with lengths', () {
    test('every step every template builds has a length of at least 5 min',
        () {
      for (final t in RoutineTemplates.all) {
        for (final s in t.buildSteps((i) => '${t.id}_$i')) {
          expect(s.durationMinutes,
              greaterThanOrEqualTo(RoutineTemplate.minStepMinutes),
              reason: '${t.id} ${s.activity}');
        }
      }
    });

    test('no template plans two steps at the same time', () {
      for (final t in RoutineTemplates.all) {
        final steps = t.buildSteps((i) => '${t.id}_$i')
          ..sort((a, b) => a.minutesOfDay!.compareTo(b.minutesOfDay!));
        for (var i = 1; i < steps.length; i++) {
          final prevEnd = steps[i - 1].minutesOfDay! +
              steps[i - 1].durationMinutes;
          expect(prevEnd, lessThanOrEqualTo(steps[i].minutesOfDay!),
              reason: '${t.id}: ${steps[i - 1].activity} runs into '
                  '${steps[i].activity}');
        }
      }
    });

    test('the new school morning, therapy day and weekend templates', () {
      final morning = RoutineTemplates.byId('school_morning')!;
      expect(morning.daysOfWeek, {1, 2, 3, 4, 5});
      expect(morning.totalMinutes, 125);
      final built = morning.buildSteps((i) => 'm$i');
      expect(built.first.hour, 6);
      expect(built.first.minute, 0);
      expect(built.last.activity, RoutineActivity.schoolTime);
      expect(built.last.durationMinutes, 60);

      final therapy = RoutineTemplates.byId('therapy_day')!;
      expect(therapy.suitedTo, contains(DisabilityType.motor));
      expect(therapy.lengthOf(RoutineActivity.exercise), 45);

      final weekend = RoutineTemplates.byId('weekend')!;
      expect(weekend.daysOfWeek, {6, 7});
    });

    test('evening teeth are brushed in the evening', () {
      final evening = RoutineTemplates.byId('evening')!;
      expect(evening.startOf(RoutineActivity.brushingTeeth), 19 * 60 + 30);
    });

    test('the template sheet says how long a template is', () {
      expect(formatTemplateLength(45, filipino: false), '45 min');
      expect(formatTemplateLength(60, filipino: false), '1 h');
      expect(formatTemplateLength(125, filipino: false), '2 h 5 min');
      expect(formatTemplateLength(125, filipino: true), '2 oras 5 minuto');
    });
  });
}
