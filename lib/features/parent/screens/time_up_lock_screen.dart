import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/lock_media.dart';
import '../../../core/security/pin_auth_service.dart';
import '../../../core/security/pin_credential_helper.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/services/guardian_address.dart';
import '../../../core/services/handoff_target.dart';
import '../../../core/services/lock_announcer.dart';
import '../../../core/services/lock_enforcer.dart';
import '../../../core/services/lock_presentation.dart';
import '../../../core/services/media_url_resolver.dart';
import '../../../core/services/story_image_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/child_time_limit.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/child_time_limit_provider.dart';
import '../../../providers/lock_announcement_provider.dart';
import '../../../providers/lock_state_provider.dart';
import '../../../providers/pin_unlock_grace_provider.dart';
import '../../../providers/unlocking_educators_provider.dart';
import '../../../widgets/fsl_fullscreen_player.dart';
import '../services/child_unlock_override_service.dart';

/// Grace window granted on a successful PIN / recovery-code entry. The
/// underlying time-limit/alarm/schedule rule may still be active, so
/// without this the [LockEnforcerGate] would re-push the lock screen
/// the moment we route to `/home`. Thirty minutes is long enough to
/// finish a session without giving the child unbounded access — the
/// override stops applying as soon as the timestamp passes.
const Duration _pinUnlockGrace = Duration(minutes: 30);

/// How long after the screen appears the announcement starts.
///
/// Two reasons for the delay: the child should *see* the lock before
/// they hear it (a chime out of nowhere mid-game is startling), and the
/// child's time-limit document — which carries the guardian's name —
/// usually lands within this window, so the spoken message can say
/// "Ma'am" rather than the generic fallback.
const Duration _announceDelay = Duration(milliseconds: 400);

/// Full-screen "Time's Up" lock that requires a parent/teacher PIN to
/// dismiss. Shown when [lockStateProvider] for the active child profile
/// returns a non-null [LockReason].
///
/// Design:
///   • System back is disabled (`PopScope` + `canPop: false`).
///   • Status bar is hidden for a kiosk feel.
///   • An alarm chime plays, then a spoken hand-off message ("Time's up.
///     Please give your device to Ma'am."). Which channels actually fire
///     is decided per accessibility profile by [LockPresentation] — a
///     hearing profile gets the FSL clip and a caption instead of speech,
///     a cognitive profile gets one chime and one short sentence.
///   • The PIN pad tries every unlocking educator profile in turn —
///     first match dismisses the lock and routes to `/home`.
///   • A "Use recovery code" link offers the educator-only fallback
///     for forgotten PINs (matches the recovery-code mechanism added
///     in [PinCredentialHelper]).
///   • "Switch account" hands the device to another profile without a
///     PIN. It is not an escape hatch: the router's lock redirect
///     re-locks this child the moment they are selected again.
class TimeUpLockScreen extends ConsumerStatefulWidget {
  const TimeUpLockScreen({super.key});

  @override
  ConsumerState<TimeUpLockScreen> createState() => _TimeUpLockScreenState();
}

