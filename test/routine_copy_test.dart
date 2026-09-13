import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_copy.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';

/// Copying a routine to other learners: everything the educator set up
/// travels, nothing that identifies the original does.
void main() {
  final source = Routine(
    id: 'ana-morning',
    childProfileId: 'ana',
    setterProfileId: 'parent-1',
    setterRole: UserRole.parent,
    name: 'Morning Routine',
    nameFilipino: 'Rutina sa Umaga',
    daysOfWeek: const {1, 3, 5},
    remindersEnabled: false,
    lockEnabled: true,
    escalateAfterMinutes: 20,
    steps: const [
      RoutineStep(
        id: 'ana-brush',
        activity: RoutineActivity.brushingTeeth,
        hour: 6,
        minute: 45,
        durationMinutes: 2,
        photoUrl: 'https://example.com/brush.jpg',
        askMood: true,
      ),
      RoutineStep(
        id: 'ana-dress',
        activity: RoutineActivity.gettingDressed,
        hour: 7,
        minute: 30,
        lockScreen: false,
      ),
    ],
    createdAt: DateTime(2026, 3),
    updatedAt: DateTime(2026, 2),
  );

  var n = 0;
  String newId() => 'new-${n++}';

  test('a copy belongs to the new learner and the educator copying it', () {
    final copy = RoutineCopy.forLearner(
      source,
      childProfileId: 'ben',
      setterProfileId: 'teacher-1',
      setterRole: UserRole.teacher,
      newId: newId,
      now: DateTime(2026, 9, 14),
    );
    expect(copy.id, isEmpty, reason: 'save must create, not overwrite');
    expect(copy.childProfileId, 'ben');
    expect(copy.setterProfileId, 'teacher-1');
    expect(copy.setterRole, UserRole.teacher);
    expect(copy.createdAt, DateTime(2026, 9, 14));
  });

  test('every step gets a fresh id, so two learners never share a tick', () {
    final copy = RoutineCopy.forLearner(
      source,
      childProfileId: 'ben',
      setterProfileId: 'teacher-1',
      setterRole: UserRole.teacher,
      newId: newId,
    );
    final ids = copy.steps.map((s) => s.id).toSet();
    expect(ids, hasLength(2));
    expect(ids.intersection({'ana-brush', 'ana-dress'}), isEmpty);
  });

  test('the whole setup travels: days, lock, escalation, times, media', () {
    final copy = RoutineCopy.forLearner(
      source,
      childProfileId: 'ben',
      setterProfileId: 'teacher-1',
      setterRole: UserRole.teacher,
      newId: newId,
    );
    expect(copy.name, 'Morning Routine');
    expect(copy.nameFilipino, 'Rutina sa Umaga');
    expect(copy.daysOfWeek, {1, 3, 5});
    expect(copy.remindersEnabled, isFalse);
    expect(copy.lockEnabled, isTrue);
    expect(copy.escalateAfterMinutes, 20);
    final brush = copy.steps.first;
    expect(brush.hour, 6);
    expect(brush.minute, 45);
    expect(brush.durationMinutes, 2);
    expect(brush.photoUrl, 'https://example.com/brush.jpg');
    expect(brush.askMood, isTrue);
    expect(copy.steps.last.lockScreen, isFalse);
  });

  test('a learner who already has a routine by that name is spotted', () {
    final existing = source.copyWith(id: 'ben-old', name: '  morning routine ');
    expect(RoutineCopy.alreadyHasNamed([existing], source), isTrue);
    expect(
      RoutineCopy.alreadyHasNamed([existing.copyWith(name: 'Bedtime')], source),
      isFalse,
    );
    expect(
      RoutineCopy.alreadyHasNamed([existing], source.copyWith(name: '')),
      isFalse,
    );
  });
}
