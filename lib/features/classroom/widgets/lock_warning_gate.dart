import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/handoff_target.dart';
import '../../../core/services/lock_announcer.dart';
import '../../../core/services/lock_presentation.dart';
import '../../../core/services/lock_warning.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/child_time_limit.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/child_time_limit_provider.dart';
import '../../../providers/lock_announcement_provider.dart';
import '../../../providers/lock_warning_provider.dart';
import '../../../providers/unlocking_educators_provider.dart';

/// How long the "nearly time" banner stays up before retiring itself.
///
/// Long enough to read at a slow reading speed and to hear the spoken
/// version finish; short enough that it doesn't sit over the activity the
/// learner is being given time to finish.
const Duration _bannerDuration = Duration(seconds: 12);

/// App-root gate that shows a non-blocking "5 minutes left" banner before
/// the [LockEnforcerGate] would lock the learner out.
///
/// Deliberately a banner and not a dialog: the whole point is to let the
/// learner finish what they are doing, so it must not steal focus or block
/// the activity underneath. It announces itself through the same channels
/// as the lock (see [LockPresentation.warningVariant]) so a learner who
/// cannot see it still hears it, and one who cannot hear it still feels it.
///
/// Mounted inside [LockEnforcerGate] in `main.dart`. It can never appear
/// over the lock screen because [lockWarningProvider] returns null as soon
/// as the lock condition is actually met.
class LockWarningGate extends ConsumerStatefulWidget {
  final Widget child;
  const LockWarningGate({super.key, required this.child});

  @override
  ConsumerState<LockWarningGate> createState() => _LockWarningGateState();
}

class _LockWarningGateState extends ConsumerState<LockWarningGate> {
  /// The warning currently on screen, or null when nothing is showing.
  LockWarning? _showing;

  /// Retires the banner after [_bannerDuration].
  Timer? _dismissTimer;

  /// The learner's policy document and linked educators, kept fresh by
  /// [build].
  ///
  /// These are **watched**, not read on demand: both arrive asynchronously
  /// (a Firestore stream and a Hive lookup), so a bare `ref.read` at the
  /// moment the warning fires would usually still see null and address the
  /// child with the generic fallback instead of the name their educator
  /// chose — the one thing this feature exists to get right.
  ChildTimeLimit? _limit;
  List<UserProfile> _educators = const [];

  /// The announcer, kept alive by a `watch` in [build].
  ///
  /// `lockAnnouncerProvider` is autoDispose, so a bare `ref.read` here
  /// would build one, hand it over, and then tear it down at the end of
  /// the microtask because nothing was listening — disposal calls `stop()`,
  /// which killed the chime a few milliseconds after it started. The
  /// subscription is what keeps it playing.
  LockAnnouncer? _announcer;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final isLearner =
        profile != null &&
        (profile.role == UserRole.student || profile.role == UserRole.child) &&
        !profile.isGuestPlayer;

    if (isLearner) {
      _announcer = ref.watch(lockAnnouncerProvider);
      _limit = ref.watch(childTimeLimitProvider(profile.id)).valueOrNull;
      _educators =
          ref.watch(unlockingEducatorsProvider(profile.id)).valueOrNull ??
          const <UserProfile>[];

      ref.listen<LockWarning?>(
        lockWarningProvider(profile.id),
        (previous, next) => _onWarningChanged(previous, next, profile),
      );
    }

