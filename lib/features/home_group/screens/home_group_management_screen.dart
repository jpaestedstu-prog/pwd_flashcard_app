import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/home_group.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/home_group_provider.dart';

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
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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
    );
  }

  Future<void> _showCreateDialog(
      BuildContext context, WidgetRef ref, String parentProfileId) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New home group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Group name',
            hintText: 'e.g. The Smith Family',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created != true) return;
    try {
      await ref
          .read(homeGroupManagementProvider(parentProfileId).notifier)
          .createGroup(controller.text);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create: $e')),
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
    final membersAsync = ref.watch(homeGroupMembersProvider(group.id));

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
            membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) =>
                  Text('Roster error: $e', style: const TextStyle(color: Colors.red)),
              data: (members) {
                if (members.isEmpty) {
                  return Text(
                    'No children have joined yet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return Column(
                  children: members
                      .map((m) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.child_care_rounded),
                            title: Text(m.displayName),
                            subtitle: Text(
                                'Joined ${_formatDate(m.joinedAt)}'),
                            trailing: IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => _confirmRemove(
                                  context, ref, m.profileId, m.displayName),
                            ),
                          ))
                      .toList(),
                );
              },
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
        final controller = TextEditingController(text: group.name);
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Rename group'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await notifier.renameGroup(group, controller.text);
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

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref,
      String childProfileId, String displayName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $displayName?'),
        content: const Text(
            'They\'ll be unenrolled from this group. Their profile and '
            'progress are kept on their device.'),
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
        .read(homeGroupManagementProvider(parentProfileId).notifier)
        .removeChild(group, childProfileId);
    // Force the members provider to re-fetch.
    // ignore: unused_result
    ref.refresh(homeGroupMembersProvider(group.id));
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
