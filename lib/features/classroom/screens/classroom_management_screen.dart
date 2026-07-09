import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/classroom.dart';
import '../../../data/models/classroom_member.dart';
import '../../../data/models/enums.dart';
import '../../../features/parent/services/child_unlock_override_service.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/classroom_management_provider.dart';
import '../widgets/accessibility_category_picker.dart';
import '../widgets/cloud_aware_text_dialog.dart';
import '../widgets/cloud_retry_banner.dart';
import '../widgets/cloud_sync_error_view.dart';

/// Teacher/parent screen: list classrooms, see join codes, manage members.
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

    final classroomsAsync = ref.watch(classroomManagementProvider(profile.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Classes',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref
                .read(classroomManagementProvider(profile.id).notifier)
                .refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context, ref, profile.id),
        tooltip: 'New class',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (!FirebaseService.isConfigured)
            CloudRetryBanner(
              onRetrySucceeded: () => ref
                  .read(classroomManagementProvider(profile.id).notifier)
                  .refresh(),
            ),
          Expanded(
            child: classroomsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => CloudSyncErrorView(
                error: e,
                onRetry: () async => ref
                    .read(classroomManagementProvider(profile.id).notifier)
                    .refresh(),
              ),
              data: (classrooms) {
                if (classrooms.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No classes yet. Tap + to create one.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: classrooms.length,
                  itemBuilder: (_, i) => _ClassRow(
                    classroom: classrooms[i],
                    teacherId: profile.id,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(
      BuildContext context, WidgetRef ref, String teacherId) async {
    final created = await CloudAwareTextDialog.show(
      context: context,
      title: 'Create class',
      inputLabel: 'Class name',
      inputHint: 'e.g. Grade 3 - Math',
      submitLabel: 'Create',
      emptyError: 'Class name is required',
      initialAccessibility: DisabilityType.none,
      onSubmitWithAccessibility: (name, accessibility) => ref
          .read(classroomManagementProvider(teacherId).notifier)
          .createClass(name, accessibility: accessibility),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class created.')),
      );
    }
  }
}

/// One classroom in the list. Tap to expand/collapse, see join code,
/// member list, and management actions.
class _ClassRow extends ConsumerWidget {
  final Classroom classroom;
  final String teacherId;

  const _ClassRow({required this.classroom, required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(classroomMembersProvider(classroom.id));
    final memberCount = membersAsync.valueOrNull?.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        title: Text(
          classroom.name,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  classroom.code,
                  style: AppTypography.labelLarge.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
              ),
              AccessibilityCategoryChip(type: classroom.accessibility),
              Text(
                memberCount != null
                    ? '$memberCount student${memberCount == 1 ? "" : "s"}'
                    : '…',
                style: AppTypography.labelMedium,
              ),
            ],
          ),
        ),
        children: [
          // Action row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _copy(context, classroom.code),
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text('Copy code', style: AppTypography.labelLarge),
                ),
                ElevatedButton.icon(
                  onPressed: () => _regen(context, ref, classroom),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text('Reset', style: AppTypography.labelLarge),
                ),
                ElevatedButton.icon(
                  onPressed: () => _rename(context, ref, classroom),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text('Rename', style: AppTypography.labelLarge),
                ),
                ElevatedButton.icon(
                  onPressed: () => _setAccessibility(context, ref, classroom),
                  icon: const Icon(Icons.accessibility_new, size: 16),
                  label:
                      Text('Accessibility', style: AppTypography.labelLarge),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.push(
                    '/leaderboard-config/${classroom.id}'
                    '?kind=classroom'
                    '&name=${Uri.encodeQueryComponent(classroom.name)}',
                  ),
                  icon: const Icon(Icons.leaderboard_rounded, size: 16),
                  label: Text('Leaderboard', style: AppTypography.labelLarge),
                ),
                ElevatedButton.icon(
                  onPressed: () => _delete(context, ref, classroom),
                  icon: const Icon(Icons.delete, size: 16),
                  label: Text('Delete', style: AppTypography.labelLarge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Members (with selection-mode bulk actions)
          _ClassMembersSection(
              classroom: classroom, teacherId: teacherId),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied $code')),
      );
    }
  }

  Future<void> _regen(
      BuildContext context, WidgetRef ref, Classroom c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset join code?'),
        content: const Text(
            'A new code will be generated. Existing students stay enrolled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(classroomManagementProvider(teacherId).notifier)
          .regenerateCode(c);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code reset')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reset: $e')),
        );
      }
    }
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, Classroom c) async {
    final renamed = await CloudAwareTextDialog.show(
      context: context,
      title: 'Rename class',
      inputLabel: 'Class name',
      inputHint: '',
      submitLabel: 'Save',
      emptyError: 'Class name is required',
      initialValue: c.name,
      onSubmit: (name) => ref
          .read(classroomManagementProvider(teacherId).notifier)
          .renameClass(c, name),
    );
    if (renamed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class renamed.')),
      );
    }
  }

  Future<void> _setAccessibility(
      BuildContext context, WidgetRef ref, Classroom c) async {
    final picked = await showAccessibilityCategoryDialog(
      context,
      current: c.accessibility,
    );
    if (picked == null || !context.mounted) return;
    try {
      await ref
          .read(classroomManagementProvider(teacherId).notifier)
          .setClassAccessibility(c, picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accessibility set to ${picked.label}.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update: $e')),
        );
      }
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Classroom c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${c.name}?'),
        content: const Text(
            'Students keep their progress; they just lose this classroom linkage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(classroomManagementProvider(teacherId).notifier)
          .deleteClass(c);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  // Member-level actions live on [_ClassMembersSection] so it can own
  // the multi-select state.
}

/// Show a duration picker for "Unlock screen". Returns the chosen
/// [Duration] or null if the educator cancelled. Shared between the
/// classroom roster (this file) and the home-group roster.
Future<Duration?> _pickUnlockDuration(
    BuildContext context, String memberName) {
  return showDialog<Duration>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Unlock $memberName'),
      content: const Text(
          'How long should the lock screen stay off? The screen will '
          'lock again automatically when this window expires.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, const Duration(minutes: 15)),
          child: const Text('15 min'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, const Duration(minutes: 30)),
          child: const Text('30 min'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, const Duration(minutes: 60)),
          child: const Text('1 hour'),
        ),
      ],
    ),
  );
}

