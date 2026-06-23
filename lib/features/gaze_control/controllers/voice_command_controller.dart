import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/accessibility/stt_service.dart';

/// Keeps the microphone listening for short spoken commands and reports each
/// final phrase via [onCommand]. Wraps the session-based [SttService] in a poll
/// loop that re-arms whenever recognition stops (it listens in ~8 s bursts), so
/// the learner can speak a command at any time.
///
/// A `ChangeNotifier` so a screen can show a small "listening / last heard"
/// indicator. The STT plumbing lives here; the *meaning* of a phrase is the pure
/// `resolveVoiceCommand` (unit-tested separately).
class VoiceCommandController extends ChangeNotifier {
  VoiceCommandController({
    required SttService stt,
    required this.locale,
    required this.onCommand,
  }) : _stt = stt;

  final SttService _stt;

  /// 'en-US' or 'fil-PH'.
  final String locale;

  /// Called with each final recognised phrase.
  final void Function(String text) onCommand;

  bool _available = false;
  bool _disposed = false;
  String _lastHeard = '';
  Timer? _poll;

  bool get isListening => _stt.isListening;
  bool get available => _available;
  String get lastHeard => _lastHeard;

  Future<void> start() async {
    _available = await _stt.init();
    if (_disposed || !_available) {
      _notify();
      return;
    }
    // Re-arm if recognition has stopped (it auto-stops after each burst).
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _ensureListening());
    _ensureListening();
    _notify();
  }

  Future<void> _ensureListening() async {
    if (_disposed || !_available || _stt.isListening) return;
    try {
      await _stt.startListening(
        locale: locale,
        onResult: (text, isFinal) {
          if (_disposed) return;
          _lastHeard = text;
          _notify();
          if (isFinal && text.trim().isNotEmpty) onCommand(text);
        },
      );
      _notify();
    } catch (_) {
      // A failed session just gets retried by the next poll tick.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _stt.cancel();
    super.dispose();
  }
}
