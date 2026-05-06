import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Animated page transitions for go_router, categorized by screen type.
///
/// Usage in app_router.dart:
/// ```dart
/// GoRoute(
///   path: '/shop',
///   pageBuilder: (context, state) => AppPageTransitions.slideUp(
///     key: state.pageKey,
///     child: const ShopScreen(),
///   ),
/// )
/// ```
class AppPageTransitions {
  AppPageTransitions._();

  static const Duration _normal = Duration(milliseconds: 400);

  // ─── Fade (default shell tabs) ────────────────────────
  static CustomTransitionPage<void> fade({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  // ─── Slide Up (assessments, modals, full-screen overlays) ──
  static CustomTransitionPage<void> slideUp({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: _normal,
      reverseTransitionDuration: _normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  // ─── Slide Right (detail screens, drill-in) ───────────
  static CustomTransitionPage<void> slideRight({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: _normal,
      reverseTransitionDuration: _normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.25, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  // ─── Scale + Fade (games, interactive activities) ─────
  static CustomTransitionPage<void> scaleUp({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: _normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  // ─── Blur + Fade (settings, profile, overlays) ────────
  static CustomTransitionPage<void> blurFade({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: _normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final blurValue = Tween<double>(begin: 4.0, end: 0.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        );
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurValue.value,
                sigmaY: blurValue.value,
              ),
              child: Opacity(
                opacity: animation.value,
                child: child,
              ),
            );
          },
        );
      },
    );
  }

  // ─── Slide from Bottom (leaderboards, showcase) ───────
  static CustomTransitionPage<void> slideFromBottom({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: _normal,
      reverseTransitionDuration: _normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: Curves.easeInQuart,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  /// For reduced motion: instant with no animation.
  static CustomTransitionPage<void> none({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }
}
