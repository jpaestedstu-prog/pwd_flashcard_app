import 'package:flutter/material.dart';
import '../core/accessibility/voice_navigation_service.dart';

/// A [NavigatorObserver] that announces screen transitions through
/// the [VoiceNavigationService] for visually impaired users.
///
/// Added to GoRouter's observers list. On each push/pop, maps the route
/// path to a human-readable description and speaks it aloud.
class VoiceNavigationObserver extends NavigatorObserver {
  final VoiceNavigationService _voiceNav;

  VoiceNavigationObserver(this._voiceNav);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _announceRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _announceRoute(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _announceRoute(newRoute);
    }
  }

  void _announceRoute(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;

    final info = VoiceNavigationService.describeRoute(name);
    _voiceNav.announceScreen(info.name, description: info.description);
  }
}
