import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_handler.dart';
import '../../../data/models/enums.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/lock_state_provider.dart';

/// App-root gate that watches the active child profile's lock state
/// and routes to `/time-up-lock` whenever a [LockReason] becomes
/// non-null mid-session.
///
/// Catches the case of a child crossing the daily limit while already
/// in the middle of a game — the router redirect alone fires only on
/// navigations, not on time-driven state changes. This widget closes
/// that gap by listening every time the [lockStateProvider] flips.
///
/// Mounted at the root of the app (above MaterialApp.router's child)
/// so it covers every route. Inert for non-learner profiles.
class LockEnforcerGate extends ConsumerWidget {
  final Widget child;
  const LockEnforcerGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final isLearner = profile != null &&
        (profile.role == UserRole.student ||
            profile.role == UserRole.child) &&
        !profile.isGuestPlayer;

    if (isLearner) {
      ref.listen(lockStateProvider(profile.id), (_, next) {
        if (next == null) return;
        try {
          // Avoid pushing on top of itself when the lock screen is the
          // current route.
          final loc =
              GoRouter.of(context).routeInformationProvider.value.uri.path;
          if (loc == '/time-up-lock') return;
          // Use the root navigator so this works from inside the shell
          // routes too (games, flashcards, …).
          final navCtx = rootNavigatorKey.currentContext ?? context;
          GoRouter.of(navCtx).go('/time-up-lock');
        } catch (e, s) {
          // GoRouter can throw if the navigator is being torn down or
          // the context isn't ready yet. Log silently — the next 10 s
          // wall-clock tick (or the router redirect on the next nav)
          // will re-evaluate and retry.
          ErrorHandler.report(e, s, 'LockEnforcerGate:silent');
        }
      });
    }

    return child;
  }
}
