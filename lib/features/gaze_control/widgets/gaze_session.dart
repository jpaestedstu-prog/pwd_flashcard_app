import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/focused_label.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../providers/app_providers.dart' show settingsProvider;
import '../../gamepad/providers/gamepad_settings_provider.dart';
import '../../gamepad/providers/gamepad_status_provider.dart'
    show gamepadServiceProvider;
import '../../gamepad/services/gamepad_service.dart';
import '../controllers/gaze_controller.dart';
import '../logic/gaze_focus_driver.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_metrics.dart';
import '../services/gaze_switch_input.dart';

/// The most recent highlights spoken aloud, newest last (debug and profile
/// builds only) — so a test can check what a learner heard.
final List<String> gazeDebugSpoken = [];

/// What a gaze scope does around its input, shared so every scope behaves
/// the same: the **usage measurements** session, the **one-switch** input,
/// and the **spoken highlight**.
///
/// A scope calls [beginGazeSession] when it starts driving input (its camera
/// came up, or switch scanning began), [endGazeSession] when it stands down —
/// disposed, or suspended under another camera surface — and
/// [reconfigureGazeSession] when the learner's settings change under it.
mixin GazeSessionMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Object? _metricsSession;
  Object? _switchToken;
  bool _speak = false;
  TtsService? _tts;
  bool _filipino = false;

  /// Whether a session is open.
  bool get gazeSessionOpen => _metricsSession != null;

  /// Whose gaze use this is: the person at the tablet (the educator while
  /// they view a learner's dashboard — never the learner, who is not there).
  String? _profileId() {
    try {
      return gazeProfileIdAtTablet(ref.read);
    } catch (_) {
      return null;
    }
  }

  /// This scope starts driving input with [settings]; a switch press calls
  /// [onSwitch].
  void beginGazeSession(GazeSettings settings, {required VoidCallback onSwitch}) {
    _metricsSession ??= GazeMetrics.instance.begin(_profileId());
    _configure(settings, onSwitch);
  }

  /// The learner's settings changed while this scope is driving input.
  void reconfigureGazeSession(
    GazeSettings settings, {
    required VoidCallback onSwitch,
  }) {
    if (_metricsSession == null) return;
    _configure(settings, onSwitch);
  }

  void _configure(GazeSettings settings, VoidCallback onSwitch) {
    if (settings.switchSelects) {
      _switchToken ??= GazeSwitchInput.instance.attach(
        onPress: onSwitch,
        service: _gamepadService(),
      );
    } else {
      _detachSwitch();
    }
    _speak = settings.speakHighlight;
    if (_speak) {
      try {
        _tts ??= ref.read(ttsServiceProvider);
        _filipino = ref.read(settingsProvider).locale == 'fil';
      } catch (_) {
        _speak = false;
      }
    }
  }

  GamepadService? _gamepadService() {
    try {
      return ref.read(gamepadServiceProvider);
    } catch (_) {
      return null;
    }
  }

  void _detachSwitch() {
    final token = _switchToken;
    if (token == null) return;
    _switchToken = null;
    var gamepadOn = false;
    try {
      gamepadOn = ref.read(gamepadSettingsProvider).enabled;
    } catch (_) {}
    GazeSwitchInput.instance.detach(token, gamepadFeatureOn: gamepadOn);
  }

  /// A control was picked: counts it, and stops a pending look-and-hold, so
  /// keeping still afterwards cannot pick a second time — on this screen, or
  /// on the one the pick opened.
  void gazePicked(GazeController? controller, GazeSelectBy by) {
    controller?.disarmRestSelect();
    GazeMetrics.instance.selected(by);
  }

  /// This scope stands down (disposed, or suspended).
  void endGazeSession() {
    _detachSwitch();
    final session = _metricsSession;
    _metricsSession = null;
    if (session != null) GazeMetrics.instance.end(session);
    if (_speak) _tts?.stop();
  }

  /// Says [label] when spoken highlights are on.
  void sayHighlight(String? label) {
    if (!_speak || label == null) return;
    final text = label.replaceAll('\n', ' ').trim();
    if (text.isEmpty) return;
    final tts = _tts;
    if (tts == null) return;
    if (!kReleaseMode) {
      gazeDebugSpoken.add(text);
      if (gazeDebugSpoken.length > 20) gazeDebugSpoken.removeAt(0);
    }
    (_filipino ? tts.speakFilipino(text) : tts.speakEnglish(text)).ignore();
  }

  /// Says the focused control's name once focus has settled (Flutter applies
  /// a focus move on the next frame).
  void sayFocusedSoon() {
    if (!_speak) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sayHighlight(FocusedLabel.of(GazeFocusDriver.focused?.context));
    });
    // A focus move that dirties nothing schedules no frame by itself.
    WidgetsBinding.instance.scheduleFrame();
  }
}
