import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../data/models/enums.dart';
import '../models/parental_controls.dart';
import '../services/parental_controls_service.dart';

/// Educator / parent screen for configuring parental controls.
///
/// Controls include: daily time limits, usage schedule, blocked games,
/// blocked categories, and feature restrictions (shop, messaging, etc.).
class ParentalControlsScreen extends ConsumerStatefulWidget {
  const ParentalControlsScreen({super.key});

  @override
  ConsumerState<ParentalControlsScreen> createState() =>
      _ParentalControlsScreenState();
}

class _ParentalControlsScreenState
    extends ConsumerState<ParentalControlsScreen> {
  late ParentalControls _controls;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();
    _controls = ParentalControlsService.getControls();
  }

  void _update(ParentalControls updated) {
    setState(() {
      _controls = updated;
      _hasChanged = true;
    });
  }

  Future<void> _save() async {
    try {
      await ParentalControlsService.saveControls(_controls);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context,
          message: "Couldn't save parental controls: $e");
      return;
    }
    if (!mounted) return;
    AppSnackBar.success(context, message: 'Parental controls saved! \u2705');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parental Controls'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _hasChanged ? _save : null,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── Info Banner ─────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.sectionLearning.withValues(alpha: 0.12),
                  AppColors.sectionLearning.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.sectionLearning.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.sectionLearning.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.sectionLearning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sectionLearning.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: AppColors.sectionLearning, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Set restrictions to manage how students use the app. '
                    'These controls apply to all student profiles on this device.',
                    style: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Daily Time Limit ────────────
          const _SectionHeader(title: 'Daily Time Limit', icon: Icons.timer_rounded),
          const SizedBox(height: 8),

          SwitchListTile.adaptive(
            title: const Text('Enable Time Limit'),
            subtitle: Text(_controls.timeLimitEnabled
                ? '${_controls.dailyTimeLimitMinutes} minutes per day'
                : 'No time restriction'),
            secondary: Icon(Icons.hourglass_empty_rounded,
                color: hc.textSecondary),
            value: _controls.timeLimitEnabled,
            activeTrackColor: AppColors.primary,
            onChanged: (v) =>
                _update(_controls.copyWith(timeLimitEnabled: v)),
          ),

          if (_controls.timeLimitEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('${_controls.dailyTimeLimitMinutes} min',
                          style: AppTypography.titleSmall
                              .copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(_timeLimitLabel(_controls.dailyTimeLimitMinutes),
                          style: AppTypography.bodySmall
                              .copyWith(color: hc.textSecondary)),
                    ],
                  ),
                  Slider(
                    value: _controls.dailyTimeLimitMinutes.toDouble(),
                    min: 15,
                    max: 180,
                    divisions: 11,
                    label: '${_controls.dailyTimeLimitMinutes} min',
                    onChanged: (v) => _update(_controls.copyWith(
                        dailyTimeLimitMinutes: v.round())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('15 min',
                          style: AppTypography.labelSmall
                              .copyWith(color: hc.textSecondary)),
                      Text('3 hours',
                          style: AppTypography.labelSmall
                              .copyWith(color: hc.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          const Divider(height: 32),

          // ─── Usage Schedule ──────────────
          const _SectionHeader(
              title: 'Usage Schedule', icon: Icons.schedule_rounded),
          const SizedBox(height: 8),

          SwitchListTile.adaptive(
            title: const Text('Enable Schedule'),
            subtitle: Text(_controls.scheduleEnabled
                ? 'Allowed: ${_formatHour(_controls.allowedStartHour)} – ${_formatHour(_controls.allowedEndHour)}'
                : 'No time-of-day restriction'),
            secondary:
                Icon(Icons.access_time_rounded, color: hc.textSecondary),
            value: _controls.scheduleEnabled,
            activeTrackColor: AppColors.primary,
            onChanged: (v) =>
                _update(_controls.copyWith(scheduleEnabled: v)),
          ),

          if (_controls.scheduleEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _TimePickerTile(
                      label: 'Start',
                      hour: _controls.allowedStartHour,
                      onChanged: (h) =>
                          _update(_controls.copyWith(allowedStartHour: h)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('to', style: TextStyle(fontSize: 16)),
                  ),
                  Expanded(
                    child: _TimePickerTile(
                      label: 'End',
                      hour: _controls.allowedEndHour,
                      onChanged: (h) =>
                          _update(_controls.copyWith(allowedEndHour: h)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          const Divider(height: 32),

          // ─── Feature Restrictions ────────
          const _SectionHeader(
              title: 'Feature Restrictions', icon: Icons.block_rounded),
          const SizedBox(height: 8),

          SwitchListTile.adaptive(
            title: const Text('Block Star Shop'),
            subtitle: const Text('Prevent students from spending stars'),
            secondary:
                Icon(Icons.store_rounded, color: hc.textSecondary),
            value: _controls.shopBlocked,
            activeTrackColor: AppColors.error,
            onChanged: (v) =>
                _update(_controls.copyWith(shopBlocked: v)),
          ),

          SwitchListTile.adaptive(
            title: const Text('Block Multiplayer'),
            subtitle: const Text('Disable multiplayer quiz mode'),
            secondary: Icon(Icons.people_rounded, color: hc.textSecondary),
            value: _controls.multiplayerBlocked,
            activeTrackColor: AppColors.error,
            onChanged: (v) =>
                _update(_controls.copyWith(multiplayerBlocked: v)),
          ),

          SwitchListTile.adaptive(
            title: const Text('Block Messaging'),
            subtitle: const Text('Disable in-app messaging'),
            secondary:
                Icon(Icons.message_rounded, color: hc.textSecondary),
            value: _controls.messagingBlocked,
            activeTrackColor: AppColors.error,
            onChanged: (v) =>
                _update(_controls.copyWith(messagingBlocked: v)),
          ),

          const Divider(height: 32),

          // ─── Blocked Games ───────────────
          const _SectionHeader(
              title: 'Blocked Games', icon: Icons.sports_esports_rounded),
          const SizedBox(height: 8),
          Text(
            'Select games to hide from students',
            style:
                AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          ...GameType.values.map((gt) => CheckboxListTile.adaptive(
                title: Text(gt.label),
                secondary: Icon(gt.icon, color: gt.color),
                value: _controls.blockedGames.contains(gt),
                activeColor: AppColors.error,
                onChanged: (v) {
                  final games = Set<GameType>.from(_controls.blockedGames);
                  if (v == true) {
                    games.add(gt);
                  } else {
                    games.remove(gt);
                  }
                  _update(_controls.copyWith(blockedGames: games));
                },
              )),

          const Divider(height: 32),

          // ─── Blocked Categories ──────────
          const _SectionHeader(
              title: 'Blocked Categories',
              icon: Icons.category_rounded),
          const SizedBox(height: 8),
          Text(
            'Select categories to hide from flashcards & games',
            style:
                AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          ...FlashcardCategory.values.map((fc) => CheckboxListTile.adaptive(
                title: Text(fc.label),
                secondary: Icon(fc.icon, color: fc.color),
                value: _controls.blockedCategories.contains(fc),
                activeColor: AppColors.error,
                onChanged: (v) {
                  final cats =
                      Set<FlashcardCategory>.from(_controls.blockedCategories);
                  if (v == true) {
                    cats.add(fc);
                  } else {
                    cats.remove(fc);
                  }
                  _update(_controls.copyWith(blockedCategories: cats));
                },
              )),

          const SizedBox(height: 32),

          // ─── Reset Button ────────────────
          Center(
            child: TextButton.icon(
              onPressed: () {
                _update(const ParentalControls());
              },
              icon: const Icon(Icons.restart_alt_rounded,
                  color: AppColors.error),
              label: const Text(
                'Reset All Controls',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _timeLimitLabel(int minutes) {
    if (minutes <= 30) return 'Very Short';
    if (minutes <= 60) return 'Short';
    if (minutes <= 90) return 'Moderate';
    if (minutes <= 120) return 'Standard';
    return 'Extended';
  }

  String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h:00 $period';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: HCColor.of(context).textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final int hour;
  final ValueChanged<int> onChanged;

  const _TimePickerTile({
    required this.label,
    required this.hour,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: 0),
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
        if (picked != null) {
          onChanged(picked.hour);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hc.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: hc.textSecondary)),
            const SizedBox(height: 4),
            Text('$displayHour:00 $period',
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
