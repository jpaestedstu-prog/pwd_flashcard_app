import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/shared_widgets.dart';
import '../models/goal_model.dart';
import '../services/goal_service.dart';
import '../../../widgets/app_back_button.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final padding = context.pagePadding;
    final hc = HCColor.of(context);

    final active = goals.where((g) => g.status == GoalStatus.active).toList();
    final completed =
        goals.where((g) => g.status == GoalStatus.completed).toList();
    final expired =
        goals.where((g) => g.status == GoalStatus.expired).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'My Goals',
                        style: AppTypography.headlineLarge.copyWith(
                          color: hc.textPrimary,
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.05, end: 0),
              ),
            ),

            // ─── Summary Card ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
                child: _SummaryCard(
                  activeCount: active.length,
                  completedCount: completed.length,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms)
                    .slideY(begin: 0.08, end: 0),
              ),
            ),

            // ─── Active Goals Section ──────────────
            if (active.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
                  child: SectionHeader(
                    title: 'Active Goals',
                    icon: Icons.flag_rounded,
                    color: hc.textPrimary,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final goal = active[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GoalCard(
                          goal: goal,
                          onDismiss: () => _removeGoal(goal.id),
                        )
                            .animate()
                            .fadeIn(
                              duration: 350.ms,
                              delay: (100 + index * 50).ms,
                            )
                            .slideY(begin: 0.05, end: 0),
                      );
                    },
                    childCount: active.length,
                  ),
                ),
              ),
            ],

            // ─── Empty State ───────────────────────
            if (active.isEmpty && completed.isEmpty && expired.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 60, padding, 0),
                  child: Column(
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text(
                        'No goals yet',
                        style: AppTypography.headlineSmall.copyWith(
                          color: hc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set a learning goal to stay motivated!',
                        style: AppTypography.bodyMedium.copyWith(
                          color: hc.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 200.ms),
                ),
              ),

            // ─── Completed Goals Section ───────────
            if (completed.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
                  child: SectionHeader(
                    title: 'Completed (${completed.length})',
                    icon: Icons.check_circle_rounded,
                    color: hc.success,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final goal = completed[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GoalCard(
                          goal: goal,
                          onDismiss: () => _removeGoal(goal.id),
                        ),
                      );
                    },
                    childCount: completed.length,
                  ),
                ),
              ),
            ],

            // ─── Expired Goals Section ─────────────
            if (expired.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 0),
                  child: SectionHeader(
                    title: 'Expired (${expired.length})',
                    icon: Icons.timer_off_rounded,
                    color: hc.textSecondary,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final goal = expired[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GoalCard(
                          goal: goal,
                          onDismiss: () => _removeGoal(goal.id),
                        ),
                      );
                    },
                    childCount: expired.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGoalDialog,
        backgroundColor: AppColors.primary,
        icon: Icon(Icons.add_rounded, color: HCColor.of(context).textOnPrimary),
        label: Text(
          'New Goal',
          style: AppTypography.labelLarge.copyWith(color: HCColor.of(context).textOnPrimary),
        ),
      ),
    );
  }

  void _removeGoal(String goalId) {
    ref.read(goalsProvider.notifier).removeGoal(goalId);
    ref.read(hapticServiceProvider).lightTap();
  }

  void _showCreateGoalDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateGoalSheet(
        onSave: (goal) {
          ref.read(goalsProvider.notifier).addGoal(goal);
          ref.read(hapticServiceProvider).mediumTap();
        },
        profileId: ref.read(profileProvider)?.id ?? 'default',
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int activeCount;
  final int completedCount;

  const _SummaryCard({
    required this.activeCount,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Goal Tracker',
                  style: AppTypography.titleLarge.copyWith(
                    color: hc.textOnPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activeCount active · $completedCount completed',
                  style: AppTypography.bodyMedium.copyWith(
                    color: hc.textOnPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Goal Card ─────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final LearningGoal goal;
  final VoidCallback onDismiss;

  const _GoalCard({required this.goal, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final isCompleted = goal.status == GoalStatus.completed;
    final isExpired = goal.status == GoalStatus.expired;

    final progressColor = isCompleted
        ? AppColors.success
        : isExpired
            ? hc.textSecondary
            : AppColors.primary;

    return Dismissible(
      key: Key(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.textOnPrimary),
      ),
      onDismissed: (_) => onDismiss(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hc.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: hc.border),
          boxShadow: [
            BoxShadow(
              color: progressColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: progressColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    goal.type.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: AppTypography.titleSmall.copyWith(
                          color: hc.textPrimary,
                          fontWeight: FontWeight.w700,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${goal.currentValue} / ${goal.targetValue} ${goal.type.label.toLowerCase()}',
                        style: AppTypography.bodySmall.copyWith(
                          color: hc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 28,
                  ),
                if (isExpired)
                  Icon(
                    Icons.timer_off_rounded,
                    color: hc.textSecondary,
                    size: 28,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearPercentIndicator(
              lineHeight: 10,
              percent: goal.progressPercent,
              backgroundColor: hc.surfaceLight,
              progressColor: progressColor,
              barRadius: const Radius.circular(5),
              padding: EdgeInsets.zero,
              animation: true,
              animationDuration: 600,
            ),
            if (goal.deadline != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: hc.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDeadline(goal.deadline!),
                    style: AppTypography.labelSmall.copyWith(
                      color: isExpired ? AppColors.error : hc.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now).inDays;
    if (diff < 0) return 'Expired';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    return 'Due in $diff days';
  }
}

// ─── Create Goal Sheet ─────────────────────────────────────

class _CreateGoalSheet extends StatefulWidget {
  final void Function(LearningGoal goal) onSave;
  final String profileId;

  const _CreateGoalSheet({
    required this.onSave,
    required this.profileId,
  });

  @override
  State<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<_CreateGoalSheet> {
  GoalType _selectedType = GoalType.wordsLearned;
  int _targetValue = 10;
  bool _hasDeadline = false;
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  FlashcardCategory? _selectedCategory;

  final _presets = <GoalType, List<int>>{
    GoalType.wordsLearned: [5, 10, 25, 50],
    GoalType.gamesCompleted: [3, 5, 10, 20],
    GoalType.categoryMastery: [50, 70, 80, 90],
    GoalType.streakDays: [3, 7, 14, 30],
    GoalType.starsEarned: [10, 25, 50, 100],
  };

  String get _goalTitle {
    final suffix = _selectedType == GoalType.categoryMastery
        ? (_selectedCategory?.label ?? 'a category')
        : '';
    return switch (_selectedType) {
      GoalType.wordsLearned => 'Learn $_targetValue words',
      GoalType.gamesCompleted => 'Complete $_targetValue games',
      GoalType.categoryMastery => 'Reach $_targetValue% mastery in $suffix',
      GoalType.streakDays => 'Maintain a $_targetValue-day streak',
      GoalType.starsEarned => 'Earn $_targetValue stars',
    };
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: hc.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Set a New Goal',
              style: AppTypography.headlineSmall.copyWith(
                color: hc.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // ─── Goal Type Selector ────────────
            Text(
              'What do you want to achieve?',
              style: AppTypography.titleSmall.copyWith(
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GoalType.values.map((type) {
                final selected = _selectedType == type;
                return ChoiceChip(
                  label: Text('${type.emoji} ${type.label}'),
                  selected: selected,
                  onSelected: (val) => setState(() {
                    _selectedType = type;
                    _targetValue = _presets[type]![1];
                    if (type != GoalType.categoryMastery) {
                      _selectedCategory = null;
                    }
                  }),
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: hc.surfaceLight,
                  labelStyle: AppTypography.labelLarge.copyWith(
                    color: selected ? AppColors.primaryDark : hc.textPrimary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ─── Category Picker (for mastery goals) ─
            if (_selectedType == GoalType.categoryMastery) ...[
              Text(
                'Which category?',
                style: AppTypography.titleSmall.copyWith(
                  color: hc.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FlashcardCategory.values.map((cat) {
                  final selected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon, size: 16),
                        const SizedBox(width: 4),
                        Text(cat.label),
                      ],
                    ),
                    selected: selected,
                    onSelected: (val) =>
                        setState(() => _selectedCategory = cat),
                    selectedColor: cat.color.withValues(alpha: 0.3),
                    backgroundColor: hc.surfaceLight,
                    labelStyle: AppTypography.labelMedium.copyWith(
                      color: selected ? cat.color : hc.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // ─── Target Value ──────────────────
            Text(
              'Target',
              style: AppTypography.titleSmall.copyWith(
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_presets[_selectedType] ?? [10]).map((val) {
                final selected = _targetValue == val;
                final suffix =
                    _selectedType == GoalType.categoryMastery ? '%' : '';
                return ChoiceChip(
                  label: Text('$val$suffix'),
                  selected: selected,
                  onSelected: (s) => setState(() => _targetValue = val),
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: hc.surfaceLight,
                  labelStyle: AppTypography.labelLarge.copyWith(
                    color: selected ? AppColors.primaryDark : hc.textPrimary,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ─── Deadline Toggle ───────────────
            SwitchListTile(
              title: Text(
                'Set a deadline',
                style: AppTypography.titleSmall.copyWith(
                  color: hc.textPrimary,
                ),
              ),
              value: _hasDeadline,
              onChanged: (val) => setState(() => _hasDeadline = val),
              activeTrackColor: AppColors.primaryLight,
              thumbColor: const WidgetStatePropertyAll(AppColors.primary),
              contentPadding: EdgeInsets.zero,
            ),
            if (_hasDeadline) ...[
              Row(
                children: [
                  for (final days in [3, 7, 14, 30]) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            _deadline =
                                DateTime.now().add(Duration(days: days));
                          }),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: hc.border),
                          ),
                          child: Text(
                            '${days}d',
                            style: AppTypography.labelMedium.copyWith(
                              color: hc.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),

            // ─── Preview ───────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hc.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _goalTitle,
                style: AppTypography.titleSmall.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Save Button ───────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Create Goal',
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSave {
    if (_selectedType == GoalType.categoryMastery &&
        _selectedCategory == null) {
      return false;
    }
    return true;
  }

  void _save() {
    final goal = GoalService.createGoal(
      title: _goalTitle,
      type: _selectedType,
      targetValue: _targetValue,
      createdBy: widget.profileId,
      deadline: _hasDeadline ? _deadline : null,
      category: _selectedCategory,
    );
    widget.onSave(goal);
    Navigator.of(context).pop();
  }
}
