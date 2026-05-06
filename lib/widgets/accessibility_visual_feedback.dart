import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

// ─────────────────────────────────────────────────────────────
//  1. Animated Focus Ring — for high-contrast mode
// ─────────────────────────────────────────────────────────────

/// Wraps a child widget with an animated pulsing focus ring when
/// high-contrast mode is active and the widget has focus.
///
/// Use this around interactive elements (buttons, cards, inputs)
/// to provide enhanced visual focus indication for PWD users.
class AccessibleFocusRing extends ConsumerWidget {
  final Widget child;
  final double borderRadius;
  final Color? ringColor;
  final bool forceFocusRing;

  const AccessibleFocusRing({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.ringColor,
    this.forceFocusRing = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = ref.watch(settingsProvider.select((s) => s.highContrastMode));
    if (!hc && !forceFocusRing) return child;

    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          if (!hasFocus) return child;

          return _PulsingFocusBorder(
            borderRadius: borderRadius,
            color: ringColor ?? Theme.of(context).colorScheme.primary,
            child: child,
          );
        },
      ),
    );
  }
}

class _PulsingFocusBorder extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final Color color;

  const _PulsingFocusBorder({
    required this.child,
    required this.borderRadius,
    required this.color,
  });

  @override
  State<_PulsingFocusBorder> createState() => _PulsingFocusBorderState();
}

class _PulsingFocusBorderState extends State<_PulsingFocusBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.5 + 0.5 * _controller.value;
        final width = 2.5 + 1.0 * _controller.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: widget.color.withValues(alpha: opacity),
              width: width,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  2. Microphone Waveform — for voice/STT input
// ─────────────────────────────────────────────────────────────

/// Animated microphone icon with pulsing waveform rings.
///
/// Shows visual feedback when the app is listening for speech input.
/// Use this in game screens and voice-guided mode alongside STT.
class MicrophoneWaveform extends StatefulWidget {
  /// Whether the mic is actively listening.
  final bool isListening;

  /// Size of the mic icon.
  final double size;

  /// Color of the animation rings.
  final Color? color;

  const MicrophoneWaveform({
    super.key,
    required this.isListening,
    this.size = 56,
    this.color,
  });

  @override
  State<MicrophoneWaveform> createState() => _MicrophoneWaveformState();
}

class _MicrophoneWaveformState extends State<MicrophoneWaveform>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isListening) _startAnimations();
  }

  @override
  void didUpdateWidget(MicrophoneWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _startAnimations();
    } else if (!widget.isListening && oldWidget.isListening) {
      _stopAnimations();
    }
  }

  void _startAnimations() {
    _pulseController.repeat(reverse: true);
    _ringController.repeat();
  }

  void _stopAnimations() {
    _pulseController.stop();
    _pulseController.value = 0;
    _ringController.stop();
    _ringController.value = 0;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding rings
          if (widget.isListening) ...[
            AnimatedBuilder(
              animation: _ringController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(widget.size * 2, widget.size * 2),
                  painter: _WaveRingPainter(
                    progress: _ringController.value,
                    color: color,
                  ),
                );
              },
            ),
          ],
          // Mic icon with pulse
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = widget.isListening
                  ? 1.0 + 0.15 * _pulseController.value
                  : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isListening
                    ? color
                    : color.withValues(alpha: 0.2),
                boxShadow: widget.isListening
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.isListening ? Icons.mic : Icons.mic_none,
                color: widget.isListening
                    ? Colors.white
                    : color,
                size: widget.size * 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * 0.4 + maxRadius * 0.6 * ringProgress;
      final opacity = (1.0 - ringProgress) * 0.5;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────────────────────
//  3. TTS Highlight Text — highlights words as TTS reads them
// ─────────────────────────────────────────────────────────────

/// Displays text with per-word highlighting that advances as
/// TTS reads aloud. Callers advance the highlight via [currentWordIndex].
///
/// Example:
/// ```dart
/// TtsHighlightText(
///   text: 'The cat sat on the mat',
///   currentWordIndex: _currentWord, // updated via TTS progress callback
/// )
/// ```
class TtsHighlightText extends StatelessWidget {
  final String text;
  final int currentWordIndex;
  final TextStyle? baseStyle;
  final Color? highlightColor;

