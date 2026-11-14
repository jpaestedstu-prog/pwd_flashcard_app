import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_service.dart';
import '../../../data/models/classroom.dart';
import '../../../data/models/home_group.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/classroom_management_provider.dart';
import '../../../providers/firestore_stream_helpers.dart';
import '../../../providers/home_group_provider.dart';
import '../../live_session/models/live_session_models.dart';
import '../models/cast_group_selection.dart';

/// The classes (Teacher) and home groups (Parent) an educator can cast for,
/// classes first, each list A–Z so the picker never reshuffles between visits.
List<CastGroupOption> castGroupOptionsFrom(
  List<Classroom> classrooms,
  List<HomeGroup> homeGroups,
) {
  int byName(CastGroupOption a, CastGroupOption b) {
    final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  final classes = [
    for (final c in classrooms)
      CastGroupOption(
        id: c.id,
        name: c.name,
        kind: LiveSessionOwnerKind.classroom,
        accessibility: c.accessibility,
      ),
  ]..sort(byName);
  final groups = [
    for (final g in homeGroups)
      CastGroupOption(
        id: g.id,
        name: g.name,
        kind: LiveSessionOwnerKind.homeGroup,
        accessibility: g.accessibility,
      ),
  ]..sort(byName);
  return [...classes, ...groups];
}

/// "All classes" (Teacher), "All groups" (Parent) or "All classes and
/// groups" for someone with both — the picker's combined choice, and what the
/// TV shows when the cast is for everyone.
String castAllGroupsLabel(AppLocalizations t, List<CastGroupOption> options) {
  final hasClass = options.any((o) => o.kind == LiveSessionOwnerKind.classroom);
  final hasGroup = options.any((o) => o.kind == LiveSessionOwnerKind.homeGroup);
  if (hasClass && hasGroup) return t.tcgAllMixed;
  return hasGroup ? t.tcgAllGroups : t.tcgAllClasses;
}

/// The educator's groups as this device last saw them, straight from Hive —
/// what the cast notifier uses (it has no widget to keep a stream alive) and
/// what the picker shows before the live list arrives. Never throws: a closed
/// box means "no groups known here".
List<CastGroupOption> cachedCastGroupOptions(String educatorProfileId) {
  try {
    return castGroupOptionsFrom(
      HiveService.getClassroomsByTeacher(educatorProfileId),
      HiveService.getHomeGroupsByOwner(educatorProfileId),
    );
  } catch (_) {
    return const [];
  }
}

/// The picker's list: the live class / home-group streams (which also keep
/// the Hive copy fresh), falling back to that copy until they report.
///
/// Kept alive (not autoDispose), like `educatorRosterProvider` which follows
/// the same two streams: an educator's cast screen comes and goes, and the
/// list should not restart from the cache every time it does.
final castGroupOptionsProvider =
    Provider.family<List<CastGroupOption>, String>((ref, educatorProfileId) {
      final classrooms = ref
          .watch(classroomsByTeacherStreamProvider(educatorProfileId))
          .valueOrNull;
      final homeGroups = ref
          .watch(homeGroupsByOwnerStreamProvider(educatorProfileId))
          .valueOrNull;
      if (classrooms == null && homeGroups == null) {
        return cachedCastGroupOptions(educatorProfileId);
      }
      return castGroupOptionsFrom(
        classrooms ?? const [],
        homeGroups ?? const [],
      );
    });

/// How many learners a group has, from its live member list (Hive first).
/// Null while unknown, so the picker can leave the count out rather than
/// show a wrong zero.
final castGroupMemberCountProvider =
    Provider.family<int?, CastGroupOption>((ref, option) {
      final members = option.kind == LiveSessionOwnerKind.homeGroup
          ? ref.watch(homeGroupMembersProvider(option.id)).valueOrNull?.length
          : ref.watch(classroomMembersProvider(option.id)).valueOrNull?.length;
      return members;
    });

/// The ids of the learners who belong to [groupIds] — through a class or
/// home-group membership, or through the learner's own profile naming the
/// group (the field a learner's app uses to find its live session).
///
/// Pure: memberships are passed in, so it can be tested without Hive.
@visibleForTesting
Set<String> castMemberIds({
  required Set<String> groupIds,
  required Map<String, Iterable<String>> membersByGroup,
  required Iterable<UserProfile> learners,
}) {
  return {
    for (final g in groupIds) ...?membersByGroup[g],
    for (final p in learners)
      if ((p.classroomId != null && groupIds.contains(p.classroomId)) ||
          (p.homeGroupId != null && groupIds.contains(p.homeGroupId)))
        p.id,
  };
}

/// The learner ids that belong to [groupIds] on this device: memberships from
/// Hive (kept fresh by the member streams) plus the profiles in [learners].
Set<String> cachedCastMemberIds(
  Set<String> groupIds,
  Iterable<UserProfile> learners,
) {
  final members = <String, Iterable<String>>{};
  for (final id in groupIds) {
    try {
      members[id] = [
        ...HiveService.getMembers(id).map((m) => m.profileId),
        ...HiveService.getHomeGroupMembers(id).map((m) => m.profileId),
      ];
    } catch (_) {
      // A closed box knows nobody; the profile fields below still count.
    }
  }
  return castMemberIds(
    groupIds: groupIds,
    membersByGroup: members,
    learners: learners,
  );
}

/// The Hive key a cast selection is saved under, per educator profile — so
/// it is removed with the profile like every other per-profile setting.
const castGroupSelectionSettingKey = 'tvCastGroups';

/// The class / group selection for one educator, saved on this device.
class CastGroupSelectionNotifier
    extends FamilyNotifier<CastGroupSelection, String> {
  @override
  CastGroupSelection build(String educatorProfileId) {
    try {
      return CastGroupSelection.fromJson(
        HiveService.getProfileSetting(
          castGroupSelectionSettingKey,
          profileId: educatorProfileId,
        ),
      );
    } catch (_) {
      return const CastGroupSelection.all();
    }
  }

  /// "All classes / groups" — the one combined choice.
  Future<void> selectAll() => _save(const CastGroupSelection.all());

  /// The picker's tap on one group (see [CastGroupSelection.toggle]).
  Future<void> toggle(String groupId, List<CastGroupOption> options) =>
      _save(state.toggle(groupId, options));

  Future<void> _save(CastGroupSelection next) async {
    if (next == state) return;
    state = next;
    await persist(next);
  }

  /// Writes [selection] for this educator, on this device. Best-effort: the
  /// choice still applies to this cast if it can't be remembered. A seam for
  /// widget tests, which must not write to Hive from their fake-async zone.
  @protected
  Future<void> persist(CastGroupSelection selection) async {
    try {
      await HiveService.saveProfileSetting(
        castGroupSelectionSettingKey,
        selection.toJson(),
        profileId: arg,
      );
    } catch (_) {
      // The choice still applies to this cast; it just won't be remembered.
    }
  }
}

final castGroupSelectionProvider =
    NotifierProvider.family<CastGroupSelectionNotifier, CastGroupSelection, String>(
      CastGroupSelectionNotifier.new,
    );
