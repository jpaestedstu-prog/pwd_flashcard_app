import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/local/hive_service.dart';

/// What picked a control.
enum GazeSelectBy {
  blink,
  switchButton,

  /// Keeping still on a highlight (look and hold).
  rest,

  /// A held head turn: looking up to choose, or holding toward one of a
  /// game's edge targets.
  headHold,
  voice,
}

/// One learner's gaze use on one day — the measurements a study of Gaze
/// Control needs, kept as plain counters so they mean the same thing on every
/// tablet:
///
///  * **time used** — the time between the learner's own inputs (moves,
///    choices, Backs, keys), leaving out any pause longer than
///    [GazeMetrics.idleGap]: gaze left running with nobody using it (a tablet
///    put down on Home, the app in the background) is not use, and counting
///    it would make every per-minute figure meaningless;
///  * **moves** / **scan steps** — highlight moves by head (or voice) and by
///    the scanner;
///  * **selections**, split by what picked them;
///  * **time to select** — from the first move after the previous selection
///    to the next selection (the effort one choice took);
///  * **backs** and **mis-selections** — a Back within [misSelectWindow] of a
///    selection counts as a mis-selection (the learner opened the wrong thing).
class GazeDayStats {
  GazeDayStats(this.date);

  /// `yyyy-MM-dd`, local time.
  final String date;

  int activeMs = 0;
  int moves = 0;
  int scanSteps = 0;
  int selections = 0;
  int blinkSelects = 0;
  int switchSelects = 0;
  int restSelects = 0;
  int headHoldSelects = 0;
  int voiceSelects = 0;
  int backs = 0;
  int misSelections = 0;
  int keyboardKeys = 0;
  int calibrations = 0;
  int latencyMsSum = 0;
  int latencyCount = 0;

  /// Selections per active minute, or null with no active time.
  double? get selectionsPerMinute =>
      activeMs <= 0 ? null : selections / (activeMs / 60000);

  /// Average seconds from first move to selection, or null with no data.
  double? get avgSecondsToSelect =>
      latencyCount == 0 ? null : latencyMsSum / latencyCount / 1000;

  /// Share of selections that were undone straight away, or null.
  double? get misSelectionRate =>
      selections == 0 ? null : misSelections / selections;

  bool get isEmpty => activeMs == 0 && moves == 0 && selections == 0;

  void addAll(GazeDayStats o) {
    activeMs += o.activeMs;
    moves += o.moves;
    scanSteps += o.scanSteps;
    selections += o.selections;
    blinkSelects += o.blinkSelects;
    switchSelects += o.switchSelects;
    restSelects += o.restSelects;
    headHoldSelects += o.headHoldSelects;
    voiceSelects += o.voiceSelects;
    backs += o.backs;
    misSelections += o.misSelections;
    keyboardKeys += o.keyboardKeys;
    calibrations += o.calibrations;
    latencyMsSum += o.latencyMsSum;
    latencyCount += o.latencyCount;
  }

  Map<String, int> toMap() => {
    'activeMs': activeMs,
    'moves': moves,
    'scanSteps': scanSteps,
    'selections': selections,
    'blinkSelects': blinkSelects,
    'switchSelects': switchSelects,
    'restSelects': restSelects,
    'headHoldSelects': headHoldSelects,
    'voiceSelects': voiceSelects,
    'backs': backs,
    'misSelections': misSelections,
    'keyboardKeys': keyboardKeys,
    'calibrations': calibrations,
    'latencyMsSum': latencyMsSum,
    'latencyCount': latencyCount,
  };

  factory GazeDayStats.fromMap(String date, Map map) {
    int v(String k) => (map[k] is num) ? (map[k] as num).toInt() : 0;
    return GazeDayStats(date)
      ..activeMs = v('activeMs')
      ..moves = v('moves')
      ..scanSteps = v('scanSteps')
      ..selections = v('selections')
      ..blinkSelects = v('blinkSelects')
      ..switchSelects = v('switchSelects')
      ..restSelects = v('restSelects')
      ..headHoldSelects = v('headHoldSelects')
      ..voiceSelects = v('voiceSelects')
      ..backs = v('backs')
      ..misSelections = v('misSelections')
      ..keyboardKeys = v('keyboardKeys')
      ..calibrations = v('calibrations')
      ..latencyMsSum = v('latencyMsSum')
      ..latencyCount = v('latencyCount');
  }
}

/// Where the counters are kept between launches. The app installs a Hive
/// store at startup; without one (tests) everything stays in memory.
abstract class GazeMetricsStore {
  /// The saved days for [profileId] as stored (date → counters), or null.
  Map? load(String profileId);
  void save(String profileId, Map<String, Map<String, int>> days);

  /// Drops everything kept for [profileId].
  void remove(String profileId);
}

