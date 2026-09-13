import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/cloud_sync_outcome.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/parent_provider.dart';
import '../../../providers/routine_provider.dart';
import '../models/routine_copy.dart';
import '../models/routine_models.dart';
import '../services/routine_service.dart';

/// A learner a routine can be copied to.
class RoutineCopyTarget {
  final String profileId;
  final String name;
  final String avatarEmoji;

  /// The class or family group they belong to, or empty when this device
  /// does not know — which is how the sheet groups them for "select class".
  final String groupName;

  /// Names of the routines they already have, trimmed and lower-cased.
  final Set<String> routineNames;

  const RoutineCopyTarget({
    required this.profileId,
    required this.name,
    this.avatarEmoji = '',
    this.groupName = '',
    this.routineNames = const <String>{},
  });

  bool alreadyHas(Routine routine) {
    final name = routine.name.trim().toLowerCase();
    return name.isNotEmpty && routineNames.contains(name);
  }
}

/// Everyone on this educator's roster, with their class and existing routine
/// names — the same roster the dashboard's "Today's Routines" lists.
final routineCopyTargetsProvider = Provider<List<RoutineCopyTarget>>((ref) {
  final children = ref.watch(parentDashboardProvider).children;
  return [
    for (final c in children)
      RoutineCopyTarget(
        profileId: c.profileId,
        name: c.name,
        avatarEmoji: c.avatarEmoji,
        groupName: _groupNameFor(c.profileId),
        routineNames: _routineNamesFor(c.profileId),
      ),
  ];
});

String _groupNameFor(String profileId) {
  try {
    final profile = HiveService.getProfileById(profileId);
    final classId = profile?.classroomId;
    if (classId != null) {
      final name = HiveService.getCachedClassroom(classId)?.name.trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    final groupId = profile?.homeGroupId;
    if (groupId != null) {
      final name = HiveService.getCachedHomeGroup(groupId)?.name.trim() ?? '';
      if (name.isNotEmpty) return name;
    }
  } catch (_) {}
  return '';
}

Set<String> _routineNamesFor(String profileId) {
  try {
    return {
      for (final r in HiveService.getRoutinesForChild(profileId))
        if (r.name.trim().isNotEmpty) r.name.trim().toLowerCase(),
    };
  } catch (_) {
    return const <String>{};
  }
}

/// Copies [routine] to learners the educator picks, then says how it went.
///
/// A teacher with a class of seven used to build the same morning routine
/// seven times. Each learner gets their **own** copy — new step ids, the same
/// days, times, media, lock and escalation — so any one of them can be changed
/// afterwards without touching the rest.
Future<void> showRoutineCopySheet(
  BuildContext context,
  WidgetRef ref, {
  required Routine routine,
  required bool filipino,
}) async {
  final targets = ref
      .read(routineCopyTargetsProvider)
      .where((t) => t.profileId != routine.childProfileId)
      .toList();
  final picked = await showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => RoutineCopySheet(
      routine: routine,
      targets: targets,
      filipino: filipino,
    ),
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;
  final setter = ref.read(profileProvider);
  if (setter == null) return;

  const service = RoutineService();
  var synced = 0;
  for (final id in picked) {
    final write = await service.save(RoutineCopy.forLearner(
      routine,
      childProfileId: id,
      setterProfileId: setter.id,
      setterRole: setter.role,
      newId: service.newId,
    ));
    if (write.outcome == CloudSyncOutcome.synced) synced++;
    ref.invalidate(routineListProvider(id));
  }
  if (!context.mounted) return;

  final n = picked.length;
  final l = filipino;
  final learners = n == 1 ? 'learner' : 'learners';
  final message = synced == n
      ? (l ? 'Kinopya sa $n na bata.' : 'Copied to $n $learners.')
      : (l
          ? 'Kinopya sa $n na bata — ${n - synced} ay naka-save sa device na '
              'ito at masi-sync kapag maaari.'
          : 'Copied to $n $learners — ${n - synced} saved on this device only '
              'for now, and will sync when it can.');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// The picker. Returns the chosen profile ids through `Navigator.pop`, and
/// does no writing itself.
class RoutineCopySheet extends StatefulWidget {
  const RoutineCopySheet({
    super.key,
    required this.routine,
    required this.targets,
    required this.filipino,
  });

  final Routine routine;
  final List<RoutineCopyTarget> targets;
  final bool filipino;

  @override
  State<RoutineCopySheet> createState() => _RoutineCopySheetState();
}

class _RoutineCopySheetState extends State<RoutineCopySheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final l = widget.filipino;
    final name = widget.routine.name.trim().isEmpty
        ? (l ? 'ang routine' : 'this routine')
        : '“${widget.routine.name.trim()}”';

    final groups = <String, List<RoutineCopyTarget>>{};
    for (final t in widget.targets) {
      final key = t.groupName.isEmpty
          ? (l ? 'Iyong mga bata' : 'Your learners')
          : t.groupName;
      groups.putIfAbsent(key, () => []).add(t);
    }

    final n = _selected.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l ? 'Kopyahin ang $name' : 'Copy $name',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l
                ? 'Bawat bata ay makakakuha ng sariling kopya na may parehong '
                    'araw, oras, hakbang at lock. Puwedeng baguhin ang anumang '
                    'kopya pagkatapos.'
                : 'Each learner gets their own copy with the same days, times, '
                    'steps and lock settings. You can change any copy '
                    'afterwards.',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 12),
          if (widget.targets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l
                    ? 'Walang ibang bata na mapagkopyahan.'
                    : 'There are no other learners to copy to yet.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final entry in groups.entries) ...[
                    _GroupHeader(
                      title: entry.key,
                      allSelected: entry.value
                          .every((t) => _selected.contains(t.profileId)),
                      filipino: l,
                      onToggle: (select) => setState(() {
                        for (final t in entry.value) {
                          select
                              ? _selected.add(t.profileId)
                              : _selected.remove(t.profileId);
                        }
                      }),
                    ),
                    for (final t in entry.value)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selected.contains(t.profileId),
                        onChanged: (v) => setState(() {
                          v == true
                              ? _selected.add(t.profileId)
                              : _selected.remove(t.profileId);
                        }),
                        secondary: Text(
                          t.avatarEmoji.isEmpty ? '🙂' : t.avatarEmoji,
                          style: const TextStyle(fontSize: 24),
                          textScaler: const TextScaler.linear(1.0),
                        ),
                        title: Text(t.name),
                        subtitle: t.alreadyHas(widget.routine)
                            ? Text(
                                l
                                    ? 'Mayroon nang routine na $name'
                                    : 'Already has a routine called $name',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: n == 0
                ? null
                : () => Navigator.of(context).pop(Set<String>.of(_selected)),
            icon: const Icon(Icons.copy_all_rounded),
            label: Text(
              n == 0
                  ? (l ? 'Pumili ng bata' : 'Choose learners')
                  : (l
                      ? 'Kopyahin sa $n na bata'
                      : 'Copy to $n ${n == 1 ? 'learner' : 'learners'}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.allSelected,
    required this.filipino,
    required this.onToggle,
  });

  final String title;
  final bool allSelected;
  final bool filipino;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: hc.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onToggle(!allSelected),
            child: Text(
              allSelected
                  ? (filipino ? 'Alisin ang lahat' : 'Clear')
                  : (filipino ? 'Piliin ang lahat' : 'Select all'),
            ),
          ),
        ],
      ),
    );
  }
}
