import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/stt_service.dart' show sttServiceProvider;
import '../../../providers/app_providers.dart' show settingsProvider;
import '../controllers/voice_command_controller.dart';

/// Shared plumbing for the gaze scopes that layer spoken-command control on top
/// of gaze ([GazeScope] and [GazeDpadScope]). It owns the
/// [VoiceCommandController], repaints the host on each "listening / last heard"
/// change, performs the global scroll gesture, and builds the little mic status
/// chip — so both scopes behave identically and only differ in what a phrase
/// *means* (their own [onVoiceCommand]).
mixin VoiceControlMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  VoiceCommandController? _voice;

  /// Logical pixels a spoken "scroll up/down" moves the list — matches the
  /// gaze step so voice and head scrolling feel the same.
  static const double _voiceScrollStep = 320;

  /// True once [startVoiceControl] has armed the microphone.
  bool get voiceActive => _voice != null;

  /// Maps a recognised phrase to an action. Implemented by the host scope.
  void onVoiceCommand(String text);

  /// Arms the microphone and begins listening. Call from `initState` only when
  /// the learner has enabled voice commands (and Gaze Control overall).
  void startVoiceControl() {
    if (_voice != null) return;
    final stt = ref.read(sttServiceProvider);
    final locale =
        ref.read(settingsProvider).locale == 'fil' ? 'fil-PH' : 'en-US';
    final voice = VoiceCommandController(
      stt: stt,
      locale: locale,
      onCommand: onVoiceCommand,
    );
    voice.addListener(_onVoiceUpdate);
    _voice = voice;
    voice.start();
  }

  void _onVoiceUpdate() {
    if (mounted) setState(() {});
  }

  /// Tears the controller down. Call from `dispose`.
  void disposeVoiceControl() {
    _voice?.removeListener(_onVoiceUpdate);
    _voice?.dispose();
    _voice = null;
  }

  /// Scrolls whatever is under the screen centre by one step. [dir] is -1 (up)
  /// or 1 (down). Synthesises a wheel event so it drives any normal scrollable
  /// without the scope needing a handle on the list's controller.
  void voiceScroll(int dir) {
    if (!mounted) return;
    final size = MediaQuery.sizeOf(context);
    WidgetsBinding.instance.handlePointerEvent(
      PointerScrollEvent(
        position: Offset(size.width / 2, size.height / 2),
        scrollDelta: Offset(0, dir * _voiceScrollStep),
      ),
    );
  }

  /// The small "Listening… / last heard" mic chip, or null when voice is off.
  /// Purely informational; the host places it (and wraps it in [IgnorePointer]).
  Widget? voiceChip() {
    final voice = _voice;
    if (voice == null) return null;
    final text = voice.unavailable
        ? 'Microphone unavailable'
        : voice.lastHeard.isNotEmpty
            ? voice.lastHeard
            : (voice.isListening ? 'Listening…' : 'Voice ready');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            voice.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
