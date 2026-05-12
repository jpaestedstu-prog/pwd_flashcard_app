import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/pin_auth_service.dart';
import '../../../core/security/pin_credential_helper.dart';
import '../../../core/services/lock_enforcer.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/lock_state_provider.dart';
import '../../../providers/pin_unlock_grace_provider.dart';
import '../../../providers/unlocking_educators_provider.dart';
import '../services/child_unlock_override_service.dart';

/// Grace window granted on a successful PIN / recovery-code entry. The
/// underlying time-limit/alarm/schedule rule may still be active, so
/// without this the [LockEnforcerGate] would re-push the lock screen
/// the moment we route to `/home`. Thirty minutes is long enough to
/// finish a session without giving the child unbounded access — the
/// override stops applying as soon as the timestamp passes.
const Duration _pinUnlockGrace = Duration(minutes: 30);

/// Full-screen "Time's Up" lock that requires a parent/teacher PIN to
/// dismiss. Shown when [lockStateProvider] for the active child profile
/// returns a non-null [LockReason].
///
/// Design:
///   • System back is disabled (`PopScope` + `canPop: false`).
///   • Status bar is hidden for a kiosk feel.
///   • The PIN pad tries every unlocking educator profile in turn —
///     first match dismisses the lock and routes to `/home`.
///   • A "Use recovery code" link offers the educator-only fallback
///     for forgotten PINs (matches the recovery-code mechanism added
///     in [PinCredentialHelper]).
class TimeUpLockScreen extends ConsumerStatefulWidget {
  const TimeUpLockScreen({super.key});

  @override
  ConsumerState<TimeUpLockScreen> createState() =>
      _TimeUpLockScreenState();
}

class _TimeUpLockScreenState extends ConsumerState<TimeUpLockScreen> {
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

  @override
  void initState() {
    super.initState();
    // Hide status / nav bars for a kiosk feel.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cooldownTicker?.cancel();
    _pinController.dispose();
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

  @override
  Widget build(BuildContext context) {
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
    ref.listen<LockReason?>(
      lockStateProvider(profile.id),
      (_, next) {
        if (next == null && mounted) {
          GoRouter.of(context).go('/home');
        }
      },
    );

    final reason = ref.watch(lockStateProvider(profile.id));
    final educatorsAsync =
        ref.watch(unlockingEducatorsProvider(profile.id));

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  Icons.lock_clock_rounded,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  reason?.title ?? 'Locked',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (reason?.subtitle != null)
                  Text(
                    reason!.subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 4),
                Text(
                  'Active profile: ${profile.name}',
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                educatorsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                  data: (educators) {
                    if (educators.isEmpty) {
                      return const _NoEducatorsHint();
                    }
                    return _PinForm(
                      controller: _pinController,
                      verifying: _verifying,
                      error: _error,
                      onSubmit: (pin) => _attempt(pin, educators, profile.id),
                      onForgot: () =>
                          _showRecoveryDialog(educators, profile.id),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _attempt(
      String pin, List<UserProfile> educators, String childProfileId) async {
    if (_verifying) return;
    // Honour any active cooldown.
    if (_cooldownRemaining != null) {
      setState(() => _error =
          'Too many attempts. Try again in ${_formatRemaining(_cooldownRemaining!)}.');
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
      List<UserProfile> educators, String childProfileId) async {
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
              decoration:
                  const InputDecoration(labelText: 'Recovery code'),
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

class _PinForm extends StatelessWidget {
  final TextEditingController controller;
  final bool verifying;
  final String? error;
  final void Function(String pin) onSubmit;
  final VoidCallback onForgot;

  const _PinForm({
    required this.controller,
    required this.verifying,
    required this.error,
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
          autofocus: true,
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
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
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
