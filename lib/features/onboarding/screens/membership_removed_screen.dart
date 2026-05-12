import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Shown to a learner whose classroom or home-group membership was just
/// deleted by the educator. The router pushes here from
/// [MembershipEvictionGate] after [ProfileNotifier.handleEviction] runs.
///
/// Behaviour: a brief notice with an auto-redirect to `/profile`
/// (the role-selection / Create Profile screen) after a short delay.
/// The learner can also tap Continue to skip the wait. Both paths land
/// on the same screen, so there's no functional difference — the timer
/// just removes the need for a young user to find and tap a button.
///
/// Query params:
///   • `from` — `class` or `group`. Tweaks the message wording.
///   • `name` — the classroom / home-group display name.
class MembershipRemovedScreen extends StatefulWidget {
  final String fromKind;
  final String? fromName;

  const MembershipRemovedScreen({
    super.key,
    required this.fromKind,
    this.fromName,
  });

  @override
  State<MembershipRemovedScreen> createState() =>
      _MembershipRemovedScreenState();
}

class _MembershipRemovedScreenState extends State<MembershipRemovedScreen> {
  /// How long the notice stays on screen before auto-redirecting. Long
  /// enough for a child to read and process "you've been removed",
  /// short enough that it doesn't feel like a stuck dead-end.
  static const _autoRedirectDelay = Duration(seconds: 4);

  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _redirectTimer = Timer(_autoRedirectDelay, () {
      if (mounted) context.go('/profile');
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  bool get _isClass => widget.fromKind == 'class';

  String get _scopeLabel => _isClass ? 'class' : 'home group';

  String get _heading {
    final n = widget.fromName?.trim();
    if (n == null || n.isEmpty) {
      return _isClass
          ? 'You\'ve been removed from your class.'
          : 'You\'ve been removed from your home group.';
    }
    return 'You\'ve been removed from $n.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.exit_to_app_rounded,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                _heading,
                style: AppTypography.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your progress is safe on this device. You can join a different $_scopeLabel using a new code.',
                style: AppTypography.bodyMedium.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    _redirectTimer?.cancel();
                    context.go('/profile');
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continue'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Returning to setup automatically…',
                style: AppTypography.bodySmall.copyWith(
                  color: HCColor.of(context).textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
