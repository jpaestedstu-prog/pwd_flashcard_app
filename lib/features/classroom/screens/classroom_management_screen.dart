import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_service.dart';
import '../../../data/models/classroom.dart';
import '../../../data/models/classroom_member.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/classroom_management_provider.dart';

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
      return const Scaffold(
        body: Center(child: Text('Please sign in to manage classes.')),
      );
    }

    final classroomsAsync = ref.watch(classroomManagementProvider(profile.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Classes'),
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
          if (!FirebaseService.isConfigured) const _CloudOffBanner(),
          Expanded(
            child: classroomsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load classes:\n$e',
                      textAlign: TextAlign.center),
                ),
              ),
              data: (classrooms) {
                if (classrooms.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No classes yet. Tap + to create one.',
                        textAlign: TextAlign.center,
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
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create class'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Class name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    try {
      await ref
          .read(classroomManagementProvider(teacherId).notifier)
          .createClass(name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create class: $e')),
        );
      }
    }
  }
}

class _CloudOffBanner extends StatelessWidget {
  const _CloudOffBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cloud sync OFF — local-only mode.',
            style: TextStyle(
              color: Colors.red.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Codes you create here can\'t be joined from other devices. '
            'Restart the app to retry. ${FirebaseService.lastInitError ?? ""}',
            style: TextStyle(color: Colors.red.shade900, fontSize: 12),
          ),
        ],
      ),
    );
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
        title: Text(classroom.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
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
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(memberCount != null
                  ? '$memberCount student${memberCount == 1 ? "" : "s"}'
                  : '…'),
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
                  label: const Text('Copy code'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _regen(context, ref, classroom),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _rename(context, ref, classroom),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Rename'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _delete(context, ref, classroom),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Members
          membersAsync.when(
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
              child: Text('Members error: $e'),
            ),
            data: (members) {
              if (members.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No students have joined yet.'),
                );
              }
              return Column(
                children: members
                    .map((m) => ListTile(
                          dense: true,
                          title: Text(m.displayName),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_remove, size: 20),
                            tooltip: 'Remove',
                            onPressed: () =>
                                _removeMember(context, ref, classroom, m),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
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
    final controller = TextEditingController(text: c.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename class'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || !context.mounted) return;
    try {
      await ref
          .read(classroomManagementProvider(teacherId).notifier)
          .renameClass(c, newName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not rename: $e')),
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

  Future<void> _removeMember(BuildContext context, WidgetRef ref,
      Classroom c, ClassroomMember m) async {
    try {
      await ref
          .read(classroomManagementProvider(teacherId).notifier)
          .removeStudent(c, m.profileId);
      // ignore: unused_result
      ref.refresh(classroomMembersProvider(c.id));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $e')),
        );
      }
    }
  }
}
