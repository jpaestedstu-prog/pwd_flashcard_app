import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/accessibility/stt_service.dart';

/// Keeps the microphone listening for short spoken commands and reports each
/// heard phrase via [onCommand]. Wraps the session-based [SttService] in a poll
/// loop that re-arms whenever recognition stops (it listens in short bursts),
/// so the learner can speak a command at any time.
///
/// **Dispatch model (why this isn't just "wait for the final result"):** on
/// real devices many sessions never deliver a final result — the recogniser
/// kills them with `error_no_match` / `error_speech_timeout` even after
/// producing partial transcripts, and a final otherwise only lands seconds
/// after the speaker pauses. So commands are fired from the **first stable
/// partial** ([_stableAfter] with no hypothesis change), and whatever is still
/// undispatched is **flushed when the session dies**. A session's transcript
/// accumulates ("left … right"), so after a dispatch only the *new words* are
/// fired next, and a re-delivery of the same utterance (the final following a
/// dispatched partial, or a re-spelled hypothesis like "lift" → "left") is
/// deduplicated instead of firing twice.
///
/// **Re-arm pacing:** the poll is fast so the gap between bursts stays small,
/// but when the recogniser *rejects* sessions (`error_client` storms — seen on
/// real devices: each session dies ~50 ms after arming), re-arming full speed
/// only feeds the storm. A session that dies almost immediately without ever
/// producing a result counts as a rejection, and re-arming backs off
/// exponentially (~0.8 s → ~4.8 s) until a session survives again.
///
/// A `ChangeNotifier` so a screen can show a small "listening / last heard"
/// indicator. The STT plumbing lives here; the *meaning* of a phrase is the
/// pure `resolveDpadVoiceCommand` / `resolveVoiceCommand` (unit-tested
/// separately).
class VoiceCommandController extends ChangeNotifier {
  VoiceCommandController({
    required SttService stt,
    required this.locale,
    required this.onCommand,
  }) : _stt = stt;

  final SttService _stt;

  /// 'en-US' or 'fil-PH'.
  final String locale;

  /// Called with each heard phrase (a stable partial, the new tail of an
  /// accumulating transcript, or a dying session's last words).
  final void Function(String text) onCommand;

  /// Re-arm poll interval — short, so the dead gap between recognition bursts
  /// (when a spoken word would fall on deaf ears) stays small. Also the unit
  /// the rejection backoff counts in.
  static const Duration _rearmEvery = Duration(milliseconds: 400);

  /// How long a partial transcript must sit unchanged before it is dispatched.
  /// Short enough to feel immediate; long enough that a mid-word hypothesis
  /// ("lef…") isn't fired prematurely.
  static const Duration _stableAfter = Duration(milliseconds: 700);

  /// A session that ends within this many poll ticks *without producing any
  /// result* was rejected by the recogniser, not spoken into.
  static const int _rejectedWithinTicks = 2;

  /// How long to wait for the platform to confirm a listen start. During an
  /// error storm the confirmation can simply never arrive — without this the
  /// awaited start wedges the `_arming` guard and voice dies silently.
  static const Duration _startTimeout = Duration(seconds: 4);

  /// A session alive this many ticks (~15 s) without producing any result is
  /// a zombie holding the microphone (a healthy silent session is killed by
  /// the engine after a few seconds) — cancel it so the loop can re-arm.
  static const int _zombieTicks = 37;

  /// After this many *consecutive* rejections, re-listening clearly isn't
  /// recovering the recogniser — fully recreate it ([SttService.reset]) before
  /// the next attempt. The plugin can't re-bind the same instance, so a wedged
  /// client-side recogniser (`error_client` on every session) only comes back
  /// this way.
  static const int _resetAfterRejections = 4;

  bool _available = false;
  bool _initDone = false;
  bool _arming = false;
  bool _disposed = false;
  String _lastHeard = '';
  Timer? _poll;

  /// Debounce for stable-partial dispatch.
  Timer? _stable;

  /// Latest transcript not yet dispatched (cleared on flush).
  String _pending = '';

  /// The transcript already dispatched in the current session — the baseline
  /// for suffix extraction and duplicate suppression. Reset per session so a
  /// command repeated in the *next* burst ("left" … "left") fires again.
  String _dispatched = '';

  /// Session health, for the rejection backoff.
  bool _armed = false;
  bool _gotResult = false;
  int _ticksAlive = 0;
  int _failStreak = 0;
  int _cooldownTicks = 0;

  /// Consecutive rejections since the recogniser was last recreated — drives
  /// the [SttService.reset] recovery.
  int _rejectionsSinceReset = 0;

  bool get isListening => _stt.isListening;
  bool get available => _available;

  /// True when init finished and the microphone is definitely not usable
  /// (permission denied / no recognizer) — lets the status chip say so instead
  /// of a misleading "Voice ready".
  bool get unavailable => _initDone && !_available;