  const TtsHighlightText({
    super.key,
    required this.text,
    this.currentWordIndex = -1,
    this.baseStyle,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final words = text.split(' ');
    final theme = Theme.of(context);
    final base = baseStyle ?? theme.textTheme.bodyLarge!;
    final highlight = highlightColor ?? theme.colorScheme.primaryContainer;

    return RichText(
      text: TextSpan(
        children: List.generate(words.length, (i) {
          final isHighlighted = i == currentWordIndex;
          return TextSpan(
            text: '${words[i]}${i < words.length - 1 ? ' ' : ''}',
            style: base.copyWith(
              backgroundColor:
                  isHighlighted ? highlight : Colors.transparent,
              fontWeight:
                  isHighlighted ? FontWeight.w700 : base.fontWeight,
              color: isHighlighted
                  ? theme.colorScheme.onPrimaryContainer
                  : base.color ?? theme.colorScheme.onSurface,
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  4. Status Pattern Overlay — patterns on status colors
//     for color-blind accessibility
// ─────────────────────────────────────────────────────────────

/// Overlays a pattern (diagonal lines, dots, crosses) on status
/// indicators so meaning isn't conveyed by color alone.
///
/// Wraps status badges, progress bars, or indicator dots.
class StatusPatternOverlay extends ConsumerWidget {
  final Widget child;
  final StatusType statusType;
  final double width;
  final double height;

  const StatusPatternOverlay({
    super.key,
    required this.child,
    required this.statusType,
    this.width = 24,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = ref.watch(settingsProvider.select((s) => s.highContrastMode));
    if (!hc) return child;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: CustomPaint(
              painter: _StatusPatternPainter(statusType: statusType),
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusType { success, error, warning, info, neutral }

class _StatusPatternPainter extends CustomPainter {
  final StatusType statusType;

  _StatusPatternPainter({required this.statusType});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    switch (statusType) {
      case StatusType.success:
        // Checkmark pattern
        final path = Path()
          ..moveTo(size.width * 0.2, size.height * 0.5)
          ..lineTo(size.width * 0.4, size.height * 0.7)
          ..lineTo(size.width * 0.8, size.height * 0.3);
        canvas.drawPath(path, paint);
        break;

      case StatusType.error:
        // X pattern
        canvas.drawLine(
          Offset(size.width * 0.25, size.height * 0.25),
          Offset(size.width * 0.75, size.height * 0.75),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.75, size.height * 0.25),
          Offset(size.width * 0.25, size.height * 0.75),
          paint,
        );
        break;

      case StatusType.warning:
        // Triangle pattern
        final path = Path()
          ..moveTo(size.width * 0.5, size.height * 0.2)
          ..lineTo(size.width * 0.8, size.height * 0.8)
          ..lineTo(size.width * 0.2, size.height * 0.8)
          ..close();
        canvas.drawPath(path, paint);
        break;

      case StatusType.info:
        // Circle with dot
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.5),
          size.width * 0.3,
          paint,
        );
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.35),
          2,
          paint,
        );
        break;

      case StatusType.neutral:
        // Horizontal lines
        for (var i = 0; i < 3; i++) {
          final y = size.height * (0.3 + i * 0.2);
          canvas.drawLine(
            Offset(size.width * 0.2, y),
            Offset(size.width * 0.8, y),
            paint,
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _StatusPatternPainter old) =>
      old.statusType != statusType;
}

// ─────────────────────────────────────────────────────────────
//  5. Audio Playing Indicator — visual feedback for TTS/audio
// ─────────────────────────────────────────────────────────────

/// Animated equalizer bars that show audio is currently playing.
///
/// Use next to TTS buttons or audio playback controls.
class AudioPlayingIndicator extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final Color? color;

  const AudioPlayingIndicator({
    super.key,
    required this.isPlaying,
    this.size = 24,
    this.color,
  });

  @override
  State<AudioPlayingIndicator> createState() => _AudioPlayingIndicatorState();
}

class _AudioPlayingIndicatorState extends State<AudioPlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(AudioPlayingIndicator old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !old.isPlaying) {
      _controller.repeat();
    } else if (!widget.isPlaying && old.isPlaying) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    if (!widget.isPlaying) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Icon(Icons.volume_up, size: widget.size * 0.7, color: color),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _EqualizerPainter(
            progress: _controller.value,
            color: color,
          ),
        );
      },
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _EqualizerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / 7;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      // Each bar oscillates at a slightly different phase
      final phase = progress * 2 * pi + i * 0.8;
      final height = size.height * (0.3 + 0.5 * (0.5 + 0.5 * sin(phase)));
      final x = i * (barWidth + barWidth * 0.5) + barWidth * 0.5;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - height, barWidth, height),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerPainter old) =>
      old.progress != progress;
}

// ─────────────────────────────────────────────────────────────
//  6. Haptic Feedback Ripple — visual confirmation of haptics
// ─────────────────────────────────────────────────────────────

/// Shows a brief expanding ripple + label (e.g., "Correct!") to
/// visually confirm haptic/sound feedback. Useful for deaf/HoH users
/// who can't hear audio cues.
///
/// Call [HapticFeedbackRipple.show(context, 'Correct!', Colors.green)]
/// as a static method.
class HapticFeedbackRipple {
  HapticFeedbackRipple._();

  static OverlayEntry? _currentEntry;

  /// Show a brief ripple overlay with a label.
  static void show(
    BuildContext context, {
    required String label,
    Color color = Colors.green,
    IconData? icon,
  }) {
    _currentEntry?.remove();

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _RippleOverlay(
        label: label,
        color: color,
        icon: icon,
        onDone: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _RippleOverlay extends StatefulWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onDone;

  const _RippleOverlay({
    required this.label,
    required this.color,
    this.icon,
    required this.onDone,
  });

  @override
  State<_RippleOverlay> createState() => _RippleOverlayState();
}

class _RippleOverlayState extends State<_RippleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            final opacity = progress < 0.7 ? 1.0 : 1.0 - (progress - 0.7) / 0.3;

            return Center(
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Expanding circle
                    Container(
                      width: 80 + 40 * progress,
                      height: 80 + 40 * progress,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withValues(alpha: 0.2 * (1.0 - progress)),
                        border: Border.all(
                          color: widget.color.withValues(alpha: 0.6 * (1.0 - progress)),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        widget.icon ?? Icons.check_circle,
                        color: widget.color,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Label
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
