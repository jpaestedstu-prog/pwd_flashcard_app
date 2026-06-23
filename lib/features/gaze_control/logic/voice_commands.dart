import '../../../core/accessibility/stt_service.dart';
import '../models/gaze_action.dart';
import '../models/gaze_models.dart';

/// What a spoken command resolves to.
enum VoiceIntent { action, scrollUp, scrollDown, goBack, none }

/// Result of [resolveVoiceCommand]: an [intent] and, when it's
/// [VoiceIntent.action], the index of the matched action.
class VoiceCommandResult {
  final VoiceIntent intent;
  final int actionIndex;
  const VoiceCommandResult(this.intent, [this.actionIndex = -1]);

  static const VoiceCommandResult none = VoiceCommandResult(VoiceIntent.none);
}

bool _has(String text, List<String> words) =>
    words.any((w) => text == w || text.contains(w));

/// Maps a spoken phrase to a [GazeZone] for the directional words, bilingual
/// (English + a few Filipino equivalents). "back" means the *previous* item
/// (left); leaving the screen uses "go back" / "exit" (see [resolveVoiceCommand]).
GazeZone? voiceZoneFor(String text) {
  if (_has(text, ['next', 'forward', 'right', 'kanan', 'susunod'])) {
    return GazeZone.right;
  }
  if (_has(text, ['previous', 'prev', 'left', 'kaliwa', 'back'])) {
    return GazeZone.left;
  }
  if (_has(text, ['up', 'taas'])) return GazeZone.up;
  if (_has(text, ['down', 'baba'])) return GazeZone.down;
  return null;
}

/// Pure mapping from a recognised phrase to an app action — the unit-tested
/// heart of voice control. Order: global commands (scroll / leave screen), then
/// a directional word → the action on that edge, then a fuzzy match against the
/// action labels (so "flip", "hear", "speak", "choose" work too).
VoiceCommandResult resolveVoiceCommand(String spoken, List<GazeAction> actions) {
  final t = spoken.trim().toLowerCase();
  if (t.isEmpty) return VoiceCommandResult.none;

  // ── Global commands ──
  if (t.contains('scroll')) {
    if (_has(t, ['up', 'taas'])) {
      return const VoiceCommandResult(VoiceIntent.scrollUp);
    }
    if (_has(t, ['down', 'baba'])) {
      return const VoiceCommandResult(VoiceIntent.scrollDown);
    }
  }
  if (_has(t, ['go back', 'exit', 'close', 'cancel', 'umalis', 'isara'])) {
    return const VoiceCommandResult(VoiceIntent.goBack);
  }

  // ── Directional word → the action on that edge ──
  final zone = voiceZoneFor(t);
  if (zone != null) {
    final i = actions.indexWhere((a) => a.zone == zone && a.enabled);
    if (i >= 0) return VoiceCommandResult(VoiceIntent.action, i);
  }

  // ── Label match (e.g. "flip", "hear", "speak", "choose") ──
  for (var i = 0; i < actions.length; i++) {
    final a = actions[i];
    if (!a.enabled) continue;
    final label = a.label.toLowerCase();
    final useFuzzy = label.length >= 4; // avoid false hits on tiny labels
    if (t == label ||
        t.contains(label) ||
        (useFuzzy && SttService.isFuzzyMatch(t, label))) {
      return VoiceCommandResult(VoiceIntent.action, i);
    }
  }

  return VoiceCommandResult.none;
}
