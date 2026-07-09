import '../../../core/accessibility/stt_service.dart';
import '../models/gaze_action.dart';
import '../models/gaze_models.dart';

/// What a spoken command resolves to on an edge-action ([GazeScope]) screen.
enum VoiceIntent { action, select, scrollUp, scrollDown, goBack, none }

/// Result of [resolveVoiceCommand]: an [intent] and, when it's
/// [VoiceIntent.action], the index of the matched action.
class VoiceCommandResult {
  final VoiceIntent intent;
  final int actionIndex;
  const VoiceCommandResult(this.intent, [this.actionIndex = -1]);

  static const VoiceCommandResult none = VoiceCommandResult(VoiceIntent.none);
}

// ─── Spoken vocabulary (English + Filipino) ───
//
// The D-pad movement words mirror the head gestures: saying "left" does what
// looking left does. "next"/"back" prefer a matching labelled button (the
// flashcard viewer's Next / Previous) and fall back to a cursor move, so the
// same word stays useful on hub grids that have no such button.
//
// Some entries are recogniser homophones rather than real words: an en-US
// recogniser transcribes "right" as "write" and Filipino "kanan" as
// "cannon"/"canon" often enough that ignoring them makes the command feel
// broken. (Near-misses one letter away — "lift", "dawn" — are caught by the
// fuzzy rule in [_isPhrase] instead.)
const _nextWords = ['next', 'forward', 'susunod', 'sunod'];
const _prevWords = ['previous', 'prev', 'back', 'balik', 'nakaraan'];
const _leftWords = ['left', 'kaliwa'];
const _rightWords = ['right', 'write', 'kanan', 'cannon', 'canon'];
const _upWords = ['up', 'taas', 'itaas', 'pataas'];
const _downWords = ['down', 'baba', 'ibaba', 'pababa'];
const _selectWords = [
  'select', 'open', 'choose', 'press', 'enter', 'activate', 'tap', 'click',
  'ok', 'okay', 'this one', 'open it', 'select this', // English
  'sige', 'piliin', 'buksan', 'pindutin', 'ito', // Filipino
];
const _backOutWords = ['go back', 'exit', 'close', 'cancel', 'umalis', 'isara'];

bool _has(String text, List<String> words) =>
    words.any((w) => text == w || text.contains(w));

/// True when [text] contains one of [words] as a whole word — so "groups"
/// doesn't count as "up" and "countdown" doesn't count as "down". Lookarounds
/// (not consuming boundary chars) so adjacent occurrences all match.
bool _hasWord(String text, List<String> words) =>
    words.any((w) => _wordRegExp(w).hasMatch(text));

RegExp _wordRegExp(String word) =>
    RegExp('(?<![a-z0-9])${RegExp.escape(word)}(?![a-z0-9])');

/// True when the whole phrase [t] *is* one of [words], allowing the natural
/// carrier verbs ("move left", "go up", "look right", "sa kaliwa") — used for
/// the movement/select commands so a longer phrase (a tile or story name that
/// happens to contain "up") still reaches the label matcher instead.
///
/// Tolerates what recognisers actually emit for a single spoken word:
/// punctuation/casing ("Left."), a split Filipino word ("kali wa" → kaliwa),
/// and a same-length near-miss one edit away ("lift" → left, "dawn" → down —
/// same length only, so "black" can never pass as "back").
bool _isPhrase(String t, List<String> words) {
  final clean = t
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final compact = clean.replaceAll(' ', '');
  for (final w in words) {
    for (final form in [w, 'move $w', 'go $w', 'look $w', 'sa $w']) {
      if (t == form || clean == form) return true;
    }
    final wCompact = w.replaceAll(' ', '');
    if (compact == wCompact) return true;
    if (wCompact.length >= 4 &&
        compact.length == wCompact.length &&
        SttService.isFuzzyMatch(compact, wCompact)) {
      return true;
    }
  }
  return false;
}

/// Maps a spoken phrase to a [GazeZone] for the directional words, bilingual
/// (English + a few Filipino equivalents). "back" means the *previous* item
/// (left); leaving the screen uses "go back" / "exit" (see [resolveVoiceCommand]).
GazeZone? voiceZoneFor(String text) {
  if (_hasWord(text, _nextWords) || _hasWord(text, _rightWords)) {
    return GazeZone.right;
  }
  if (_hasWord(text, _prevWords) || _hasWord(text, _leftWords)) {
    return GazeZone.left;
  }
  if (_hasWord(text, _upWords)) return GazeZone.up;
  if (_hasWord(text, _downWords)) return GazeZone.down;
  return null;
}