class _TimeUpLockScreenState extends ConsumerState<TimeUpLockScreen>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  String? _error;
  bool _verifying = false;

  /// Cumulative failed attempts in this session (any educator). Drives
  /// the local cooldown via [PinAuthService.cooldownFor] — escalates
  /// from no-cooldown (< 5) to 30 s, 1 min, 5 min, 15 min, then 1 h.
  int _failedAttempts = 0;

  /// When the current lockout ends, if any.
  DateTime? _cooldownEndsAt;

  /// Drives the per-second countdown text rebuild.
  Timer? _cooldownTicker;

  /// Channel policy for this learner's accessibility profile. Resolved
  /// once in [initState] — the learner cannot change their settings from
  /// behind the lock, so there is nothing to react to.
  late final LockPresentation _presentation;

  /// Slow border pulse for profiles that can't hear the chime.
  AnimationController? _pulse;

  /// Fires the announcement shortly after the screen appears.
  Timer? _announceTimer;

  /// Guards against a second announcement (rebuilds, stream emissions).
  bool _announced = false;

  /// Held directly rather than re-read from `ref` on the way out: `ref`
  /// is unusable inside [dispose], and the announcement has to be
  /// silenced there so a voice never trails onto the next screen.
  LockAnnouncer? _announcer;

  @override
  void initState() {
    super.initState();
    // Hide status / nav bars for a kiosk feel.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    final profile = ref.read(profileProvider);
    _presentation = LockPresentation.forProfile(
      profile?.disabilityType ?? DisabilityType.none,
      ref.read(settingsProvider),
    );

    if (_presentation.visualAlert) {
      _pulse = AnimationController(
        vsync: this,
        duration: _presentation.flashPeriod,
      )..repeat(reverse: true);
    }

    _announceTimer = Timer(_announceDelay, _announce);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _announceTimer?.cancel();
    _cooldownTicker?.cancel();
    _pulse?.dispose();
    _pinController.dispose();
    // The provider is autoDispose and stops the announcer on disposal,
    // but that happens a frame later — silence it now so the voice never
    // trails onto the next screen.
    unawaited(_announcer?.stop());
    super.dispose();
  }

  Duration? get _cooldownRemaining {
    final ends = _cooldownEndsAt;
    if (ends == null) return null;
    final delta = ends.difference(DateTime.now());
    return delta.isNegative ? null : delta;
  }

  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _cooldownRemaining;
      if (remaining == null) {
        _cooldownTicker?.cancel();
        setState(() {
          _cooldownEndsAt = null;
          _error = null;
        });
      } else {
        setState(() {
          _error =
              'Too many attempts. Try again in ${_formatRemaining(remaining)}.';
        });
      }
    });
  }

  /// Plays the chime + spoken hand-off once per appearance of the lock.
  void _announce() {
    if (!mounted || _announced) return;
    _announced = true;
    final profile = ref.read(profileProvider);
    if (profile == null) return;

    final limit = ref.read(childTimeLimitProvider(profile.id)).valueOrNull;
    final reason = ref.read(lockStateProvider(profile.id));
    final educators =
        ref.read(unlockingEducatorsProvider(profile.id)).valueOrNull ??
        const <UserProfile>[];
    final filipino = ref.read(settingsProvider).locale == 'fil';

    // `build` has always run by the time this timer fires, so the held
    // reference is set; the read is only a belt-and-braces fallback.
    final LockAnnouncer announcer =
        _announcer ?? ref.read(lockAnnouncerProvider);

    unawaited(
      announcer.announce(
        presentation: _presentation,
        message: _handoffMessageFor(
          _handoffTarget(
            limit: limit,
            reason: reason,
            educators: educators,
            filipino: filipino,
          ),
          filipino: filipino,
        ),
        alarmEnabled: limit?.alarmSoundEnabled ?? true,
        voiceEnabled: limit?.voiceMessageEnabled ?? true,
        speakFilipino: filipino,
      ),
    );
  }

  /// Who this learner is being handed to, resolved from whatever the
  /// device knows. The caption, the spoken message and the picture all
  /// come from this one value so they cannot disagree.
  HandoffTarget _handoffTarget({
    required ChildTimeLimit? limit,
    required LockReason? reason,
    required List<UserProfile> educators,
    required bool filipino,
  }) => HandoffTarget.resolve(
    limit: limit,
    educators: educators,
    filipino: filipino,
    alarmSetterRole: reason is AlarmTriggered ? reason.alarm.setterRole : null,
  );

  String _handoffMessageFor(HandoffTarget target, {required bool filipino}) {
    if (_presentation.simplifiedWording) {
      return filipino
          ? GuardianAddress.timesUpMessageSimpleFilipino(
              address: target.address,
            )
          : GuardianAddress.timesUpMessageSimple(address: target.address);
    }
    return filipino
        ? GuardianAddress.timesUpMessageFilipino(
            address: target.address,
            setterRole: target.setterRole,
          )
        : GuardianAddress.timesUpMessage(
            address: target.address,
            setterRole: target.setterRole,
          );
  }

  @override
  Widget build(BuildContext context) {
    // Watched (not read): the provider is autoDispose, so a subscription
    // is what keeps the announcer alive for the life of this screen.
    _announcer = ref.watch(lockAnnouncerProvider);

    final profile = ref.watch(profileProvider);
    if (profile == null) {
      // No active profile — don't lock; route home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GoRouter.of(context).go('/home');
      });
      return const SizedBox.shrink();
    }

    // Auto-dismiss when the lock state clears — covers educator-driven
    // remote unlocks, local PIN grace becoming active, and the
    // underlying time-limit / alarm condition lapsing on its own.
    // Without this, `build()` would just redraw and the child would be
    // stuck on the lock screen until they tapped a PIN.
    ref.listen<LockReason?>(lockStateProvider(profile.id), (_, next) {
      if (next == null && mounted) {
        unawaited(_announcer?.stop());
        GoRouter.of(context).go('/home');
      }
    });

    final reason = ref.watch(lockStateProvider(profile.id));
    final educatorsAsync = ref.watch(unlockingEducatorsProvider(profile.id));
    final limit = ref.watch(childTimeLimitProvider(profile.id)).valueOrNull;
    final educators = educatorsAsync.valueOrNull ?? const <UserProfile>[];
    final filipino = ref.watch(settingsProvider).locale == 'fil';

    final scheme = Theme.of(context).colorScheme;
    final target = _handoffTarget(
      limit: limit,
      reason: reason,
      educators: educators,
      filipino: filipino,
    );
    final handoff = _handoffMessageFor(target, filipino: filipino);

    // The scrolling half. "Switch account" deliberately lives outside it —
    // see [_SwitchAccountBar].
    final scrollingBody = ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      children: [
        Icon(
          Icons.lock_clock_rounded,
          size: 72 * _presentation.messageScale,
          color: scheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          reason?.title ?? 'Locked',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize:
                (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) *
                _presentation.messageScale,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // The hand-off line, always on screen as a caption — it is the
        // channel that works for every profile, including when audio
        // fails or the FSL clip hasn't downloaded.
        _HandoffCaption(
          message: handoff,
          scale: _presentation.messageScale,
          announce: _presentation.announce,
        ),
        if (reason?.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            reason!.subtitle!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Active profile: ${profile.name}',
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Shown for every accessibility profile — the picture of who to
        // hand the device to is the only cue that doesn't assume the
        // learner reads, hears, or signs.
        _HandoffFlipCard(
          figure: target.figure,
          clip: _clipFor(limit, target.figure),
          videoFirst: _presentation.clipFirst,
          reducedMotion: _presentation.reduceMotion,
          caption: handoff,
        ),
        const SizedBox(height: 24),
        educatorsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            '$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const _NoEducatorsHint();
            }
            return _PinForm(
              controller: _pinController,
              verifying: _verifying,
              error: _error,
              minTouchTarget: _presentation.minTouchTarget,
              // Never raise the keyboard on arrival. The lock is seen by
              // the *child* first — the clip is what tells them the
              // session ended, and a keyboard covering it helps nobody.
              // The adult taps the field when they get there.
              autofocus: false,
              onSubmit: (pin) => _attempt(pin, list, profile.id),
              onForgot: () => _showRecoveryDialog(list, profile.id),
            );
          },
        ),
        const SizedBox(height: 16),
        // Sits with the button below it, but stays in the scroll area so
        // the pinned bar costs only one button of height.
        const _SwitchAccountNote(),
      ],
    );

    final body = SafeArea(
      child: Column(
        children: [
          Expanded(child: scrollingBody),
          // Pinned, not scrolled: on a shared classroom tablet the next
          // learner must be able to start without an adult unlocking this
          // child first, and at large font scales the content above is
          // taller than a small phone's viewport — so a scrolled button
          // would be exactly the one control a child can't find.
          _SwitchAccountBar(
            minTouchTarget: _presentation.minTouchTarget,
            onPressed: _switchAccount,
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: _presentation.visualAlert && _pulse != null
            ? AnimatedBuilder(
                animation: _pulse!,
                builder: (context, child) => DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      // Slow, low-contrast breathing border. Never a fast
                      // flash: 3–55 Hz is a seizure risk (WCAG 2.3.1).
                      color: scheme.primary.withValues(
                        alpha: 0.25 + 0.55 * _pulse!.value,
                      ),
                      width: 6,
                    ),
                  ),
                  child: child,
                ),
                child: body,
              )
            : body,
      ),
    );
  }

  /// What goes on the back of the hand-off picture, and where to fetch it.
  ///
  /// Two kinds, and the card is told which one it actually got rather than
  /// which one the profile asked for — a learner who signs but whose
  /// educator has no matching figure ends up with the alarm animation, and
  /// calling that "sign language" on screen would be a lie to exactly the
  /// learner who can least afford one.
  ///
  /// Resolution order for a signing profile:
  ///   1. The educator's per-child clip, if they pasted one.
  ///   2. The signed hand-off for this figure (Ma'am / Sir / Mommy /
  ///      Daddy) — it names the adult, which a generic clip cannot.
  ///   3. The alarm animation, so the card still has a second face.
  ///
  /// URLs are normalised here rather than inside the player so the
  /// disk-cache key is computed from the same string that gets downloaded
  /// — otherwise a clip pasted as `.gif` and the `.mp4` actually fetched
  /// would occupy two cache entries and re-download on every lock.
  ({LockClipKind kind, String url}) _clipFor(
    ChildTimeLimit? limit,
    HandoffFigure? figure,
  ) {
    switch (_presentation.clip) {
      case LockClipKind.none:
        return (kind: LockClipKind.none, url: '');
      case LockClipKind.alarm:
        return _alarmClip;
      case LockClipKind.fsl:
        final perChild = (limit?.fslVideoUrl ?? '').trim();
        if (perChild.isNotEmpty) {
          return (
            kind: LockClipKind.fsl,
            url: MediaUrlResolver.asPlayableVideo(perChild),
          );
        }
        final signed = LockMediaDefaults.timesUpFslVideoUrl(figure);
        if (signed != null) {
          return (
            kind: LockClipKind.fsl,
            url: MediaUrlResolver.asPlayableVideo(signed),
          );
        }
        return _alarmClip;
    }
  }

  ({LockClipKind kind, String url}) get _alarmClip => (
    kind: LockClipKind.alarm,
    url: MediaUrlResolver.asPlayableVideo(
      LockMediaDefaults.timesUpAlarmClipUrl,
    ),
  );

  /// Hands the device to another profile without dismissing this child's
  /// lock. The router's lock redirect re-applies the moment this child is
  /// selected again, so this is a hand-off, not a bypass.
  void _switchAccount() {
    unawaited(_announcer?.stop());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    GoRouter.of(context).go('/profile-switcher');
  }

  Future<void> _attempt(
    String pin,
    List<UserProfile> educators,
    String childProfileId,
  ) async {
    if (_verifying) return;
    // Honour any active cooldown.
    if (_cooldownRemaining != null) {
      setState(
        () => _error =
            'Too many attempts. Try again in ${_formatRemaining(_cooldownRemaining!)}.',
      );
      return;
    }
    if (pin.length < 4) {
      setState(() => _error = 'Enter a 4-digit PIN.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });

    // Try each educator in turn — first match wins.
    UserProfile? matched;
    for (final ed in educators) {
      if (PinCredentialHelper.verify(ed, pin)) {
        matched = ed;
        break;
      }
    }
    if (!mounted) return;
    setState(() => _verifying = false);

    if (matched != null) {
      _pinController.clear();
      unawaited(_announcer?.stop());
      // Write a short grace window so the gate doesn't immediately
      // re-lock on the underlying still-active time limit / alarm /
      // schedule rule. Fire-and-forget — a Firestore failure here is
      // non-fatal (the child stays unlocked locally; the educator can
      // either retry or relax the rule).
      _grantPinUnlockGrace(childProfileId, matched);
      // Route to home — the gate widget sees the new override and
      // returns null from lockStateProvider for the next 30 minutes.
      GoRouter.of(context).go('/home');
    } else {
      _failedAttempts += 1;
      final cooldown = PinAuthService.cooldownFor(_failedAttempts);
      if (cooldown > Duration.zero) {
        _cooldownEndsAt = DateTime.now().add(cooldown);
        _startCooldownTicker();
      }
      setState(() {
        _error = cooldown > Duration.zero
            ? 'Too many attempts. Try again in ${_formatRemaining(cooldown)}.'
            : 'Incorrect PIN. Ask your parent or teacher.';
      });
      _pinController.clear();
    }
  }

  String _formatRemaining(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return '${h}h ${m}m';
    }
    if (d.inMinutes >= 1) {
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return '${m}m ${s}s';
    }
    return '${d.inSeconds}s';
  }

  Future<void> _showRecoveryDialog(
    List<UserProfile> educators,
    String childProfileId,
  ) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Use recovery code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the recovery code printed when this profile\'s PIN '
              'was set. Codes are case-insensitive.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Recovery code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;

    UserProfile? matched;
    for (final ed in educators) {
      if (PinCredentialHelper.verifyRecoveryCode(ed, code)) {
        matched = ed;
        break;
      }
    }
    if (!mounted) return;
    if (matched != null) {
      unawaited(_announcer?.stop());
      _grantPinUnlockGrace(childProfileId, matched);
      GoRouter.of(context).go('/home');
    } else {
      setState(() => _error = 'Recovery code did not match.');
    }
  }

  /// Persist a 30-minute unlock grace.
  ///
  /// Authoritative path: the local Hive-backed [pinUnlockGraceProvider].
  /// Firestore can't accept this write from the child's device because
  /// the security rule on `child_unlock_overrides` requires the writer
  /// to own the setter profile, which the child's device does not.
  ///
  /// Best-effort mirror: still attempt the Firestore write so the
  /// educator's dashboard can see "PIN was used" when the rule does
  /// happen to allow it (e.g. on the educator's own device). Failures
  /// route to the silent diagnostics path — the local grace is what
  /// the lock provider trusts, so a rejected mirror is non-fatal.
  void _grantPinUnlockGrace(String childProfileId, UserProfile educator) {
    unawaited(
      ref
          .read(pinUnlockGraceProvider(childProfileId).notifier)
          .grant(_pinUnlockGrace)
          .catchError((Object e, StackTrace s) {
            ErrorHandler.report(e, s, 'PinUnlockGrace:silent');
          }),
    );
    unawaited(
      const ChildUnlockOverrideService()
          .setUnlockFor(
            childProfileId: childProfileId,
            duration: _pinUnlockGrace,
            setter: educator,
          )
          .catchError((Object e, StackTrace s) {
            ErrorHandler.report(e, s, 'PinUnlockGrace:silent');
          }),
    );
  }
}

