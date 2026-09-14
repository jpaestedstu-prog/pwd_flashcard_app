import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../services/routine_native_alarms.dart';

/// Whether "Display over other apps" is granted on this device.
///
/// While someone is using another app, Android shows a due lock as a banner
/// instead of letting FlashLearn take the screen. This is the one permission
/// that lets it come to the front anyway, and it belongs to the *device* — so
/// it has to be granted on the learner's own tablet.
///
/// One provider for both places that ask, so the educator's row and the
/// learner's banner can never disagree, and so a test can give either answer.
/// Re-read on every resume ([_RecheckOnResume]): coming back from Android's
/// settings page is when the answer changes.
final routineOverOtherAppsGrantedProvider =
    FutureProvider.autoDispose<bool>((ref) {
  return RoutineNativeAlarms.canDrawOverlays();
});

/// The educator's half, inside the routine builder's lock section: says
/// whether the permission is granted *here* and opens Android's page for it.
class RoutineOverOtherAppsRow extends ConsumerWidget {
  const RoutineOverOtherAppsRow({super.key, required this.filipino});

  final bool filipino;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Theme.of(context).platform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final hc = HCColor.of(context);
    final l = filipino;
    final known = ref.watch(routineOverOtherAppsGrantedProvider).valueOrNull;
    final granted = known ?? false;
    return _RecheckOnResume(
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l
                  ? 'Kapag may ibang app na nakabukas, banner lang ang lock '
                      'maliban kung pinapayagang lumabas ang FlashLearn sa '
                      'ibabaw ng ibang app. Itakda ito sa tablet ng bata.'
                  : 'When another app is open, the lock is only a banner unless '
                      'FlashLearn may appear over other apps. Set this on the '
                      'learner’s tablet.',
              style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed:
                      granted ? null : RoutineNativeAlarms.openOverlaySettings,
                  icon: const Icon(Icons.layers_rounded, size: 18),
                  label: Text(
                    l ? 'Ipakita sa ibabaw ng ibang app' : 'Open over other apps',
                    maxLines: 2,
                  ),
                ),
                if (known != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    granted ? Icons.check_circle_rounded : Icons.info_rounded,
                    size: 18,
                    color: granted ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      granted
                          ? (l
                              ? 'Pinayagan sa device na ito'
                              : 'Allowed on this device')
                          : (l ? 'Hindi pa pinapayagan' : 'Not allowed yet'),
                      style: AppTypography.labelSmall.copyWith(
                        color: hc.textSecondary,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The learner's half, at the top of their own My Day.
///
/// The builder's row says "set this on the learner's tablet" — but when the
/// educator builds on their own phone, the tablet never offered anywhere to do
/// it, and found on the NDL W09 the lock at 22:25 stayed a banner
/// (`no takeover: … overlay=false`). So the tablet asks for itself, once a
/// routine that locks is on today, and says who should answer: the grown-up
/// setting the tablet up, not the child.
///
/// Renders nothing unless the permission is *known* to be missing: an answer
/// still loading, or granted, shows nothing.
class RoutineOverOtherAppsBanner extends ConsumerWidget {
  const RoutineOverOtherAppsBanner({super.key, required this.filipino});

  final bool filipino;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Theme.of(context).platform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final granted = ref.watch(routineOverOtherAppsGrantedProvider).valueOrNull;
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
            const Icon(Icons.layers_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l
                        ? 'Hayaang lumabas ang lock sa ibabaw ng ibang app'
                        : 'Let the lock appear over other apps',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l
                        ? 'Magpatulong sa nakatatanda. Kapag may ibang app na '
                            'nakabukas, banner lang ang lock hanggang payagang '
                            'lumabas ang FlashLearn sa ibabaw ng ibang app sa '
                            'tablet na ito.'
                        : 'Ask a grown-up. When another app is open, the lock '
                            'is only a banner until FlashLearn may appear over '
                            'other apps on this tablet.',
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: RoutineNativeAlarms.openOverlaySettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: Text(
                      l
                          ? 'Payagan sa ibabaw ng ibang app'
                          : 'Allow over other apps',
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
      ref.invalidate(routineOverOtherAppsGrantedProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
