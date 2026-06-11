import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../models/assessment_models.dart';
import '../services/assessment_service.dart';
import '../../../widgets/app_back_button.dart';

/// Screen for educators to assign an assessment to students.
class AssessmentAssignScreen extends ConsumerStatefulWidget {
  const AssessmentAssignScreen({super.key});

  @override
  ConsumerState<AssessmentAssignScreen> createState() =>
      _AssessmentAssignScreenState();
}

class _AssessmentAssignScreenState
    extends ConsumerState<AssessmentAssignScreen> {
  Assessment? _selectedAssessment;
  final Set<String> _selectedStudentIds = {};
  DateTime? _deadline;
  final _instructionsController = TextEditingController();
  bool _saving = false;

  late final List<Assessment> _assessments;
  late final List<({String id, String name})> _students;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    final profileId = profile?.id ?? '';

    // Load assessments created by this educator + system assessments
    _assessments = AssessmentService.getAssessments(profileId);

    // Load all student profiles
    final allData = HiveService.getAllProfilesWithProgress();
    _students = allData
        .where((d) => d.$1.role == UserRole.student)
        .map((d) => (id: d.$1.id, name: d.$1.name))
        .toList();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  bool get _canAssign =>
      _selectedAssessment != null && _selectedStudentIds.isNotEmpty;

  Future<void> _assign() async {
    if (!_canAssign || _saving) return;
    setState(() => _saving = true);

    final profile = ref.read(profileProvider);
    final assignment = AssessmentAssignment(
      id: const Uuid().v4(),
      assessmentId: _selectedAssessment!.id,
      assessmentTitle: _selectedAssessment!.title,
      assignedBy: profile!.id,
      studentIds: _selectedStudentIds.toList(),
      assignedAt: DateTime.now(),
      deadline: _deadline,
      instructions: _instructionsController.text.trim().isEmpty
          ? null
          : _instructionsController.text.trim(),
    );

    await AssessmentService.saveAssignment(profile.id, assignment);

    if (mounted) {
      AppSnackBar.success(context, message: 'Assessment assigned to ${_selectedStudentIds.length} student(s)!');
      context.pop();
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedStudentIds.length == _students.length) {
        _selectedStudentIds.clear();
      } else {
        _selectedStudentIds
          ..clear()
          ..addAll(_students.map((s) => s.id));
      }
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 23, minute: 59),
      );
      setState(() {
        _deadline = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time?.hour ?? 23,
          time?.minute ?? 59,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/assessment-hub'),
        title: Text(
          'Assign Assessment',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _assessments.isEmpty
          ? _EmptyAssessments(hc: hc)
          : _students.isEmpty
              ? _EmptyStudents(hc: hc)
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ─── Select Assessment ────────────
                    Text(
                      'Select Assessment',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_assessments.length, (i) {
                      final a = _assessments[i];
                      final selected = _selectedAssessment?.id == a.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AssessmentTile(
                          assessment: a,
                          selected: selected,
                          hc: hc,
                          onTap: () =>
                              setState(() => _selectedAssessment = a),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 300.ms, delay: (50 * i).ms);
                    }),

                    const SizedBox(height: 24),

                    // ─── Select Students ──────────────
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select Students (${_selectedStudentIds.length}/${_students.length})',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hc.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _toggleSelectAll,
                          child: Text(
                            _selectedStudentIds.length == _students.length
                                ? 'Deselect All'
                                : 'Select All',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_students.length, (i) {
                      final s = _students[i];
                      final checked = _selectedStudentIds.contains(s.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedStudentIds.add(s.id);
                            } else {
                              _selectedStudentIds.remove(s.id);
                            }
                          });
                        },
                        title: Text(
                          s.name,
                          style: AppTypography.bodyMedium.copyWith(
                            color: hc.textPrimary,
                          ),
                        ),
                        secondary: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }),

                    const SizedBox(height: 24),

                    // ─── Deadline (optional) ──────────
                    Text(
                      'Deadline (optional)',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickDeadline,
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(
                        _deadline != null
                            ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year} ${_deadline!.hour}:${_deadline!.minute.toString().padLeft(2, '0')}'
                            : 'Set Deadline',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (_deadline != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => _deadline = null),
                          child: const Text('Remove deadline'),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ─── Instructions (optional) ──────
                    Text(
                      'Instructions (optional)',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _instructionsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add instructions for students...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ─── Assign Button ────────────────
                    FilledButton.icon(
                      onPressed: _canAssign && !_saving ? _assign : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _saving ? 'Assigning...' : 'Assign Assessment',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
    );
  }
}

// ─── Assessment Tile ──────────────────────────────────

class _AssessmentTile extends StatelessWidget {
  final Assessment assessment;
  final bool selected;
  final HCColor hc;
  final VoidCallback onTap;

  const _AssessmentTile({
    required this.assessment,
    required this.selected,
    required this.hc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : hc.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : hc.textSecondary.withValues(alpha: 0.15),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(assessment.type.emoji,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assessment.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${assessment.questions.length} questions  •  ${assessment.difficulty.name}',
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty States ─────────────────────────────────────

class _EmptyAssessments extends StatelessWidget {
  final HCColor hc;
  const _EmptyAssessments({required this.hc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📋', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No assessments yet',
            style: AppTypography.titleMedium.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Create an assessment first using the Assessment Builder.',
            style:
                AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/assessment/builder'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Assessment'),
          ),
        ],
      ),
    );
  }
}

class _EmptyStudents extends StatelessWidget {
  final HCColor hc;
  const _EmptyStudents({required this.hc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👩‍🎓', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No students found',
            style: AppTypography.titleMedium.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Create student profiles first to assign assessments.',
            style:
                AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Create Student'),
          ),
        ],
      ),
    );
  }
}
