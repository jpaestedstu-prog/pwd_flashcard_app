import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/focused_label.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_providers.dart' show settingsProvider;
import '../../gamepad/providers/gamepad_settings_provider.dart';
import '../../gamepad/providers/gamepad_status_provider.dart'
    show gamepadServiceProvider;
import '../../gamepad/services/gamepad_service.dart';
import '../controllers/gaze_controller.dart';
import '../logic/gaze_focus_driver.dart';
import '../models/gaze_models.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_settings_provider.dart';
import '../services/gaze_metrics.dart';
import '../services/gaze_switch_input.dart';

/// The most recent highlights spoken aloud, newest last (debug and profile
/// builds only) — so a test can check what a learner heard.
final List<String> gazeDebugSpoken = [];

/// What a gaze scope does around its input, shared so every scope behaves
/// the same: the **usage measurements** session, the **one-switch** input,
/// and the **spoken highlight** — including how long scanning waits for it
/// ([scanHoldForSpeech]).
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
  /// [onSwitch], a controller's stick or arrows [onSwitchSteer].
  void beginGazeSession(
    GazeSettings settings, {
    required VoidCallback onSwitch,
    void Function(GazeZone direction)? onSwitchSteer,
  }) {
    _metricsSession ??= GazeMetrics.instance.begin(_profileId());
    _configure(settings, onSwitch, onSwitchSteer);
  }

  /// The learner's settings changed while this scope is driving input.
  void reconfigureGazeSession(
    GazeSettings settings, {
    required VoidCallback onSwitch,
    void Function(GazeZone direction)? onSwitchSteer,
  }) {
    if (_metricsSession == null) return;
    _configure(settings, onSwitch, onSwitchSteer);
  }

  void _configure(
    GazeSettings settings,
    VoidCallback onSwitch,
    void Function(GazeZone direction)? onSwitchSteer,
  ) {
    if (settings.switchSelects) {
      _switchToken ??= GazeSwitchInput.instance.attach(
        onPress: onSwitch,
        onSteer: onSwitchSteer,
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
    if (_speak) {
      _listenToSpeech();
    } else {
      _stopListeningToSpeech();
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

  /// The learner left a surface (Back pill, exit row, "go back"): counts it,
  /// and stops a pending look-and-hold — keeping still after a Back must not
  /// pick whatever the screen underneath has highlighted.
  void gazeBacked(GazeController? controller) {
    controller?.disarmRestSelect();
    GazeMetrics.instance.backed();
  }

  /// This scope stands down (disposed, or suspended).
  void endGazeSession() {
    _detachSwitch();
    final session = _metricsSession;
    _metricsSession = null;
    if (session != null) GazeMetrics.instance.end(session);
    if (_speak) _tts?.stop();
    _stopListeningToSpeech();
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
    // A new name: until the engine starts reading it, nothing holds the scan.
    _highlightSpeaking = false;
    _afterSpeechTimer?.cancel();
    _afterSpeechTimer = null;
    _speechPending = true;
    (_filipino ? tts.speakFilipino(text) : tts.speakEnglish(text)).ignore();
  }

  /// Says the focused control's name once focus has settled (Flutter applies
  /// a focus move on the next frame) — or "Back" when the highlight is on the
  /// Back pill ([exit]), which holds no focus of its own: the name read used
  /// to be the control the pill was lit after.
  void sayFocusedSoon({bool exit = false}) {
    if (!_speak) return;
    if (exit) {
      final t = AppLocalizations.of(context);
      sayHighlight(t?.back ?? 'Back');
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sayHighlight(FocusedLabel.of(GazeFocusDriver.focused?.context));
    });
    // A focus move that dirties nothing schedules no frame by itself.
    WidgetsBinding.instance.scheduleFrame();
  }

  // ── Scanning by ear ───────────────────────────────────────────────────

  /// After a highlight's name has been read in full, the highlight stays a
  /// moment longer, so a learner who scans by ear can react to what they
  /// heard before it moves on.
  static const Duration afterSpeech = Duration(seconds: 1);

  bool _listeningToSpeech = false;

  /// A name was handed to the engine and it has not started reading it yet.
  bool _speechPending = false;

  /// The engine is reading the latest highlight's name.
  bool _highlightSpeaking = false;
  Timer? _afterSpeechTimer;

  void _listenToSpeech() {
    if (_listeningToSpeech) return;
    _listeningToSpeech = true;
    TtsService.speaking.addListener(_onSpeaking);
  }

  void _stopListeningToSpeech() {
    if (!_listeningToSpeech) return;
    _listeningToSpeech = false;
    TtsService.speaking.removeListener(_onSpeaking);
    _speechPending = false;
    _highlightSpeaking = false;
    _afterSpeechTimer?.cancel();
    _afterSpeechTimer = null;
  }

  void _onSpeaking() {
    if (TtsService.speaking.value) {
      // Only speech that started after the latest name counts as reading
      // it (the stop before it ends the previous one).
      if (_speechPending) {
        _speechPending = false;
        _highlightSpeaking = true;
      }
      return;
    }
    if (!_highlightSpeaking) return;
    _highlightSpeaking = false;
    _afterSpeechTimer?.cancel();
    _afterSpeechTimer = Timer(afterSpeech, () => _afterSpeechTimer = null);
  }

  /// How much longer a scanning step should wait for the spoken highlight:
  /// while its name is still being read, and for [afterSpeech] after. Zero
  /// when highlights are not read aloud, or the engine never started.
  ///
  /// Names used to be cut off by the next step: at the default speed a row
  /// such as "Assessments, Learning Gains, My Portfolio, My Goals" takes
  /// longer to say than a step lasts.
  Duration scanHoldForSpeech() {
    if (!_speak) return Duration.zero;
    if (_highlightSpeaking || _afterSpeechTimer != null) {
      return const Duration(milliseconds: 150);
    }
    return Duration.zero;
  }
}
