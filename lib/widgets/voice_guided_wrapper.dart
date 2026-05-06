import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/accessibility/voice_navigation_service.dart';

/// Wraps an interactive widget with voice navigation announcements.
///
/// When voice-guided navigation is enabled, this widget announces the
/// [label] when the child receives focus or is tapped.
///
/// Usage:
/// ```dart
/// VoiceGuidedWrapper(
///   label: 'Button: Start Game',
///   child: ElevatedButton(...),
/// )
/// ```
class VoiceGuidedWrapper extends ConsumerWidget {
  final String label;
  final Widget child;
  final bool announceOnTap;

  const VoiceGuidedWrapper({
    super.key,
    required this.label,
    required this.child,
    this.announceOnTap = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceNav = ref.watch(voiceNavigationProvider);

    return Semantics(
      label: label,
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus && voiceNav.isEnabled) {
            voiceNav.announceWidget(label);
          }
        },
        child: announceOnTap
            ? GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (voiceNav.isEnabled) {
                    voiceNav.announceAction(label);
                  }
                },
                child: child,
              )
            : child,
      ),
    );
  }
}
