import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/avatar_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/local/profile_export_service.dart';
import '../../../providers/app_providers.dart';

/// Screen for importing and exporting individual student profiles.
class ProfileImportExportScreen extends ConsumerStatefulWidget {
  const ProfileImportExportScreen({super.key});

  @override
  ConsumerState<ProfileImportExportScreen> createState() =>
      _ProfileImportExportScreenState();
}

class _ProfileImportExportScreenState
    extends ConsumerState<ProfileImportExportScreen> {
  List<UserProfile> _students = [];
  bool _exporting = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() {
    final rawProfiles = HiveService.getProfiles();
    setState(() {
      _students = rawProfiles
          .map((data) => HiveService.getProfileById(data['id'] as String))
          .whereType<UserProfile>()
          .where((p) => p.role == UserRole.student)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Future<void> _exportProfile(UserProfile profile) async {
    setState(() => _exporting = true);
    try {
      await ProfileExportService.exportProfile(profile);
      if (mounted) {
        AppSnackBar.success(context, message: '${profile.name} exported successfully');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: 'Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importProfile() async {
    setState(() => _importing = true);
    try {
      final result = await ProfileExportService.importProfile();
      if (mounted) {
        if (result.success) {
          AppSnackBar.success(context, message: result.message);
        } else {
          AppSnackBar.error(context, message: result.message);
        }
        if (result.success) {
          ref.invalidate(allProfilesWithProgressProvider);
          _loadStudents();
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: 'Import failed: $e');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import / Export'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Import Section ──────────────
          _ActionCard(
            icon: Icons.file_download_rounded,
            title: 'Import Student Profile',
            description:
                'Restore a student profile from a JSON file exported by another device.',
            buttonLabel: _importing ? 'Importing…' : 'Choose File',
            buttonIcon: Icons.folder_open_rounded,
            color: AppColors.primary,
            onPressed: _importing ? null : _importProfile,
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05, end: 0),
          const SizedBox(height: 24),

          // ─── Export Section ─────────────
          Text(
            'Export a Student',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a student below to export their profile, progress, and achievements as a JSON file.',
            style: AppTypography.bodySmall.copyWith(
              color: hc.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          if (_students.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: hc.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 48,
                      color: AppColors.textHint.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'No student profiles to export',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_students.length, (index) {
              final student = _students[index];
              final avatar = AvatarData.getAvatar(student.avatarIndex);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExportProfileCard(
                  profile: student,
                  avatar: avatar,
                  exporting: _exporting,
                  onExport: () => _exportProfile(student),
                ),
              )
                  .animate()
                  .fadeIn(
                      duration: 400.ms, delay: (150 + index * 60).ms)
                  .slideY(begin: 0.05, end: 0);
            }),
        ],
      ),
    );
  }
}

// ─── Action Card (Import) ────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final IconData buttonIcon;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: AppTypography.bodySmall.copyWith(
              color: HCColor.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(buttonIcon, size: 18),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Export Profile Card ─────────────────────────────────

class _ExportProfileCard extends StatelessWidget {
  final UserProfile profile;
  final AvatarOption avatar;
  final bool exporting;
  final VoidCallback onExport;

  const _ExportProfileCard({
    required this.profile,
    required this.avatar,
    required this.exporting,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: avatar.color.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(avatar.emoji,
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (profile.age != null)
                      Text(
                        '${profile.age} yrs',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    if (profile.age != null && profile.gradeLevel != null)
                      Text(
                        ' · ',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    if (profile.gradeLevel != null)
                      Text(
                        profile.gradeLevel!.label,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Export button
          FilledButton.tonalIcon(
            onPressed: exporting ? null : onExport,
            icon: const Icon(Icons.file_upload_rounded, size: 18),
            label: const Text('Export'),
            style: FilledButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
