import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_catalog.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_day_state.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/routine_provider.dart';

/// In-memory doubles for the Routine widget tests.
///
/// **No Hive in the widget tests.** The day log is written on every tick, and
/// one fire-and-forget `box.put` inside the fake-async zone poisons the write
/// queue for the rest of the run (the same trap the Talk Board tests document).
/// Persistence is covered by the pure model tests instead.
const String kTestProfileId = 'routine-test-profile';

/// Stubs [profileProvider] without dragging in `ProfileNotifier.build`'s
/// Firebase remote-changes stream.
class StubRoutineProfileNotifier extends ProfileNotifier {
  StubRoutineProfileNotifier({
    required this.role,
    required this.disability,
    this.classroomId = 'routine-test-class',
  });

  final UserRole role;
  final DisabilityType disability;

  /// Enrolled by default: a routine is something an educator sets, so the
  /// realistic learner in these tests belongs to a class. Pass null for the
  /// Player shape — nobody to set one, and nobody to be told to ask.
  final String? classroomId;

  @override
  UserProfile? build() => UserProfile(
        id: kTestProfileId,
        name: 'Routine Tester',
        role: role,
        disabilityType: disability,
        classroomId: classroomId,
        createdAt: DateTime(2026),
      );
}

/// A routine covering the shapes the screens have to handle: scheduled steps,
/// an unscheduled one, media, and a timer.
Routine buildTestRoutine({
  String id = 'r1',
  String name = 'School Morning',
  Set<int> days = const <int>{},
  bool enabled = true,
  List<RoutineStep>? steps,
}) =>
    Routine(
      id: id,
      childProfileId: kTestProfileId,
      setterProfileId: 'adult',
      setterRole: UserRole.parent,
      name: name,
      daysOfWeek: days,
      enabled: enabled,
      steps: steps ?? defaultTestSteps(),
      createdAt: DateTime(2026, 9),
      updatedAt: DateTime(2026, 9),
    );

List<RoutineStep> defaultTestSteps() => const [
      RoutineStep(
        id: 'step-wake',
        activity: RoutineActivity.morningRoutine,
        hour: 6,
        minute: 30,
        durationMinutes: 15,
      ),
      RoutineStep(
        id: 'step-brush',
        activity: RoutineActivity.brushingTeeth,
        hour: 6,
        minute: 45,
        durationMinutes: 2,
        photoUrl: 'assets/images/placeholder-brush.png',
      ),
      RoutineStep(
        id: 'step-breakfast',
        activity: RoutineActivity.breakfast,
        hour: 7,
        minute: 0,
        note: 'Sit with Lola',
      ),
      RoutineStep(
        id: 'step-tidy',
        activity: RoutineActivity.custom,
        title: 'Tidy the toys',
        titleFilipino: 'Ligpitin ang laruan',
        emoji: '🧺',
      ),
    ];

/// Overrides that put [routines] and [log] in front of the screens without
/// touching Hive or Firestore.
List<Override> routineOverrides({
  UserRole role = UserRole.student,
  DisabilityType disability = DisabilityType.none,
  List<Routine>? routines,
  Set<String> completed = const <String>{},
  String profileId = kTestProfileId,
  DateTime? today,
  String? classroomId = 'routine-test-class',
}) {
  final day = today ?? DateTime.now();
  return [
    profileProvider.overrideWith(
      () => StubRoutineProfileNotifier(
        role: role,
        disability: disability,
        classroomId: classroomId,
      ),
    ),
    routineListProvider(profileId).overrideWith(
      (ref) => Stream.value(routines ?? [buildTestRoutine()]),
    ),
    routineDayActionsProvider(routineDayKey(profileId, day)).overrideWith(
      (ref) => Stream.value(RoutineDayActions.empty(profileId, day)),
    ),
    routineDayLogProvider(routineDayKey(profileId, day)).overrideWith(
      (ref) => Stream.value(
        RoutineDayLog(
          profileId: profileId,
          day: DateTime(day.year, day.month, day.day),
          completedStepIds: completed,
          updatedAt: DateTime(2026, 9),
        ),
      ),
    ),
  ];
}

/// The learner-facing title of [step] in English — what a finder should look
/// for on screen.
String testTitleOf(RoutineStep step) =>
    RoutineCatalog.titleFor(step, filipino: false);
