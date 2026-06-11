import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/avatar_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/local/local_repository.dart';
import '../../../providers/app_providers.dart';

/// Displays all created student profiles with name, age, and learning level.
class StudentProfileListScreen extends ConsumerStatefulWidget {
  const StudentProfileListScreen({super.key});

  @override
  ConsumerState<StudentProfileListScreen> createState() =>
      _StudentProfileListScreenState();
}

class _StudentProfileListScreenState
    extends ConsumerState<StudentProfileListScreen> {
  /// Pulls the educator roster from Firestore (or local Hive fallback).
  /// Returns sorted-by-createdAt-desc list of student profiles.
  Future<List<UserProfile>> _fetchStudents() async {
    final active = ref.read(profileProvider);
    if (active != null && active.role != UserRole.student) {
      // Educator: fetch students from their Firestore classrooms.
      final pairs = await ref.read(educatorRosterProvider(active.id).future);
      final list = pairs.map((p) => p.$1).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    // Fallback: local Hive (legacy single-device flow).
    final raw = HiveService.getProfiles();
    return raw
        .map((data) => HiveService.getProfileById(data['id'] as String))
        .whereType<UserProfile>()
        .where((p) => p.role == UserRole.student && !p.isGuestPlayer)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _refresh() {
    final active = ref.read(profileProvider);
    if (active != null && active.role != UserRole.student) {
      // ignore: unused_result
      ref.refresh(educatorRosterProvider(active.id));
    }
    setState(() {});
  }

  Future<void> _confirmDelete(UserProfile student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text(
          'Are you sure you want to delete "${student.name}"? '
          'This will permanently remove all progress data for this student.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await const LocalRepository().deleteProfile(student.id);
      if (mounted) {
        ref.invalidate(allProfilesWithProgressProvider);
        AppSnackBar.info(context, message: '${student.name} deleted');
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.import_export_rounded),
            tooltip: 'Import / Export',
            onPressed: () async {
              await context.push('/profile-import-export');
              if (mounted) _refresh();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<UserProfile>>(
        future: _fetchStudents(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load students:\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final students = snap.data ?? const <UserProfile>[];
          if (students.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 80,
                    color: AppColors.textHint.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No student profiles yet',
                    style: AppTypography.titleLarge.copyWith(
                      color: HCColor.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Students appear here after joining your class with a code.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textHint,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/classroom-manage'),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text('Share Class Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final avatar = AvatarData.getAvatar(student.avatarIndex);
                return Dismissible(
                  key: ValueKey(student.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    await _confirmDelete(student);
                    return false; // We handle removal ourselves
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.delete_rounded,
                        color: AppColors.error, size: 28),
                  ),
                  child: GestureDetector(
                    onTap: () => context.push(
                      '/student-profile-detail',
                      extra: student,
                    ),
                    child: _StudentProfileCard(
                      profile: student,
                      avatar: avatar,
                      isDark: isDark,
                      onDelete: () => _confirmDelete(student),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(
                        duration: 400.ms, delay: (100 + index * 60).ms)
                    .slideY(begin: 0.05, end: 0);
            },
          );
        },
      ),
    );
  }
}

class _StudentProfileCard extends StatelessWidget {
  final UserProfile profile;
  final AvatarOption avatar;
  final bool isDark;
  final VoidCallback onDelete;

  const _StudentProfileCard({
    required this.profile,
    required this.avatar,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HCColor.of(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
          width: 1.5,
        ),
        boxShadow: isDark ? null : AppColors.softShadow,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: avatar.color.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(avatar.emoji,
                  style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                // Wrap so age + grade chips never overflow horizontally on
                // narrow tablets or at large font scales.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (profile.age != null)
                      _DetailChip(
                        icon: Icons.cake_rounded,
                        label: '${profile.age} yrs old',
                      ),
                    if (profile.gradeLevel != null)
                      _DetailChip(
                        icon: Icons.school_rounded,
                        label: profile.gradeLevel!.label,
                      ),
                  ],
                ),
                if (profile.age == null && profile.gradeLevel == null)
                  Text(
                    'No age or level set',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          // Created date & actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(profile.createdAt),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (profile.hasPinProtection)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.lock_rounded,
                          size: 16, color: AppColors.warning),
                    ),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.delete_outline_rounded,
                        size: 20, color: AppColors.error.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
