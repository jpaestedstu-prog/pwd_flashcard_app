import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_presentation.dart';

/// The Routine accessibility matrix. Pure, like the policy it covers.

UserProfile _profile(UserRole role, DisabilityType type) => UserProfile(
      id: 'p',
      name: 'n',
      role: role,
      disabilityType: type,
      createdAt: DateTime(2026),
    );

List<RoutineStep> _steps(int n) => [
      for (var i = 0; i < n; i++)
        RoutineStep(
          id: 's$i',
          activity: RoutineActivity.breakfast,
          hour: 7 + i,
          minute: 0,
        ),
    ];

void main() {
  group('RoutinePresentation.forType', () {
    test('every category yields a usable configuration', () {
      for (final type in DisabilityType.values) {
        final p = RoutinePresentation.forType(type);
        expect(p.stepsPerView, greaterThan(0), reason: '$type');
        expect(p.mediaOrder.toSet(), RoutineMediaKind.values.toSet(),
            reason: '$type must be able to show every media channel');
        expect(p.mediaOrder.length, RoutineMediaKind.values.length,
            reason: '$type lists a media channel twice');
      }
    });

    test('visual: speaks, announces, leads with audio, no FSL', () {
      final p = RoutinePresentation.forType(DisabilityType.visual);
      expect(p.speakOnOpen, isTrue);
      expect(p.announceProgress, isTrue);
      // Signs are visual — useless here, and the app makes the same call on
      // every other surface (AccessibilityContentPolicy).
      expect(p.showFsl, isFalse);
      expect(p.mediaOrder.first, RoutineMediaKind.audio);
      expect(p.largeCompleteTarget, isTrue);
      // A timer read as a bar is drawing for nobody.
      expect(p.timerAsBar, isFalse);
    });

    test('hearing: FSL on, speech off, video leads, audio last', () {
      final p = RoutinePresentation.forType(DisabilityType.hearing);
      expect(p.showFsl, isTrue);
      // Speech a Deaf learner cannot hear is feedback only to the room.
      expect(p.speakOnOpen, isFalse);
      expect(p.announceProgress, isFalse);
      expect(p.playSoundCues, isFalse);
      expect(p.mediaOrder.first, RoutineMediaKind.video);
      expect(p.mediaOrder.last, RoutineMediaKind.audio);
    });

    test('motor: one step, big target, no drag', () {
      final p = RoutinePresentation.forType(DisabilityType.motor);
      expect(p.stepsPerView, 1);
      expect(p.showOnlyNextStep, isTrue);
      expect(p.largeCompleteTarget, isTrue);
      // A drag is the hardest gesture on this screen for an unsteady hand or
      // a gaze cursor; the menu reorder is always available instead.
      expect(p.allowDragReorder, isFalse);
    });

    test('cognitive: one step, instructions open, bar timer, no FSL', () {
      final p = RoutinePresentation.forType(DisabilityType.cognitive);
      expect(p.stepsPerView, 1);
      expect(p.showOnlyNextStep, isTrue);
      expect(p.instructionsExpanded, isTrue);
      expect(p.timerAsBar, isTrue);
      expect(p.showFsl, isFalse);
      expect(p.speakOnOpen, isTrue);
    });

    test('multiple: the calm shape, but every modality stays on', () {
      final p = RoutinePresentation.forType(DisabilityType.multiple);
      expect(p.stepsPerView, 1);
      expect(p.showOnlyNextStep, isTrue);
      expect(p.showFsl, isTrue);
      expect(p.speakOnOpen, isTrue);
    });

    test('none: the whole day at a glance', () {
      final p = RoutinePresentation.forType(DisabilityType.none);
      expect(p.showOnlyNextStep, isFalse);
      expect(p.stepsPerView, greaterThan(10));
      expect(p.allowDragReorder, isTrue);
    });

    test('no configuration silently hides a media channel', () {
      // `mediaFor` filters by what the step supplies, never by policy: a
      // photo an educator attached must reach every learner who can see it.
      var step = const RoutineStep(id: 's', activity: RoutineActivity.lunch);
      for (final kind in RoutineMediaKind.values) {
        step = step.withMedia(kind, 'https://x/${kind.name}');
      }
      for (final type in DisabilityType.values) {
        final p = RoutinePresentation.forType(type);
        expect(p.mediaFor(step).toSet(), RoutineMediaKind.values.toSet(),
            reason: '$type dropped a supplied channel');
      }
    });
  });

  group('RoutinePresentation.forProfile', () {
    test('a learner gets their own category', () {
      for (final type in DisabilityType.values) {
        final p = RoutinePresentation.forProfile(
          _profile(UserRole.student, type),
        );
        expect(p.showOnlyNextStep,
            RoutinePresentation.forType(type).showOnlyNextStep,
            reason: '$type');
      }
    });

    test('educators always get the full day, whatever their own category', () {
      // A teacher opening a learner's routine is checking it *for* them; their
      // own accessibility category must not hide steps they are trying to see.
      for (final role in [UserRole.teacher, UserRole.parent]) {
        final p = RoutinePresentation.forProfile(
          _profile(role, DisabilityType.cognitive),
        );
        expect(p.showOnlyNextStep, isFalse, reason: '$role');
        expect(p.stepsPerView, greaterThan(10), reason: '$role');
      }
    });

    test('no profile falls back to the full experience', () {
      expect(RoutinePresentation.forProfile(null).showOnlyNextStep, isFalse);
    });
  });

  group('visibleSteps', () {
    test('the full-day policy returns everything', () {
      final p = RoutinePresentation.forType(DisabilityType.none);
      final steps = _steps(6);
      expect(p.visibleSteps(steps, const {}).length, 6);
    });

    test('the one-step policy shows the next incomplete step', () {
      final p = RoutinePresentation.forType(DisabilityType.cognitive);
      final steps = _steps(4);
      expect(p.visibleSteps(steps, const {}).single.id, 's0');
      expect(p.visibleSteps(steps, {'s0'}).single.id, 's1');
      expect(p.visibleSteps(steps, {'s0', 's1', 's2'}).single.id, 's3');
    });

    test('a finished day shows the whole day back, never an empty screen', () {
      // An empty screen reads as a bug to a child, and there would be no way
      // back from a step ticked off by mistake.
      final p = RoutinePresentation.forType(DisabilityType.cognitive);
      final steps = _steps(3);
      final done = {for (final s in steps) s.id};
      expect(p.visibleSteps(steps, done).length, 3);
    });

    test('an empty day stays empty rather than throwing', () {
      for (final type in DisabilityType.values) {
        final p = RoutinePresentation.forType(type);
        expect(p.visibleSteps(const [], const {}), isEmpty, reason: '$type');
      }
    });
  });
}
