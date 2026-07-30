import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/classroom.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/classroom_management_provider.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../widgets/group_management_view.dart';

/// Teacher screen: list classes, see join codes, manage rosters.
///
/// The whole surface is [GroupManagementView] — the same widget behind the
/// parent's "Home Groups" screen. Only the copy and the provider calls
/// differ, and they live in [_ClassroomDelegate] below, so the two educator
/// roles can never drift apart on features again.
///
/// All operations call Firestore directly via [classroomManagementProvider].
/// If you don't see your data in the Firebase Console immediately after
/// tapping a button, the network/auth/security-rules layer is the issue —
/// the app isn't caching anything to obscure that.
class ClassroomManagementScreen extends ConsumerWidget {
  const ClassroomManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Please sign in to manage classes.',
            style: AppTypography.bodyMedium,
          ),
        ),
      );
    }
    return GroupManagementView(
      delegate: _ClassroomDelegate(teacherId: profile.id),
    );
  }
}

/// Binds [GroupManagementView] to the `classrooms` / `classroom_members`
/// collections and to teacher-facing copy.
class _ClassroomDelegate extends GroupManagementDelegate {
  final String teacherId;

  const _ClassroomDelegate({required this.teacherId});

  @override
  String get screenTitle => 'Manage Classes';

  @override
  String get groupNoun => 'class';

  @override
  String get groupNounPlural => 'classes';

  @override
  String get memberNoun => 'student';

  @override
  String get memberNounPlural => 'students';

  @override
  IconData get groupIcon => Icons.school_rounded;

  @override
  IconData get memberIcon => Icons.people_rounded;

  @override
  String get createHint => 'e.g. Grade 3 - Math';

  @override
  String get leaderboardKind => 'classroom';

  @override
  GradientPreset get gradientPreset => GradientPreset.assessment;

  @override
  Color get accent => AppColors.sectionLearning;

  @override
  String get emptyEmoji => '🏫';

  @override
  String get shareBlurb =>
      'Open the app, tap "Join a class", and enter the code.';

  @override
  AsyncValue<List<ManagedGroup>> watchGroups(WidgetRef ref) {
    return ref
        .watch(classroomManagementProvider(teacherId))
        .whenData(
          (classrooms) => classrooms
              .map(
                (c) => ManagedGroup(
                  id: c.id,
                  code: c.code,
                  name: c.name,
                  accessibility: c.accessibility,
                  source: c,
                ),
              )
              .toList(),
        );
  }

  @override
  AsyncValue<List<ManagedMember>> watchMembers(WidgetRef ref, String groupId) {
    return ref
        .watch(classroomMembersProvider(groupId))
        .whenData(
          (members) => members
              .map(
                (m) => ManagedMember(
                  profileId: m.profileId,
                  displayName: m.displayName,
                  joinedAt: m.joinedAt,
                ),
              )
              .toList(),
        );
  }

  ClassroomManagementNotifier _notifier(WidgetRef ref) =>
      ref.read(classroomManagementProvider(teacherId).notifier);

  Classroom _classroom(ManagedGroup group) => group.source as Classroom;

  @override
  Future<void> refresh(WidgetRef ref) => _notifier(ref).refresh();

  @override
  Future<void> createGroup(
    WidgetRef ref,
    String name,
    DisabilityType accessibility,
  ) async {
    await _notifier(ref).createClass(name, accessibility: accessibility);
  }

  @override
  Future<void> renameGroup(WidgetRef ref, ManagedGroup group, String name) =>
      _notifier(ref).renameClass(_classroom(group), name);

  @override
  Future<void> setAccessibility(
    WidgetRef ref,
    ManagedGroup group,
    DisabilityType accessibility,
  ) => _notifier(ref).setClassAccessibility(_classroom(group), accessibility);

  @override
  Future<void> regenerateCode(WidgetRef ref, ManagedGroup group) async {
    await _notifier(ref).regenerateCode(_classroom(group));
  }

  @override
  Future<void> deleteGroup(WidgetRef ref, ManagedGroup group) =>
      _notifier(ref).deleteClass(_classroom(group));

  @override
  Future<void> renameMember(
    WidgetRef ref,
    ManagedGroup group,
    String profileId,
    String displayName,
  ) => _notifier(
    ref,
  ).renameMember(_classroom(group), profileId, displayName);

  @override
  Future<void> removeMember(
    WidgetRef ref,
    ManagedGroup group,
    String profileId,
  ) => _notifier(ref).removeStudent(_classroom(group), profileId);

  @override
  Future<void> removeMembers(
    WidgetRef ref,
    ManagedGroup group,
    List<String> profileIds,
  ) => _notifier(ref).removeStudents(_classroom(group), profileIds);
}