/// Keeps each learner's counters in the per-profile settings, beside their
/// gaze settings.
class HiveGazeMetricsStore implements GazeMetricsStore {
  const HiveGazeMetricsStore();

  static const String key = 'gazeMetrics';

  @override
  Map? load(String profileId) {
    final raw = HiveService.getProfileSetting(key, profileId: profileId);
    return raw is Map ? raw : null;
  }

  @override
  void save(String profileId, Map<String, Map<String, int>> days) {
    HiveService.saveProfileSetting(key, days, profileId: profileId).ignore();
  }

  @override
  void remove(String profileId) {
    HiveService.saveProfileSetting(key, null, profileId: profileId).ignore();
  }
}

/// The app-wide recorder. Gaze scopes report what the learner does; the
/// Gaze Control settings and the teacher / parent view read it back.
class GazeMetrics {
  GazeMetrics._();

  /// The single, app-wide recorder.
  static final GazeMetrics instance = GazeMetrics._();

  /// A Back this soon after a selection counts as a mis-selection.
  static const Duration misSelectWindow = Duration(seconds: 4);

  /// Days kept per learner.
  static const int keepDays = 120;

  GazeMetricsStore? store;

  /// Injectable for tests.
  DateTime Function() clock = DateTime.now;

  final Map<String, Map<String, GazeDayStats>> _profiles = {};

  /// Pauses longer than this between a learner's inputs are not counted as
  /// time using gaze, and restart the time-to-choose clock.
  static const Duration idleGap = Duration(minutes: 2);

  /// Sessions currently running (one per gaze scope with a live input).
  final Map<Object, String> _sessions = {};
  String? _activeProfile;

  /// The learner's previous input, for time used.
  DateTime? _lastInputAt;

  DateTime? _firstMoveAt;
  DateTime? _lastSelectAt;
  Timer? _flushTimer;

  static String _dateKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  Map<String, GazeDayStats> _daysOf(String profileId) {
    return _profiles.putIfAbsent(profileId, () {
      final out = <String, GazeDayStats>{};
      try {
        final raw = store?.load(profileId);
        raw?.forEach((date, map) {
          if (date is String && map is Map) {
            out[date] = GazeDayStats.fromMap(date, map);
          }
        });
      } catch (_) {}
      return out;
    });
  }

  GazeDayStats? _today() {
    final id = _activeProfile;
    if (id == null) return null;
    final key = _dateKey(clock());
    return _daysOf(id).putIfAbsent(key, () => GazeDayStats(key));
  }

  // ── Sessions ───────────────────────────────────────────────────────────