/// The "Time's up. Please give your device to Ma'am." caption.
///
/// Its own widget so the screen-reader announcement (`liveRegion`) is
/// scoped to exactly this text — announcing the whole lock screen would
/// read the PIN pad aloud too.
class _HandoffCaption extends StatelessWidget {
  final String message;
  final double scale;
  final bool announce;

  const _HandoffCaption({
    required this.message,
    required this.scale,
    required this.announce,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium;
    final text = Text(
      message,
      textAlign: TextAlign.center,
      style: base?.copyWith(
        fontSize: (base.fontSize ?? 16) * scale,
        fontWeight: FontWeight.w600,
      ),
    );
    return Semantics(
      liveRegion: announce,
      label: message,
      child: ExcludeSemantics(child: text),
    );
  }
}

/// The hand-off card: a picture of the adult to give the device to, with a
/// moving image on its other face.
///
/// The picture is the point. A caption only works for a learner who reads,
/// speech only for one who hears, and the FSL clip only for one who signs —
/// but a photograph of Ma'am / Sir / Mommy / Daddy answers "who do I hand
/// this to?" for every profile, which is why it shows on all six.
///
/// The back face is whichever [LockClipKind] this learner resolved to: the
/// signed hand-off for a learner who signs, the alarm animation for
/// everyone else. Both are labelled for what they are — a deaf learner
/// must never be told an alarm clock is sign language.
///
/// Tap-to-flip mirrors Stories' cartoon ⇄ real-life illustration and the
/// Flashcards emoji ⇄ photo toggle: the same 650 ms `rotateY`, the same
/// counter-rotated back face, the same near-instant turn under Reduced
/// Motion, and the same caption pill telling the learner what a tap does.
///
/// Degrades cleanly. With no artwork (a legacy educator avatar) it shows
/// the clip alone; with no clip it shows the picture alone; with neither it
/// renders nothing and the written caption above carries the message.
class _HandoffFlipCard extends ConsumerStatefulWidget {
  /// Which artwork to show, or null when the educator's avatar isn't one of
  /// the four gendered ones.
  final HandoffFigure? figure;