/// Pure mapping from a recognised phrase to an app action — the unit-tested
/// heart of voice control on edge-action screens. Order: global commands
/// (scroll / leave screen), then a directional word → the action on that edge,
/// then a fuzzy match against the action labels (so "flip", "hear", "speak",
/// "choose" work too), then the select words → a blink (fires the screen's
/// blink action, mirroring the camera).
VoiceCommandResult resolveVoiceCommand(String spoken, List<GazeAction> actions) {
  final t = spoken.trim().toLowerCase();
  if (t.isEmpty) return VoiceCommandResult.none;

  // ── Global commands ──
  final scroll = _scrollIntentFor(t);
  if (scroll != null) {
    return VoiceCommandResult(
      scroll == DpadVoiceIntent.scrollUp
          ? VoiceIntent.scrollUp
          : VoiceIntent.scrollDown,
    );
  }
  if (_has(t, _backOutWords)) {
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
    if (_labelMatches(t, a.label.toLowerCase())) {
      return VoiceCommandResult(VoiceIntent.action, i);
    }
  }

  // ── "select" / "piliin" → the screen's blink action ──
  if (_isPhrase(t, _selectWords)) {
    return const VoiceCommandResult(VoiceIntent.select);
  }

  return VoiceCommandResult.none;
}

/// "scroll down", "i-scroll pababa", … → a scroll intent; bare "scroll"
/// defaults to down. Null when the phrase isn't a scroll command.
DpadVoiceIntent? _scrollIntentFor(String t) {
  if (!t.contains('scroll')) return null;
  if (_hasWord(t, _upWords)) return DpadVoiceIntent.scrollUp;
  if (_hasWord(t, _downWords)) return DpadVoiceIntent.scrollDown;
  return DpadVoiceIntent.scrollDown;
}

/// True when the spoken phrase [t] names the control [label] — an exact match, a
/// substring either way (so "flip the card" opens "Flip", and "flip" opens
/// "I-flip"; the spoken word must be ≥ 4 chars so "no" can't hit "Notebook"),
/// or a near-miss the recogniser mis-heard (fuzzy, only for labels long enough
/// to be safe).
bool _labelMatches(String t, String label) {
  if (t == label || t.contains(label)) return true;
  if (t.length >= 4 && label.contains(t)) return true;
  return label.length >= 4 && SttService.isFuzzyMatch(t, label);
}

/// A control that voice can address by its visible [label]; [enabled] mirrors the
/// matching touch button's greyed state (a disabled target is skipped). Lets the
/// pure [resolveDpadVoiceCommand] resolver stay decoupled from the `GazeDpadCell`
/// widget it runs against.
abstract interface class VoiceTarget {
  String get label;
  bool get enabled;
}

/// What a spoken command resolves to in a D-pad ([GazeDpadScope] /
/// `NavGazeScope`) screen. [activate] fires a specific cell by label;
/// the four move intents and [select] mirror the head D-pad (move the
/// highlight, then commit), so voice can drive exactly what the camera drives.
enum DpadVoiceIntent {
  activate,
  select,
  moveLeft,
  moveRight,
  moveUp,
  moveDown,
  scrollUp,
  scrollDown,
  goBack,
  none,
}

/// Result of [resolveDpadVoiceCommand]: an [intent] and, when it's
/// [DpadVoiceIntent.activate], the [row]/[col] of the target to fire.
class DpadVoiceResult {
  final DpadVoiceIntent intent;
  final int row;
  final int col;
  const DpadVoiceResult(this.intent, [this.row = -1, this.col = -1]);

  static const DpadVoiceResult none = DpadVoiceResult(DpadVoiceIntent.none);
}