  /// A gaze scope's input came up for [profileId]. Returns the token for
  /// [end]. Events are counted while any session is open.
  Object begin(String? profileId) {
    final token = Object();
    if (profileId == null) return token;
    if (_activeProfile != null && _activeProfile != profileId) {
      // A different learner: the previous learner's use has ended.
      _persist();
      _forgetPending();
    }
    _sessions[token] = profileId;
    _activeProfile = profileId;
    _flushTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _persist(),
    );
    return token;
  }

  /// The scope behind [token] stood down.
  void end(Object token) {
    if (_sessions.remove(token) == null) return;
    if (_sessions.isEmpty) {
      // Gaze is off now: the time until it comes back is not use.
      _forgetPending();
      _flushTimer?.cancel();
      _flushTimer = null;
      _persist();
    }
  }

  /// Drops the clocks that run between inputs (time used, time to choose,
  /// the mis-selection window).
  void _forgetPending() {
    _lastInputAt = null;
    _firstMoveAt = null;
    _lastSelectAt = null;
  }

  /// The learner did something at [now]. The time since their previous
  /// input is time using gaze — unless it was a pause longer than [idleGap],
  /// which is not use, and also means the choice in progress has no
  /// meaningful time-to-choose.
  void _input(GazeDayStats day, DateTime now) {
    final last = _lastInputAt;
    if (last != null) {
      final gap = now.difference(last);
      if (gap > idleGap) {
        _firstMoveAt = null;
      } else if (gap > Duration.zero) {
        day.activeMs += gap.inMilliseconds;
      }
    }
    _lastInputAt = now;
  }

  // ── Events ─────────────────────────────────────────────────────────────

  bool get _recording => _sessions.isNotEmpty;

  /// The highlight moved by head, voice or traversal.
  void moved() {
    final day = _today();
    if (!_recording || day == null) return;
    final now = clock();
    _input(day, now);
    day.moves++;
    _firstMoveAt ??= now;
  }

  /// The scanner stepped. Not an input — the scanner steps by itself, with
  /// or without anyone there — but it starts the time-to-choose clock.
  void scanned() {
    final day = _today();
    if (!_recording || day == null) return;
    day.scanSteps++;
    _firstMoveAt ??= clock();
  }

  /// A control was picked.
  void selected(GazeSelectBy by) {
    final day = _today();
    if (!_recording || day == null) return;
    final now = clock();
    _input(day, now);
    day.selections++;
    switch (by) {
      case GazeSelectBy.blink:
        day.blinkSelects++;
      case GazeSelectBy.switchButton:
        day.switchSelects++;
      case GazeSelectBy.rest:
        day.restSelects++;
      case GazeSelectBy.headHold:
        day.headHoldSelects++;
      case GazeSelectBy.voice:
        day.voiceSelects++;
    }
    final first = _firstMoveAt;
    if (first != null) {
      day.latencyMsSum += now.difference(first).inMilliseconds;
      day.latencyCount++;
    }
    _firstMoveAt = null;
    _lastSelectAt = now;
  }

  /// The learner left a surface (Back pill, exit row, "go back").
  void backed() {
    final day = _today();
    if (!_recording || day == null) return;
    final now = clock();
    _input(day, now);
    day.backs++;
    final last = _lastSelectAt;
    if (last != null && now.difference(last) <= misSelectWindow) {
      day.misSelections++;
    }
    _lastSelectAt = null;
  }

  /// A key typed on the gaze keyboard.
  void keyTyped() {
    final day = _today();
    if (!_recording || day == null) return;
    _input(day, clock());
    day.keyboardKeys++;
  }

  /// A resting position was captured for [profileId].
  void calibrated(String profileId) {
    final key = _dateKey(clock());
    _daysOf(profileId).putIfAbsent(key, () => GazeDayStats(key)).calibrations++;
    _persist(profileId);
  }

  // ── Reading ────────────────────────────────────────────────────────────

  /// The last [days] days for [profileId], oldest first, including empty days.
  List<GazeDayStats> recentDays(String profileId, {int days = 7}) {
    final all = _daysOf(profileId);
    final today = clock();
    return [
      for (var i = days - 1; i >= 0; i--)
        all[_dateKey(today.subtract(Duration(days: i)))] ??
            GazeDayStats(_dateKey(today.subtract(Duration(days: i)))),
    ];
  }

  /// Every recorded day for [profileId], oldest first.
  List<GazeDayStats> allDays(String profileId) {
    return _daysOf(profileId).values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// The last [days] days summed.
  GazeDayStats total(String profileId, {int days = 7}) {
    final sum = GazeDayStats('total');
    for (final d in recentDays(profileId, days: days)) {
      sum.addAll(d);
    }
    return sum;
  }

  /// Every recorded day as CSV, oldest first — for a study's data sheet.
  String csv(String profileId, {String learner = ''}) {
    final days = allDays(profileId);
    String n(double? v, [int digits = 2]) =>
        v == null ? '' : v.toStringAsFixed(digits);
    final rows = <String>[
      'date,learner,active_minutes,moves,scan_steps,selections,'
          'selections_per_minute,avg_seconds_to_select,backs,mis_selections,'
          'blink,switch,hold_still,head_hold,voice,keyboard_keys,calibrations',
      for (final d in days)
        if (!d.isEmpty || d.calibrations > 0)
          [
            d.date,
            '"${learner.replaceAll('"', '""')}"',
            n(d.activeMs / 60000, 1),
            d.moves,
            d.scanSteps,
            d.selections,
            n(d.selectionsPerMinute),
            n(d.avgSecondsToSelect),
            d.backs,
            d.misSelections,
            d.blinkSelects,
            d.switchSelects,
            d.restSelects,
            d.headHoldSelects,
            d.voiceSelects,
            d.keyboardKeys,
            d.calibrations,
          ].join(','),
    ];
    return '${rows.join('\n')}\n';
  }

  void _persist([String? profileId]) {
    final id = profileId ?? _activeProfile;
    final s = store;
    if (id == null || s == null) return;
    final all = _daysOf(id);
    // Keep the most recent [keepDays].
    final keys = all.keys.toList()..sort();
    for (final k in keys.take((keys.length - keepDays).clamp(0, keys.length))) {
      all.remove(k);
    }
    try {
      s.save(id, {for (final e in all.entries) e.key: e.value.toMap()});
    } catch (_) {}
  }

  /// Saves now.
  void flush() => _persist();

  /// The app went to the background: save, and stop the clocks — the time
  /// away is not use, however the learner comes back.
  void pause() {
    _forgetPending();
    _persist();
  }

  /// Forgets everything recorded for [profileId], here and in the store —
  /// the debug bridge clears what a test run recorded on a test profile.
  void forget(String profileId) {
    _profiles.remove(profileId);
    try {
      store?.remove(profileId);
    } catch (_) {}
  }

  /// Test seam.
  @visibleForTesting
  void reset() {
    _profiles.clear();
    _sessions.clear();
    _activeProfile = null;
    _forgetPending();
    _flushTimer?.cancel();
    _flushTimer = null;
    store = null;
    clock = DateTime.now;
  }
}
