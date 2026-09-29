import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/localized_date.dart';
import '../models/alert_models.dart';
import '../services/alert_service.dart';
import '../../../widgets/app_back_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Screen for configuring alert preferences.
///
/// Parents and teachers can:
/// - Toggle alerts globally
/// - Set accuracy threshold
/// - Set inactivity days
/// - Toggle individual alert types
/// - View and clear alert history
class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  late AlertConfig _config;
  List<AlertEntry> _alerts = [];

  @override
  void initState() {
    super.initState();
    _config = AlertService.getConfig();
    _alerts = AlertService.getAlerts();
  }

  Future<void> _saveConfig(AlertConfig config) async {
    setState(() => _config = config);
    await AlertService.saveConfig(config);
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return Scaffold(
      backgroundColor: hc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          _t(context).asTitle,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ─── Global Toggle ─────────────
          _SectionCard(
            hc: hc,
            child: SwitchListTile(
              title: Text(
                _t(context).asEnable,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
              subtitle: Text(
                _t(context).asEnableSub,
                style: AppTypography.bodySmall
                    .copyWith(color: hc.textSecondary),
              ),
              value: _config.enabled,
              onChanged: (val) =>
                  _saveConfig(_config.copyWith(enabled: val)),
              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
              thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? AppColors.primary
                      : null),
              secondary: Icon(
                Icons.notifications_active_rounded,
                color: _config.enabled ? HCColor.of(context).primary : hc.textHint,
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 12),

          // ─── Thresholds ────────────────
          if (_config.enabled) ...[
            _SectionCard(
              hc: hc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      _t(context).asThresholds,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                  ),

                  // Accuracy threshold
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Icon(Icons.percent_rounded,
                            size: 18, color: HCColor.of(context).graphic(AppColors.warning)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _t(context).asAccuracyBelow,
                            style: AppTypography.bodySmall
                                .copyWith(color: hc.textPrimary),
                          ),
                        ),
                        Text(
                          '${(_config.accuracyThreshold * 100).round()}%',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: HCColor.of(context).primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Slider(
                    value: _config.accuracyThreshold,
                    min: 0.2,
                    max: 0.8,
                    divisions: 12,
                    activeColor: AppColors.primary,
                    label:
                        '${(_config.accuracyThreshold * 100).round()}%',
                    onChanged: (val) => _saveConfig(
                        _config.copyWith(accuracyThreshold: val)),
                  ),

                  const Divider(height: 1),

                  // Inactivity days
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Icon(Icons.timer_off_rounded,
                            size: 18, color: HCColor.of(context).graphic(AppColors.info)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _t(context).asInactivityAfter,
                            style: AppTypography.bodySmall
                                .copyWith(color: hc.textPrimary),
                          ),
                        ),
                        Text(
                          _t(context).asDays(_config.inactivityDays),
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: HCColor.of(context).primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Slider(
                    value: _config.inactivityDays.toDouble(),
                    min: 1,
                    max: 14,
                    divisions: 13,
                    activeColor: AppColors.primary,
                    label: _t(context).asDays(_config.inactivityDays),
                    onChanged: (val) => _saveConfig(
                        _config.copyWith(inactivityDays: val.round())),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 50.ms),

            const SizedBox(height: 12),

            // ─── Alert Type Toggles ──────
            _SectionCard(
              hc: hc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      _t(context).asTypes,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hc.textPrimary,
                      ),
                    ),
                  ),
                  ...AlertType.values.map((type) {
                    final enabled =
                        _config.enabledTypes.contains(type);
                    return CheckboxListTile(
                      title: Row(
                        children: [
                          Text(type.emoji,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            _alertTypeLabel(_t(context), type),
                            style: AppTypography.bodySmall.copyWith(
                              color: hc.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      value: enabled,
                      onChanged: (val) {
                        final types =
                            Set<AlertType>.from(_config.enabledTypes);
                        if (val == true) {
                          types.add(type);
                        } else {
                          types.remove(type);
                        }
                        _saveConfig(
                            _config.copyWith(enabledTypes: types));
                      },
                      activeColor: AppColors.primary,
                      dense: true,
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

            const SizedBox(height: 16),

            // ─── Alert History ───────────
            Row(
              children: [
                Icon(Icons.history_rounded,
                    color: hc.textSecondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  _t(context).asRecent(_alerts.length),
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_alerts.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await AlertService.clearAlerts();
                      if (!mounted) return;
                      setState(() => _alerts = []);
                    },
                    child: Text(
                      _t(context).tcClear,
                      style: AppTypography.labelSmall
                          .copyWith(color: HCColor.of(context).errorText),
                    ),
                  ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 150.ms),

            const SizedBox(height: 8),

            if (_alerts.isEmpty)
              _SectionCard(
                hc: hc,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 40, color: hc.textHint),
                      const SizedBox(height: 8),
                      Text(
                        _t(context).asNone,
                        style: AppTypography.bodySmall
                            .copyWith(color: hc.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...(_alerts.take(20).toList().asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AlertTile(
                        alert: entry.value,
                        hc: hc,
                        onMarkRead: () async {
                          await AlertService.markRead(
                              entry.value.id);
                          setState(
                              () => _alerts = AlertService.getAlerts());
                        },
                      )
                          .animate()
                          .fadeIn(
                            duration: 200.ms,
                            delay: (200 + entry.key * 40).ms,
                          )
                          .slideY(begin: 0.03, end: 0),
                    ),
                  )),

            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}

// ─── Section Card ────────────────────────────────

class _SectionCard extends StatelessWidget {
  final HCColor hc;
  final Widget child;

  const _SectionCard({required this.hc, required this.child});

  @override
  Widget build(BuildContext context) {
    // `Material`, not a decorated `Container`.
    //
    // The switches and checkboxes inside this card are `ListTile`s, and a
    // ListTile paints its background and its tap ripple on the nearest Material
    // ancestor. A coloured box in between hides both, so every row here
    // responded to a tap with no visible feedback — which matters most to the
    // learners least able to tell whether a tap registered. Flutter asserts on
    // exactly this, and nothing had ever rendered the screen to hear it.
    return Material(
      color: hc.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: hc.border),
      ),
      child: child,
    );
  }
}

// ─── Alert Tile ──────────────────────────────────

class _AlertTile extends StatelessWidget {
  final AlertEntry alert;
  final HCColor hc;
  final VoidCallback onMarkRead;

  const _AlertTile({
    required this.alert,
    required this.hc,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final isConcerning = alert.type.isConcerning;
    final color = isConcerning ? AppColors.error : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alert.isRead
            ? hc.surface
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert.isRead
              ? hc.border
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(alert.type.emoji,
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _alertMessage(_t(context), alert),
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textPrimary,
                    fontWeight:
                        alert.isRead ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimestamp(context, alert.timestamp),
                  style: AppTypography.labelSmall.copyWith(
                    color: hc.textHint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (!alert.isRead)
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded,
                  size: 20),
              color: hc.textSecondary,
              onPressed: onMarkRead,
              tooltip: _t(context).alMarkRead,
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(BuildContext context, DateTime t) {
    final l = _t(context);
    final diff = DateTime.now().difference(t);
    // Future stamps (a tablet's clock ahead) read as "just now", not "-5m ago".
    if (diff.inMinutes < 1) return l.gmJustNow;
    if (diff.inMinutes < 60) return l.asMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.asHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.asDaysAgo(diff.inDays);
    return LocalizedDate.monthDayYear(t, l);
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

String _alertTypeLabel(AppLocalizations t, AlertType type) => switch (type) {
  AlertType.lowAccuracy => t.atLowAccuracy,
  AlertType.streakBroken => t.atStreakBroken,
  AlertType.inactivity => t.atInactivity,
  AlertType.assignmentOverdue => t.atOverdue,
  AlertType.achievementEarned => t.atAchievement,
  AlertType.assessmentCompleted => t.atAssessment,
};

/// An alert's message in the reader's language. Alerts are stored with the
/// English sentence [AlertService] wrote, so the numbers are read back out of
/// it; anything that doesn't match shows as stored.
String _alertMessage(AppLocalizations t, AlertEntry alert) {
  final m = alert.message;
  final low = RegExp(r"^(.+)'s accuracy is (\d+)% \(below (\d+)% threshold\)$").firstMatch(m);
  if (low != null) return t.amLowAccuracy(low[1]!, low[2]!, low[3]!);
  final idle = RegExp(r'^(.+) has been inactive for (\d+) days$').firstMatch(m);
  if (idle != null) return t.amInactive(idle[1]!, idle[2]!);
  final streak = RegExp(r"^(.+)'s streak was broken$").firstMatch(m);
  if (streak != null) return t.amStreak(streak[1]!);
  return m;
}
