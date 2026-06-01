import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import 'dart:math';
import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../widgets/app_snack_bar.dart';
import '../../../providers/app_providers.dart';
import '../../../data/models/enums.dart';
import '../../../data/local/hive_service.dart';
import '../models/experiment_models.dart';
import '../services/experiment_service.dart';

/// Teacher-facing screen to configure experiment mode for students.
///
/// Allows assigning students to treatment (gamified) or control
/// (non-gamified) groups, or toggling individual gamification features.
class ExperimentSetupScreen extends ConsumerStatefulWidget {
  const ExperimentSetupScreen({super.key});

  @override
  ConsumerState<ExperimentSetupScreen> createState() =>
      _ExperimentSetupScreenState();
}

class _ExperimentSetupScreenState
    extends ConsumerState<ExperimentSetupScreen> {
  /// Maps profileId → ExperimentConfig for editing.
  final Map<String, ExperimentConfig> _configs = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() {
    final allProfiles = HiveService.getAllProfilesWithProgress();
    final students = allProfiles.where((p) => p.$1.role == UserRole.student);
    for (final (profile, _) in students) {
      _configs[profile.id] = ExperimentService.getConfig(profile.id);
    }
    setState(() => _loaded = true);
  }

  Future<void> _saveAll() async {
    for (final entry in _configs.entries) {
      await ExperimentService.saveConfig(entry.key, entry.value);
    }
    ref.read(hapticServiceProvider).success();
    if (mounted) {
      AppSnackBar.success(context, message: 'Experiment settings saved!');
    }
  }

  Future<void> _batchAssign(String group) async {
    final config = group == 'control'
        ? ExperimentConfig.control()
        : ExperimentConfig.treatment();
    setState(() {
      for (final id in _configs.keys) {
        _configs[id] = config;
      }
    });
  }

  /// Randomly assigns students 50/50 to treatment and control groups.
  void _randomize5050() {
    final ids = _configs.keys.toList()..shuffle(Random());
    final half = (ids.length / 2).ceil();
    setState(() {
      for (var i = 0; i < ids.length; i++) {
        _configs[ids[i]] =
            i < half ? ExperimentConfig.treatment() : ExperimentConfig.control();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isFilipino = settings.locale == 'fil';
    final padding = context.pagePadding;
    final colorScheme = Theme.of(context).colorScheme;

    final allProfiles = HiveService.getAllProfilesWithProgress();
    final students =
        allProfiles.where((p) => p.$1.role == UserRole.student).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isFilipino ? 'Mode ng Eksperimento' : 'Experiment Mode'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _saveAll,
            icon: const Icon(Icons.save_rounded),
            label: Text(isFilipino ? 'I-save' : 'Save All'),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    _buildInfoBanner(isFilipino, colorScheme),
                    const SizedBox(height: 20),
                    // Quick-assign buttons
                    _buildQuickAssign(isFilipino, colorScheme),
                    const SizedBox(height: 24),
                    // Per-student configs
                    Text(
                      isFilipino
                          ? 'Mga Mag-aaral (${students.length})'
                          : 'Students (${students.length})',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (students.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            isFilipino
                                ? 'Walang available na mag-aaral'
                                : 'No students available',
                            style: AppTypography.bodyMedium.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      ...students.asMap().entries.map((entry) {
                        final profile = entry.value.$1;
                        final config = _configs[profile.id] ??
                            const ExperimentConfig();
                        return _buildStudentCard(
                          profile,
                          config,
                          isFilipino,
                          colorScheme,
                        ).animate().fadeIn(
                              duration: 300.ms,
                              delay: Duration(
                                  milliseconds: 50 * entry.key),
                            );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoBanner(bool isFilipino, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_rounded,
              color: Colors.amber.shade800, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFilipino
                      ? 'Pang-pananaliksik na Mode'
                      : 'Research Experiment Mode',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFilipino
                      ? 'I-assign ang mga mag-aaral sa treatment (may gamification) '
                        'o control (walang gamification) group para sa iyong thesis experiment.'
                      : 'Assign students to treatment (with gamification) or control '
                        '(without gamification) groups for your thesis experiment.',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildQuickAssign(bool isFilipino, ColorScheme colorScheme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickPresetButton(
                label: isFilipino ? 'Lahat → Treatment' : 'All → Treatment',
                emoji: '🎮',
                color: Colors.green,
                onTap: () => _batchAssign('treatment'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickPresetButton(
                label: isFilipino ? 'Lahat → Control' : 'All → Control',
                emoji: '📚',
                color: Colors.blue,
                onTap: () => _batchAssign('control'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickPresetButton(
                label: isFilipino ? 'Random 50/50' : 'Randomize 50/50',
                emoji: '🎲',
                color: Colors.deepPurple,
                onTap: () {
                  _randomize5050();
                  if (mounted) {
                    final t = _configs.values
                        .where((c) =>
                            c.enabled && c.groupLabel == 'treatment')
                        .length;
                    final c = _configs.values
                        .where((c) =>
                            c.enabled && c.groupLabel == 'control')
                        .length;
                    AppSnackBar.success(
                      context,
                      message: isFilipino
                          ? '$t treatment, $c control — random na na-assign!'
                          : '$t treatment, $c control — randomly assigned!',
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickPresetButton(
                label: isFilipino ? 'I-reset Lahat' : 'Reset All',
                emoji: '🔄',
                color: Colors.grey,
                onTap: () {
                  setState(() {
                    for (final id in _configs.keys) {
                      _configs[id] = const ExperimentConfig();
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStudentCard(
    dynamic profile,
    ExperimentConfig config,
    bool isFilipino,
    ColorScheme colorScheme,
  ) {
    final groupColor = !config.enabled
        ? Colors.grey
        : config.groupLabel == 'control'
            ? Colors.blue
            : Colors.green;
    final groupText = !config.enabled
        ? (isFilipino ? 'Normal' : 'Normal')
        : config.groupLabel == 'control'
            ? 'Control'
            : 'Treatment';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: groupColor.withValues(alpha: 0.3),
          width: config.enabled ? 1.5 : 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: groupColor.withValues(alpha: 0.15),
          child: Text(
            profile.name.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: groupColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          profile.name,
          style: AppTypography.titleSmall
              .copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: groupColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                groupText,
                style: AppTypography.labelSmall.copyWith(
                  color: groupColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (config.enabled)
              Text(
                '${GamificationFeature.values.length - config.disabledFeatures.length}'
                '/${GamificationFeature.values.length} features',
                style: AppTypography.labelSmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (config.enabled && config.assignedAt != null)
              Text(
                '${isFilipino ? 'Na-assign' : 'Assigned'} '
                '${config.assignedAt!.toIso8601String().split('T').first}',
                style: AppTypography.labelSmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        children: [
          // Group toggle
          Row(
            children: [
              Expanded(
                child: _GroupButton(
                  label: isFilipino ? 'Normal' : 'Normal',
                  selected: !config.enabled,
                  color: Colors.grey,
                  onTap: () => setState(() {
                    _configs[profile.id] =
                        const ExperimentConfig();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GroupButton(
                  label: 'Treatment',
                  selected:
                      config.enabled && config.groupLabel == 'treatment',
                  color: Colors.green,
                  onTap: () => setState(() {
                    _configs[profile.id] =
                        ExperimentConfig.treatment();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GroupButton(
                  label: 'Control',
                  selected:
                      config.enabled && config.groupLabel == 'control',
                  color: Colors.blue,
                  onTap: () => setState(() {
                    _configs[profile.id] =
                        ExperimentConfig.control();
                  }),
                ),
              ),
            ],
          ),
          if (config.enabled) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            Text(
              isFilipino
                  ? 'Mga feature ng gamification:'
                  : 'Gamification features:',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...GamificationFeature.values.map((feature) {
              final isOn = config.isFeatureEnabled(feature);
              return SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  isFilipino ? feature.labelFilipino : feature.label,
                  style: AppTypography.bodySmall,
                ),
                subtitle: Text(
                  feature.description,
                  style: AppTypography.labelSmall.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                value: isOn,
                onChanged: (value) {
                  final disabled = Set<GamificationFeature>.from(
                      config.disabledFeatures);
                  if (value) {
                    disabled.remove(feature);
                  } else {
                    disabled.add(feature);
                  }
                  setState(() {
                    _configs[profile.id] = config.copyWith(
                      disabledFeatures: disabled,
                    );
                  });
                },
              );
            }),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _QuickPresetButton extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _QuickPresetButton({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _GroupButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label group',
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: selected ? color : null,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
