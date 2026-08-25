import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/adult_gate.dart';
import '../core/security/pin_auth_service.dart';
import '../core/security/pin_credential_helper.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../data/models/enums.dart';
import '../data/models/models.dart';
import '../providers/adult_gate_grace_provider.dart';
import '../providers/app_providers.dart';
import '../providers/unlocking_educators_provider.dart';

/// Asks whoever is holding the device to prove they are the adult, then
/// returns whether they did.
///
/// Returns true immediately when the active profile is not a supervised
/// learner, or when a check already passed inside [kAdultGateGrace]. Otherwise
/// it puts up [AdultGateDialog] — a linked educator's PIN where one exists, an
/// arithmetic question where none does — and returns what that dialog decided.
///
/// Callers should treat false as "the learner tapped this by mistake": say
/// nothing accusatory, just do not proceed.
Future<bool> requireAdult(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  final profile = ref.read(profileProvider);
  if (profile == null) return true;

  final grace = ref.read(adultGateGraceProvider.notifier);
  if (grace.isGranted(profile.id)) return true;

  // Only load the educator list for someone who could actually be gated —
  // it is a Hive join, and a Player has nobody linked by definition.
  if (!profile.role.isEnrollableLearner) return true;

  List<UserProfile> educators;
  try {
    educators = await ref.read(unlockingEducatorsProvider(profile.id).future);
  } catch (_) {
    // A failed lookup must fall through to the arithmetic gate rather than
    // leaving the board permanently uneditable.
    educators = const [];
  }
  if (!context.mounted) return false;

  final mode = adultGateModeFor(profile: profile, educators: educators);
  if (mode == AdultGateMode.none) return true;

  final passed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AdultGateDialog(
      reason: reason,
      candidates: adultGateCandidates(educators),
      mode: mode,
    ),
  );

  if (passed == true) {
    grace.grant(profile.id);
    return true;
  }
  return false;
}

/// The gate itself. Public so it can be pumped directly in tests.
class AdultGateDialog extends StatefulWidget {
  const AdultGateDialog({
    super.key,
    required this.reason,
    required this.candidates,
    required this.mode,
    this.random,
  });

  /// One line saying what is being protected, e.g. "to change this board".
  final String reason;

  /// Educator profiles whose PIN opens the gate. Empty in
  /// [AdultGateMode.math].
  final List<UserProfile> candidates;

  final AdultGateMode mode;

  /// Seam so a test can pin the arithmetic question.
  final Random? random;

  @override
  State<AdultGateDialog> createState() => _AdultGateDialogState();
}

class _AdultGateDialogState extends State<AdultGateDialog> {
  final _controller = TextEditingController();

  late AdultMathChallenge _challenge =
      AdultMathChallenge.random(widget.random);

  String? _error;

  /// Failed PIN attempts in this dialog, driving the shared cooldown curve.
  int _failedAttempts = 0;
  DateTime? _cooldownEndsAt;

  bool get _isPin => widget.mode == AdultGateMode.pin;

  Duration? get _cooldownRemaining {
    final until = _cooldownEndsAt;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left > Duration.zero ? left : null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isPin) {
      _submitPin();
    } else {
      _submitMath();
    }
  }

  void _submitPin() {
    final remaining = _cooldownRemaining;
    if (remaining != null) {
      setState(() => _error =
          'Too many tries. Wait ${_formatRemaining(remaining)}.');
      return;
    }

    final pin = _controller.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'Enter the 4-digit PIN.');
      return;
    }

    final ok = adultGateAcceptsPin(
      pin: pin,
      candidates: widget.candidates,
      verify: PinCredentialHelper.verify,
    );
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }

    _failedAttempts += 1;
    // Same escalating curve the "Time's Up" lock uses, so a learner cannot
    // sit and try every combination.
    final cooldown = PinAuthService.cooldownFor(_failedAttempts);
    setState(() {
      if (cooldown > Duration.zero) {
        _cooldownEndsAt = DateTime.now().add(cooldown);
        _error = 'Too many tries. Wait ${_formatRemaining(cooldown)}.';
      } else {
        _error = 'That PIN did not match. Ask your parent or teacher.';
      }
      _controller.clear();
    });
  }

  void _submitMath() {
    if (_challenge.accepts(_controller.text)) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      // A fresh question rather than a retry of the same one: guessing at a
      // moving target is not worth a learner's patience.
      _challenge = AdultMathChallenge.random(widget.random);
      _error = 'Not quite. Here is a new question.';
      _controller.clear();
    });
  }

  static String _formatRemaining(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);

    return AlertDialog(
      title: const Text('Ask an adult'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isPin
                    ? 'A parent or teacher PIN is needed ${widget.reason}.'
                    : 'Answer this ${widget.reason}.',
                style: AppTypography.bodyMedium.copyWith(
                  color: hc.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (!_isPin) ...[
                Semantics(
                  // Read as words: a screen reader says "4 times 9" rather
                  // than spelling out the symbol.
                  label: 'What is ${_challenge.a} times ${_challenge.b}?',
                  child: ExcludeSemantics(
                    child: Text(
                      '${_challenge.question} = ?',
                      style: AppTypography.titleLarge.copyWith(
                        color: hc.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                obscureText: _isPin,
                maxLength: 4,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: _isPin ? 'PIN' : 'Answer',
                  counterText: '',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
