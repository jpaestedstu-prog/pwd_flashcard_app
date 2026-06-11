import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/accessibility/haptic_service.dart' show hapticServiceProvider;
import '../../../data/local/hive_service.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../models/focus_mode_models.dart';

class FocusModeScreen extends ConsumerStatefulWidget {
  const FocusModeScreen({super.key});

  @override
  ConsumerState<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends ConsumerState<FocusModeScreen> {
  // Timer state
  FocusDuration _selectedDuration = FocusDuration.medium;
  int _customMinutes = 15;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isCompleted = false;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  Timer? _timer;
  DateTime? _startTime;

  // History
  List<FocusSession> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadHistory() {
    final profile = ref.read(profileProvider);
    if (profile != null) {
      _history = HiveService.getFocusSessions(profile.id);
    }
  }

  void _startTimer() {
    final minutes = _selectedDuration == FocusDuration.custom
        ? _customMinutes
        : _selectedDuration.defaultMinutes;
    _totalSeconds = minutes * 60;
    _remainingSeconds = _totalSeconds;
    _startTime = DateTime.now();
    _isRunning = true;
    _isPaused = false;
    _isCompleted = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 0) {
        _onTimerComplete();
      } else {
        setState(() => _remainingSeconds--);
      }
    });

    ref.read(hapticServiceProvider).mediumTap();
    setState(() {});
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isPaused = true);
    ref.read(hapticServiceProvider).lightTap();
  }

  void _resumeTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 0) {
        _onTimerComplete();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
    setState(() => _isPaused = false);
    ref.read(hapticServiceProvider).lightTap();
  }

  void _stopTimer() {
    _timer?.cancel();
    _saveSession(completed: false);
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isCompleted = false;
    });
    ref.read(hapticServiceProvider).lightTap();
  }

  Future<void> _onTimerComplete() async {
    _timer?.cancel();
    await _saveSession(completed: true);
    ref.read(hapticServiceProvider).celebration();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isCompleted = true;
    });
  }

  Future<void> _saveSession({required bool completed}) async {
    final profile = ref.read(profileProvider);
    if (profile == null || _startTime == null) return;

    final minutes = _selectedDuration == FocusDuration.custom
        ? _customMinutes
        : _selectedDuration.defaultMinutes;
    final starsEarned = completed ? (minutes ~/ 10).clamp(1, 3) : 0;

    final session = FocusSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      profileId: profile.id,
      durationMinutes: minutes,
      startedAt: _startTime!,
      endedAt: DateTime.now(),
      completed: completed,
      starsEarned: starsEarned,
    );

    _history.add(session);
    // Keep last 50 sessions
    if (_history.length > 50) {
      _history.removeRange(0, _history.length - 50);
    }
    await HiveService.saveFocusSessions(profile.id, _history);

    if (completed && starsEarned > 0) {
      ref.read(progressProvider.notifier).addStars(starsEarned);
      if (mounted) {
        final settings = ref.read(settingsProvider);
        final isFilipino = settings.locale == 'fil';
        AppSnackBar.success(
          context,
          message: isFilipino
              ? 'Mahusay! +$starsEarned ⭐'
              : 'Great focus! +$starsEarned ⭐',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.pagePadding;
    final hc = HCColor.of(context);
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';

    final completedToday = _history
        .where((s) =>
            s.completed &&
            s.startedAt.year == DateTime.now().year &&
            s.startedAt.month == DateTime.now().month &&
            s.startedAt.day == DateTime.now().day)
        .length;
    final totalMinutesToday = _history
        .where((s) =>
            s.completed &&
            s.startedAt.year == DateTime.now().year &&
            s.startedAt.month == DateTime.now().month &&
            s.startedAt.day == DateTime.now().day)
        .fold(0, (sum, s) => sum + s.durationMinutes);

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Focus Mode' : 'Focus Mode'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: isFilipino ? 'Kasaysayan' : 'History',
              onPressed: () => _showHistory(context, hc, isFilipino),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              // ─── Today's Stats ──────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatsCard(
                      emoji: '🎯',
                      value: '$completedToday',
                      label: isFilipino ? 'Sesyon Ngayon' : 'Sessions Today',
                      color: hc.primary,
                      hc: hc,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatsCard(
                      emoji: '⏱️',
                      value: '$totalMinutesToday min',
                      label: isFilipino ? 'Oras ng Focus' : 'Focus Time',
                      color: hc.success,
                      hc: hc,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 32),

              // ─── Timer Display ──────────────────
              if (_isRunning || _isCompleted) ...[
                _buildTimerDisplay(hc, isFilipino),
              ] else ...[
                _buildDurationPicker(hc, isFilipino),
              ],

              const SizedBox(height: 32),

              // ─── Timer Controls ──────────────────
              _buildControls(hc, isFilipino),

              if (_isCompleted) ...[
                const SizedBox(height: 24),
                _buildCompletionCard(hc, isFilipino),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(HCColor hc, bool isFilipino) {
    final progress = _totalSeconds > 0
        ? 1.0 - (_remainingSeconds / _totalSeconds)
        : 0.0;
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    // Timer ring scales by screen tier so it stays a focal point on
    // tablets without dwarfing phones. Stroke width follows the same
    // tier so the ring stays proportional.
    final timerSize = context.responsiveTier<double>(
      phone: 220,
      tablet: 300,
      large: 360,
      xl: 420,
      ultra: 480,
    );
    final strokeWidth = context.responsiveTier<double>(
      phone: 12,
      tablet: 14,
      large: 16,
      xl: 18,
      ultra: 20,
    );

    return Column(
      children: [
        SizedBox(
          width: timerSize,
          height: timerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: timerSize,
                height: timerSize,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: strokeWidth,
                  backgroundColor: hc.border,
                  valueColor: AlwaysStoppedAnimation(
                    _isCompleted ? hc.success : hc.primary,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isCompleted ? '✅' : (_isPaused ? '⏸️' : '🧘'),
                    style: const TextStyle(fontSize: 36),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCompleted
                        ? (isFilipino ? 'Tapos na!' : 'Done!')
                        : timeStr,
                    style: AppTypography.headlineLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hc.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (_isPaused)
                    Text(
                      isFilipino ? 'Naka-pause' : 'Paused',
                      style: AppTypography.labelMedium.copyWith(
                        color: hc.warning,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildDurationPicker(HCColor hc, bool isFilipino) {
    return Column(
      children: [
        const Text(
          '🧘',
          style: TextStyle(fontSize: 64),
        ).animate().scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 600.ms,
              curve: Curves.elasticOut,
            ),
        const SizedBox(height: 16),
        Text(
          isFilipino
              ? 'Pumili ng tagal ng focus'
              : 'Choose your focus time',
          style: AppTypography.titleMedium.copyWith(color: hc.textPrimary),
        ),
        const SizedBox(height: 24),

        // Duration options
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: FocusDuration.values
              .where((d) => d != FocusDuration.custom)
              .map((d) => _DurationChip(
                    duration: d,
                    isSelected: _selectedDuration == d,
                    onTap: () => setState(() => _selectedDuration = d),
                    hc: hc,
                    isFilipino: isFilipino,
                  ))
              .toList(),
        ),

        const SizedBox(height: 12),

        // Custom duration
        _DurationChip(
          duration: FocusDuration.custom,
          isSelected: _selectedDuration == FocusDuration.custom,
          onTap: () => setState(() => _selectedDuration = FocusDuration.custom),
          hc: hc,
          isFilipino: isFilipino,
        ),

        if (_selectedDuration == FocusDuration.custom) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _customMinutes > 5
                    ? () => setState(() => _customMinutes -= 5)
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  '$_customMinutes min',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hc.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: _customMinutes < 60
                    ? () => setState(() => _customMinutes += 5)
                    : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildControls(HCColor hc, bool isFilipino) {
    if (_isCompleted) {
      return Semantics(
        button: true,
        label: isFilipino ? 'Magsimula ulit' : 'Start again',
        child: FilledButton.icon(
          onPressed: () => setState(() => _isCompleted = false),
          icon: const Icon(Icons.replay_rounded),
          label: Text(isFilipino ? 'Ulitin' : 'Start Again'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      );
    }

    if (!_isRunning) {
      return Semantics(
        button: true,
        label: isFilipino ? 'Simulan ang focus timer' : 'Start focus timer',
        child: FilledButton.icon(
          onPressed: _startTimer,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(isFilipino ? 'Magsimula' : 'Start Focus'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ).animate().scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1.0, 1.0),
            duration: 400.ms,
          );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          label: isFilipino ? 'Itigil' : 'Stop',
          child: OutlinedButton.icon(
            onPressed: _stopTimer,
            icon: const Icon(Icons.stop_rounded),
            label: Text(isFilipino ? 'Itigil' : 'Stop'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              foregroundColor: hc.error,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Semantics(
          button: true,
          label: _isPaused
              ? (isFilipino ? 'Ituloy' : 'Resume')
              : (isFilipino ? 'I-pause' : 'Pause'),
          child: FilledButton.icon(
            onPressed: _isPaused ? _resumeTimer : _pauseTimer,
            icon: Icon(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            label: Text(
                _isPaused
                    ? (isFilipino ? 'Ituloy' : 'Resume')
                    : (isFilipino ? 'I-pause' : 'Pause')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionCard(HCColor hc, bool isFilipino) {
    final minutes = _selectedDuration == FocusDuration.custom
        ? _customMinutes
        : _selectedDuration.defaultMinutes;
    final starsEarned = (minutes ~/ 10).clamp(1, 3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hc.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('🌟', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            isFilipino ? 'Mahusay na Focus!' : 'Great Focus Session!',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: hc.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isFilipino
                ? 'Nag-focus ka ng $minutes minuto. +$starsEarned ⭐'
                : 'You focused for $minutes minutes. +$starsEarned ⭐',
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  void _showHistory(BuildContext context, HCColor hc, bool isFilipino) {
    final completed = _history.where((s) => s.completed).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
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
              const SizedBox(height: 16),
              Text(
                isFilipino ? 'Kasaysayan ng Focus' : 'Focus History',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: hc.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: completed.isEmpty
                    ? Center(
                        child: Text(
                          isFilipino
                              ? 'Wala pang nakumpletong sesyon.'
                              : 'No completed sessions yet.',
                          style: AppTypography.bodyMedium
                              .copyWith(color: hc.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: completed.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final s = completed[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  hc.success.withValues(alpha: 0.15),
                              child: const Text('🎯'),
                            ),
                            title: Text(
                              '${s.durationMinutes} ${isFilipino ? 'minuto' : 'minutes'}',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              _formatDateTime(s.startedAt, isFilipino),
                              style: AppTypography.bodySmall
                                  .copyWith(color: hc.textSecondary),
                            ),
                            trailing: Text(
                              '+${s.starsEarned} ⭐',
                              style: AppTypography.labelMedium.copyWith(
                                color: hc.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime d, bool isFilipino) {
    final months = isFilipino
        ? ['Ene', 'Peb', 'Mar', 'Abr', 'May', 'Hun',
           'Hul', 'Ago', 'Set', 'Okt', 'Nob', 'Dis']
        : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, $hour:${d.minute.toString().padLeft(2, '0')} $ampm';
  }
}

class _StatsCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color color;
  final HCColor hc;

  const _StatsCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
    required this.hc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final FocusDuration duration;
  final bool isSelected;
  final VoidCallback onTap;
  final HCColor hc;
  final bool isFilipino;

  const _DurationChip({
    required this.duration,
    required this.isSelected,
    required this.onTap,
    required this.hc,
    required this.isFilipino,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: isFilipino ? duration.labelFilipino : duration.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? hc.primary.withValues(alpha: 0.2)
                : hc.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? hc.primary : hc.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(duration.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                isFilipino ? duration.labelFilipino : duration.label,
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? hc.primary : hc.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