/// Maps a spoken phrase to a labelled D-pad [VoiceTarget] (e.g. the flashcard
/// viewer's bottom bar, a hub's feature tiles), a D-pad **cursor move**
/// ("left" / "up" / "kanan"…), a **select** ("select", "piliin", …) that
/// commits the focused cell like a blink, or a global scroll / leave-screen
/// intent.
///
/// Order:
///  1. global commands — scroll, then "go back" / "exit";
///  2. "next" / "previous" (and Filipino equivalents) → a *button actually
///     labelled* that way (the viewer's Next / Previous), bilingually;
///  3. a bare movement/select phrase ("left", "move up", "select") → the
///     matching D-pad intent, exactly like the head gestures;
///  4. a fuzzy match against the target labels ("games", "flip", a story's
///     title) → activate that cell;
///  5. a longer phrase that still *contains* a directional word ("one step
///     back") → the movement fallback.
DpadVoiceResult resolveDpadVoiceCommand(
  String spoken,
  List<List<VoiceTarget>> rows,
) {
  final t = spoken.trim().toLowerCase();
  if (t.isEmpty) return DpadVoiceResult.none;

  // ── Global commands ──
  final scroll = _scrollIntentFor(t);
  if (scroll != null) return DpadVoiceResult(scroll);
  if (_has(t, _backOutWords)) {
    return const DpadVoiceResult(DpadVoiceIntent.goBack);
  }

  // ── "next" / "previous" → a button literally labelled that way ──
  // (bilingual, so "back" reaches "Nakaraan" and "susunod" reaches "Next").
  // Only short labels qualify — a story titled "The Way Back Home" is a label
  // match, not a Previous button.
  final wantsNext = _hasWord(t, _nextWords);
  final wantsPrev = _hasWord(t, _prevWords);
  if (wantsNext || wantsPrev) {
    final hit = _findButton(rows, wantsNext ? _nextWords : _prevWords);
    if (hit != null) return hit;
  }

  // ── Bare movement / select phrases — the spoken D-pad ──
  final exactMove = _moveIntentFor(t, exact: true);
  if (exactMove != null) return DpadVoiceResult(exactMove);
  if (_isPhrase(t, _selectWords)) {
    return const DpadVoiceResult(DpadVoiceIntent.select);
  }

  // ── Match a target by label ──
  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final target = row[c];
      if (!target.enabled) continue;
      if (_labelMatches(t, target.label.toLowerCase())) {
        return DpadVoiceResult(DpadVoiceIntent.activate, r, c);
      }
    }
  }

  // ── Longer phrases that still contain a directional word ──
  final looseMove = _moveIntentFor(t, exact: false);
  if (looseMove != null) return DpadVoiceResult(looseMove);

  return DpadVoiceResult.none;
}

/// A movement intent for [t]: with [exact] the whole phrase must be the
/// command ("left", "move up"), otherwise a whole-word occurrence anywhere is
/// enough (the post-label-match fallback). "next"/"back" map onto ▶ / ◀ so
/// they stay useful on grids without a Next / Previous button.
DpadVoiceIntent? _moveIntentFor(String t, {required bool exact}) {
  if (exact) {
    if (_isPhrase(t, _leftWords) || _isPhrase(t, _prevWords)) {
      return DpadVoiceIntent.moveLeft;
    }
    if (_isPhrase(t, _rightWords) || _isPhrase(t, _nextWords)) {
      return DpadVoiceIntent.moveRight;
    }
    if (_isPhrase(t, _upWords)) return DpadVoiceIntent.moveUp;
    if (_isPhrase(t, _downWords)) return DpadVoiceIntent.moveDown;
    return null;
  }
  // Loose fallback: a recogniser session's transcript accumulates, so one
  // final can hold several commands ("left … right"). The *most recently
  // spoken* directional wins, not the first in list order.
  var best = -1;
  DpadVoiceIntent? intent;
  void consider(List<String> words, DpadVoiceIntent candidate) {
    final at = _lastWordMatch(t, words);
    if (at > best) {
      best = at;
      intent = candidate;
    }
  }

  consider(_leftWords, DpadVoiceIntent.moveLeft);
  consider(_prevWords, DpadVoiceIntent.moveLeft);
  consider(_rightWords, DpadVoiceIntent.moveRight);
  consider(_nextWords, DpadVoiceIntent.moveRight);
  consider(_upWords, DpadVoiceIntent.moveUp);
  consider(_downWords, DpadVoiceIntent.moveDown);
  return intent;
}

/// Start index of the last whole-word occurrence of any of [words] in [text],
/// or -1 when none occurs.
int _lastWordMatch(String text, List<String> words) {
  var best = -1;
  for (final w in words) {
    for (final m in _wordRegExp(w).allMatches(text)) {
      if (m.start > best) best = m.start;
    }
  }
  return best;
}

/// Finds an enabled target whose label is (essentially) one of [keywords] — an
/// exact label like "Next" / "Nakaraan", or a two-word one like "Next card".
/// Longer labels (story titles, tile names) never qualify.
DpadVoiceResult? _findButton(
  List<List<VoiceTarget>> rows,
  List<String> keywords,
) {
  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final target = row[c];
      if (!target.enabled) continue;
      final tokens = target.label
          .toLowerCase()
          .split(RegExp(r'[^a-z0-9]+'))
        ..removeWhere((s) => s.isEmpty);
      if (tokens.isEmpty || tokens.length > 2) continue;
      if (tokens.any(keywords.contains)) {
        return DpadVoiceResult(DpadVoiceIntent.activate, r, c);
      }
    }
  }
  return null;
}