  String get lastHeard => _lastHeard;

  Future<void> start() async {
    _available = await _stt.init();
    _initDone = true;
    if (_disposed || !_available) {
      _notify();
      return;
    }
    _poll = Timer.periodic(_rearmEvery, (_) => _tick());
    _ensureListening();
    _notify();
  }

  void _tick() {
    if (_stt.isListening) {
      _ticksAlive++;
      if (!_gotResult && _ticksAlive > _zombieTicks) {
        _log('zombie session ($_ticksAlive ticks, no results) — cancelling');
        _stt.cancel();
      }
      return;
    }
    // A session that ended without a final result (error_no_match /
    // error_speech_timeout kill it silently) still carries its last partial —
    // dispatch it now so the spoken command isn't lost.
    _flushPending();
    _noteSessionEnd();
    if (_cooldownTicks > 0) {
      _cooldownTicks--;
      return;
    }
    _ensureListening();
  }

  /// Bookkeeps the session that just ended: a near-instant death with no
  /// results is a recogniser rejection → back off before re-arming
  /// (0.8 s, 1.6 s, 3.2 s, then 4.8 s while the storm lasts). Even after a
  /// healthy session, wait one settle tick: re-arming within ~50 ms of the
  /// platform's 'done' is exactly what provokes `error_client` rejections.
  void _noteSessionEnd() {
    if (!_armed) return;
    _armed = false;
    if (!_gotResult && _ticksAlive <= _rejectedWithinTicks) {
      _registerRejection('session rejected');
    } else {
      _failStreak = 0;
      _rejectionsSinceReset = 0;
      _cooldownTicks = 1;
    }
  }

  void _registerRejection(String cause) {
    _failStreak = (_failStreak + 1).clamp(0, 4);
    _rejectionsSinceReset++;
    _cooldownTicks = (2 << (_failStreak - 1)).clamp(2, 12);
    _log('$cause (streak $_failStreak) — '
        'backing off ${_cooldownTicks * _rearmEvery.inMilliseconds} ms');
  }

  Future<void> _ensureListening() async {
    // _arming keeps poll ticks from stacking a second listen() on top of one
    // still starting up — the platform answers that with a busy error and can
    // wedge the whole session loop.
    if (_arming || _disposed || !_available || _stt.isListening) return;
    _arming = true;
    try {
      // Re-listening isn't recovering the recogniser — recreate it from
      // scratch (the only thing that re-binds a wedged client-side recogniser)
      // before trying again.
      if (_rejectionsSinceReset >= _resetAfterRejections) {
        _rejectionsSinceReset = 0;
        await _stt.reset();
        if (_disposed) return;
        _available = await _stt.init();
        if (!_available) return;
      }
      // New session → fresh transcript accumulation.
      _dispatched = '';
      await _stt
          .startListening(
            locale: locale,
            onResult: _onResult,
          )
          .timeout(_startTimeout);
      _armed = true;
      _gotResult = false;
      _ticksAlive = 0;
      _notify();
    } on TimeoutException {
      // The platform never confirmed the session. Reset the plugin so the
      // half-open session can't hold the microphone, and pace the retry.
      _stt.cancel();
      _registerRejection('listen start timed out');
    } catch (_) {
      // A failed session just gets retried by the next poll tick.
    } finally {
      _arming = false;
    }
  }

  void _onResult(String text, bool isFinal) {
    if (_disposed || text.trim().isEmpty) return;
    _log('heard "$text" (final: $isFinal)');
    _gotResult = true;
    _lastHeard = text;
    _notify();
    _pending = text;
    _stable?.cancel();
    if (isFinal) {
      _flushPending();
    } else {
      // Fire once the hypothesis stops changing — a command responds in under
      // a second instead of waiting out the recogniser's pause window.
      _stable = Timer(_stableAfter, _flushPending);
    }
  }

  void _flushPending() {
    _stable?.cancel();
    _stable = null;
    final text = _pending.trim();
    if (text.isEmpty || _disposed) return;
    _pending = '';

    var phrase = text;
    if (_dispatched.isNotEmpty) {
      final lower = text.toLowerCase();
      final done = _dispatched.toLowerCase();
      if (lower == done || SttService.isFuzzyMatch(lower, done)) {
        // The same utterance re-delivered: the final result following an
        // already-dispatched partial, or a re-spelled hypothesis
        // ("lift" → "left"). Firing again would move the cursor twice.
        _log('skip duplicate "$text"');
        return;
      }
      if (lower.startsWith(done)) {
        // The session transcript accumulates — only the new words are the
        // next command ("left … right" must not re-fire "left").
        phrase = text.substring(_dispatched.length).trim();
        if (phrase.isEmpty) return;
      }
    }
    _dispatched = text;
    _log('dispatch "$phrase"');
    onCommand(phrase);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('VoiceCmd $message');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _stable?.cancel();
    _stt.cancel();
    super.dispose();
  }
}