String _formatUnlockDuration(Duration d) {
  if (d.inHours >= 1) {
    final h = d.inHours;
    return h == 1 ? '1 hour' : '$h hours';
  }
  return '${d.inMinutes} minutes';
}

/// Roster + per-member actions for one classroom.
///
/// Owns the long-press selection state: while [_selected] is non-empty,
/// member rows render with checkboxes and a "Remove (N) / Cancel" bar
/// replaces per-row popup menus. When the set empties, the UI returns
/// to single-action mode (Rename / Remove via popup).
class _ClassMembersSection extends ConsumerStatefulWidget {
  final Classroom classroom;
  final String teacherId;

  const _ClassMembersSection({
    required this.classroom,
    required this.teacherId,
  });

  @override
  ConsumerState<_ClassMembersSection> createState() =>
      _ClassMembersSectionState();
}

class _ClassMembersSectionState
    extends ConsumerState<_ClassMembersSection> {
  final Set<String> _selected = {};

  bool get _selectionMode => _selected.isNotEmpty;

  void _toggle(String profileId) {
    setState(() {
      if (!_selected.add(profileId)) _selected.remove(profileId);
    });
  }

  void _clearSelection() {
    setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync =
        ref.watch(classroomMembersProvider(widget.classroom.id));

    return membersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Members error: $e',
          style: AppTypography.bodyMedium,
        ),
      ),
      data: (members) {
        if (members.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No students have joined yet.',
              style: AppTypography.bodyMedium,
            ),
          );
        }
        // Drop selections for members that no longer exist (after refresh).
        final liveIds = members.map((m) => m.profileId).toSet();
        _selected.removeWhere((id) => !liveIds.contains(id));

        return Column(
          children: [
            if (_selectionMode)
              Container(
                color: Colors.orange.shade50,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      '${_selected.length} selected',
                      style: AppTypography.labelMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearSelection,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => _bulkRemove(members),
                      icon: const Icon(Icons.delete, size: 16),
                      label: Text(
                        'Remove (${_selected.length})',
                        style: AppTypography.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
            for (final m in members)
              _MemberRow(
                key: ValueKey(m.profileId),
                member: m,
                selected: _selected.contains(m.profileId),
                selectionMode: _selectionMode,
                onLongPress: () => _toggle(m.profileId),
                onTapInSelection: () => _toggle(m.profileId),
                onRename: () => _renameMember(m),
                onUnlock: () => _unlockMember(m),
                onRemove: () => _removeOne(m),
              ),
          ],
        );
      },
    );
  }

  Future<void> _renameMember(ClassroomMember m) async {
    final renamed = await CloudAwareTextDialog.show(
      context: context,
      title: 'Rename in roster',
      inputLabel: 'Display name in this class',
      inputHint: '',
      submitLabel: 'Save',
      emptyError: 'Display name is required',
      initialValue: m.displayName,
      helperText:
          'This will rename the student in your roster and on their device.',
      onSubmit: (name) => ref
          .read(classroomManagementProvider(widget.teacherId).notifier)
          .renameMember(widget.classroom, m.profileId, name),
    );
    if (renamed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student renamed.')),
      );
    }
  }

  Future<void> _removeOne(ClassroomMember m) async {
    try {
      await ref
          .read(classroomManagementProvider(widget.teacherId).notifier)
          .removeStudent(widget.classroom, m.profileId);
      // classroomMembersProvider is a Firestore stream — no manual refresh needed.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e')),
        );
      }
    }
  }

  /// Show the duration picker and write a `child_unlock_overrides` doc
  /// for [m]. The student's [lockStateProvider] watches that doc and
  /// short-circuits to "not locked" while the override is in the future,
  /// so the lock screen on their device dismisses within seconds.
  Future<void> _unlockMember(ClassroomMember m) async {
    final teacher = ref.read(profileProvider);
    if (teacher == null) return;
    final picked = await _pickUnlockDuration(context, m.displayName);
    if (picked == null) return;
    try {
      await const ChildUnlockOverrideService().setUnlockFor(
        childProfileId: m.profileId,
        duration: picked,
        setter: teacher,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${m.displayName} unlocked for ${_formatUnlockDuration(picked)}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not unlock: $e')),
        );
      }
    }
  }

  Future<void> _bulkRemove(List<ClassroomMember> all) async {
    final n = _selected.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $n student${n == 1 ? "" : "s"}?'),
        content: const Text(
            'Their profiles and progress are kept; they just lose this '
            'classroom linkage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ids = _selected.toList();
    try {
      await ref
          .read(classroomManagementProvider(widget.teacherId).notifier)
          .removeStudents(widget.classroom, ids);
      _clearSelection();
      // classroomMembersProvider is a Firestore stream — no manual refresh needed.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e')),
        );
      }
    }
  }
}

