import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/alert_models.dart';
import '../services/alert_service.dart';
import '../../../widgets/app_back_button.dart';

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
          'Alert Settings',
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
                'Enable Alerts',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: hc.textPrimary,
                ),
              ),
              subtitle: Text(
                'Get notified about student activity',
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
                color: _config.enabled ? AppColors.primary : hc.textHint,
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
                      'Thresholds',
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
                        const Icon(Icons.percent_rounded,
                            size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Accuracy alert below',
                            style: AppTypography.bodySmall
                                .copyWith(color: hc.textPrimary),
                          ),
                        ),
                        Text(
                          '${(_config.accuracyThreshold * 100).round()}%',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
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
                        const Icon(Icons.timer_off_rounded,
                            size: 18, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Inactivity alert after',
                            style: AppTypography.bodySmall
                                .copyWith(color: hc.textPrimary),
                          ),
                        ),
                        Text(
                          '${_config.inactivityDays} days',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
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
                    label: '${_config.inactivityDays} days',
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
                      'Alert Types',
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
                            type.label,
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
                  'Recent Alerts (${_alerts.length})',
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
                      'Clear',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.error),
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
                        'No alerts yet',
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
    return Container(
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border),
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
                  alert.message,
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textPrimary,
                    fontWeight:
                        alert.isRead ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimestamp(alert.timestamp),
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
              tooltip: 'Mark as read',
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.month}/${t.day}/${t.year}';
  }
}
