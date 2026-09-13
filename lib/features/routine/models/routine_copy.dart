import '../../../data/models/enums.dart';
import 'routine_models.dart';

/// Copying one learner's routine to other learners.
///
/// Pure, so the rules that matter are testable: a copy is a **new** routine
/// with **new step ids** — the day log keys ticks, excuses and lock records by
/// step id, and two learners sharing ids would mean one child's "done"
/// quietly counting on another child's morning in any view that joins them.
/// Everything the educator configured travels with it: days, reminders, the
/// lock and its escalation, every step's time, media, cues and exemptions.
class RoutineCopy {
  const RoutineCopy._();

  /// [source], rebuilt for [childProfileId] and owned by the educator making
  /// the copy.
  ///
  /// The routine id is left empty so `RoutineService.save` creates a fresh
  /// document rather than overwriting the source.
  static Routine forLearner(
    Routine source, {
    required String childProfileId,
    required String setterProfileId,
    required UserRole setterRole,
    required String Function() newId,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return source.copyWith(
      id: '',
      childProfileId: childProfileId,
      setterProfileId: setterProfileId,
      setterRole: setterRole,
      steps: [for (final s in source.steps) s.copyWith(id: newId())],
      createdAt: at,
      updatedAt: at,
    );
  }

  /// Whether [existing] already has a routine called what [source] is called,
  /// ignoring case and surrounding space — the educator is warned rather than
  /// silently given a second "Morning Routine" to tell apart.
  static bool alreadyHasNamed(List<Routine> existing, Routine source) {
    final name = source.name.trim().toLowerCase();
    if (name.isEmpty) return false;
    return existing.any((r) => r.name.trim().toLowerCase() == name);
  }
}