/// One row in the classroom roster — handles both popup-mode and
/// selection-mode rendering. Pure widget, state lives on the parent.
class _MemberRow extends StatelessWidget {
  final ClassroomMember member;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onLongPress;
  final VoidCallback onTapInSelection;
  final VoidCallback onRename;
  final VoidCallback onUnlock;
  final VoidCallback onRemove;

  const _MemberRow({
    super.key,
    required this.member,
    required this.selected,
    required this.selectionMode,
    required this.onLongPress,
    required this.onTapInSelection,
    required this.onRename,
    required this.onUnlock,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: selected,
      onLongPress: onLongPress,
      onTap: selectionMode ? onTapInSelection : null,
      title: Text(
        member.displayName,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: selectionMode
          ? Checkbox(
              value: selected,
              onChanged: (_) => onTapInSelection(),
            )
          : PopupMenuButton<String>(
              tooltip: 'Member actions',
              onSelected: (action) {
                switch (action) {
                  case 'rename':
                    onRename();
                  case 'time_limits':
                    GoRouter.of(context).push(
                      '/child-time-limits/${member.profileId}'
                      '?name=${Uri.encodeQueryComponent(member.displayName)}',
                    );
                  case 'alarms':
                    GoRouter.of(context).push(
                      '/child-alarms/${member.profileId}'
                      '?name=${Uri.encodeQueryComponent(member.displayName)}',
                    );
                  case 'unlock':
                    onUnlock();
                  case 'remove':
                    onRemove();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename', style: AppTypography.bodyMedium),
                ),
                PopupMenuItem(
                  value: 'time_limits',
                  child:
                      Text('Time limits', style: AppTypography.bodyMedium),
                ),
                PopupMenuItem(
                  value: 'alarms',
                  child: Text('Alarms', style: AppTypography.bodyMedium),
                ),
                PopupMenuItem(
                  value: 'unlock',
                  child:
                      Text('Unlock screen', style: AppTypography.bodyMedium),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    'Remove from class',
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ],
            ),
    );
  }
}
