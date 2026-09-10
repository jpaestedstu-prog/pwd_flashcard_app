import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/voice_navigation_service.dart';
import '../providers/app_providers.dart';

/// Decides what to say when the visible screen changes, and says it.
///
/// Separate from [VoiceNavigationObserver] because Flutter asserts that a
/// `NavigatorObserver` belongs to exactly one Navigator
/// (`assert(observer.navigator == null)`), and two navigators matter here: the
/// root one for drill-downs, and the shell's for bottom-nav tabs. So the router
/// builds two observers over a single announcer, which is what lets "did I
/// already say this?" be answered across both.
class VoiceRouteAnnouncer {
  VoiceRouteAnnouncer(this._ref);

  final Ref _ref;

  String? _lastAnnounced;

  /// What was last spoken, for tests. Null once voice navigation is off.
  @visibleForTesting
  String? get lastAnnounced => _lastAnnounced;

  /// Announce whichever screen the router is now showing.
  ///
  /// Never throws. This runs inside `Navigator`'s observer callbacks on every
  /// navigation in the app, including for the great majority of users who have
  /// the feature off, so an exception here would break navigation itself. A
  /// screen that cannot be announced is silent, not fatal.
  void announceCurrent(BuildContext? context) {
    try {
      announceLocation(context == null ? null : locationOf(context));
    } on Object catch (e, st) {
      if (kDebugMode) debugPrint('VoiceNav announce failed: $e\n$st');
    }
  }

  /// The gate, the de-duplication and the speech, split from [locationOf] so
  /// each can be tested without the other.
  @visibleForTesting
  void announceLocation(String? location) {
    // The OFF path stops on this line: one bool read, then nothing. It matters
    // that the check comes first — `voiceNavigationProvider` constructs a
    // FlutterTts, and no other live code reads it, so touching it before this
    // point would spin up the platform speech engine for every user who never
    // turned the feature on.
    if (!_ref.read(settingsProvider).voiceNavigation) {
      // Cleared so that turning the setting on mid-session cannot be swallowed
      // by a stale match in the de-duplication below.
      _lastAnnounced = null;
      return;
    }
    if (location == null || location.isEmpty) return;

    // A dialog or sheet leaves the router's location alone, so opening and
    // closing one lands here with the screen that is already announced.
    if (location == _lastAnnounced) return;
    _lastAnnounced = location;

    if (kDebugMode) debugPrint('VoiceNav route: $location');

    final service = _ref.read(voiceNavigationProvider);
    final info = service.describeRouteForViewer(location);
    // An empty description means the route is not in the description map and
    // the generic "Page." / "Pahina." fallback came back. Announcing that is
    // worse than announcing nothing: it masks the transition with a word that
    // carries no information. Found on device, where the Analytics tab and the
    // Parent Dashboard both said "Page."
    if (info.description.isEmpty) return;
    service.announceScreen(info.name, description: info.description);
  }

  /// The route pattern the router is currently showing.
  ///
  /// Taken from GoRouter rather than from the `Route` the observer was handed,
  /// which is the mistake this used to make. `RouteSettings.name` is null for
  /// every screen here — all 132 of them come from custom `pageBuilder`s via
  /// `AppPageTransitions`, which pass only `key` — and that page key is the
  /// matched path only for *declarative* navigation. An imperative
  /// `context.push` wraps the match in an `ImperativeRouteMatch` carrying a
  /// generated unique key, so pushed screens resolved to random strings like
  /// `vjy\cgklpfbmc[fqtYugnsec[kgmceaj`: every drill-down in the app was
  /// undescribable while bottom-nav tabs worked fine.
  ///
  /// `fullPath` is the matched *pattern* (`/child-alarms/:profileId`), which is
  /// what the description map is keyed on; `uri.path` covers the rare match
  /// that has no pattern.
  @visibleForTesting
  static String? locationOf(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return null;
    final state = router.state;
    final fullPath = state.fullPath;
    return (fullPath != null && fullPath.isNotEmpty)
        ? fullPath
        : state.uri.path;
  }
}

/// A [NavigatorObserver] that announces screen transitions through
/// [VoiceNavigationService] for visually impaired users.
///
/// Attached to GoRouter's root observers and to the bottom-nav shell's, both
/// over the same [VoiceRouteAnnouncer]. Inert unless the profile has
/// Voice-Guided Navigation switched on.
class VoiceNavigationObserver extends NavigatorObserver {
  VoiceNavigationObserver(this._announcer);

  final VoiceRouteAnnouncer _announcer;

  /// Announce once the frame has settled.
  ///
  /// Navigator notifies its observers while it is still updating, and on a pop
  /// the router's own state has not necessarily caught up — reading it there
  /// would announce the screen being left rather than the one returned to.
  void _announceAfterFrame() {
    final context = navigator?.context;
    if (context == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      _announcer.announceCurrent(context);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _announceAfterFrame();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _announceAfterFrame();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _announceAfterFrame();
  }

  // didRemove is deliberately not overridden. A declarative tab switch pushes
  // the new page and removes the old one, so didPush has already announced the
  // destination by the time the removal lands.
}