  /// The back face: what kind of clip it is, and its URL already normalised
  /// to a playable form. [LockClipKind.none] or an empty URL means the card
  /// has only the picture.
  final ({LockClipKind kind, String url}) clip;

  /// Start on the clip rather than the picture. True only where the clip is
  /// the message (hearing profiles), so what already shipped is unchanged.
  final bool videoFirst;

  final bool reducedMotion;

  /// The hand-off sentence, used as the semantic label for both faces.
  final String caption;

  const _HandoffFlipCard({
    required this.figure,
    required this.clip,
    required this.videoFirst,
    required this.reducedMotion,
    required this.caption,
  });

  @override
  ConsumerState<_HandoffFlipCard> createState() => _HandoffFlipCardState();
}

class _HandoffFlipCardState extends ConsumerState<_HandoffFlipCard> {
  // Picture face.
  ImageProvider? _image;
  bool _imageFailed = false;
  bool _resolvingImage = false;

  // Clip face.
  VideoSource? _source;
  VideoPlayerController? _controller;
  bool _videoLoading = false;
  bool _videoFailed = false;

  /// false = picture, true = the clip.
  late bool _showVideo = widget.videoFirst && _wantsVideo;

  bool get _wantsVideo =>
      widget.clip.kind != LockClipKind.none && widget.clip.url.isNotEmpty;