    final showing = _showing;
    return Stack(
      children: [
        widget.child,
        if (showing != null && profile != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _WarningBanner(
              warning: showing,
              message: _bodyFor(showing, profile),
              presentation: _presentationFor(profile),
              onDismiss: _dismiss,
            ),
          ),
      ],
    );
  }

  /// Shows the banner the first time each impending lock is seen, and
  /// re-arms once that lock has passed or been called off.
  void _onWarningChanged(
    LockWarning? previous,
    LockWarning? next,
    UserProfile profile,
  ) {
    final seen = ref.read(lockWarningSeenProvider(profile.id).notifier);

    if (next == null) {
      // The warning window closed: the lock landed, an educator granted
      // more time, or the day rolled over. Re-arm every cause so the next
      // genuine approach warns again.
      if (previous != null) seen.clear(previous.eventKey);
      return;
    }

    // Only the first tick of a given approaching lock interrupts. Later
    // ticks ("4 minutes left") describe the same event and are ignored.
    if (!seen.markShown(next.eventKey)) return;

    setState(() => _showing = next);
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_bannerDuration, _dismiss);

    unawaited(
      _announcer?.announce(
        presentation: _presentationFor(profile).warningVariant,
        message: '${next.title}. ${_bodyFor(next, profile)}',
        alarmEnabled: _limit?.alarmSoundEnabled ?? true,
        voiceEnabled: _limit?.voiceMessageEnabled ?? true,
        speakFilipino: _isFilipino,
      ),
    );
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    if (!mounted) return;
    setState(() => _showing = null);
  }

  bool get _isFilipino => ref.read(settingsProvider).locale == 'fil';

  LockPresentation _presentationFor(UserProfile profile) =>
      LockPresentation.forProfile(
        profile.disabilityType,
        ref.read(settingsProvider),
      );

  /// The "…then hand it over to X" half of the message, in the wording
  /// this learner's profile uses.
  String _bodyFor(LockWarning warning, UserProfile profile) {
    final target = HandoffTarget.resolve(
      limit: _limit,
      educators: _educators,
      filipino: _isFilipino,
    );
    if (_isFilipino) return warning.bodyFilipino(target.address);
    if (_presentationFor(profile).simplifiedWording) {
      return warning.bodySimple(target.address);
    }
    return warning.body(target.address);
  }
}

/// The banner itself: a top-anchored card that never covers the whole
/// screen and can always be dismissed by tapping it.
class _WarningBanner extends StatelessWidget {
  final LockWarning warning;
  final String message;
  final LockPresentation presentation;
  final VoidCallback onDismiss;

  const _WarningBanner({
    required this.warning,
    required this.message,
    required this.presentation,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = presentation.messageScale;

    final card = Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Semantics(
            liveRegion: true,
            label: '${warning.title}. $message',
            container: true,
            child: ExcludeSemantics(
              child: Card(
                elevation: 6,
                color: scheme.secondaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.warning, width: 2),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onDismiss,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.hourglass_bottom_rounded,
                          size: 30 * scale,
                          color: scheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                warning.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          (Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.fontSize ??
                                              16) *
                                          scale,
                                      color: scheme.onSecondaryContainer,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: scheme.onSecondaryContainer,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // A real target rather than a bare icon: motor
                        // profiles get the same minimum size the lock
                        // screen's buttons use.
                        //
                        // No `tooltip:` — this banner is mounted above the
                        // Navigator (see main.dart), so there is no Overlay
                        // ancestor and a Tooltip throws on first build,
                        // which the ErrorBoundary then renders as an
                        // "Oops!" card *inside* the warning. The semantics
                        // label gives screen readers the same information.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: presentation.minTouchTarget,
                            minHeight: presentation.minTouchTarget,
                          ),
                          child: Semantics(
                            button: true,
                            label: 'Dismiss',
                            child: IconButton(
                              onPressed: onDismiss,
                              iconSize: 24 * scale,
                              icon: const Icon(Icons.close_rounded),
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (presentation.reduceMotion) return card;
    return _SlideInFromTop(child: card);
  }
}

/// Entrance animation, skipped entirely under Reduced Motion.
class _SlideInFromTop extends StatefulWidget {
  final Widget child;
  const _SlideInFromTop({required this.child});

  @override
  State<_SlideInFromTop> createState() => _SlideInFromTopState();
}

class _SlideInFromTopState extends State<_SlideInFromTop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(curve),
      child: FadeTransition(opacity: curve, child: widget.child),
    );
  }
}
