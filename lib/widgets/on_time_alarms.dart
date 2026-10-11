import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// Whether Android lets FlashLearn fire alarms at the exact minute — "Alarms
/// & reminders" in the app's system settings. Null where the question does
/// not arise (iOS, the test harness, no answer from the plugin).
///
/// The website APK declares `USE_EXACT_ALARM`, which Android grants at
/// install, so there this is always true. The Google Play build may not
/// declare it (Play keeps it for alarm-clock and calendar apps), and from
/// Android 14 its replacement, `SCHEDULE_EXACT_ALARM`, starts out **denied**.
/// Nothing fails then: every alarm and routine reminder quietly gets an
/// hour-wide window instead — "time's up" for 8:00 arriving at 8:47 — which
/// is exactly why it has to be asked for out loud.
///
/// Re-read on every resume ([_RecheckOnResume]): coming back from Android's
/// settings page is when the answer changes.
final onTimeAlarmsGrantedProvider = FutureProvider.autoDispose<bool?>((
  ref,
) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    return await _android()?.canScheduleExactNotifications();
  } catch (_) {
    return null;
  }
});

AndroidFlutterLocalNotificationsPlugin? _android() =>
    FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

/// Opens Android's "Alarms & reminders" page for the app. The schedulers
/// notice the change themselves when the app comes back to the front and
/// schedule everything again at the exact minute.
Future<void> openOnTimeAlarmSettings() async {
  try {
    await _android()?.requestExactAlarmsPermission();
  } catch (_) {
    // No settings page to open (an old or unusual device): nothing to do.
  }
}

/// The educator's half, inside the routine builder and the alarm list: shown
/// only while this device is known to deliver alarms late.
class OnTimeAlarmsRow extends ConsumerWidget {
  const OnTimeAlarmsRow({super.key, required this.filipino});

  final bool filipino;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Theme.of(context).platform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final granted = ref.watch(onTimeAlarmsGrantedProvider).valueOrNull;
    if (granted != false) {
      return const _RecheckOnResume(child: SizedBox.shrink());
    }
    final hc = HCColor.of(context);
    final l = filipino;
    return _RecheckOnResume(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l
                  ? 'Sa device na ito, maaaring mahuli nang hanggang isang oras '
                      'ang mga alarm at paalala hanggang payagan ng Android ang '
                      'eksaktong oras. Payagan ito rito at sa tablet ng bata.'
                  : 'On this device, alarms and reminders can arrive up to an '
                      'hour late until Android allows exact times. Allow it '
                      'here and on the learner’s tablet.',
              style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: openOnTimeAlarmSettings,
              icon: const Icon(Icons.alarm_on_rounded, size: 18),
              label: Text(
                l ? 'Payagan ang alarm sa tamang oras' : 'Allow on-time alarms',
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The learner's half, at the top of their own My Day: the tablet asks for
/// itself, addressed to the adult who looks after it, never to the child.
/// Renders nothing unless the permission is *known* to be missing.
class OnTimeAlarmsBanner extends ConsumerWidget {
  const OnTimeAlarmsBanner({super.key, required this.filipino});

  final bool filipino;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Theme.of(context).platform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final granted = ref.watch(onTimeAlarmsGrantedProvider).valueOrNull;
    if (granted != false) {
      return const _RecheckOnResume(child: SizedBox.shrink());
    }

    final hc = HCColor.of(context);
    final l = filipino;
    return _RecheckOnResume(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            AppColors.warning.withValues(alpha: 0.18),
            hc.surface,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.alarm_on_rounded,
              color: hc.graphic(AppColors.warning),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l
                        ? 'Hayaang dumating sa tamang oras ang mga paalala'
                        : 'Let reminders arrive on time',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l
                        ? 'Para sa nakatatandang namamahala sa tablet na ito: '
                            'maaaring mahuli nang hanggang isang oras ang mga '
                            'paalala at alarm hanggang payagan ang FlashLearn '
                            'na gumamit ng eksaktong alarm dito.'
                        : 'For the adult who looks after this tablet: '
                            'reminders and alarms can arrive up to an hour '
                            'late until FlashLearn may use exact alarms here.',
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: openOnTimeAlarmSettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: Text(
                      l
                          ? 'Payagan ang eksaktong alarm'
                          : 'Allow exact alarms',
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Re-reads the permission when the app comes back to the foreground.
class _RecheckOnResume extends ConsumerStatefulWidget {
  const _RecheckOnResume({required this.child});

  final Widget child;

  @override
  ConsumerState<_RecheckOnResume> createState() => _RecheckOnResumeState();
}

class _RecheckOnResumeState extends ConsumerState<_RecheckOnResume>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(onTimeAlarmsGrantedProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
