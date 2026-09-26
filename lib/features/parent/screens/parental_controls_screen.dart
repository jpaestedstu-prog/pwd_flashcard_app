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
import '../../../core/widgets/fit_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

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
      debugPrint('Parental controls save failed: $e');
      AppSnackBar.error(context, message: _t(context).pcSaveFailed);
      return;
    }
    if (!mounted) return;
    AppSnackBar.success(context, message: _t(context).pcSaved);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context).pcTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _hasChanged ? _save : null,
              child: Text(_t(context).gmSave),
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
                    _t(context).pcIntro,
                    style: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ─── Daily Time Limit ────────────
          _SectionHeader(title: _t(context).pcDaily, icon: Icons.timer_rounded),
          const SizedBox(height: 8),

          SwitchListTile.adaptive(
            title: Text(_t(context).pcEnableLimit),
            subtitle: Builder(
              builder: (context) {
                final text = _controls.timeLimitEnabled
                    ? _t(context).pcMinutesPerDay(_controls.dailyTimeLimitMinutes)
                    : _t(context).pcNoRestriction;
                // A ListTile subtitle shares its row with the switch, so the
                // column is narrow: "restr / iction" at a large scale.
                return Text(
                  text,
                  style: fittedStyle(
                    context,
                    text,
                    Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              },
            ),
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
                      Text(_t(context).pcMin(_controls.dailyTimeLimitMinutes),
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
                    label: _t(context).pcMin(_controls.dailyTimeLimitMinutes),
                    onChanged: (v) => _update(_controls.copyWith(
                        dailyTimeLimitMinutes: v.round())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t(context).pc15,
                          style: AppTypography.labelSmall
                              .copyWith(color: hc.textSecondary)),
                      Text(_t(context).pc3h,
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
          _SectionHeader(
              title: _t(context).pcSchedule, icon: Icons.schedule_rounded),
          const SizedBox(height: 8),

          SwitchListTile.adaptive(
            title: Text(_t(context).pcEnableSchedule),
            subtitle: Text(_controls.scheduleEnabled
                ? _t(context).pcAllowed(
                    _formatHour(_controls.allowedStartHour),
                    _formatHour(_controls.allowedEndHour),
                  )
                : _t(context).pcNoTimeOfDay),
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
                      label: _t(context).pcStart,
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
                      label: _t(context).pcEnd,
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
          _SectionHeader(
              title: _t(context).pcFeatures, icon: Icons.block_rounded),
          const SizedBox(height: 8),

          SwitchListTile.adaptive(
            title: Text(_t(context).pcBlockShop),
            subtitle: Text(_t(context).pcBlockShopSub),
            secondary:
                Icon(Icons.store_rounded, color: hc.textSecondary),
            value: _controls.shopBlocked,
            activeTrackColor: AppColors.error,
            onChanged: (v) =>
                _update(_controls.copyWith(shopBlocked: v)),
          ),

          SwitchListTile.adaptive(
            title: Text(_t(context).pcBlockMulti),
            subtitle: Text(_t(context).pcBlockMultiSub),
            secondary: Icon(Icons.people_rounded, color: hc.textSecondary),
            value: _controls.multiplayerBlocked,
            activeTrackColor: AppColors.error,
            onChanged: (v) =>
                _update(_controls.copyWith(multiplayerBlocked: v)),
          ),

          SwitchListTile.adaptive(
            title: Text(_t(context).pcBlockMsg),
            subtitle: Text(_t(context).pcBlockMsgSub),
            secondary:
                Icon(Icons.message_rounded, color: hc.textSecondary),
            value: _controls.messagingBlocked,
            activeTrackColor: AppColors.error,
            onChanged: (v) =>
                _update(_controls.copyWith(messagingBlocked: v)),
          ),

          const Divider(height: 32),

          // ─── Blocked Games ───────────────
          _SectionHeader(
              title: _t(context).pcBlockedGames, icon: Icons.sports_esports_rounded),
          const SizedBox(height: 8),
          Text(
            _t(context).pcBlockedGamesSub,
            style:
                AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          ...GameType.values.map((gt) => CheckboxListTile.adaptive(
                title: Text(gt.labelOf(_t(context))),
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
          _SectionHeader(
              title: _t(context).pcBlockedCats,
              icon: Icons.category_rounded),
          const SizedBox(height: 8),
          Text(
            _t(context).pcBlockedCatsSub,
            style:
                AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 8),
          ...FlashcardCategory.values.map((fc) => CheckboxListTile.adaptive(
                title: Text(fc.labelOf(_t(context))),
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
              label: Text(
                _t(context).pcReset,
                style: TextStyle(color: HCColor.of(context).errorText),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _timeLimitLabel(int minutes) {
    if (minutes <= 30) return _t(context).pcVeryShort;
    if (minutes <= 60) return _t(context).pcShort;
    if (minutes <= 90) return _t(context).pcModerate;
    if (minutes <= 120) return _t(context).pcStandard;
    return _t(context).pcExtended;
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

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
