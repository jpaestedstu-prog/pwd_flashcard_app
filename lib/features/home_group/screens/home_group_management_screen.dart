import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/firebase_service.dart';
import '../../../data/models/home_group.dart';
import '../../../data/models/home_group_member.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/home_group_provider.dart';
import '../../classroom/widgets/cloud_aware_text_dialog.dart';
import '../../classroom/widgets/cloud_retry_banner.dart';
import '../../classroom/widgets/cloud_sync_error_view.dart';
import '../../parent/services/child_unlock_override_service.dart';

/// Parent-facing screen to create, rename, regenerate, or delete home
/// groups, and to view each group's members. Mirrors the teacher's
/// classroom-management screen at a smaller scope: parents typically have
/// one or two groups (immediate family + an extended-family / co-parent
/// group), so we keep the UI compact.
class HomeGroupManagementScreen extends ConsumerWidget {
  const HomeGroupManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('No active profile.')),
      );
    }

    final groupsAsync =
        ref.watch(homeGroupManagementProvider(profile.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Groups'),
        actions: [
          IconButton(
            tooltip: 'New home group',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreateDialog(context, ref, profile.id),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!FirebaseService.isConfigured)
            CloudRetryBanner(
              onRetrySucceeded: () => ref
                  .read(homeGroupManagementProvider(profile.id).notifier)
                  .refresh(),
            ),
          Expanded(
            child: groupsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => CloudSyncErrorView(
                error: e,
                onRetry: () async => ref
                    .read(homeGroupManagementProvider(profile.id).notifier)
                    .refresh(),
              ),
              data: (groups) {
                if (groups.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.family_restroom_rounded, size: 56),
                          const SizedBox(height: 12),
                          const Text(
                            'No home groups yet.\nCreate one to invite your child.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create home group'),
                            onPressed: () =>
                                _showCreateDialog(context, ref, profile.id),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _HomeGroupCard(
                    group: groups[i],
                    parentProfileId: profile.id,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(
      BuildContext context, WidgetRef ref, String parentProfileId) async {
    final created = await CloudAwareTextDialog.show(
      context: context,
      title: 'New home group',
      inputLabel: 'Group name',
      inputHint: 'e.g. The Smith Family',
      submitLabel: 'Create',
      emptyError: 'Group name is required',
      onSubmit: (name) => ref
          .read(homeGroupManagementProvider(parentProfileId).notifier)
          .createGroup(name),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Home group created.')),
      );
    }
  }
}

class _HomeGroupCard extends ConsumerWidget {
  final HomeGroup group;
  final String parentProfileId;

  const _HomeGroupCard({
    required this.group,
    required this.parentProfileId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) =>
                      _handleMenu(context, ref, action),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(
                        value: 'regen', child: Text('New code')),
                    PopupMenuItem(
                        value: 'leaderboard', child: Text('Leaderboard')),
                    PopupMenuItem(
                        value: 'delete', child: Text('Delete group')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ─── Code reveal + copy ────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    group.code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copy code',
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: group.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ─── Member roster ─────────────────────────
            _HomeGroupMembersSection(
              group: group,
              parentProfileId: parentProfileId,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenu(
      BuildContext context, WidgetRef ref, String action) async {
    final notifier =
        ref.read(homeGroupManagementProvider(parentProfileId).notifier);
    switch (action) {
      case 'rename':
        final renamed = await CloudAwareTextDialog.show(
          context: context,
          title: 'Rename group',
          inputLabel: 'Group name',
          inputHint: '',
          submitLabel: 'Save',
          emptyError: 'Group name is required',
          initialValue: group.name,
          onSubmit: (name) => notifier.renameGroup(group, name),
        );
        if (renamed == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group renamed.')),
          );
        }
      case 'regen':
        try {
          await notifier.regenerateCode(group);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New code generated.')),
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not regenerate: $e')),
          );
        }
      case 'leaderboard':
        context.push(
          '/leaderboard-config/${group.id}'
          '?kind=homeGroup'
          '&name=${Uri.encodeQueryComponent(group.name)}',
        );
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete this group?'),
            content: const Text(
                'All children will be unenrolled. Their profiles stay '
                'on their devices.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await notifier.deleteGroup(group);
        }
    }
  }

  // Member-level actions live on [_HomeGroupMembersSection] so it can
  // own the multi-select state.
}

/// Roster + per-member actions for one home group.
///
/// Owns the long-press selection state: while [_selected] is non-empty,
/// member rows render with checkboxes and a "Remove (N) / Cancel" bar
/// replaces the per-row popup menu. Mirrors [_ClassMembersSection].
class _HomeGroupMembersSection extends ConsumerStatefulWidget {
  final HomeGroup group;
  final String parentProfileId;

  const _HomeGroupMembersSection({
    required this.group,
    required this.parentProfileId,
  });

  @override
  ConsumerState<_HomeGroupMembersSection> createState() =>
      _HomeGroupMembersSectionState();
}

class _HomeGroupMembersSectionState
    extends ConsumerState<_HomeGroupMembersSection> {
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

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final membersAsync =
        ref.watch(homeGroupMembersProvider(widget.group.id));

    return membersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Roster error: $e',
          style: const TextStyle(color: Colors.red)),
      data: (members) {
        if (members.isEmpty) {
          return Text(
            'No children have joined yet.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        // Drop selections for members that no longer exist.
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
                    Text('${_selected.length} selected'),
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
                      onPressed: _bulkRemove,
                      icon: const Icon(Icons.delete, size: 16),
                      label: Text('Remove (${_selected.length})'),
                    ),
                  ],
                ),
              ),
            for (final m in members)
              _HomeGroupMemberRow(
                member: m,
                selected: _selected.contains(m.profileId),
                selectionMode: _selectionMode,
                joinedAtLabel: 'Joined ${_formatDate(m.joinedAt)}',
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

  Future<void> _renameMember(HomeGroupMember m) async {
    final renamed = await CloudAwareTextDialog.show(
      context: context,
      title: 'Rename in roster',
      inputLabel: 'Display name in this group',
      inputHint: '',
      submitLabel: 'Save',
      emptyError: 'Display name is required',
      initialValue: m.displayName,
      helperText:
          'This will rename the child in your roster and on their device.',
      onSubmit: (name) => ref
          .read(homeGroupManagementProvider(widget.parentProfileId).notifier)
          .renameMember(widget.group, m.profileId, name),
    );
    if (renamed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Child renamed.')),
      );
    }
  }

  /// Show the duration picker and write a `child_unlock_overrides` doc
  /// for [m]. The child's [lockStateProvider] watches that doc and
  /// short-circuits to "not locked" while the override is in the future,
  /// so the lock screen on their device dismisses within seconds.
  Future<void> _unlockMember(HomeGroupMember m) async {
    final parent = ref.read(profileProvider);
    if (parent == null) return;
    final picked = await _pickUnlockDuration(context, m.displayName);
    if (picked == null) return;
    try {
      await const ChildUnlockOverrideService().setUnlockFor(
        childProfileId: m.profileId,
        duration: picked,
        setter: parent,
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

  Future<void> _removeOne(HomeGroupMember m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${m.displayName}?'),
        content: const Text(
            "They'll be unenrolled from this group. Their profile and "
            "progress are kept on their device."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref
        .read(homeGroupManagementProvider(widget.parentProfileId).notifier)
        .removeChild(widget.group, m.profileId);
    // homeGroupMembersProvider is a Firestore stream — no manual refresh needed.
  }

  Future<void> _bulkRemove() async {
    final n = _selected.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $n child${n == 1 ? "" : "ren"}?'),
        content: const Text(
            'Their profiles and progress are kept on their devices; they '
            'just lose this home-group linkage.'),
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
          .read(homeGroupManagementProvider(widget.parentProfileId).notifier)
          .removeChildren(widget.group, ids);
      _clearSelection();
      // homeGroupMembersProvider is a Firestore stream — no manual refresh needed.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove: $e')),
      );
    }
  }
}

/// One row in the home-group roster.
class _HomeGroupMemberRow extends StatelessWidget {
  final HomeGroupMember member;
  final bool selected;
  final bool selectionMode;
  final String joinedAtLabel;
  final VoidCallback onLongPress;
  final VoidCallback onTapInSelection;
  final VoidCallback onRename;
  final VoidCallback onUnlock;
  final VoidCallback onRemove;

  const _HomeGroupMemberRow({
    required this.member,
    required this.selected,
    required this.selectionMode,
    required this.joinedAtLabel,
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
      contentPadding: EdgeInsets.zero,
      selected: selected,
      onLongPress: onLongPress,
      onTap: selectionMode ? onTapInSelection : null,
      leading: const Icon(Icons.child_care_rounded),
      title: Text(member.displayName),
      subtitle: Text(joinedAtLabel),
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
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(
                    value: 'time_limits', child: Text('Time limits')),
                PopupMenuItem(value: 'alarms', child: Text('Alarms')),
                PopupMenuItem(value: 'unlock', child: Text('Unlock screen')),
                PopupMenuItem(
                    value: 'remove', child: Text('Remove from group')),
              ],
            ),
    );
  }
}

/// Show a duration picker for "Unlock screen". Mirror of the helper in
/// `classroom_management_screen.dart` — kept file-private so neither
/// screen has to depend on the other.
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
