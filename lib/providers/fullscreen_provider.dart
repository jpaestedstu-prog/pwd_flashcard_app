import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Fullscreen ("presentation") Mode ──────────────────
/// Whether the app is showing content edge-to-edge, with the bottom nav bar
/// hidden ([BottomNavShell]) and every screen's app bar collapsed to a slim
/// exit-only strip ([fullscreenBar]).
///
/// Turned on by a Teacher / Parent from Settings, for the case this exists to
/// serve: a shared tablet propped up in front of a class, or mirrored to a TV,
/// where the navigation chrome is both wasted pixels and a distraction.
///
/// **Session-scoped on purpose.** It is deliberately *not* part of
/// [AppSettings] (which persists to Hive per profile) for two reasons:
///
/// 1. Presentation mode describes the current *situation*, not a preference. A
///    tablet that was projecting yesterday is an ordinary tablet today, and an
///    educator should never have to remember to undo it.
/// 2. [AppSettings] is per-profile, but this is not: an educator turns it on
///    and then hands the device to a learner, whose profile must inherit the
///    mode rather than reset it.
///
/// Defaults to `false`, so an app that never touches this behaves exactly as
/// it did before the mode existed.
final fullscreenModeProvider = StateProvider<bool>((ref) => false);