  /// Whether the back face is a person signing rather than the alarm clock.
  /// Everything the learner reads or hears about the clip branches on this.
  bool get _isFsl => widget.clip.kind == LockClipKind.fsl;

  String? get _imageUrl => LockMediaDefaults.timesUpImageUrl(widget.figure);

  /// Both faces exist, so flipping means something.
  bool get _canFlip => _imageUrl != null && _wantsVideo;

  /// What the back face is, in words — used in the prompt and the
  /// screen-reader label so they can't drift from each other.
  String get _clipNoun => _isFsl ? 'sign-language video' : 'alarm';

  @override
  void initState() {
    super.initState();
    _resolveImage();
    if (_wantsVideo) unawaited(_loadVideo());
  }

  /// The child's time-limit document arrives over a stream, so the first
  /// build usually has neither the per-child clip URL nor the educator's
  /// stamped honorific. Without this the configured clip would never load
  /// and the picture would never appear.
  @override
  void didUpdateWidget(_HandoffFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.figure != widget.figure) {
      _image = null;
      _imageFailed = false;
      _resolvingImage = false;
      _resolveImage();
    }
    if (oldWidget.clip != widget.clip) {
      final stale = _controller;
      _controller = null;
      _source = null;
      _videoLoading = false;
      _videoFailed = false;
      unawaited(stale?.dispose());
      if (_wantsVideo) unawaited(_loadVideo());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _resolveImage() {
    final url = _imageUrl;
    final figure = widget.figure;
    if (url == null || figure == null || _resolvingImage) return;

    final key = LockMediaDefaults.imageCacheKey(figure, url);
    // Already on disk from an earlier lock → paint it on this frame.
    final cached = StoryImageService.resolvedFile(key);
    if (cached != null) {
      _image = FileImage(cached);
      return;
    }
    _resolvingImage = true;
    StoryImageService.imageFile(url, cacheKey: key).then((file) {
      _resolvingImage = false;
      if (!mounted) return;
      setState(() {
        if (file != null) {
          _image = FileImage(file);
        } else {
          _imageFailed = true;
        }
      });
    });
  }

  Future<void> _loadVideo() async {
    if (_videoLoading) return;
    _videoLoading = true;
    try {
      final loader = ref.read(lockFslVideoLoaderProvider);
      final source = await loader(
        widget.clip.url,
        cacheKey: LockMediaDefaults.clipCacheKey(widget.clip.url),
      );
      if (!mounted) {
        _videoLoading = false;
        return;
      }
      if (source == null) {
        setState(() {
          _videoLoading = false;
          _videoFailed = true;
        });
        return;
      }
      final controller = source.createController();
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      // Loop and mute: a sign-language message is short, and a learner who
      // looked away shouldn't have to hunt for a replay button.
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (_showVideo) await controller.play();
      setState(() {
        _source = source;
        _controller = controller;
        _videoLoading = false;
      });
    } catch (e, s) {
      ErrorHandler.report(e, s, 'LockAnnouncer:silent');
      if (mounted) {
        setState(() {
          _videoLoading = false;
          _videoFailed = true;
        });
      }
    }
  }

  void _flip() {
    if (!_canFlip) return;
    setState(() => _showVideo = !_showVideo);
    final controller = _controller;
    if (controller == null) return;
    unawaited(_showVideo ? controller.play() : controller.pause());
  }

  @override
  Widget build(BuildContext context) {
    // Nothing configured for this learner — the written caption above is
    // already carrying the message, so stay out of the way.
    if (_imageUrl == null && !_wantsVideo) return const SizedBox.shrink();

    // Cap the height. The artwork and the alarm clip are both close to
    // square, so an unconstrained AspectRatio eats the whole viewport and
    // pushes the PIN pad and "Switch account" off-screen — on exactly the
    // profiles that most need a reachable hand-off button.
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.28).clamp(
      140.0,
      280.0,
    );

    final card = _canFlip
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _showVideo ? math.pi : 0),
            duration: widget.reducedMotion
                ? const Duration(milliseconds: 80)
                : const Duration(milliseconds: 650),
            curve: widget.reducedMotion ? Curves.linear : Curves.easeOutBack,
            builder: (context, value, child) {
              final showFront = value < math.pi / 2;
              final face = showFront
                  ? _face(video: false, maxHeight: maxHeight)
                  : Transform(
                      // Counter-rotate the back face so the clip isn't
                      // mirrored once the card turns past 90°.
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _face(video: true, maxHeight: maxHeight),
                    );
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(value),
                child: face,
              );
            },
          )
        : _face(video: _imageUrl == null, maxHeight: maxHeight);

    return Column(
      children: [
        MergeSemantics(
          child: Semantics(
            button: _canFlip,
            image: true,
            label: _semanticLabel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _canFlip ? _flip : null,
              child: Center(child: card),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_canFlip) _tapHintPill(context) else _fullScreenButton(context),
      ],
    );
  }

  String get _semanticLabel {
    if (!_canFlip) return widget.caption;
    if (_showVideo) {
      return _isFsl
          ? 'Sign-language video. Tap to see the picture.'
          : 'Alarm clock animation. Tap to see the picture.';
    }
    return '${widget.caption} Tap to see the $_clipNoun.';
  }

  Widget _face({required bool video, required double maxHeight}) {
    final content = video ? _videoFace() : _imageFace();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: content),
    );
  }

  Widget _imageFace() {
    final provider = _image;
    if (provider == null) {
      return SizedBox(
        height: 140,
        width: 140,
        child: Center(
          child: _imageFailed
              ? const Icon(Icons.image_not_supported_rounded, size: 40)
              : const CircularProgressIndicator(),
        ),
      );
    }
    return Image(
      image: provider,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox(
        height: 140,
        width: 140,
        child: Center(child: Icon(Icons.image_not_supported_rounded, size: 40)),
      ),
    );
  }

  Widget _videoFace() {
    final controller = _controller;
    if (controller == null) {
      return SizedBox(
        height: 140,
        child: Center(
          child: _videoFailed
              ? const Icon(Icons.videocam_off_rounded, size: 40)
              : const CircularProgressIndicator(),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio == 0
          ? 16 / 9
          : controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }

  Widget _tapHintPill(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: _flip,
      icon: Icon(
        _showVideo
            ? Icons.image_rounded
            : (_isFsl ? Icons.sign_language_rounded : Icons.alarm_rounded),
        color: scheme.primary,
      ),
      label: Text(
        _showVideo ? 'Tap to see the picture' : 'Tap to see the $_clipNoun',
      ),
    );
  }

  /// Shown when there is only a clip (no artwork for this educator) — the
  /// same full-screen affordance the clip had before the picture existed.
  ///
  /// FSL only: full screen exists so a learner can read a sign clearly.
  /// Blowing up the alarm clock buys nothing and would push the PIN pad
  /// off the one screen an adult needs to reach.
  Widget _fullScreenButton(BuildContext context) {
    if (!_isFsl || _imageUrl != null || _source == null) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      onPressed: _openFullscreen,
      icon: const Icon(Icons.fullscreen_rounded),
      label: const Text('Watch in full screen'),
    );
  }

  Future<void> _openFullscreen() async {
    final source = _source;
    if (source == null) return;
    await _controller?.pause();
    if (!mounted) return;
    await openFslFullscreenPlayer(
      context,
      videoSource: source,
      wordEnglish: widget.caption,
    );
    if (!mounted) return;
    if (_showVideo) await _controller?.play();
  }
}

