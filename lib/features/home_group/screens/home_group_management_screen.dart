import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/home_group.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/home_group_provider.dart';
import '../../../widgets/animated_gradient_background.dart';
import '../../classroom/widgets/group_management_view.dart';

/// Parent screen: create, rename, regenerate or delete home groups, and
/// manage each group's roster.
///
/// The whole surface is [GroupManagementView] — the same widget behind the
/// teacher's "Manage Classes" screen. Only the copy and the provider calls
/// differ, and they live in [_HomeGroupDelegate] below.
class HomeGroupManagementScreen extends ConsumerWidget {
  const HomeGroupManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return Scaffold(
        body: Center(
          child: Text('No active profile.', style: AppTypography.bodyMedium),
        ),
      );
    }
    return GroupManagementView(
      delegate: _HomeGroupDelegate(parentProfileId: profile.id),
    );
  }
}

/// Binds [GroupManagementView] to the `home_groups` / `home_group_members`
/// collections and to parent-facing copy.
class _HomeGroupDelegate extends GroupManagementDelegate {
  final String parentProfileId;

  const _HomeGroupDelegate({required this.parentProfileId});

  @override
  String get screenTitle => 'Home Groups';

  @override
  String get groupNoun => 'home group';

  @override
  String get groupNounPlural => 'home groups';

  @override
  String get memberNoun => 'child';

  @override
  String get memberNounPlural => 'children';

  @override
  IconData get groupIcon => Icons.family_restroom_rounded;

  @override
  IconData get memberIcon => Icons.child_care_rounded;

  @override
  String get createHint => 'e.g. The Santos Family';

  @override
  String get leaderboardKind => 'homeGroup';

  @override
  GradientPreset get gradientPreset => GradientPreset.home;

  @override
  Color get accent => AppColors.secondary;

  @override
  String get emptyEmoji => '👨‍👩‍👧';

  @override
  String get shareBlurb =>
      'Open the app, tap "Join a home group", and enter the code.';

  @override
  AsyncValue<List<ManagedGroup>> watchGroups(WidgetRef ref) {
    return ref
        .watch(homeGroupManagementProvider(parentProfileId))
        .whenData(
          (groups) => groups
              .map(
                (g) => ManagedGroup(
                  id: g.id,
                  code: g.code,
                  name: g.name,
                  accessibility: g.accessibility,
                  source: g,
                ),
              )
              .toList(),
        );
  }

  @override
  AsyncValue<List<ManagedMember>> watchMembers(WidgetRef ref, String groupId) {
    return ref
        .watch(homeGroupMembersProvider(groupId))
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

  HomeGroupManagementNotifier _notifier(WidgetRef ref) =>
      ref.read(homeGroupManagementProvider(parentProfileId).notifier);

  HomeGroup _group(ManagedGroup group) => group.source as HomeGroup;

  @override
  Future<void> refresh(WidgetRef ref) => _notifier(ref).refresh();

  @override
  Future<void> createGroup(
    WidgetRef ref,
    String name,
    DisabilityType accessibility,
  ) async {
    await _notifier(ref).createGroup(name, accessibility: accessibility);
  }

  @override
  Future<void> renameGroup(WidgetRef ref, ManagedGroup group, String name) =>
      _notifier(ref).renameGroup(_group(group), name);

  @override
  Future<void> setAccessibility(
    WidgetRef ref,
    ManagedGroup group,
    DisabilityType accessibility,
  ) => _notifier(ref).setGroupAccessibility(_group(group), accessibility);

  @override
  Future<void> regenerateCode(WidgetRef ref, ManagedGroup group) async {
    await _notifier(ref).regenerateCode(_group(group));
  }

  @override
  Future<void> deleteGroup(WidgetRef ref, ManagedGroup group) =>
      _notifier(ref).deleteGroup(_group(group));

  @override
  Future<void> renameMember(
    WidgetRef ref,
    ManagedGroup group,
    String profileId,
    String displayName,
  ) => _notifier(ref).renameMember(_group(group), profileId, displayName);

  @override
  Future<void> removeMember(
    WidgetRef ref,
    ManagedGroup group,
    String profileId,
  ) => _notifier(ref).removeChild(_group(group), profileId);

  @override
  Future<void> removeMembers(
    WidgetRef ref,
    ManagedGroup group,
    List<String> profileIds,
  ) => _notifier(ref).removeChildren(_group(group), profileIds);
}