class _PinForm extends StatelessWidget {
  final TextEditingController controller;
  final bool verifying;
  final String? error;
  final double minTouchTarget;

  /// Whether to raise the keyboard as soon as the lock appears. Off when a
  /// sign-language clip is showing — see the call site.
  final bool autofocus;
  final void Function(String pin) onSubmit;
  final VoidCallback onForgot;

  const _PinForm({
    required this.controller,
    required this.verifying,
    required this.error,
    required this.minTouchTarget,
    required this.autofocus,
    required this.onSubmit,
    required this.onForgot,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter parent / teacher PIN to continue',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          textAlign: TextAlign.center,
          autofocus: autofocus,
          style: const TextStyle(
            fontSize: 28,
            letterSpacing: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: '••••',
            counterText: '',
            errorText: error,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: onSubmit,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(minTouchTarget),
          ),
          onPressed: verifying ? null : () => onSubmit(controller.text),
          icon: verifying
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_open_rounded),
          label: Text(verifying ? 'Verifying…' : 'Unlock'),
        ),
        TextButton(
          onPressed: onForgot,
          child: const Text('Forgot PIN? Use recovery code'),
        ),
      ],
    );
  }
}

/// Hand the device to another learner without unlocking this one.
///
/// Pinned below the scrolling body rather than sitting at the end of it.
/// The lock's content — headline, caption, hand-off card, PIN pad — is
/// taller than a small phone's viewport once the learner's font scale is
/// turned up, and this is the one control that must never be hunted for:
/// it is how a classroom tablet reaches the next child, and how a learner
/// who cannot summon an adult gets out of a screen with no back button.
///
/// Only the button is pinned. Its explanatory line stays in the scroll area
/// as [_SwitchAccountNote], so the bar costs one button of height even at
/// 2× text.
class _SwitchAccountBar extends StatelessWidget {
  final double minTouchTarget;
  final VoidCallback onPressed;

  const _SwitchAccountBar({
    required this.minTouchTarget,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        // A hairline so the bar reads as a fixed ledge rather than as
        // content that happens to be at the bottom of the scroll.
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: Size.fromHeight(minTouchTarget),
          ),
          onPressed: onPressed,
          icon: const Icon(Icons.switch_account_rounded),
          label: const Text('Switch account'),
        ),
      ),
    );
  }
}

/// The line explaining what "Switch account" does — and does not — do.
/// Scrolls with the body; see [_SwitchAccountBar] for why it is separate.
class _SwitchAccountNote extends StatelessWidget {
  const _SwitchAccountNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Switching accounts does not unlock this profile — it stays locked '
      'until an adult enters the PIN.',
      style: Theme.of(context).textTheme.labelSmall,
      textAlign: TextAlign.center,
    );
  }
}

class _NoEducatorsHint extends StatelessWidget {
  const _NoEducatorsHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded, size: 32),
          SizedBox(height: 8),
          Text(
            'No parent or teacher is linked to this device yet, so the '
            'lock cannot be dismissed here. Ask the device owner to '
            'sign in once.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
